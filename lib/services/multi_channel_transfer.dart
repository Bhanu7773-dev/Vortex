/// Multi-channel file transfer engine inspired by HybridFileXfer.
///
/// Uses all available network interfaces (WiFi, USB tethering, Ethernet, etc.)
/// simultaneously to maximise throughput.  Files are split into 1 MB blocks,
/// distributed across channels by the sender, and reassembled in-order by the
/// receiver.
///
/// ┌────────┐   block queue   ┌──────────┐  TCP ch0  ┌──────────┐   per-channel   ┌────────┐
/// │ Reader │ ─────────────▶ │ Sender 0 │ ────────▶ │ Recvr 0  │ ──── queues ──▶│ Writer │
/// │ (file  │                 ├──────────┤  TCP ch1  ├──────────┤                 │ (merge │
/// │  I/O)  │                 │ Sender 1 │ ────────▶ │ Recvr 1  │                 │  sort) │
/// └────────┘                 └──────────┘           └──────────┘                 └────────┘

import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Size of each file block (1 MB) — matches single-channel chunk size.
/// Larger blocks reduce per-block overhead (header serialization, yield,
/// progress checks) which is critical for multi-channel throughput.
const int kBlockSize = 1024 * 1024;

/// Base port for multi-channel transfer sockets.  The receiver opens
/// [kMultiChannelBasePort + channelIndex] for each channel.
const int kMultiChannelBasePort = 46470;

/// Protocol identifiers sent as 2-byte headers in each block packet.
class TransferIds {
  static const int file = 0x0001;
  static const int folder = 0x0002;
  static const int eof = 0x0010;
  static const int interrupt = 0x0011;
  static const int readError = 0x0012;
  static const int writeError = 0x0013;
}

/// A single block of a file (or a directory marker) flowing through the
/// transfer pipeline.
class FileBlock implements Comparable<FileBlock> {
  final bool isFile;
  final int fileIndex;
  final String path;
  final int lastModified;
  final int totalSize;
  final int blockIndex;
  final Uint8List? data;

  FileBlock({
    required this.isFile,
    required this.fileIndex,
    required this.path,
    this.lastModified = 0,
    this.totalSize = 0,
    this.blockIndex = 0,
    this.data,
  });

  int get startPosition => kBlockSize * blockIndex;
  int get length => data?.length ?? 0;

  /// Sentinel blocks ─ used to signal channel completion or errors.
  static final endPoint = FileBlock(
    isFile: true,
    fileIndex: -1,
    path: 'END_POINT',
  );
  static final interruptFlag = FileBlock(
    isFile: true,
    fileIndex: -1,
    path: 'INTERRUPT',
  );
  static final readErrorFlag = FileBlock(
    isFile: true,
    fileIndex: -1,
    path: 'READ_ERROR',
  );
  static final writeErrorFlag = FileBlock(
    isFile: true,
    fileIndex: -1,
    path: 'WRITE_ERROR',
  );

  bool get isSentinel => fileIndex == -1;

  @override
  int compareTo(FileBlock other) {
    if (fileIndex != other.fileIndex) {
      return fileIndex.compareTo(other.fileIndex);
    }
    return blockIndex.compareTo(other.blockIndex);
  }
}

/// Describes one network interface available for transfer.
class ChannelEndpoint {
  final String name;
  final String ip;

  ChannelEndpoint({required this.name, required this.ip});

  Map<String, dynamic> toJson() => {'name': name, 'ip': ip};

  factory ChannelEndpoint.fromJson(Map<String, dynamic> j) =>
      ChannelEndpoint(name: j['name'] as String, ip: j['ip'] as String);
}

/// Returns all usable (non-loopback, non-virtual) IPv4 interface addresses.
Future<List<ChannelEndpoint>> enumerateInterfaces() async {
  final endpoints = <ChannelEndpoint>[];
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLinkLocal: false,
  );
  for (final iface in interfaces) {
    final name = iface.name.toLowerCase();
    if (name.startsWith('docker') ||
        name.startsWith('virbr') ||
        name.startsWith('veth') ||
        name.startsWith('br-') ||
        name.startsWith('vmnet') ||
        name.startsWith('tun') ||
        name.startsWith('tap')) {
      continue;
    }
    for (final addr in iface.addresses) {
      if (addr.isLoopback) continue;
      endpoints.add(ChannelEndpoint(name: iface.name, ip: addr.address));
    }
  }
  if (endpoints.isEmpty) {
    endpoints.add(ChannelEndpoint(name: 'any', ip: '0.0.0.0'));
  }
  return endpoints;
}

void _writeUint16(BytesBuilder bb, int v) {
  bb.addByte((v >> 8) & 0xFF);
  bb.addByte(v & 0xFF);
}

void _writeInt32(BytesBuilder bb, int v) {
  bb.addByte((v >> 24) & 0xFF);
  bb.addByte((v >> 16) & 0xFF);
  bb.addByte((v >> 8) & 0xFF);
  bb.addByte(v & 0xFF);
}

void _writeInt64(BytesBuilder bb, int v) {
  bb.addByte((v >> 56) & 0xFF);
  bb.addByte((v >> 48) & 0xFF);
  bb.addByte((v >> 40) & 0xFF);
  bb.addByte((v >> 32) & 0xFF);
  bb.addByte((v >> 24) & 0xFF);
  bb.addByte((v >> 16) & 0xFF);
  bb.addByte((v >> 8) & 0xFF);
  bb.addByte(v & 0xFF);
}

void _writeUTF(BytesBuilder bb, String s) {
  final bytes = utf8.encode(s);
  _writeInt32(bb, bytes.length);
  bb.add(bytes);
}

class _BinaryReader {
  final ListQueue<Uint8List> _chunks = ListQueue<Uint8List>();
  int _headOffset = 0;
  int _buffered = 0;
  late final StreamSubscription<List<int>> _sub;
  bool _closed = false;
  bool _paused = false;
  Object? _error;

  /// Completer that is resolved whenever new data arrives or the stream ends.
  Completer<void>? _waiter;

  _BinaryReader(Stream<List<int>> source) {
    _sub = source.listen(
      (data) {
        _chunks.addLast(Uint8List.fromList(data));
        _buffered += data.length;
        _waiter?.complete();
        _waiter = null;
      },
      onError: (e) {
        _error = e;
        _waiter?.completeError(e);
        _waiter = null;
      },
      onDone: () {
        _closed = true;
        _waiter?.complete();
        _waiter = null;
      },
    );
  }

  /// Wait until at least [n] bytes are available in the buffer (or stream
  /// error / EOF).
  Future<void> _waitForBytes(int n) async {
    while (_buffered < n) {
      if (_error != null) throw _error!;
      if (_closed) {
        throw Exception('Stream ended prematurely: need $n, have $_buffered');
      }
      _waiter ??= Completer<void>();
      await _waiter!.future;
    }
  }

  Future<Uint8List> readExact(int n) async {
    await _waitForBytes(n);

    final result = Uint8List(n);
    int written = 0;

    while (written < n) {
      final head = _chunks.first;
      final available = head.length - _headOffset;
      final need = n - written;
      final take = available < need ? available : need;

      result.setRange(written, written + take, head, _headOffset);

      written += take;
      _headOffset += take;
      _buffered -= take;

      if (_headOffset >= head.length) {
        _chunks.removeFirst();
        _headOffset = 0;
      }
    }

    return result;
  }

  int get bufferedBytes => _buffered;

  void pause() {
    if (_paused) return;
    _sub.pause();
    _paused = true;
  }

  void resume() {
    if (!_paused) return;
    _sub.resume();
    _paused = false;
  }

  int readUint16FromBytes(Uint8List b) => (b[0] << 8) | b[1];

  int readInt32FromBytes(Uint8List b) =>
      (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3];

  int readInt64FromBytes(Uint8List b) {
    int v = 0;
    for (int i = 0; i < 8; i++) {
      v = (v << 8) | b[i];
    }
    return v;
  }

  Future<int> readUint16() async => readUint16FromBytes(await readExact(2));
  Future<int> readInt32() async => readInt32FromBytes(await readExact(4));
  Future<int> readInt64() async => readInt64FromBytes(await readExact(8));

  Future<String> readUTF() async {
    final len = await readInt32();
    final bytes = await readExact(len);
    return utf8.decode(bytes);
  }

  void dispose() {
    _sub.cancel();
  }
}

/// Per-channel speed / traffic info.
class ChannelStats {
  final String name;
  int bytesSent = 0;
  int bytesReceived = 0;
  double sendSpeed = 0;
  double receiveSpeed = 0;
  DateTime _lastSample = DateTime.now();
  int _lastSentSnapshot = 0;
  int _lastRecvSnapshot = 0;

  ChannelStats(this.name);

  void sampleSpeed() {
    final now = DateTime.now();
    final ms = now.difference(_lastSample).inMilliseconds;
    if (ms < 200) return;
    sendSpeed = (bytesSent - _lastSentSnapshot) * 1000 / ms;
    receiveSpeed = (bytesReceived - _lastRecvSnapshot) * 1000 / ms;
    _lastSample = now;
    _lastSentSnapshot = bytesSent;
    _lastRecvSnapshot = bytesReceived;
  }
}

/// Callback for aggregate progress.
typedef MultiSendProgressCallback =
    void Function(int sentBytes, int totalBytes, List<ChannelStats> channels);

/// Builds the wire-format header for a file block (without the data bytes).
Uint8List _buildBlockHeader(FileBlock block) {
  final bb = BytesBuilder(copy: false);
  _writeUint16(bb, block.isFile ? TransferIds.file : TransferIds.folder);
  _writeInt32(bb, block.fileIndex);
  _writeUTF(bb, block.path);
  _writeInt64(bb, block.lastModified);
  if (block.isFile) {
    _writeInt64(bb, block.totalSize);
    _writeInt32(bb, block.blockIndex);
    _writeInt32(bb, block.length);
  }
  return bb.toBytes();
}

Uint8List _buildEofSentinel() {
  final bb = BytesBuilder(copy: false);
  _writeUint16(bb, TransferIds.eof);
  return bb.toBytes();
}

/// Each sender isolate reads its OWN blocks from disk and sends them over TCP.
/// No 1 MB data copies cross between isolates — only tiny metadata messages.
void _senderIsolateEntry(List<dynamic> args) {
  final mainPort = args[0] as SendPort;
  final ip = args[1] as String;
  final port = args[2] as int;
  final chIndex = args[3] as int;
  final channelCount = args[4] as int;
  final fileManifest = args[5] as List<Map<String, dynamic>>;

  _runSenderIsolate(mainPort, ip, port, chIndex, channelCount, fileManifest);
}

Future<void> _runSenderIsolate(
  SendPort mainPort,
  String ip,
  int port,
  int chIndex,
  int channelCount,
  List<Map<String, dynamic>> fileManifest,
) async {
  Socket? socket;
  try {
    socket = await Socket.connect(
      ip,
      port,
      timeout: const Duration(seconds: 15),
    );
    socket.setOption(SocketOption.tcpNoDelay, true);
    mainPort.send('connected');

    bool pipeError = false;
    socket.done.catchError((e) {
      pipeError = true;
    });

    int sentBytes = 0;
    int sentBlocks = 0;
    var lastLogAt = DateTime.now();
    int lastLogBytes = 0;
    int globalBlockIndex = 0;

    int adaptiveBlock = kBlockSize;

    for (int fi = 0; fi < fileManifest.length && !pipeError; fi++) {
      final entry = fileManifest[fi];
      final filePath = entry['filePath'] as String;
      final relativePath = entry['relativePath'] as String;
      final isDir = entry['isDir'] as bool;
      final fileSize = entry['size'] as int;
      final lastModified = entry['lastModified'] as int;

      if (isDir) {
        if (globalBlockIndex % channelCount == chIndex) {
          final header = _buildBlockHeader(
            FileBlock(
              isFile: false,
              fileIndex: fi,
              path: relativePath,
              lastModified: lastModified,
            ),
          );
          socket.add(header);
        }
        globalBlockIndex++;
        continue;
      }

      if (fileSize == 0) {
        if (globalBlockIndex % channelCount == chIndex) {
          final header = _buildBlockHeader(
            FileBlock(
              isFile: true,
              fileIndex: fi,
              path: relativePath,
              lastModified: lastModified,
              totalSize: 0,
              blockIndex: 0,
              data: Uint8List(0),
            ),
          );
          socket.add(header);
        }
        globalBlockIndex++;
        continue;
      }

      final file = File(filePath);
      final raf = await file.open(mode: FileMode.read);
      try {
        int remaining = fileSize;
        int blkIdx = 0;
        while (remaining > 0 && !pipeError) {
          final chunkSize = remaining < adaptiveBlock
              ? remaining
              : adaptiveBlock;

          if (globalBlockIndex % channelCount == chIndex) {
            final data = await raf.read(chunkSize);
            final header = _buildBlockHeader(
              FileBlock(
                isFile: true,
                fileIndex: fi,
                path: relativePath,
                lastModified: lastModified,
                totalSize: fileSize,
                blockIndex: blkIdx,
                data: data,
              ),
            );
            socket.add(header);
            socket.add(data);
            sentBytes += chunkSize;
            sentBlocks++;

            if (sentBlocks % 4 == 0) {
              await socket.flush();
              mainPort.send(sentBytes);
            }

            if (sentBlocks == 32) {
              final elapsedMs = DateTime.now()
                  .difference(lastLogAt)
                  .inMilliseconds;
              final mbps = elapsedMs > 0
                  ? (sentBytes / (elapsedMs / 1000.0) / (1024 * 1024))
                  : 0.0;
              if (mbps > 200) {
                adaptiveBlock = 4 * 1024 * 1024;
              } else if (mbps > 80) {
                adaptiveBlock = 2 * 1024 * 1024;
              }
              mainPort.send(
                'log:[MultiSend ch$chIndex] warmup done: ${mbps.toStringAsFixed(0)}MB/s → blockSize=${adaptiveBlock ~/ 1024}KB',
              );
            }

            final now = DateTime.now();
            if (now.difference(lastLogAt).inMilliseconds >= 1000) {
              final elapsed = now.difference(lastLogAt).inMilliseconds / 1000.0;
              final speed =
                  ((sentBytes - lastLogBytes) / elapsed / (1024 * 1024))
                      .toStringAsFixed(1);
              mainPort.send(
                'log:[MultiSend ch$chIndex] blocks=$sentBlocks sent=$sentBytes speed=${speed}MB/s blk=${adaptiveBlock ~/ 1024}KB',
              );
              lastLogAt = now;
              lastLogBytes = sentBytes;
            }
          } else {
            await raf.setPosition(await raf.position() + chunkSize);
          }

          remaining -= chunkSize;
          blkIdx++;
          globalBlockIndex++;
        }
      } finally {
        await raf.close();
      }
    }

    socket.add(_buildEofSentinel());
    if (!pipeError) {
      await socket.flush();
    }
    mainPort.send(sentBytes);
    mainPort.send('done');
  } catch (e) {
    mainPort.send('error:$e');
  } finally {
    try {
      await socket?.close();
    } catch (_) {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }
}

/// Sends files over multiple TCP sockets using Dart Isolates — one isolate
/// per network interface — each doing its own file I/O for zero-copy transfer.
class MultiChannelSender {
  final List<String> targetIps;
  final List<McTransferFile> files;
  final int totalBytes;
  final MultiSendProgressCallback? onProgress;
  final VoidCallback? onComplete;
  final void Function(String error)? onError;

  bool _cancelled = false;
  final List<ChannelStats> channelStats = [];
  final List<Isolate> _isolates = [];

  MultiChannelSender({
    required this.targetIps,
    required this.files,
    required this.totalBytes,
    this.onProgress,
    this.onComplete,
    this.onError,
  });

  void cancel() {
    _cancelled = true;
    for (final iso in _isolates) {
      iso.kill(priority: Isolate.immediate);
    }
  }

  int _totalSent = 0;

  Future<void> start() async {
    if (targetIps.isEmpty) {
      onError?.call('No target IPs');
      return;
    }

    final channelCount = targetIps.length;
    debugPrint(
      '[MultiSend] start channels=$channelCount blockSize=$kBlockSize totalBytes=$totalBytes (isolate+ownIO)',
    );
    channelStats.clear();
    for (int i = 0; i < channelCount; i++) {
      channelStats.add(ChannelStats('ch$i'));
    }

    final manifest = <Map<String, dynamic>>[];
    for (final tf in files) {
      final stat = await tf.file.stat();
      manifest.add({
        'filePath': tf.file.path,
        'relativePath': tf.relativePath,
        'isDir': stat.type == FileSystemEntityType.directory,
        'size': stat.type == FileSystemEntityType.directory ? 0 : stat.size,
        'lastModified': stat.modified.millisecondsSinceEpoch,
      });
    }

    final doneCompleters = <Completer<void>>[];

    for (int i = 0; i < channelCount; i++) {
      final completer = Completer<void>();
      doneCompleters.add(completer);

      final mainReceivePort = ReceivePort();
      final isolate = await Isolate.spawn(_senderIsolateEntry, [
        mainReceivePort.sendPort,
        targetIps[i],
        kMultiChannelBasePort + i,
        i,
        channelCount,
        manifest,
      ]);
      _isolates.add(isolate);

      mainReceivePort.listen((message) {
        if (message is int) {
          channelStats[i].bytesSent = message;
          channelStats[i].sampleSpeed();
          _totalSent = channelStats.fold(0, (a, s) => a + s.bytesSent);
          onProgress?.call(_totalSent, totalBytes, channelStats);
        } else if (message is String) {
          if (message == 'connected') {
            debugPrint(
              '[MultiSend ch$i] Connected to ${targetIps[i]}:${kMultiChannelBasePort + i}',
            );
          } else if (message == 'done') {
            if (!completer.isCompleted) completer.complete();
          } else if (message.startsWith('log:')) {
            debugPrint(message.substring(4));
          } else if (message.startsWith('error:')) {
            if (!completer.isCompleted) {
              completer.completeError(message.substring(6));
            }
          }
        }
      });
    }

    try {
      await Future.wait(
        doneCompleters.map((c) => c.future),
      ).timeout(const Duration(seconds: 300));
      if (!_cancelled) {
        onComplete?.call();
      }
    } catch (e) {
      onError?.call(e.toString());
    } finally {
      for (final iso in _isolates) {
        iso.kill(priority: Isolate.immediate);
      }
    }
  }
}

/// Callback for aggregate receive progress.
typedef MultiRecvProgressCallback =
    void Function(
      int receivedBytes,
      int totalBytes,
      List<ChannelStats> channels,
    );

/// Accepts multiple TCP connections and reassembles file blocks in order.
class MultiChannelReceiver {
  final int channelCount;
  final String saveBasePath;
  final MultiRecvProgressCallback? onProgress;
  final VoidCallback? onComplete;
  final void Function(String error)? onError;
  final void Function(String relativePath, String savedPath)? onFileReceived;

  bool _cancelled = false;
  final List<ChannelStats> channelStats = [];
  final List<ServerSocket> _servers = [];

  /// Completes when all server sockets are bound and ready to accept
  /// connections.  The caller should await [readyFuture] before telling
  /// the sender to connect (i.e. before sending mc_accept).
  final Completer<void> _readyCompleter = Completer<void>();
  Future<void> get readyFuture => _readyCompleter.future;

  late final List<Queue<FileBlock>> _channelQueues;
  late final List<int> _channelQueuedBytes;
  final _blockPushed = StreamController<void>.broadcast();
  final List<bool> _channelDone = [];
  int _totalReceived = 0;
  int _totalBytes = 0;
  bool _hadChannelError = false;

  MultiChannelReceiver({
    required this.channelCount,
    required this.saveBasePath,
    this.onProgress,
    this.onComplete,
    this.onError,
    this.onFileReceived,
  });

  void cancel() {
    _cancelled = true;
    _blockPushed.add(null);
    for (final s in _servers) {
      try {
        s.close();
      } catch (_) {}
    }
  }

  /// Opens [channelCount] server sockets and waits for the sender to connect.
  Future<void> start({int totalBytes = 0}) async {
    _totalBytes = totalBytes;
    _channelQueues = List.generate(channelCount, (_) => Queue<FileBlock>());
    _channelQueuedBytes = List.filled(channelCount, 0);
    _channelDone.clear();
    _channelDone.addAll(List.filled(channelCount, false));
    _hadChannelError = false;
    channelStats.clear();
    for (int i = 0; i < channelCount; i++) {
      channelStats.add(ChannelStats('ch$i'));
    }

    try {
      for (int i = 0; i < channelCount; i++) {
        final server = await ServerSocket.bind(
          InternetAddress.anyIPv4,
          kMultiChannelBasePort + i,
          shared: false,
        );
        _servers.add(server);
        debugPrint(
          '[MultiRecv] Channel $i listening on port ${kMultiChannelBasePort + i}',
        );
      }

      if (!_readyCompleter.isCompleted) _readyCompleter.complete();

      final receiverFutures = <Future>[];
      for (int i = 0; i < channelCount; i++) {
        receiverFutures.add(_acceptAndReceive(i));
      }

      final writerFuture = _writer();

      await Future.wait([...receiverFutures, writerFuture]);
      if (!_cancelled && !_hadChannelError) {
        onComplete?.call();
      } else if (!_cancelled && _hadChannelError) {
        onError?.call('One or more receive channels failed');
      }
    } catch (e) {
      if (!_readyCompleter.isCompleted) _readyCompleter.completeError(e);
      onError?.call(e.toString());
    } finally {
      for (final s in _servers) {
        try {
          s.close();
        } catch (_) {}
      }
    }
  }

  Future<void> _acceptAndReceive(int chIndex) async {
    final socket = await _servers[chIndex].first;
    socket.setOption(SocketOption.tcpNoDelay, true);
    debugPrint('[MultiRecv ch$chIndex] Client connected');
    await _receiveChannel(chIndex, socket);
  }

  Future<void> _receiveChannel(int chIndex, Socket socket) async {
    final reader = _BinaryReader(socket);
    try {
      int recvBlocks = 0;
      var lastLogAt = DateTime.now();
      while (!_cancelled) {
        if (_channelQueuedBytes[chIndex] > 16 * 1024 * 1024) {
          reader.pause();
          while (_channelQueuedBytes[chIndex] > 8 * 1024 * 1024 &&
              !_cancelled) {
            await Future<void>.delayed(const Duration(milliseconds: 4));
          }
          reader.resume();
        }

        final header = await reader.readUint16();

        switch (header) {
          case TransferIds.folder:
            {
              final fileIndex = await reader.readInt32();
              final path = await reader.readUTF();
              final lastModified = await reader.readInt64();
              _channelQueues[chIndex].add(
                FileBlock(
                  isFile: false,
                  fileIndex: fileIndex,
                  path: path,
                  lastModified: lastModified,
                ),
              );
              _blockPushed.add(null);
            }
            break;

          case TransferIds.file:
            {
              final fileIndex = await reader.readInt32();
              final path = await reader.readUTF();
              final lastModified = await reader.readInt64();
              final totalSize = await reader.readInt64();
              final blockIndex = await reader.readInt32();
              final dataLen = await reader.readInt32();
              final data = await reader.readExact(dataLen);

              channelStats[chIndex].bytesReceived += dataLen;
              _totalReceived += dataLen;
              recvBlocks++;
              channelStats[chIndex].sampleSpeed();
              onProgress?.call(_totalReceived, _totalBytes, channelStats);

              _channelQueues[chIndex].add(
                FileBlock(
                  isFile: true,
                  fileIndex: fileIndex,
                  path: path,
                  lastModified: lastModified,
                  totalSize: totalSize,
                  blockIndex: blockIndex,
                  data: data,
                ),
              );
              _channelQueuedBytes[chIndex] += dataLen;
              _blockPushed.add(null);

              if (_channelQueuedBytes[chIndex] > 16 * 1024 * 1024) {
                reader.pause();
                while (_channelQueuedBytes[chIndex] > 8 * 1024 * 1024 &&
                    !_cancelled) {
                  await Future<void>.delayed(const Duration(milliseconds: 4));
                }
                reader.resume();
              }

              final now = DateTime.now();
              if (now.difference(lastLogAt).inMilliseconds >= 1000) {
                final speed =
                    (channelStats[chIndex].receiveSpeed / (1024 * 1024))
                        .toStringAsFixed(1);
                debugPrint(
                  '[MultiRecv ch$chIndex] blocks=$recvBlocks qBytes=${_channelQueuedBytes[chIndex]} rBuf=${reader.bufferedBytes} speed=${speed}MB/s total=$_totalReceived',
                );
                lastLogAt = now;
              }
            }
            break;

          case TransferIds.eof:
            _channelDone[chIndex] = true;
            _blockPushed.add(null);
            reader.dispose();
            socket.destroy();
            debugPrint('[MultiRecv ch$chIndex] EOF — channel done');
            return;

          case TransferIds.interrupt:
          case TransferIds.readError:
          case TransferIds.writeError:
            _hadChannelError = true;
            _channelDone[chIndex] = true;
            _blockPushed.add(null);
            reader.dispose();
            socket.destroy();
            debugPrint(
              '[MultiRecv ch$chIndex] Error sentinel received (header=$header)',
            );
            return;

          default:
            debugPrint(
              '[MultiRecv ch$chIndex] Unknown header: $header — aborting',
            );
            _channelDone[chIndex] = true;
            _blockPushed.add(null);
            reader.dispose();
            socket.destroy();
            return;
        }
      }
    } catch (e) {
      debugPrint('[MultiRecv ch$chIndex] Error: $e');
      _hadChannelError = true;
      _channelDone[chIndex] = true;
      _blockPushed.add(null);
    } finally {
      reader.dispose();
    }
  }

  /// Writer: drains whichever channel has data available (round-robin) and
  /// writes blocks directly at their offsets. This removes head-of-line
  /// blocking where a fast channel had to wait for a missing block index from
  /// a slower channel.
  Future<void> _writer() async {
    final openRafs = <int, RandomAccessFile>{};
    final openFilePaths = <int, String>{};
    final relativePaths = <int, String>{};
    final expectedBytes = <int, int>{};
    final writtenBytes = <int, int>{};
    final rafPositions = <int, int>{};
    int rr = 0;
    int wroteBlocks = 0;
    var lastLogAt = DateTime.now();

    try {
      while (true) {
        if (_cancelled) break;

        FileBlock? block;
        int queueIdx = -1;

        for (int step = 0; step < channelCount; step++) {
          final idx = (rr + step) % channelCount;
          if (_channelQueues[idx].isNotEmpty) {
            block = _channelQueues[idx].removeFirst();
            queueIdx = idx;
            if (block.isFile) {
              _channelQueuedBytes[idx] -= block.length;
              if (_channelQueuedBytes[idx] < 0) {
                _channelQueuedBytes[idx] = 0;
              }
            }
            rr = (idx + 1) % channelCount;
            break;
          }
        }

        if (block == null) {
          if (_allDone()) break;
          await _blockPushed.stream.first.timeout(
            const Duration(milliseconds: 500),
            onTimeout: () {},
          );
          continue;
        }

        if (!block.isFile) {
          final dirPath = '$saveBasePath/${block.path}';
          await Directory(dirPath).create(recursive: true);
          continue;
        }

        final fileIndex = block.fileIndex;
        final filePath = '$saveBasePath/${block.path}';
        final parentDir = File(filePath).parent;
        if (!parentDir.existsSync()) {
          await parentDir.create(recursive: true);
        }

        if (!openRafs.containsKey(fileIndex)) {
          final file = File(filePath);
          openRafs[fileIndex] = await file.open(mode: FileMode.write);
          openFilePaths[fileIndex] = filePath;
          relativePaths[fileIndex] = block.path;
          expectedBytes[fileIndex] = block.totalSize;
          writtenBytes[fileIndex] = 0;
          rafPositions[fileIndex] = 0;
        }

        final raf = openRafs[fileIndex]!;
        final expectedPos = block.startPosition;
        if ((rafPositions[fileIndex] ?? 0) != expectedPos) {
          await raf.setPosition(expectedPos);
          rafPositions[fileIndex] = expectedPos;
        }
        if (block.data != null && block.data!.isNotEmpty) {
          await raf.writeFrom(block.data!);
          rafPositions[fileIndex] =
              (rafPositions[fileIndex] ?? 0) + block.data!.length;
        }
        wroteBlocks++;
        writtenBytes[fileIndex] =
            (writtenBytes[fileIndex] ?? 0) + (block.data?.length ?? 0);

        final expBytes = expectedBytes[fileIndex] ?? 0;
        final wBytes = writtenBytes[fileIndex] ?? 0;
        if (expBytes == 0 || wBytes >= expBytes) {
          await raf.flush();
          await raf.close();
          openRafs.remove(fileIndex);
          expectedBytes.remove(fileIndex);
          writtenBytes.remove(fileIndex);
          rafPositions.remove(fileIndex);
          final rel = relativePaths.remove(fileIndex);
          if (rel != null) {
            onFileReceived?.call(rel, '$saveBasePath/$rel');
          }
        }

        if (queueIdx >= 0 && _channelQueues[queueIdx].length <= 3) {
          _blockPushed.add(null);
        }

        await Future<void>.delayed(Duration.zero);

        final now = DateTime.now();
        if (now.difference(lastLogAt).inMilliseconds >= 1000) {
          final pendingBytes = _channelQueuedBytes.fold<int>(
            0,
            (a, b) => a + b,
          );
          final pendingBlocks = _channelQueues.fold<int>(
            0,
            (a, q) => a + q.length,
          );
          debugPrint(
            '[MultiRecv writer] wroteBlocks=$wroteBlocks openFiles=${openRafs.length} pendingBlocks=$pendingBlocks pendingBytes=$pendingBytes totalRecv=$_totalReceived',
          );
          lastLogAt = now;
        }
      }

      if (_cancelled) {
        for (final entry in openRafs.entries) {
          try { await entry.value.close(); } catch (_) {}
          final path = openFilePaths[entry.key];
          if (path != null) {
            try { await File(path).delete(); } catch (_) {}
          }
        }
        return;
      }

      for (final entry in openRafs.entries) {
        await entry.value.flush();
        await entry.value.close();
        final rel = relativePaths[entry.key];
        if (rel != null) {
          onFileReceived?.call(rel, '$saveBasePath/$rel');
        }
      }
    } catch (e) {
      debugPrint('[MultiRecv Writer] Error: $e');
      for (final raf in openRafs.values) {
        try {
          await raf.close();
        } catch (_) {}
      }
      rethrow;
    }
  }

  bool _allDone() {
    for (int i = 0; i < channelCount; i++) {
      if (!_channelDone[i]) return false;
      if (_channelQueues[i].isNotEmpty) return false;
    }
    return true;
  }
}

class McTransferFile {
  final File file;
  final String relativePath;
  McTransferFile({required this.file, required this.relativePath});
}

/// JSON messages exchanged on the control channel before a multi-channel
/// transfer begins.
///
/// Sender → Receiver:
/// ```json
/// {
///   "type": "mc_request",
///   "files": [
///     {"path": "Photos/img.jpg", "size": 1234567, "isDir": false}, ...
///   ],
///   "channels": [
///     {"name": "wlan0", "ip": "192.168.1.10"}, ...
///   ]
/// }
/// ```
///
/// Receiver → Sender:
/// ```json
/// {
///   "type": "mc_accept",
///   "channels": [
///     {"name": "wlan0", "ip": "192.168.1.42"}, ...
///   ]
/// }
/// ```
class McProtocol {
  static Map<String, dynamic> buildRequest({
    required List<Map<String, dynamic>> files,
    required List<ChannelEndpoint> senderChannels,
  }) {
    return {
      'type': 'mc_request',
      'files': files,
      'channels': senderChannels.map((e) => e.toJson()).toList(),
    };
  }

  static Map<String, dynamic> buildAccept({
    required List<ChannelEndpoint> receiverChannels,
  }) {
    return {
      'type': 'mc_accept',
      'channels': receiverChannels.map((e) => e.toJson()).toList(),
    };
  }
}
