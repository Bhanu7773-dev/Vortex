import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ConnectionManager extends ChangeNotifier {
  // Fixed port so it can be opened in the OS firewall once and for all.
  // UDP discovery uses 46465; the HTTP/WebSocket server uses 46466.
  static const int serverFixedPort = 46466;

  HttpServer? _httpServer;

  // Maps deviceName -> WebSocketChannel
  final Map<String, WebSocketChannel> _activeChannels = {};

  String? _currentPairCode;
  String? _pendingDeviceName; // Temporarily store the requester's name

  // Callback when another device wants to link with this one
  // Provides (requesterDeviceName, generatedPairCode)
  Function(String deviceName, String pairCode)? onIncomingLinkRequest;

  // Callback when WebSocket is successfully connected
  VoidCallback? onConnectionEstablished;

  bool get isLinked => _activeChannels.isNotEmpty;
  List<String> get connectedDeviceNames => _activeChannels.keys.toList();
  int? get serverPort => _httpServer?.port;

  final _uuid = const Uuid();
  late final String deviceId;

  ConnectionManager() {
    deviceId = _uuid.v4();
  }

  /// Starts the background HTTP server on the fixed Vortex port.
  Future<void> startServer() async {
    if (_httpServer != null) return;

    try {
      _httpServer = await HttpServer.bind(
        InternetAddress.anyIPv4,
        serverFixedPort,
        shared: true,  // allows re-binding after hot-restart
      );
      debugPrint('Vortex Server listening on port: ${_httpServer!.port}');

      _httpServer!.listen((HttpRequest request) async {
        if (request.uri.path == '/request_link' && request.method == 'POST') {
          await _handleLinkRequest(request);
        } else if (request.uri.path == '/ws') {
          await _handleWebSocketUpgrade(request);
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
        }
      });
    } catch (e) {
      debugPrint('Failed to start server: $e');
    }
  }

  /// Handles incoming requests from other devices trying to connect
  Future<void> _handleLinkRequest(HttpRequest request) async {
    try {
      final content = await utf8.decoder.bind(request).join();
      final data = jsonDecode(content);
      final requesterName = data['deviceName'] ?? 'Unknown Device';

      // Generate a random 6 digit code
      _currentPairCode = (Random().nextInt(900000) + 100000).toString();
      _pendingDeviceName = requesterName;

      // Notify the UI to show the code to the user
      if (onIncomingLinkRequest != null) {
        onIncomingLinkRequest!(requesterName, _currentPairCode!);
      }

      // Tell the requester that we are waiting for the code via WebSocket
      request.response
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({'status': 'waiting_for_websocket'}))
        ..close();
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
    }
  }

  /// Completes the connection if the correct pairing code is provided
  Future<void> _handleWebSocketUpgrade(HttpRequest request) async {
    final providedCode = request.uri.queryParameters['code'];

    if (providedCode == null || providedCode != _currentPairCode) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..write('Invalid pair code')
        ..close();
      return;
    }

    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      _setupChannel(
        _pendingDeviceName ?? 'Unknown Device',
        IOWebSocketChannel(socket),
      );
      _currentPairCode = null; // Clear code after successful use
      _pendingDeviceName = null;
    } else {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
    }
  }

  // ============== CLIENT (INITIATOR) METHODS ==============

  /// Called by Device A to trigger the pairing popup on Device B
  Future<bool> sendLinkRequest(String ip, int port, String myDeviceName) async {
    try {
      final url = Uri.parse('http://$ip:$port/request_link');
      final request = await HttpClient().postUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({'deviceName': myDeviceName, 'deviceId': deviceId}),
      );

      final response = await request.close();
      return response.statusCode == HttpStatus.ok;
    } catch (e) {
      debugPrint('Error sending link request: $e');
      return false;
    }
  }

  /// Called by Device A after the user enters the code they see on Device B
  Future<bool> connectWebSocket(
    String ip,
    int port,
    String code,
    String targetDeviceName,
  ) async {
    try {
      final wsUrl = Uri.parse('ws://$ip:$port/ws?code=$code');
      final socket = await WebSocket.connect(wsUrl.toString());
      final channel = IOWebSocketChannel(socket);
      _setupChannel(targetDeviceName, channel);
      return true;
    } catch (e) {
      debugPrint('Error connecting WebSocket: $e');
      return false;
    }
  }

  // ============== COMMON WEBSOCKET LOGIC ==============

  void _setupChannel(String deviceName, WebSocketChannel channel) {
    if (_activeChannels.containsKey(deviceName)) {
      _activeChannels[deviceName]!.sink.close();
    }

    _activeChannels[deviceName] = channel;

    debugPrint('Vortex Devices Linked Successfully! ($deviceName)');
    onConnectionEstablished?.call();
    notifyListeners();

    channel.stream.listen(
      (message) {
        debugPrint('Received message from $deviceName: $message');
        // TODO: Handle incoming files, ping/pong, etc.
      },
      onDone: () {
        debugPrint('WebSocket connection closed with $deviceName');
        _activeChannels.remove(deviceName);
        notifyListeners();
      },
      onError: (error) {
        debugPrint('WebSocket error with $deviceName: $error');
        _activeChannels.remove(deviceName);
        notifyListeners();
      },
    );
  }

  void sendMessageToAll(String message) {
    for (var channel in _activeChannels.values) {
      channel.sink.add(message);
    }
  }

  Future<void> disconnectDevice(String deviceName) async {
    final channel = _activeChannels.remove(deviceName);
    await channel?.sink.close();
    notifyListeners();
  }

  Future<void> disconnectAll() async {
    for (var channel in _activeChannels.values) {
      await channel.sink.close();
    }
    _activeChannels.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    disconnectAll();
    _httpServer?.close(force: true);
    super.dispose();
  }
}
