import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;

class DiscoveryService extends ChangeNotifier {
  static const String serviceType = '_vortex._tcp';

  nsd.Discovery? _discovery;
  nsd.Registration? _registration;

  List<nsd.Service> _discoveredServices = [];
  List<nsd.Service> get discoveredServices => _discoveredServices;

  String? _registeredName;
  String get registeredName => _registeredName ?? 'Vortex Device';

  bool get isDiscovering => _discovery != null;
  bool get isRegistered => _registration != null;

  /// Starts listening for other Vortex devices on the local network
  Future<void> startDiscovery() async {
    if (_discovery != null) return;

    try {
      _discovery = await nsd.startDiscovery(serviceType);
      _discovery!.addListener(() {
        final uniqueServices = <String, nsd.Service>{};

        for (final service in _discovery!.services) {
          // Aggressively strip '(2)', '(3)' etc. which happen when mDNS caches records across hot restarts
          // e.g. "RMX3762 (2)" becomes "RMX3762"
          String rawName = service.name ?? 'Unknown Device';
          String baseName = rawName.replaceAll(RegExp(r'\s*\(\d+\)$'), '');

          // Filter out our own device using the base name! This ensures that even if we hot restart
          // and get a new deviceId, the ghost record of our old deviceId (which shares our base name)
          // will still be filtered out perfectly.
          if (_registeredName != null && baseName == _registeredName) {
            continue;
          }

          // Group by base name to perfectly squash all ghost records of another device into exactly 1 entry
          uniqueServices[baseName] = service;
        }

        _discoveredServices = uniqueServices.values.toList();
        notifyListeners();
      });
      debugPrint('Started mDNS discovery for $serviceType');
    } catch (e) {
      debugPrint('Error starting discovery: $e');
    }
  }

  /// Stops listening for other devices
  Future<void> stopDiscovery() async {
    if (_discovery == null) return;

    try {
      await nsd.stopDiscovery(_discovery!);
      _discovery = null;
      _discoveredServices.clear();
      notifyListeners();
      debugPrint('Stopped mDNS discovery');
    } catch (e) {
      debugPrint('Error stopping discovery: $e');
    }
  }

  /// Broadcasts this device's presence on the network
  Future<void> registerService(
    String deviceName,
    String deviceId,
    int port,
  ) async {
    if (_registration != null) return;

    _registeredName = deviceName;

    try {
      final service = nsd.Service(
        name: deviceName,
        type: serviceType,
        port: port,
        txt: {
          'platform': Uint8List.fromList(Platform.operatingSystem.codeUnits),
          'deviceId': Uint8List.fromList(deviceId.codeUnits),
        }, // Optional metadata
      );

      _registration = await nsd.register(service);
      debugPrint('Registered mDNS service $deviceName on port $port');
      notifyListeners();
    } catch (e) {
      debugPrint('Error registering service: $e');
    }
  }

  /// Stops broadcasting this device's presence
  Future<void> unregisterService() async {
    if (_registration == null) return;

    try {
      await nsd.unregister(_registration!);
      _registration = null;
      debugPrint('Unregistered mDNS service');
      notifyListeners();
    } catch (e) {
      debugPrint('Error unregistering service: $e');
    }
  }

  @override
  void dispose() {
    stopDiscovery();
    unregisterService();
    super.dispose();
  }
}
