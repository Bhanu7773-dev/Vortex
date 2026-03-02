import 'dart:async';
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
  final bool isBothMode;
  const ConnectDeviceView({
    Key? key,
    this.isUsbMode = false,
    this.isBothMode = false,
  }) : super(key: key);

  @override
  State<ConnectDeviceView> createState() => _ConnectDeviceViewState();
}

class _ConnectDeviceViewState extends State<ConnectDeviceView>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _radarController;
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  String _myDeviceName = 'Unknown Device';
  String _myIp = '127.0.0.1';
  String? _wifiIp;      // This device's WiFi/LAN interface IP
  List<String> _myAllIps = []; // populated in isBothMode
  bool _isConnecting = false;
  String? _usbPeerIp;   // IP of connected computer via USB tethering
  String? _usbPhoneIp;  // This device's own USB tethering interface IP
  Timer? _usbPollTimer; // Polls USB status while sheet is open

  String? _scanError;   // Inline error shown in the scanner tab
  bool _scanCooldown = false; // Prevents repeated scans after an error

  bool get _isUsbConnected => _usbPhoneIp != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: Platform.isAndroid || Platform.isIOS ? 3 : 2,
      vsync: this,
    );
    _radarController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();
    _fetchNetworkInfo();
    // Poll USB status every 2 s so the card updates without needing a manual refresh
    if (widget.isUsbMode || widget.isBothMode) {
      _usbPollTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _detectUsbPeerIp(),
      );
    }
  }

  /// Collects ALL usable IPv4 interfaces (for Both mode).
  static Future<List<String>> _getAllIps() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      final ips = <String>[];
      for (final iface in interfaces) {
        final n = iface.name.toLowerCase();
        if (n.startsWith('docker') || n.startsWith('veth') ||
            n.startsWith('virbr') || n.startsWith('br-') ||
            n.startsWith('vmnet') || n.startsWith('tun') ||
            n.startsWith('tap')) continue;
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) ips.add(addr.address);
        }
      }
      return ips;
    } catch (_) {
      return [];
    }
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

    // In Both mode also grab every interface IP
    if (widget.isBothMode) {
      final all = await _getAllIps();
      if (mounted) setState(() => _myAllIps = all);
    }

    // Detect connected USB computer IP via ARP cache
    if (widget.isUsbMode || widget.isBothMode) await _detectUsbPeerIp();

    // Detect WiFi IP for QR embedding (so the other device can verify same network)
    await _detectWifiIp();
  }

  /// Finds THIS device's WiFi/LAN interface IP (any non-loopback, non-USB IP).
  Future<void> _detectWifiIp() async {
    // USB subnet helper reused here
    bool looksLikeUsb(String addr) =>
        addr.startsWith('192.168.42.') ||
        addr.startsWith('192.168.43.') ||
        addr.startsWith('192.168.44.') ||
        (_usbPhoneIp != null &&
            addr.startsWith(
                _usbPhoneIp!.substring(0, _usbPhoneIp!.lastIndexOf('.') + 1)));

    String? found;
    try {
      final ifaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLinkLocal: false);
      for (final iface in ifaces) {
        final n = iface.name.toLowerCase();
        // Skip virtual interfaces
        if (n.startsWith('docker') || n.startsWith('veth') ||
            n.startsWith('virbr') || n.startsWith('br-')) continue;
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !looksLikeUsb(addr.address)) {
            found = addr.address;
            break;
          }
        }
        if (found != null) break;
      }
    } catch (_) {}
    if (mounted) setState(() => _wifiIp = found);
  }

  /// Scans all network interfaces for a USB tethering IP, then checks ARP
  /// for the connected computer's IP.
  Future<void> _detectUsbPeerIp() async {
    // USB tethering interface names used by Android (RNDIS, CDC-ECM, NCM)
    const usbIfaceNames = ['rndis', 'usb', 'ncm', 'ecm'];

    String? phoneUsbIp;
    String? detectedPrefix;

    try {
      // includeLinkLocal: true so we don't accidentally miss anything
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: true,
      );

      debugPrint('[USB] All interfaces: ${interfaces.map((i) => '${i.name}:${i.addresses.map((a) => a.address).join(',')}').join(' | ')}');

      for (final iface in interfaces) {
        final n = iface.name.toLowerCase();
        final isUsbIface = usbIfaceNames.any((prefix) => n.startsWith(prefix));
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final ip = addr.address;
          // Match by interface name OR by the well-known Android tethering subnets
          final isUsbSubnet = ip.startsWith('192.168.42.') ||
              ip.startsWith('192.168.43.') ||
              ip.startsWith('192.168.44.');
          if (isUsbIface || isUsbSubnet) {
            phoneUsbIp = ip;
            detectedPrefix = '${ip.substring(0, ip.lastIndexOf('.'))}.';
            debugPrint('[USB] Detected USB iface: $n → $ip');
            break;
          }
        }
        if (phoneUsbIp != null) break;
      }
    } catch (e) {
      debugPrint('[USB] Interface scan error: $e');
    }

    if (mounted) setState(() => _usbPhoneIp = phoneUsbIp);
    if (phoneUsbIp == null || detectedPrefix == null) {
      if (mounted) setState(() => _usbPeerIp = null);
      return;
    }

    // Read ARP cache for the connected computer's IP on the same subnet.
    if (!Platform.isAndroid) return;
    try {
      final arpFile = File('/proc/net/arp');
      if (!await arpFile.exists()) return;
      final lines = await arpFile.readAsLines();
      debugPrint('[USB] ARP: ${lines.join(' | ')}');
      for (final line in lines.skip(1)) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 4) continue;
        final ip = parts[0];
        final mac = parts.length > 3 ? parts[3] : '';
        if (ip.startsWith(detectedPrefix) &&
            ip != phoneUsbIp &&
            mac.isNotEmpty &&
            mac != '00:00:00:00:00:00') {
          if (mounted) setState(() => _usbPeerIp = ip);
          return;
        }
      }
    } catch (e) {
      debugPrint('[USB] ARP read error: $e');
    }
    if (mounted) setState(() => _usbPeerIp = null);
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
            // USB interface names on Linux / Android (RNDIS, CDC-NCM, ECM)
            else if (n.startsWith('usb') || n.startsWith('rndis') ||
                     n.startsWith('ncm') || n.startsWith('ecm')) score = 80;
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

  Future<void> _handleQrDetect(BarcodeCapture capture) async {
    if (_isConnecting || _scanCooldown) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(rawValue) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[QR] Failed to decode JSON: $e');
      return;
    }

    final ip = data['ip'];
    final token = data['token'];
    final port = data['port'];
    if (ip == null || token == null || port == null) {
      debugPrint('[QR] Missing ip/token/port in QR data: $data');
      return;
    }

    // ── Helpers ──────────────────────────────────────────────────────────
    void showError(String msg) {
      if (mounted) setState(() { _scanError = msg; _scanCooldown = true; });
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() { _scanError = null; _scanCooldown = false; });
      });
    }

    final usbPrefix = _usbPhoneIp != null
        ? '${_usbPhoneIp!.substring(0, _usbPhoneIp!.lastIndexOf('.'))}.': null;
    bool isUsbIp(String addr) =>
        (usbPrefix != null && addr.startsWith(usbPrefix)) ||
        addr.startsWith('192.168.42.') ||
        addr.startsWith('192.168.43.') ||
        addr.startsWith('192.168.44.');

    // ── Mode lock: reject QR codes that don't match the selected transport ─
    final String qrMode = data['mode']?.toString() ?? 'wifi';
    final String myMode = widget.isBothMode ? 'both' : widget.isUsbMode ? 'usb' : 'wifi';
    if (qrMode != myMode) {
      final qrLabel = qrMode == 'both' ? 'Via Both' : qrMode == 'usb' ? 'Via USB' : 'Via Wi-Fi';
      showError('Wrong QR — this is a $qrLabel code.\nOpen the $qrLabel option to use it.');
      return;
    }

    // All IPs from the QR (may include several if sender was in Both mode)
    final List<String> allIps = data['ips'] != null
        ? List<String>.from(data['ips'] as List)
        : [ip.toString()];

    // QR-embedded transport IPs from the other device
    final String? remoteWifiIp = data['wifi_ip']?.toString();
    final String? remoteUsbIp  = data['usb_ip']?.toString();

    // ── Fresh scan of THIS device's WiFi IP ───────────────────────────────
    String? myWifi;
    try {
      final ifaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLinkLocal: false);
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !isUsbIp(addr.address)) {
            myWifi = addr.address;
            break;
          }
        }
        if (myWifi != null) break;
      }
    } catch (_) {}
    if (mounted) setState(() => _wifiIp = myWifi);

    // ── Pre-flight: verify both devices have the required transport ──────
    // NOTE: We do NOT compare subnets — hotspots, different DHCP configs,
    // and bridged networks often have different subnets but can still
    // connect. The actual WebSocket attempt will verify reachability.
    if (widget.isUsbMode) {
      if (_usbPhoneIp == null) {
        showError('USB tethering is not active on this device.\n'
            'Enable it in Settings → Hotspot & Tethering → USB Tethering.');
        return;
      }
      if (remoteUsbIp == null && allIps.where(isUsbIp).isEmpty) {
        showError('The other device has no USB tethering active.\n'
            'Both devices need USB tethering enabled and the cable connected.');
        return;
      }
    } else if (!widget.isBothMode) {
      // WiFi mode
      if (myWifi == null) {
        showError('Wi-Fi is not connected on this device.\n'
            'Connect to a Wi-Fi network or hotspot and retry.');
        return;
      }
      // Check other device has a WiFi IP (explicit field, or any non-USB IP)
      final hasRemoteWifi = remoteWifiIp != null ||
          allIps.any((a) => !isUsbIp(a));
      if (!hasRemoteWifi) {
        showError('The other device has no Wi-Fi connection.\n'
            'Both devices must be on the same network or hotspot.');
        return;
      }
    } else {
      // Via Both — need BOTH transports on BOTH devices
      if (myWifi == null) {
        showError('Wi-Fi is not connected on this device.\n'
            'Via Both requires both Wi-Fi and USB active.');
        return;
      }
      final hasRemoteWifi = remoteWifiIp != null ||
          allIps.any((a) => !isUsbIp(a));
      if (!hasRemoteWifi) {
        showError('The other device has no Wi-Fi connection.\n'
            'Both devices need Wi-Fi for Via Both mode.');
        return;
      }
      if (_usbPhoneIp == null) {
        showError('USB tethering is not active on this device.\n'
            'Via Both requires both Wi-Fi and USB active.');
        return;
      }
      if (remoteUsbIp == null && allIps.where(isUsbIp).isEmpty) {
        showError('The other device has no USB tethering.\n'
            'Both devices need USB tethering for Via Both.');
        return;
      }
    }

    // ── Filter IPs to only use the selected transport ─────────────────────
    final List<String> filteredIps;
    if (widget.isUsbMode) {
      final usbIps = allIps.where(isUsbIp).toList();
      if (usbIps.isEmpty) {
        showError(
          'The scanned QR has no USB tethering IP.\n'
          'Make sure the other device also opened "Via USB" or "Via Both".',
        );
        return;
      }
      filteredIps = usbIps;
    } else if (!widget.isBothMode) {
      final wifiIps = allIps.where((a) => !isUsbIp(a)).toList();
      if (wifiIps.isEmpty) {
        showError(
          'The scanned QR has no Wi-Fi IP.\n'
          'Make sure the other device opened "Via Wi-Fi" or "Via Both".',
        );
        return;
      }
      filteredIps = wifiIps;
    } else {
      filteredIps = allIps; // Both: use everything
    }

    setState(() => _isConnecting = true);

    _connectToFirstReachable(
      ips: filteredIps,
      port: port is int ? port : int.parse(port.toString()),
      token: token.toString(),
      targetName: data['name']?.toString() ?? 'Device',
      extraIps: filteredIps,
      connectionMode: widget.isBothMode ? 'both' : widget.isUsbMode ? 'usb' : 'wifi',
    );
  }

  /// Try IPs in parallel; use whichever succeeds first, ignore the rest.
  Future<void> _connectToFirstReachable({
    required List<String> ips,
    required int port,
    required String token,
    required String targetName,
    List<String> extraIps = const [],
    String connectionMode = 'wifi',
  }) async {
    if (ips.isEmpty) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _scanError = 'No suitable IP found for the selected connection mode.';
          _scanCooldown = false;
        });
      }
      return;
    }

    final cm = context.read<ConnectionManager>();
    final winner = Completer<bool>();

    // Race all IPs — first success wins, others are ignored.
    for (final ip in ips) {
      cm
          .connectToDevice(
            ip, port, token, _myDeviceName,
            targetDeviceName: targetName,
            extraIps: extraIps,
            connectionMode: connectionMode,
          )
          .then((success) {
            if (!winner.isCompleted) {
              if (success) winner.complete(true);
            }
          })
          .catchError((e) {
            debugPrint('[Connect] $ip failed: $e');
          });
    }

    // Also complete with false after timeout if nothing worked.
    Future.delayed(const Duration(seconds: 8)).then((_) {
      if (!winner.isCompleted) winner.complete(false);
    });

    final connected = await winner.future;

    if (!mounted) return;
    if (connected) {
      Navigator.pop(context);
    } else {
      final modeHint = connectionMode == 'usb'
          ? 'Check USB tethering is active on both devices.'
          : connectionMode == 'wifi'
              ? 'Check both devices are on the same Wi-Fi network.'
              : 'Check your USB and/or Wi-Fi connection.';
      setState(() {
        _isConnecting = false;
        _scanError = 'Could not connect to $targetName.\n$modeHint';
        _scanCooldown = false;
      });
    }
  }

  void _connectToTarget({
    required String ip,
    required int port,
    required String token,
    required String targetName,
  }) {
    _connectToFirstReachable(
      ips: [ip],
      port: port,
      token: token,
      targetName: targetName,
      connectionMode: widget.isBothMode ? 'both' : widget.isUsbMode ? 'usb' : 'wifi',
    );
  }

  @override
  void dispose() {
    _usbPollTimer?.cancel();
    _tabController.dispose();
    _radarController.dispose();
    _ipController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCamera = Platform.isAndroid || Platform.isIOS;
    final cm = context.watch<ConnectionManager>();

    final String _myMode = widget.isBothMode ? 'both' : widget.isUsbMode ? 'usb' : 'wifi';

    final qrData = jsonEncode({
      'ip': _myIp,
      'port': ConnectionManager.serverFixedPort,
      'token': cm.qrToken,
      'name': _myDeviceName,
      'mode': _myMode,
      if (_wifiIp != null) 'wifi_ip': _wifiIp,
      if (_usbPhoneIp != null) 'usb_ip': _usbPhoneIp,
      if (widget.isBothMode && _myAllIps.isNotEmpty) 'ips': _myAllIps,
    });

    final modeLabel = widget.isBothMode
        ? 'Connect via Wi-Fi + USB'
        : widget.isUsbMode
            ? 'Connect via USB'
            : 'Connect Device';

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
            modeLabel,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.isUsbMode || widget.isBothMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: _buildUsbStatusCard(),
            ),
          // ── Inline error banner (visible on all tabs, stays in the sheet) ────
          if (_scanError != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A0A0A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _scanError!,
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() { _scanError = null; _scanCooldown = false; }),
                    child: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                  ),
                ],
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

  Widget _buildUsbStatusCard() {
    if (_isUsbConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F2318),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.usb_rounded, color: Colors.greenAccent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'USB Tethering Active',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _usbPeerIp != null
                        ? 'Computer IP: $_usbPeerIp'
                        : 'Device IP: $_usbPhoneIp',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 20),
              tooltip: 'Refresh',
              onPressed: _fetchNetworkInfo,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      );
    }
    // Not connected — show tethering settings button + refresh
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.usb_rounded),
          label: const Text(
            'Open Tethering Settings',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          onPressed: () async {
            try {
              const intent = AndroidIntent(
                action: 'android.settings.TETHER_SETTINGS',
              );
              await intent.launch();
            } catch (_) {
              try {
                const fallbackIntent = AndroidIntent(
                  action: 'android.settings.WIRELESS_SETTINGS',
                );
                await fallbackIntent.launch();
              } catch (_) {}
            }
          },
        ),
        TextButton.icon(
          onPressed: _fetchNetworkInfo,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 18),
          label: const Text(
            'Refresh Network',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      ],
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
          // Pulsing radar animation behind QR
          SizedBox(
            width: 280,
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Radar rings
                AnimatedBuilder(
                  animation: _radarController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(280, 280),
                      painter: _RadarPainter(
                        progress: _radarController.value,
                        color: Colors.purpleAccent,
                      ),
                    );
                  },
                ),
                // QR code container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purpleAccent.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                ),
              ],
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
          // In Both mode show every interface IP
          if (widget.isBothMode && _myAllIps.isNotEmpty) ...
            _myAllIps.map(
              (ip) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  ip,
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                ),
              ),
            )
          else
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

/// Custom painter for pulsing radar rings animation
class _RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw 3 expanding rings at different phases
    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + i / 3) % 1.0;
      final radius = maxRadius * ringProgress;
      final opacity = (1.0 - ringProgress) * 0.6;

      if (opacity > 0) {
        final paint = Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        canvas.drawCircle(center, radius, paint);
      }
    }

    // Draw static center glow
    final glowPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 120, glowPaint);
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
