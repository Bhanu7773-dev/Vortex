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
import 'multi_channel_transfer.dart';

class ConnectionManager extends ChangeNotifier {
  static const int serverFixedPort = 46466;
  static const int tcpTransferPort = 46467;

  HttpServer? _httpServer;
  ServerSocket? _tcpServer;

  MultiChannelReceiver? _activeMultiReceiver;

  /// Cached network endpoints for this device (populated on server start).
  List<ChannelEndpoint> _localEndpoints = [];
  List<ChannelEndpoint> get localEndpoints => _localEndpoints;

  final Map<String, Socket> _activeReceiveSockets = {};

  final Map<String, HttpRequest> _activeHttpUploads = {};
  final Set<String> _cancelledHttpUploadIds = {};

  final Map<String, WebSocketChannel> _activeChannels = {};

  final Set<WebSocketChannel> _replacedChannels = {};

  final Map<String, String> _deviceIps = {};

  final Map<String, List<String>> _deviceAllIps = {};

  final Map<String, String> _deviceConnectionMode = {};

  /// Returns the connection mode label for [deviceName].
  String getDeviceMode(String deviceName) =>
      _deviceConnectionMode[deviceName] ?? 'Wi-Fi';

  /// Returns all known IPs for [deviceName], or just the primary IP if only one.
  List<String> getDeviceAllIps(String deviceName) {
    final all = _deviceAllIps[deviceName];
    if (all != null && all.isNotEmpty) return all;
    final primary = _deviceIps[deviceName];
    return primary != null ? [primary] : [];
  }

  late String qrToken;

  VoidCallback? onConnectionEstablished;

  Function(String relativePath, String savedPath)? onFileReceived;

  /// Fired on the RECEIVER device when the sender cancels the transfer.
  VoidCallback? onSenderCancelledTransfer;

  /// Fired on the SENDER device when the receiver cancels the transfer.
  VoidCallback? onReceiverCancelledTransfer;

  Function(String id, String relativePath, int totalBytes)? onFileReceiveStart;
  Function(String id, int receivedBytes)? onFileReceiveProgress;

  /// Called after all bytes are received but BEFORE flush/close — for "Saving…" UI.
  Function(String id)? onFileReceiveSaving;
  Function(String id, String error)? onFileReceiveError;
  Function(String id, String relativePath, String savedPath)?
  onFileReceiveComplete;
  String? _activeMultiReceiveJobId;
  VoidCallback? onHttpUploadCancelled;
  VoidCallback? onHttpUploadStarted;

  bool get isLinked => _activeChannels.isNotEmpty;
  List<String> get connectedDeviceNames => _activeChannels.keys.toList();
  int? get serverPort => _httpServer?.port;

  /// Returns the IP address stored for [deviceName], or null if unknown.
  String? getDeviceIp(String deviceName) => _deviceIps[deviceName];

  final _uuid = const Uuid();
  late final String deviceId;

  ConnectionManager() {
    deviceId = _uuid.v4();
    qrToken = (Random().nextInt(900000) + 100000).toString();
  }

  /// Optional handler for Web Share HTTP requests (served by WebShareService).
  Future<bool> Function(HttpRequest request)? webShareHandler;

  /// Starts the background HTTP server on the fixed Vortex port.
  Future<void> startServer() async {
    if (_httpServer != null) return;

    _localEndpoints = await enumerateInterfaces();
    debugPrint(
      '[Vortex] Local interfaces: ${_localEndpoints.map((e) => '${e.name}=${e.ip}').join(', ')}',
    );

    try {
      _httpServer = await HttpServer.bind(
        InternetAddress.anyIPv4,
        serverFixedPort,
        shared: true,
      );
      debugPrint('Vortex Server listening on port: ${_httpServer!.port}');

      _httpServer!.listen((HttpRequest request) async {
        request.response.headers.set('Access-Control-Allow-Origin', '*');
        request.response.headers.set(
          'Access-Control-Allow-Methods',
          'GET, POST, OPTIONS',
        );
        request.response.headers.set('Access-Control-Allow-Headers', '*');

        if (request.method == 'OPTIONS') {
          request.response
            ..statusCode = HttpStatus.ok
            ..close();
          return;
        }

        if (request.uri.path == '/ws') {
          await _handleWebSocketUpgrade(request);
        } else if (request.uri.path == '/upload' && request.method == 'POST') {
          await handleUpload(request);
        } else if (webShareHandler != null && await webShareHandler!(request)) {
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
        }
      });
    } catch (e) {
      debugPrint('Failed to start server: $e');
    }

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

  void _handleTcpClient(Socket socket) async {
    final jobId = _uuid.v4();
    _activeReceiveSockets[jobId] = socket;

    socket.setOption(SocketOption.tcpNoDelay, true);

    try {
      final headerBytes = <int>[];
      List<int>? leftover;
      bool headerDone = false;

      final completer = Completer<void>();
      late StreamSubscription<List<int>> sub;

      sub = socket.listen(
        (chunk) {
          if (headerDone) return;
          for (int i = 0; i < chunk.length; i++) {
            if (chunk[i] == 0x0A) {
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
          if (!_activeReceiveSockets.containsKey(jobId)) {
            cancelled = true;
          }
          if (!dataCompleter.isCompleted) dataCompleter.complete();
        });

        sub.resume();
        await dataCompleter.future;
      }

      await sink.flush();
      await sink.close();

      if (cancelled) {
        try { await file.delete(); } catch (_) {}
        _activeReceiveSockets.remove(jobId);
        return;
      }

      onFileReceiveSaving?.call(jobId);

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

  DateTime? _lastHttpUploadCancelTime;

  /// Cancel an active receive job by jobId (closes socket) and notify the sender.
  void cancelReceiveJob(String jobId) {
    final sock = _activeReceiveSockets.remove(jobId);
    if (sock != null) {
      try {
        sock.destroy();
      } catch (_) {}
    }
    _lastHttpUploadCancelTime = DateTime.now();
    debugPrint(
      '[ConnectionManager] cancelReceiveJob($jobId) called. Cancelling ${_activeHttpUploads.length} active uploads.',
    );
    onHttpUploadCancelled?.call();
    final uploadIds = List<String>.from(_activeHttpUploads.keys);
    for (final id in uploadIds) {
      final httpReq = _activeHttpUploads.remove(id);
      if (httpReq != null) {
        _cancelledHttpUploadIds.add(id);
        try {
          httpReq.response.persistentConnection = false;
          httpReq.response.statusCode = HttpStatus.badRequest;
          httpReq.response.headers.contentType = ContentType.json;
          httpReq.response.headers.set(HttpHeaders.connectionHeader, 'close');
          httpReq.response.write(
            jsonEncode({
              'status': 'cancelled',
              'error': 'Transfer cancelled by recipient',
            }),
          );
          httpReq.response.close().catchError((_) {});
        } catch (_) {}
      }
    }
    if (jobId == _activeMultiReceiveJobId) {
      _activeMultiReceiver?.cancel();
      _activeMultiReceiver = null;
      _activeMultiReceiveJobId = null;
    }
    _broadcastControl({'type': 'transfer_cancelled_by_receiver'});
  }

  /// Send a cancel notification to a specific device (used by sender side).
  void sendTransferCancelledBySender(String deviceName) {
    final ch = _activeChannels[deviceName];
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode({'type': 'transfer_cancelled_by_sender'}));
    } catch (_) {}
  }

  /// Broadcast a JSON control message to all connected WebSocket channels.
  void _broadcastControl(Map<String, dynamic> msg) {
    final encoded = jsonEncode(msg);
    for (final ch in _activeChannels.values) {
      try {
        ch.sink.add(encoded);
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
      final mode = request.uri.queryParameters['mode'] ?? 'wifi';

      if (_activeChannels.containsKey(requesterName)) {
        debugPrint(
          '[WebSocket] Duplicate connection from $requesterName — closing extra socket.',
        );
        await socket.close(WebSocketStatus.normalClosure, 'duplicate');
        return;
      }

      _setupChannel(
        requesterName,
        IOWebSocketChannel(socket),
        ip: deviceIp,
        mode: mode,
      );
    } else {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
    }
  }

  /// Tracks device names currently being connected — prevents duplicate
  /// _setupChannel calls when "Via Both" fires two parallel connects.
  final Set<String> _pendingConnects = {};

  /// Called by Device A to connect to Device B after scanning QR or entering IP
  Future<bool> connectToDevice(
    String ip,
    int port,
    String token,
    String myDeviceName, {
    String? targetDeviceName,
    List<String> extraIps = const [],
    String connectionMode = 'wifi',
  }) async {
    final name = targetDeviceName ?? 'Device ($ip)';

    if (_activeChannels.containsKey(name) || _pendingConnects.contains(name)) {
      debugPrint(
        '[connectToDevice] $name already connected/pending — skipping $ip',
      );
      return false;
    }
    _pendingConnects.add(name);

    try {
      final wsUrl = Uri.parse(
        'ws://$ip:$port/ws?code=$token'
        '&name=${Uri.encodeComponent(myDeviceName)}'
        '&mode=${Uri.encodeComponent(connectionMode)}',
      );
      final socket = await WebSocket.connect(
        wsUrl.toString(),
      ).timeout(const Duration(seconds: 7));
      final channel = IOWebSocketChannel(socket);
      _setupChannel(name, channel, ip: ip, mode: connectionMode);
      if (extraIps.isNotEmpty) {
        _deviceAllIps[name] = extraIps.toList();
      }
      return true;
    } catch (e) {
      debugPrint('Error connecting WebSocket: $e');
      return false;
    } finally {
      _pendingConnects.remove(name);
    }
  }

  /// Schedules [notifyListeners] on the next frame so it never fires while
  /// the widget tree is locked (e.g. during layout or a build pass).
  /// Also ensures a frame is scheduled so the callback actually fires even
  /// when the screen is idle (no animations running).
  void _safeNotify() {
    SchedulerBinding.instance
      ..ensureVisualUpdate()
      ..addPostFrameCallback((_) {
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
    _activeMultiReceiver?.cancel();
    _activeMultiReceiver = null;
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
    String mode = 'wifi',
  }) {
    if (_activeChannels.containsKey(deviceName)) {
      final old = _activeChannels[deviceName]!;
      _replacedChannels.add(old);
      old.sink.close();
    }

    _activeChannels[deviceName] = channel;
    if (ip != null) _deviceIps[deviceName] = ip;
    _deviceConnectionMode[deviceName] = mode;

    debugPrint(
      'Vortex Devices Linked Successfully! ($deviceName, ip: $ip, mode: $mode)',
    );

    SchedulerBinding.instance
      ..ensureVisualUpdate()
      ..addPostFrameCallback((_) {
        onConnectionEstablished?.call();
      });
    _safeNotify();

    channel.stream.listen(
      (message) {
        debugPrint('Received message from $deviceName: $message');
        _handleControlMessage(deviceName, message);
      },
      onDone: () {
        debugPrint('WebSocket connection closed with $deviceName');
        if (_replacedChannels.remove(channel)) return;
        _activeChannels.remove(deviceName);
        _deviceConnectionMode.remove(deviceName);
        _safeNotify();
      },
      onError: (error) {
        debugPrint('WebSocket error with $deviceName: $error');
        if (_replacedChannels.remove(channel)) return;
        _activeChannels.remove(deviceName);
        _deviceConnectionMode.remove(deviceName);
        _safeNotify();
      },
    );
  }

  /// Callback fired when a multi-channel transfer completes on receive side.
  Function(String relativePath, String savedPath)? onMultiChannelFileReceived;

  /// Called when a mc_request or mc_accept arrives over the WebSocket.
  void _handleControlMessage(String deviceName, dynamic rawMessage) {
    try {
      final msg = jsonDecode(rawMessage as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;

      switch (type) {
        case 'mc_request':
          _handleMultiChannelRequest(deviceName, msg);
          break;
        case 'mc_accept':
          if (!_pendingMcAccept.isCompleted) {
            _pendingMcAccept.complete(msg);
          }
          break;
        case 'transfer_cancelled_by_sender':
          onSenderCancelledTransfer?.call();
          break;
        case 'transfer_cancelled_by_receiver':
          onReceiverCancelledTransfer?.call();
          break;
        default:
          break;
      }
    } catch (_) {
    }
  }

  Completer<Map<String, dynamic>> _pendingMcAccept = Completer();

  /// Called by TransferService on the SENDER side: sends a mc_request to the
  /// receiver and waits for mc_accept.
  Future<Map<String, dynamic>> requestMultiChannel({
    required String deviceName,
    required List<Map<String, dynamic>> files,
  }) async {
    _localEndpoints = await enumerateInterfaces();

    _pendingMcAccept = Completer<Map<String, dynamic>>();

    final request = McProtocol.buildRequest(
      files: files,
      senderChannels: _localEndpoints,
    );
    final channel = _activeChannels[deviceName];
    if (channel == null) throw Exception('Device $deviceName not connected');

    channel.sink.add(jsonEncode(request));

    final response = await _pendingMcAccept.future.timeout(
      const Duration(seconds: 15),
    );
    return response;
  }

  /// RECEIVER side — handle the incoming mc_request.
  Future<void> _handleMultiChannelRequest(
    String deviceName,
    Map<String, dynamic> msg,
  ) async {
    try {
      if (_activeMultiReceiver != null) {
        debugPrint('[MultiRecv] Replacing previous active receiver');
        if (_activeMultiReceiveJobId != null) {
          onFileReceiveError?.call(
            _activeMultiReceiveJobId!,
            'Previous transfer was replaced by a new request',
          );
        }
        _activeMultiReceiver!.cancel();
        _activeMultiReceiver = null;
        _activeMultiReceiveJobId = null;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      final senderChannels = (msg['channels'] as List)
          .map((e) => ChannelEndpoint.fromJson(e as Map<String, dynamic>))
          .toList();
      final files = msg['files'] as List<dynamic>;

      int totalBytes = 0;
      for (final f in files) {
        if (f['isDir'] != true) totalBytes += (f['size'] as int?) ?? 0;
      }

      final jobId = 'mc_${deviceName}_${DateTime.now().millisecondsSinceEpoch}';
      _activeMultiReceiveJobId = jobId;

      _localEndpoints = await enumerateInterfaces();
      final channelCount = senderChannels.length < _localEndpoints.length
          ? senderChannels.length
          : _localEndpoints.length;

      final saveDir = await TransferService.getReceiveDir();

      final fileCount = files.length;
      final String receiveLabel;
      if (fileCount == 1) {
        final firstPath = (files.first['path'] as String?) ?? 'file';
        receiveLabel = firstPath.split('/').last;
      } else {
        receiveLabel = '$fileCount files from $deviceName';
      }

      _activeMultiReceiver = MultiChannelReceiver(
        channelCount: channelCount,
        saveBasePath: saveDir.path,
        onProgress: (received, total, channels) {
          onFileReceiveProgress?.call(jobId, received);
        },
        onComplete: () {
          debugPrint('[MultiRecv] Transfer from $deviceName complete');
          onFileReceiveComplete?.call(
            jobId,
            receiveLabel,
            saveDir.path,
          );
          _activeMultiReceiver = null;
          _activeMultiReceiveJobId = null;
        },
        onError: (e) {
          debugPrint('[MultiRecv] Error from $deviceName: $e');
          onFileReceiveError?.call(jobId, e);
          _activeMultiReceiver = null;
          _activeMultiReceiveJobId = null;
        },
        onFileReceived: (relativePath, savedPath) {
          onFileReceived?.call(relativePath, savedPath);
        },
      );

      _activeMultiReceiver!.start(totalBytes: totalBytes).catchError((e) {
        debugPrint('[MultiRecv] Fatal: $e');
        onFileReceiveError?.call(jobId, e.toString());
        _activeMultiReceiver = null;
        _activeMultiReceiveJobId = null;
      });

      await _activeMultiReceiver!.readyFuture.timeout(
        const Duration(seconds: 10),
      );

      final matchedEndpoints = <ChannelEndpoint>[];
      for (int ci = 0; ci < channelCount; ci++) {
        final senderIp = senderChannels[ci].ip;
        final match = _localEndpoints.firstWhere(
          (local) => _sameSubnet(local.ip, senderIp),
          orElse: () => _localEndpoints.first,
        );
        matchedEndpoints.add(match);
      }
      final accept = McProtocol.buildAccept(receiverChannels: matchedEndpoints);
      final channel = _activeChannels[deviceName];
      channel?.sink.add(jsonEncode(accept));

      onFileReceiveStart?.call(jobId, receiveLabel, totalBytes);
    } catch (e) {
      debugPrint('[MultiRecv] Failed to set up multi-channel: $e');
    }
  }

  /// Returns true if [ip1] and [ip2] are on the same /24 subnet.
  static bool _sameSubnet(String ip1, String ip2) {
    final p1 = ip1.split('.');
    final p2 = ip2.split('.');
    if (p1.length != 4 || p2.length != 4) return false;
    return p1[0] == p2[0] && p1[1] == p2[1] && p1[2] == p2[2];
  }

  Future<void> handleUpload(HttpRequest request) async {
    if (_lastHttpUploadCancelTime != null &&
        DateTime.now().difference(_lastHttpUploadCancelTime!).inMilliseconds < 4000) {
      debugPrint('[Upload] Rejecting post-cancel request');
      request.response
        ..persistentConnection = false
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.json
        ..headers.set(HttpHeaders.connectionHeader, 'close')
        ..write(jsonEncode({'status': 'cancelled', 'error': 'Transfer was cancelled'}))
        ..close().catchError((_) {});
      return;
    }

    _lastHttpUploadCancelTime = null;
    onHttpUploadStarted?.call();

    final jobId = _uuid.v4();
    _activeHttpUploads[jobId] = request;
    String relativePath = 'received_file';
    File? file;
    IOSink? sink;
    bool wasCancelled = false;
    try {
      final encoded = request.headers.value('x-vortex-path') ?? 'received_file';
      relativePath = Uri.decodeComponent(encoded);

      final totalBytes = request.contentLength;

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

      file = File('${targetDir.path}/$fileName');
      sink = file.openWrite();

      onFileReceiveStart?.call(jobId, relativePath, totalBytes);

      int received = 0;
      int pendingNotify = 0;
      await for (final chunk in request) {
        if (_cancelledHttpUploadIds.contains(jobId) ||
            (_lastHttpUploadCancelTime != null &&
                DateTime.now()
                        .difference(_lastHttpUploadCancelTime!)
                        .inSeconds <
                    4)) {
          debugPrint('[Upload] Cancel detected during streaming for $jobId');
          wasCancelled = true;
          break;
        }
        sink.add(chunk);
        received += chunk.length;
        pendingNotify += chunk.length;

        if (totalBytes > 0 && received >= totalBytes) {
          onFileReceiveProgress?.call(jobId, received);
        } else if (pendingNotify >= 65536) {
          pendingNotify = 0;
          onFileReceiveProgress?.call(jobId, received);
        }
      }

      if (wasCancelled || _cancelledHttpUploadIds.contains(jobId)) {
        await sink.flush();
        await sink.close();
        try {
          if (file.existsSync()) await file.delete();
        } catch (_) {}
        return;
      }

      if (totalBytes > 0 && received < totalBytes) {
        await sink.flush();
        await sink.close();
        try {
          if (file.existsSync()) await file.delete();
        } catch (_) {}
        onFileReceiveError?.call(
          jobId,
          'Upload incomplete (sent $received of $totalBytes bytes)',
        );
        try {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'status': 'error', 'error': 'Incomplete upload'}))
            ..close();
        } catch (_) {}
        return;
      }

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
      try {
        await sink?.flush();
        await sink?.close();
      } catch (_) {}
      if (file != null) {
        try {
          if (file.existsSync()) await file.delete();
        } catch (_) {}
      }
      onFileReceiveError?.call(jobId, 'Upload interrupted: $e');
      try {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..close();
      } catch (_) {}
    } finally {
      _activeHttpUploads.remove(jobId);
      _cancelledHttpUploadIds.remove(jobId);
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
    _deviceAllIps.remove(deviceName);
    _deviceConnectionMode.remove(deviceName);
    if (channel != null) {
      _replacedChannels.add(channel);
      await channel.sink.close();
    }
    _safeNotify();
  }

  Future<void> disconnectAll() async {
    for (var channel in _activeChannels.values) {
      _replacedChannels.add(channel);
      await channel.sink.close();
    }
    _activeChannels.clear();
    _deviceIps.clear();
    _deviceAllIps.clear();
    _deviceConnectionMode.clear();
    _replacedChannels.clear();
    _safeNotify();
  }
}
