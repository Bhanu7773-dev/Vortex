import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_intent_plus/android_intent.dart';

import '../../services/connection_manager.dart';

class ConnectDeviceView extends StatefulWidget {
  final bool isUsbMode;
  const ConnectDeviceView({Key? key, this.isUsbMode = false}) : super(key: key);

  @override
  State<ConnectDeviceView> createState() => _ConnectDeviceViewState();
}

class _ConnectDeviceViewState extends State<ConnectDeviceView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  String _myDeviceName = 'Unknown Device';
  String _myIp = '127.0.0.1';
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: Platform.isAndroid || Platform.isIOS ? 3 : 2,
      vsync: this,
    );
    _fetchNetworkInfo();
  }

  Future<void> _fetchNetworkInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceName = 'Unknown Device';
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        deviceName = linuxInfo.prettyName;
      }
    } catch (_) {}

    final best = await _pickBestIp(widget.isUsbMode);

    if (mounted) {
      setState(() {
        _myDeviceName = deviceName;
        _myIp = best;
      });
    }
  }

  /// Automatically picks the best IP for the given mode.
  /// USB mode priority:
  ///   1. 192.168.42-44.x  – Android tethering subnet (most reliable)
  ///   2. usb*/rndis*/enp*u*/eth* interface names
  ///   3. Any non-loopback IP
  /// Wi-Fi mode priority:
  ///   1. wlan*/wifi*/en0 interface
  ///   2. eth* interface
  ///   3. Any non-loopback IP
  static Future<String> _pickBestIp(bool usbMode) async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      final candidates = <({int score, String ip})>[];

      for (final iface in interfaces) {
        final n = iface.name.toLowerCase();
        // Skip virtual/container interfaces
        if (n.startsWith('docker') || n.startsWith('veth') ||
            n.startsWith('virbr') || n.startsWith('br-') ||
            n.startsWith('vmnet') || n.startsWith('tun') ||
            n.startsWith('tap')) continue;

        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final ip = addr.address;
          int score = 0;

          if (usbMode) {
            // Strongest signal: Android USB tethering subnets
            if (ip.startsWith('192.168.42.') ||
                ip.startsWith('192.168.43.') ||
                ip.startsWith('192.168.44.')) score = 100;
            // USB interface names on Linux
            else if (n.startsWith('usb') || n.startsWith('rndis')) score = 80;
            // Generic USB host: enp0s26u1u1, enp0s20u1, etc.
            else if (RegExp(r'u\d').hasMatch(n)) score = 70;
            else if (n.startsWith('eth')) score = 40;
            else score = 10;
          } else {
            // Wi-Fi mode
            if (n.startsWith('wlan') || n.startsWith('wifi')) score = 100;
            else if (n == 'en0') score = 90;
            else if (n.startsWith('en')) score = 70;
            else if (n.startsWith('eth')) score = 50;
            else score = 10;
          }

          candidates.add((score: score, ip: ip));
          debugPrint('[Net] $n → $ip  (score $score)');
        }
      }

      if (candidates.isEmpty) return '127.0.0.1';
      candidates.sort((a, b) => b.score.compareTo(a.score));
      return candidates.first.ip;
    } catch (e) {
      debugPrint('Error detecting IP: $e');
      return '127.0.0.1';
    }
  }

  void _handleQrDetect(BarcodeCapture capture) {
    if (_isConnecting) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    try {
      final data = jsonDecode(rawValue);
      if (data['ip'] == null || data['token'] == null || data['port'] == null) {
        return; // Not a valid Vortex QR
      }

      setState(() => _isConnecting = true);

      _connectToTarget(
        ip: data['ip'],
        port: data['port'],
        token: data['token'],
        targetName: data['name'] ?? 'Device',
      );
    } catch (_) {
      // Invalid JSON
    }
  }

  void _connectToTarget({
    required String ip,
    required int port,
    required String token,
    required String targetName,
  }) async {
    final cm = context.read<ConnectionManager>();

    final success = await cm.connectToDevice(
      ip,
      port,
      token,
      _myDeviceName,
      targetDeviceName: targetName,
    );

    if (mounted) {
      if (success) {
        Navigator.pop(context); // Close sheet
      } else {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to connect to $targetName at $ip'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCamera = Platform.isAndroid || Platform.isIOS;
    final cm = context.watch<ConnectionManager>();

    final qrData = jsonEncode({
      'ip': _myIp,
      'port': ConnectionManager.serverFixedPort,
      'token': cm.qrToken,
      'name': _myDeviceName,
    });

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.isUsbMode ? 'Connect via USB' : 'Connect Device',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.isUsbMode && Platform.isAndroid)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.usb, color: Colors.white),
                label: const Text(
                  'Open Tethering Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () async {
                  // Try explicit tether settings first, which is standard on AOSP
                  try {
                    const intent = AndroidIntent(
                      action: 'android.settings.TETHER_SETTINGS',
                    );
                    await intent.launch();
                  } catch (e) {
                    // Fallback for custom skins (like Realme UI, MIUI) which might hide it
                    try {
                      const fallbackIntent = AndroidIntent(
                        action: 'android.settings.WIRELESS_SETTINGS',
                      );
                      await fallbackIntent.launch();
                    } catch (_) {
                      // Do nothing if even wireless settings fail
                    }
                  }
                },
              ),
            ),
          if (widget.isUsbMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: TextButton.icon(
                onPressed: _fetchNetworkInfo,
                icon: const Icon(Icons.refresh, color: Colors.white54),
                label: const Text(
                  'Refresh Network',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.purpleAccent,
            labelColor: Colors.purpleAccent,
            unselectedLabelColor: Colors.white54,
            tabs: [
              if (hasCamera) const Tab(text: 'Scan QR'),
              const Tab(text: 'My QR'),
              const Tab(text: 'Manual IP'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                if (hasCamera) _buildScannerTab(),
                _buildMyQrTab(qrData, cm.qrToken),
                _buildManualTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerTab() {
    return Stack(
      children: [
        MobileScanner(onDetect: _handleQrDetect),
        if (_isConnecting)
          Container(
            color: Colors.black87,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.purpleAccent),
                  SizedBox(height: 16),
                  Text(
                    'Connecting...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        // A simple overlay to guide the user
        if (!_isConnecting)
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.purpleAccent, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        if (!_isConnecting)
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Scan Vortex QR code on other device',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
      ],
    );
  }

  Widget _buildMyQrTab(String qrData, String currentToken) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200.0,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _myDeviceName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'IP: $_myIp',
            style: const TextStyle(fontSize: 14, color: Colors.white54),
          ),
          const SizedBox(height: 6),
          Text(
            'Token: $currentToken',
            style: const TextStyle(
              fontSize: 15,
              color: Colors.purpleAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Scan this code from another device to connect instantly.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildManualTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _ipController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Target IP Address',
              labelStyle: TextStyle(color: Colors.white54),
              hintText: 'e.g. 192.168.1.100',
              hintStyle: TextStyle(color: Colors.white24),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.purpleAccent),
              ),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _tokenController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: '6-Digit Token',
              labelStyle: TextStyle(color: Colors.white54),
              hintText: 'e.g. 123456',
              hintStyle: TextStyle(color: Colors.white24),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.purpleAccent),
              ),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isConnecting
                  ? null
                  : () {
                      final ip = _ipController.text.trim();
                      final token = _tokenController.text.trim();
                      if (ip.isEmpty || token.length != 6) return;

                      setState(() => _isConnecting = true);
                      _connectToTarget(
                        ip: ip,
                        port: ConnectionManager.serverFixedPort,
                        token: token,
                        targetName: 'Device ($ip)',
                      );
                    },
              child: _isConnecting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'CONNECT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}


