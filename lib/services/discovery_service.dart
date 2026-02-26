import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;

class DiscoveredDevice {
  final String name;
  final String host;
  final int port;

  DiscoveredDevice({
    required this.name,
    required this.host,
    required this.port,
  });
}

/// Holds a sender socket bound to a specific network interface.
class _InterfaceSender {
  final String interfaceIp;
  final String broadcastAddress;
  final RawDatagramSocket socket;

  _InterfaceSender({
    required this.interfaceIp,
    required this.broadcastAddress,
    required this.socket,
  });
}

class DiscoveryService extends ChangeNotifier {
  static const int broadcastPort = 46465;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    stopDiscovery();
    super.dispose();
  }

  RawDatagramSocket? _receiver;
  // One sender socket per network interface so broadcasts go out on the
  // correct interface with the correct source IP address.
  final List<_InterfaceSender> _senders = [];
  bool _isDiscovering = false;
  Timer? _broadcastTimer;

  final Map<String, DiscoveredDevice> _uniqueServices = {};
  List<DiscoveredDevice> get discoveredServices =>
      _uniqueServices.values.toList();

  String? _registeredName;
  int? _registeredPort;
  final Set<String> _localIps = {};
  String get registeredName => _registeredName ?? 'Vortex Device';

  bool get isDiscovering => _isDiscovering;
  bool get isRegistered => _broadcastTimer != null;

  void _safeNotify() {
    if (_disposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.transientCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  /// Starts listening for other Vortex devices on the local network.
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    _uniqueServices.clear();
    notifyListeners();

    try {
      _receiver = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        broadcastPort,
        reuseAddress: true,
        reusePort: true,
      );
      _receiver!.broadcastEnabled = true;

      _receiver!.listen((RawSocketEvent event) {
        if (event != RawSocketEvent.read) return;
        final datagram = _receiver!.receive();
        if (datagram == null) return;

        try {
          final jsonString = utf8.decode(datagram.data);
          final data = jsonDecode(jsonString);
          if (data['type'] != 'vortex_discovery' ||
              data['name'] == null ||
              data['port'] == null) return;

          final host = datagram.address.address;
          final senderName = data['name'] as String;

          // Filter out our own packets by name or source IP.
          if (_registeredName != null && senderName == _registeredName) return;
          if (_localIps.isNotEmpty && _localIps.contains(host)) return;

          debugPrint('[Discovery] Heard from "$senderName" at $host');
          _handleResolvedService(
            DiscoveredDevice(name: senderName, host: host, port: data['port']),
          );
        } catch (_) {}
      });

      debugPrint('[Discovery] Receiver bound on port $broadcastPort');
    } catch (e) {
      debugPrint('[Discovery] Error starting receiver: $e');
      _isDiscovering = false;
    }
  }

  void _handleResolvedService(DiscoveredDevice service) {
    final baseName = service.name.replaceAll(RegExp(r'\s*\(\d+\)$'), '');
    if (_registeredName != null && baseName == _registeredName) return;
    _uniqueServices[baseName] = service;
    if (!_disposed) {
      _safeNotify();
    }
  }

  /// Stops listening for other devices.
  void stopDiscovery() {
    if (!_isDiscovering) return;
    _isDiscovering = false;
    _receiver?.close();
    _receiver = null;
    _uniqueServices.clear();
    if (!_disposed) {
      _safeNotify();
    }
    debugPrint('[Discovery] Receiver stopped');
  }

  /// Broadcasts this device's presence once per interface so each packet
  /// carries the correct source IP for that subnet.
  Future<void> registerService(
    String deviceName,
    String deviceId,
    int port,
  ) async {
    if (_broadcastTimer != null) return;

    _registeredName = deviceName;
    _registeredPort = port;

    try {
      _localIps.clear();
      for (var sender in _senders) {
        sender.socket.close();
      }
      _senders.clear();

      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (var iface in interfaces) {
        for (var addr in iface.addresses) {
          if (addr.isLoopback) continue;

          // Skip obviously virtual interfaces (Docker, VirtualBox, VMware, VPN)
          final name = iface.name.toLowerCase();
          if (name.startsWith('docker') ||
              name.startsWith('virbr') ||
              name.startsWith('veth') ||
              name.startsWith('br-') ||
              name.startsWith('vmnet') ||
              name.startsWith('tun') ||
              name.startsWith('tap')) continue;

          _localIps.add(addr.address);
          final parts = addr.address.split('.');
          if (parts.length != 4) continue;
          final subnetBcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';

          try {
            // Bind sender to THIS interface's IP so the UDP source address
            // is the correct WiFi/Ethernet IP — not a Docker or VPN address.
            final sock = await RawDatagramSocket.bind(
              InternetAddress(addr.address),
              0,
              reuseAddress: true,
            );
            sock.broadcastEnabled = true;
            _senders.add(_InterfaceSender(
              interfaceIp: addr.address,
              broadcastAddress: subnetBcast,
              socket: sock,
            ));
            debugPrint(
              '[Discovery] Sender bound to ${addr.address} '
              '→ broadcasts $subnetBcast (${iface.name})',
            );
          } catch (e) {
            debugPrint('[Discovery] Could not bind sender on ${addr.address}: $e');
          }
        }
      }

      // Fallback: if no interface sockets succeeded, use 0.0.0.0 → 255.255.255.255
      if (_senders.isEmpty) {
        final sock = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
          reuseAddress: true,
        );
        sock.broadcastEnabled = true;
        _senders.add(_InterfaceSender(
          interfaceIp: '0.0.0.0',
          broadcastAddress: '255.255.255.255',
          socket: sock,
        ));
        debugPrint('[Discovery] Fallback sender on 0.0.0.0');
      }

      _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _broadcastDiscoveryPacket();
      });
      _broadcastDiscoveryPacket();

      debugPrint(
        '[Discovery] Registered "$deviceName" port $port '
        'localIps: $_localIps',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[Discovery] Error registering: $e');
    }
  }

  void _broadcastDiscoveryPacket() {
    if (_senders.isEmpty || _registeredName == null || _registeredPort == null) {
      return;
    }
    final bytes = utf8.encode(jsonEncode({
      'type': 'vortex_discovery',
      'name': _registeredName,
      'port': _registeredPort,
    }));

    for (final sender in _senders) {
      try {
        sender.socket.send(
          bytes,
          InternetAddress(sender.broadcastAddress),
          broadcastPort,
        );
      } catch (_) {}
    }
  }

  /// Stops broadcasting this device's presence.
  void unregisterService() {
    if (_broadcastTimer == null) return;
    _broadcastTimer!.cancel();
    _broadcastTimer = null;
    for (var s in _senders) {
      s.socket.close();
    }
    _senders.clear();
    _localIps.clear();
    debugPrint('[Discovery] Unregistered');
    notifyListeners();
  }
}

