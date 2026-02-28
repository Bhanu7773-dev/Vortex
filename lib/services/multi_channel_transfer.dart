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
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

// ─── Constants ───────────────────────────────────────────────────────────────

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

// ─── FileBlock ───────────────────────────────────────────────────────────────

/// A single block of a file (or a directory marker) flowing through the
/// transfer pipeline.
class FileBlock implements Comparable<FileBlock> {
  final bool isFile;
  final int fileIndex;
  final String path;
  final int lastModified; // milliseconds since epoch
  final int totalSize; // total file size in bytes
  final int blockIndex; // which 1 MB block within the file
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

// ─── Channel info exchanged during negotiation ──────────────────────────────

/// Describes one network interface available for transfer.
class ChannelEndpoint {
  final String name; // e.g. "wlan0", "eth0", "usb0"
  final String ip;

  ChannelEndpoint({required this.name, required this.ip});

  Map<String, dynamic> toJson() => {'name': name, 'ip': ip};

  factory ChannelEndpoint.fromJson(Map<String, dynamic> j) =>
      ChannelEndpoint(name: j['name'] as String, ip: j['ip'] as String);
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Returns all usable (non-loopback, non-virtual) IPv4 interface addresses.
Future<List<ChannelEndpoint>> enumerateInterfaces() async {
  final endpoints = <ChannelEndpoint>[];
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLinkLocal: false,
  );
  for (final iface in interfaces) {
    final name = iface.name.toLowerCase();
    // Skip virtual / Docker / VPN interfaces
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
  // Guarantee at least one — fallback to any IPv4
  if (endpoints.isEmpty) {
    endpoints.add(ChannelEndpoint(name: 'any', ip: '0.0.0.0'));
  }
  return endpoints;
}

// ─── Binary protocol helpers ─────────────────────────────────────────────────
// All multi-byte integers are big-endian (network byte order).

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

// ─── Read helpers (from buffered stream) ─────────────────────────────────────

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

// ─── Progress info ───────────────────────────────────────────────────────────

/// Per-channel speed / traffic info.
class ChannelStats {
  final String name;
  int bytesSent = 0;
  int bytesReceived = 0;
  double sendSpeed = 0; // bytes/sec
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

// ═════════════════════════════════════════════════════════════════════════════
// MULTI-CHANNEL SENDER
// ═════════════════════════════════════════════════════════════════════════════

/// Callback for aggregate progress.
typedef MultiSendProgressCallback =
    void Function(int sentBytes, int totalBytes, List<ChannelStats> channels);

/// Sends files over multiple TCP sockets (one per network interface) to a
/// remote Vortex device.
///
/// Usage:
/// ```dart
/// final sender = MultiChannelSender(
///   targetIps: ['192.168.1.42', '192.168.50.1'],  // receiver IPs per iface
///   files: expandedFiles,
///   onProgress: (sent, total, ch) { ... },
/// );
/// await sender.start();
/// ```
class MultiChannelSender {
  final List<String> targetIps;
  final List<McTransferFile> files;
  final int totalBytes;
  final MultiSendProgressCallback? onProgress;
  final VoidCallback? onComplete;
  final void Function(String error)? onError;

  bool _cancelled = false;
  final List<ChannelStats> channelStats = [];

  // Per-channel queues — reader assigns blocks round-robin so each sender
  // channel always has its own dedicated work.  This eliminates the Dart
  // cooperative-scheduling starvation where the first Future to run drains
  // the entire shared queue before the other Future gets a chance to execute.
  late final List<Queue<FileBlock>> _channelQueues;
  late final List<StreamController<void>> _channelSignals;
  final List<bool> _channelReaderDone = [];

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
    for (final sc in _channelSignals) {
      sc.add(null);
    }
  }

  int _totalSent = 0;
  int _lastProgressAt = 0;

  Future<void> start() async {
    if (targetIps.isEmpty) {
      onError?.call('No target IPs');
      return;
    }

    final channelCount = targetIps.length;
    debugPrint(
      '[MultiSend] start channels=$channelCount blockSize=$kBlockSize totalBytes=$totalBytes',
    );
    channelStats.clear();
    _channelQueues = List.generate(channelCount, (_) => Queue<FileBlock>());
    _channelSignals = List.generate(
      channelCount,
      (_) => StreamController<void>.broadcast(),
    );
    _channelReaderDone.clear();
    _channelReaderDone.addAll(List.filled(channelCount, false));

    for (int i = 0; i < channelCount; i++) {
      channelStats.add(ChannelStats('ch$i'));
    }

    // Start file reader (produces blocks, distributes round-robin)
    final readerFuture = _readFiles(channelCount);

    // Start sender channels (each consumes its own queue)
    final senderFutures = <Future>[];
    for (int i = 0; i < channelCount; i++) {
      senderFutures.add(_senderChannel(i));
    }

    try {
      await Future.wait([readerFuture, ...senderFutures]);
      if (!_cancelled) {
        onComplete?.call();
      }
    } catch (e) {
      onError?.call(e.toString());
    } finally {
      for (final sc in _channelSignals) {
        await sc.close();
      }
    }
  }

  /// Reads all files into 1 MB blocks and distributes them round-robin across
  /// per-channel queues.  Round-robin guarantees that every channel always has
  /// roughly the same number of blocks regardless of which Future the Dart
  /// scheduler happened to run first.
  Future<void> _readFiles(int channelCount) async {
    int fileIndex = 0;
    int roundRobin = 0; // which channel gets the next block
    try {
      for (final tf in files) {
        if (_cancelled) break;
        final stat = await tf.file.stat();

        if (stat.type == FileSystemEntityType.directory) {
          // Assign directory marker to the next channel in round-robin, same
          // as file blocks — broadcasting to all channels would cause the
          // merge-sort writer to see duplicate directory entries.
          final ch = roundRobin % channelCount;
          roundRobin++;
          _channelQueues[ch].add(
            FileBlock(
              isFile: false,
              fileIndex: fileIndex,
              path: tf.relativePath,
              lastModified: stat.modified.millisecondsSinceEpoch,
            ),
          );
          _channelSignals[ch].add(null);
          fileIndex++;
          continue;
        }

        final length = stat.size;
        final modified = stat.modified.millisecondsSinceEpoch;
        final raf = await tf.file.open(mode: FileMode.read);
        try {
          if (length == 0) {
            final ch = roundRobin % channelCount;
            roundRobin++;
            _channelQueues[ch].add(
              FileBlock(
                isFile: true,
                fileIndex: fileIndex,
                path: tf.relativePath,
                lastModified: modified,
                totalSize: 0,
                blockIndex: 0,
                data: Uint8List(0),
              ),
            );
            _channelSignals[ch].add(null);
          } else {
            int remaining = length;
            int blkIdx = 0;
            while (remaining > 0 && !_cancelled) {
              final chunkSize = remaining < kBlockSize ? remaining : kBlockSize;
              final data = await raf.read(chunkSize);
              final ch = roundRobin % channelCount;
              roundRobin++;
              _channelQueues[ch].add(
                FileBlock(
                  isFile: true,
                  fileIndex: fileIndex,
                  path: tf.relativePath,
                  lastModified: modified,
                  totalSize: length,
                  blockIndex: blkIdx,
                  data: Uint8List.fromList(data),
                ),
              );
              _channelSignals[ch].add(null);
              remaining -= data.length;
              blkIdx++;
              // Back-pressure: if any channel's queue is too deep, yield so
              // the sender tasks can drain.
              final maxQ = _channelQueues
                  .map((q) => q.length)
                  .reduce((a, b) => a > b ? a : b);
              if (maxQ > 32 && !_cancelled) {
                await Future.delayed(const Duration(milliseconds: 2));
              }
            }
          }
        } finally {
          await raf.close();
        }
        fileIndex++;
      }
    } catch (e) {
      debugPrint('[MultiSend] Reader error: $e');
      for (int i = 0; i < channelCount; i++) {
        _channelQueues[i].add(FileBlock.readErrorFlag);
        _channelSignals[i].add(null);
        _channelReaderDone[i] = true;
      }
      return;
    }

    // Push one EOF sentinel per channel.
    for (int i = 0; i < channelCount; i++) {
      _channelQueues[i].add(FileBlock.endPoint);
      _channelSignals[i].add(null);
      _channelReaderDone[i] = true;
    }
  }

  /// Connects a TCP socket and sends blocks from this channel's own queue.
  Future<void> _senderChannel(int chIndex) async {
    Socket? socket;
    try {
      final ip = targetIps[chIndex];
      final port = kMultiChannelBasePort + chIndex;
      socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 15),
      );
      socket.setOption(SocketOption.tcpNoDelay, true);
      debugPrint('[MultiSend ch$chIndex] Connected to $ip:$port');

      bool pipeError = false;
      socket.done.catchError((e) {
        pipeError = true;
        debugPrint('[MultiSend ch$chIndex] Pipe error: $e');
      });

      final myQueue = _channelQueues[chIndex];
      int sentBlocks = 0;
      var lastLogAt = DateTime.now();

      while (!_cancelled && !pipeError) {
        FileBlock? block;

        if (myQueue.isNotEmpty) {
          block = myQueue.removeFirst();
        } else if (_channelReaderDone[chIndex]) {
          break;
        } else {
          // Wait for reader to assign a block to this channel.
          await _channelSignals[chIndex].stream.first.timeout(
            const Duration(milliseconds: 500),
            onTimeout: () {},
          );
          if (myQueue.isNotEmpty) {
            block = myQueue.removeFirst();
          } else {
            continue;
          }
        }

        // Sentinel handling
        if (block.isSentinel) {
          final bb = BytesBuilder(copy: false);
          if (identical(block, FileBlock.endPoint)) {
            _writeUint16(bb, TransferIds.eof);
          } else if (identical(block, FileBlock.interruptFlag)) {
            _writeUint16(bb, TransferIds.interrupt);
          } else if (identical(block, FileBlock.readErrorFlag)) {
            _writeUint16(bb, TransferIds.readError);
          } else {
            _writeUint16(bb, TransferIds.writeError);
          }
          socket.add(bb.toBytes());
          await socket.flush();
          break;
        }

        // Serialize and send block
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
        socket.add(bb.toBytes());
        if (block.isFile && block.data != null && block.data!.isNotEmpty) {
          socket.add(block.data!);
        }

        final bytes = block.length;
        channelStats[chIndex].bytesSent += bytes;
        _totalSent += bytes;
        sentBlocks++;

        // Yield every ~4 MB (4 blocks) to share the event loop.
        if (sentBlocks % 4 == 0) {
          if (sentBlocks % 64 == 0) {
            await socket.flush();
          } else {
            await Future<void>.delayed(Duration.zero);
          }

          // Only do expensive work (speed sample, progress, logging) on
          // yield boundaries to keep the hot path tight.
          channelStats[chIndex].sampleSpeed();
          if (_totalSent - _lastProgressAt > 4 * 1024 * 1024) {
            _lastProgressAt = _totalSent;
            onProgress?.call(_totalSent, totalBytes, channelStats);
          }

          final now = DateTime.now();
          if (now.difference(lastLogAt).inMilliseconds >= 1000) {
            final speed = (channelStats[chIndex].sendSpeed / (1024 * 1024))
                .toStringAsFixed(1);
            debugPrint(
              '[MultiSend ch$chIndex] blocks=$sentBlocks queue=${myQueue.length} sent=${channelStats[chIndex].bytesSent} speed=${speed}MB/s total=$_totalSent',
            );
            lastLogAt = now;
          }
        }
      }

      if (!pipeError) {
        await socket.flush();
      }
    } catch (e) {
      debugPrint('[MultiSend ch$chIndex] Error: $e');
      rethrow;
    } finally {
      // Use graceful close() instead of destroy() to avoid TCP RST
      // that discards unACKed data still in the OS send buffer.
      try {
        await socket?.close();
      } catch (_) {
        try {
          socket?.destroy();
        } catch (_) {}
      }
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MULTI-CHANNEL RECEIVER
// ═════════════════════════════════════════════════════════════════════════════

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

  // Per-channel block queues — receiver pushes, writer pulls.
  late final List<Queue<FileBlock>> _channelQueues;
  late final List<int> _channelQueuedBytes;
  final _blockPushed = StreamController<void>.broadcast();
  final List<bool> _channelDone = [];
  int _totalReceived = 0;
  int _totalBytes = 0; // set by negotiation
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
      // Bind server sockets
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

      // Signal that all server sockets are bound and ready.
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();

      // Accept one connection per channel
      final receiverFutures = <Future>[];
      for (int i = 0; i < channelCount; i++) {
        receiverFutures.add(_acceptAndReceive(i));
      }

      // Start writer (merges all channel queues)
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
        // Apply back-pressure BEFORE reading next frame header so we stop
        // consuming socket data when this channel is already too far ahead.
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

              // Back-pressure: pause reading while the writer drains the
              // queue.  Only check _channelQueuedBytes — checking
              // reader.bufferedBytes here would deadlock because bufferedBytes
              // can never decrease while we're not calling readExact().
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
    final relativePaths = <int, String>{};
    final expectedBlocks = <int, int>{};
    final writtenBlocks = <int, int>{};
    int writeCount = 0;
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
          relativePaths[fileIndex] = block.path;
          expectedBlocks[fileIndex] = block.totalSize == 0
              ? 1
              : ((block.totalSize + kBlockSize - 1) ~/ kBlockSize);
          writtenBlocks[fileIndex] = 0;
        }

        final raf = openRafs[fileIndex]!;
        await raf.setPosition(block.startPosition);
        if (block.data != null && block.data!.isNotEmpty) {
          await raf.writeFrom(block.data!);
        }
        wroteBlocks++;

        writtenBlocks[fileIndex] = (writtenBlocks[fileIndex] ?? 0) + 1;

        final expected = expectedBlocks[fileIndex] ?? 0;
        final written = writtenBlocks[fileIndex] ?? 0;
        if (expected > 0 && written >= expected) {
          await raf.flush();
          await raf.close();
          openRafs.remove(fileIndex);
          expectedBlocks.remove(fileIndex);
          writtenBlocks.remove(fileIndex);
          final rel = relativePaths.remove(fileIndex);
          if (rel != null) {
            onFileReceived?.call(rel, '$saveBasePath/$rel');
          }
        }

        writeCount++;
        if (writeCount % 8 == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }

        if (queueIdx >= 0 && _channelQueues[queueIdx].length <= 3) {
          _blockPushed.add(null);
        }

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

// ─── Transfer file helper (shared with TransferService) ──────────────────────

class McTransferFile {
  final File file;
  final String relativePath;
  McTransferFile({required this.file, required this.relativePath});
}

// ═════════════════════════════════════════════════════════════════════════════
// NEGOTIATION PROTOCOL — runs over the existing WebSocket control channel
// ═════════════════════════════════════════════════════════════════════════════

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
