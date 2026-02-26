import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'transfer_service.dart';

class ConnectionManager extends ChangeNotifier {
  // Fixed port so it can be opened in the OS firewall once and for all.
  // UDP discovery uses 46465; the HTTP/WebSocket server uses 46466.
  // Raw TCP file transfer uses 46467 for maximum throughput.
  static const int serverFixedPort = 46466;
  static const int tcpTransferPort = 46467;

  HttpServer? _httpServer;
  ServerSocket? _tcpServer;

  // Active incoming TCP sockets keyed by receive-job ID so they can be
  // cancelled from the UI.
  final Map<String, Socket> _activeReceiveSockets = {};

  // Maps deviceName -> WebSocketChannel
  final Map<String, WebSocketChannel> _activeChannels = {};

  // Maps deviceName -> IP address (populated when a WebSocket is established)
  final Map<String, String> _deviceIps = {};

  // Token used for QR scanning/manual entry
  late String qrToken;

  // Callback when WebSocket is successfully connected
  VoidCallback? onConnectionEstablished;

  // Callback when a file is fully received: (relativePath, savedPath)
  Function(String relativePath, String savedPath)? onFileReceived;

  // Progress callbacks for incoming receive
  Function(String id, String relativePath, int totalBytes)? onFileReceiveStart;
  Function(String id, int receivedBytes)? onFileReceiveProgress;
  /// Called after all bytes are received but BEFORE flush/close — for "Saving…" UI.
  Function(String id)? onFileReceiveSaving;
  Function(String id, String relativePath, String savedPath)?
  onFileReceiveComplete;

  bool get isLinked => _activeChannels.isNotEmpty;
  List<String> get connectedDeviceNames => _activeChannels.keys.toList();
  int? get serverPort => _httpServer?.port;

  /// Returns the IP address stored for [deviceName], or null if unknown.
  String? getDeviceIp(String deviceName) => _deviceIps[deviceName];

  final _uuid = const Uuid();
  late final String deviceId;

  ConnectionManager() {
    deviceId = _uuid.v4();
    // Generate a new 6-digit token for this session
    qrToken = (Random().nextInt(900000) + 100000).toString();
  }

  /// Starts the background HTTP server on the fixed Vortex port.
  Future<void> startServer() async {
    if (_httpServer != null) return;

    try {
      _httpServer = await HttpServer.bind(
        InternetAddress.anyIPv4,
        serverFixedPort,
        shared: true, // allows re-binding after hot-restart
      );
      debugPrint('Vortex Server listening on port: ${_httpServer!.port}');

      _httpServer!.listen((HttpRequest request) async {
        if (request.uri.path == '/ws') {
          await _handleWebSocketUpgrade(request);
        } else if (request.uri.path == '/upload' && request.method == 'POST') {
          await _handleUpload(request);
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
        }
      });
    } catch (e) {
      debugPrint('Failed to start server: $e');
    }

    // ── Raw TCP transfer server (high-speed) ──────────────────────────────
    try {
      _tcpServer = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        tcpTransferPort,
        shared: true,
      );
      debugPrint('Vortex TCP transfer server on port: $tcpTransferPort');
      _tcpServer!.listen(_handleTcpClient);
    } catch (e) {
      debugPrint('Failed to start TCP transfer server: $e');
    }
  }

  // ── Raw TCP file receive handler ──────────────────────────────────────────
  void _handleTcpClient(Socket socket) async {
    final jobId = _uuid.v4();
    _activeReceiveSockets[jobId] = socket;

    // Disable Nagle for lower latency ACK.
    socket.setOption(SocketOption.tcpNoDelay, true);

    try {
      // ── Phase 1: read the JSON header (everything up to first '\n') ────
      final headerBytes = <int>[];
      List<int>? leftover; // bytes after '\n' that belong to the file
      bool headerDone = false;

      final completer = Completer<void>();
      late StreamSubscription<List<int>> sub;

      sub = socket.listen(
        (chunk) {
          if (headerDone) return;
          for (int i = 0; i < chunk.length; i++) {
            if (chunk[i] == 0x0A) {
              // '\n'
              headerDone = true;
              if (i + 1 < chunk.length) {
                leftover = chunk.sublist(i + 1);
              }
              sub.pause();
              completer.complete();
              return;
            }
            headerBytes.add(chunk[i]);
          }
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
      );

      await completer.future;

      if (headerBytes.isEmpty) {
        sub.cancel();
        _activeReceiveSockets.remove(jobId);
        await socket.close();
        return;
      }

      final header = jsonDecode(utf8.decode(headerBytes));
      final relativePath = header['path'] as String? ?? 'received_file';
      final totalBytes = header['size'] as int? ?? -1;

      // ── Prepare destination file ──────────────────────────────────────
      final saveDir = await TransferService.getReceiveDir();
      final parts = relativePath.split('/');
      final fileName = parts.last;
      final Directory targetDir;
      if (parts.length > 1) {
        targetDir = Directory(
          '${saveDir.path}/${parts.sublist(0, parts.length - 1).join('/')}',
        );
        await targetDir.create(recursive: true);
      } else {
        targetDir = saveDir;
      }
      final file = File('${targetDir.path}/$fileName');
      final sink = file.openWrite();

      onFileReceiveStart?.call(jobId, relativePath, totalBytes);

      // ── Phase 2: stream file bytes (reuse the SAME subscription) ──────
      int received = 0;
      bool cancelled = false;

      if (leftover != null && leftover!.isNotEmpty) {
        sink.add(leftover!);
        received += leftover!.length;
        onFileReceiveProgress?.call(jobId, received);
      }

      if (totalBytes > 0 && received >= totalBytes) {
        sub.cancel();
      } else {
        final dataCompleter = Completer<void>();
        int pendingNotify = 0;

        sub.onData((chunk) {
          if (chunk.isEmpty) return;

          sink.add(chunk);
          received += chunk.length;
          pendingNotify += chunk.length;

          if (totalBytes > 0 && received >= totalBytes) {
            onFileReceiveProgress?.call(jobId, received);
            sub.cancel();
            if (!dataCompleter.isCompleted) dataCompleter.complete();
          } else if (pendingNotify >= 65536) {
            // 64KB trigger
            pendingNotify = 0;
            onFileReceiveProgress?.call(jobId, received);
          }
        });
        sub.onError((e) {
          cancelled = true;
          sub.cancel();
          if (!dataCompleter.isCompleted) dataCompleter.complete();
        });
        sub.onDone(() {
          if (!dataCompleter.isCompleted) dataCompleter.complete();
        });

        sub.resume();
        await dataCompleter.future;
      }

      // All bytes are in the sink — notify the UI to show "Saving…"
      onFileReceiveSaving?.call(jobId);

      await sink.flush();
      await sink.close();

      if (cancelled) return; // Receiver was cancelled midway

      // Send single ACK byte to let sender know we saved exactly what they sent.
      socket.add([0x06]);
      onFileReceiveComplete?.call(jobId, relativePath, file.path);
      _activeReceiveSockets.remove(jobId);
      await socket.close();
    } catch (e) {
      debugPrint('[TCP Receive] Error: $e');
      _activeReceiveSockets.remove(jobId);
      try {
        await socket.close();
      } catch (_) {}
    }
  }

  /// Cancel an active receive job by jobId (closes socket)
  void cancelReceiveJob(String jobId) {
    final sock = _activeReceiveSockets.remove(jobId);
    if (sock != null) {
      try {
        sock.destroy();
      } catch (_) {}
    }
  }

  /// Completes the connection if the correct pairing code is provided
  Future<void> _handleWebSocketUpgrade(HttpRequest request) async {
    final providedCode = request.uri.queryParameters['code'];
    final requesterName =
        request.uri.queryParameters['name'] ?? 'Unknown Device';

    if (providedCode == null || providedCode != qrToken) {
      debugPrint(
        '[WebSocket] Refused connection. Expected: "$qrToken", Got: "$providedCode". Name: "$requesterName"',
      );
      request.response
        ..statusCode = HttpStatus.forbidden
        ..write('Invalid token')
        ..close();
      return;
    }

    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      final deviceIp = request.connectionInfo?.remoteAddress.address;
      _setupChannel(requesterName, IOWebSocketChannel(socket), ip: deviceIp);
    } else {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
    }
  }

  // ============== CLIENT (INITIATOR) METHODS ==============

  /// Called by Device A to connect to Device B after scanning QR or entering IP
  Future<bool> connectToDevice(
    String ip,
    int port,
    String token,
    String myDeviceName, {
    String? targetDeviceName,
  }) async {
    try {
      final wsUrl = Uri.parse(
        'ws://$ip:$port/ws?code=$token&name=${Uri.encodeComponent(myDeviceName)}',
      );
      final socket = await WebSocket.connect(
        wsUrl.toString(),
      ).timeout(const Duration(seconds: 15));
      final channel = IOWebSocketChannel(socket);
      _setupChannel(targetDeviceName ?? 'Device ($ip)', channel, ip: ip);
      return true;
    } catch (e) {
      debugPrint('Error connecting WebSocket: $e');
      return false;
    }
  }

  // ============== COMMON WEBSOCKET LOGIC ==============

  /// Schedules [notifyListeners] on the next frame so it never fires while
  /// the widget tree is locked (e.g. during layout or a build pass).
  void _safeNotify() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    disconnectAll();
    _httpServer?.close(force: true);
    _tcpServer?.close();
    for (final sock in _activeReceiveSockets.values) {
      try {
        sock.destroy();
      } catch (_) {}
    }
    _activeReceiveSockets.clear();
    super.dispose();
  }

  void _setupChannel(
    String deviceName,
    WebSocketChannel channel, {
    String? ip,
  }) {
    if (_activeChannels.containsKey(deviceName)) {
      _activeChannels[deviceName]!.sink.close();
    }

    _activeChannels[deviceName] = channel;
    if (ip != null) _deviceIps[deviceName] = ip;

    debugPrint('Vortex Devices Linked Successfully! ($deviceName, ip: $ip)');

    // Defer UI callbacks to the next frame — they may call Navigator.pop /
    // setState which crash if fired while the widget tree is locked.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      onConnectionEstablished?.call();
    });
    _safeNotify();

    channel.stream.listen(
      (message) {
        debugPrint('Received message from $deviceName: $message');
      },
      onDone: () {
        debugPrint('WebSocket connection closed with $deviceName');
        _activeChannels.remove(deviceName);
        _safeNotify();
      },
      onError: (error) {
        debugPrint('WebSocket error with $deviceName: $error');
        _activeChannels.remove(deviceName);
        _safeNotify();
      },
    );
  }

  // ============== FILE RECEIVE ==============

  Future<void> _handleUpload(HttpRequest request) async {
    final jobId = _uuid.v4();
    String relativePath = 'received_file';
    File? file;
    try {
      final encoded = request.headers.value('x-vortex-path') ?? 'received_file';
      relativePath = Uri.decodeComponent(encoded);

      // Content-Length may be -1 when the sender does not provide it.
      final totalBytes = request.contentLength;

      final saveDir = await TransferService.getReceiveDir();

      // Preserve subdirectory structure inside the Vortex folder
      final parts = relativePath.split('/');
      final fileName = parts.last;
      final Directory targetDir;
      if (parts.length > 1) {
        targetDir = Directory(
          '${saveDir.path}/${parts.sublist(0, parts.length - 1).join('/')}',
        );
        await targetDir.create(recursive: true);
      } else {
        targetDir = saveDir;
      }

      file = File('${targetDir.path}/$fileName');
      final sink = file.openWrite();

      // Notify: transfer starting
      onFileReceiveStart?.call(jobId, relativePath, totalBytes);

      int received = 0;
      int pendingNotify = 0;
      await for (final chunk in request) {
        sink.add(chunk);
        received += chunk.length;
        pendingNotify += chunk.length;

        if (totalBytes > 0 && received >= totalBytes) {
          onFileReceiveProgress?.call(jobId, received);
        } else if (pendingNotify >= 65536) {
          // 64KB threshold
          pendingNotify = 0;
          onFileReceiveProgress?.call(jobId, received);
        }
      }
      // Ensure the final progress is sent if we exited early or had no totalBytes
      if (pendingNotify > 0) {
        onFileReceiveProgress?.call(jobId, received);
      }

      await sink.flush();
      await sink.close();

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'status': 'ok', 'path': file.path}))
        ..close();

      debugPrint('[Upload] Saved: $relativePath → ${file.path}');
      onFileReceived?.call(relativePath, file.path);
      onFileReceiveComplete?.call(jobId, relativePath, file.path);
    } catch (e) {
      debugPrint('[Upload] Error: $e');
      if (file != null) {
        onFileReceiveComplete?.call(jobId, relativePath, file.path);
      }
      try {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..close();
      } catch (_) {}
    }
  }

  void sendMessageToAll(String message) {
    for (var channel in _activeChannels.values) {
      channel.sink.add(message);
    }
  }

  Future<void> disconnectDevice(String deviceName) async {
    final channel = _activeChannels.remove(deviceName);
    _deviceIps.remove(deviceName);
    await channel?.sink.close();
    _safeNotify();
  }

  Future<void> disconnectAll() async {
    for (var channel in _activeChannels.values) {
      await channel.sink.close();
    }
    _activeChannels.clear();
    _deviceIps.clear();
    _safeNotify();
  }
}
