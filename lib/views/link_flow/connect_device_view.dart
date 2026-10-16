import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_intent_plus/android_intent.dart';

import '../../services/connection_manager.dart';
import '../../theme/app_theme.dart';

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
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final FocusNode _tokenFocusNode = FocusNode();

  String _myDeviceName = 'Unknown Device';
  String _myIp = '127.0.0.1';
  String? _wifiIp;
  List<String> _myAllIps = [];
  bool _isConnecting = false;
  String? _usbPeerIp;
  String? _usbPhoneIp;
  Timer? _usbPollTimer;

  String? _scanError;
  bool _scanCooldown = false;

  bool get _isUsbConnected => _usbPhoneIp != null;

  @override
  void initState() {
    super.initState();
    final bool hasCamera = Platform.isAndroid || Platform.isIOS;
    _tabController = TabController(
      length: hasCamera ? 3 : 2,
      vsync: this,
    );

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });

    _tokenController.addListener(() {
      if (mounted) setState(() {});
    });

    _fetchNetworkInfo();

    if (widget.isUsbMode || widget.isBothMode) {
      _usbPollTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _detectUsbPeerIp(),
      );
    }
  }

  @override
  void dispose() {
    _usbPollTimer?.cancel();
    _tabController.dispose();
    _ipController.dispose();
    _tokenController.dispose();
    _tokenFocusNode.dispose();
    super.dispose();
  }

  static Future<List<String>> _getAllIps() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      final ips = <String>[];
      for (final iface in interfaces) {
        final n = iface.name.toLowerCase();
        if (n.startsWith('docker') ||
            n.startsWith('veth') ||
            n.startsWith('virbr') ||
            n.startsWith('br-') ||
            n.startsWith('vmnet') ||
            n.startsWith('tun') ||
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

    if (widget.isBothMode) {
      final all = await _getAllIps();
      if (mounted) setState(() => _myAllIps = all);
    }

    if (widget.isUsbMode || widget.isBothMode) await _detectUsbPeerIp();
    await _detectWifiIp();
  }

  Future<void> _detectWifiIp() async {
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
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in ifaces) {
        final n = iface.name.toLowerCase();
        if (n.startsWith('docker') ||
            n.startsWith('veth') ||
            n.startsWith('virbr') ||
            n.startsWith('br-')) continue;
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

  Future<void> _detectUsbPeerIp() async {
    const usbIfaceNames = ['rndis', 'usb', 'ncm', 'ecm'];
    String? phoneUsbIp;
    String? detectedPrefix;

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: true,
      );

      for (final iface in interfaces) {
        final n = iface.name.toLowerCase();
        final isUsbIface = usbIfaceNames.any((prefix) => n.startsWith(prefix));
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final ip = addr.address;
          final isUsbSubnet = ip.startsWith('192.168.42.') ||
              ip.startsWith('192.168.43.') ||
              ip.startsWith('192.168.44.');
          if (isUsbIface || isUsbSubnet) {
            phoneUsbIp = ip;
            detectedPrefix = '${ip.substring(0, ip.lastIndexOf('.'))}.';
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

    if (!Platform.isAndroid) return;
    try {
      final arpFile = File('/proc/net/arp');
      if (!await arpFile.exists()) return;
      final lines = await arpFile.readAsLines();
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

  static Future<String> _pickBestIp(bool usbMode) async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      final candidates = <({int score, String ip})>[];

      for (final iface in interfaces) {
        final n = iface.name.toLowerCase();
        if (n.startsWith('docker') ||
            n.startsWith('veth') ||
            n.startsWith('virbr') ||
            n.startsWith('br-') ||
            n.startsWith('vmnet') ||
            n.startsWith('tun') ||
            n.startsWith('tap')) continue;

        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final ip = addr.address;
          int score = 0;

          if (usbMode) {
            if (ip.startsWith('192.168.42.') ||
                ip.startsWith('192.168.43.') ||
                ip.startsWith('192.168.44.')) {
              score = 100;
            } else if (n.startsWith('usb') ||
                n.startsWith('rndis') ||
                n.startsWith('ncm') ||
                n.startsWith('ecm')) {
              score = 80;
            } else if (RegExp(r'u\d').hasMatch(n)) {
              score = 70;
            } else if (n.startsWith('eth')) {
              score = 40;
            } else {
              score = 10;
            }
          } else {
            if (n.startsWith('wlan') || n.startsWith('wifi')) {
              score = 100;
            } else if (n == 'en0') {
              score = 90;
            } else if (n.startsWith('en')) {
              score = 70;
            } else if (n.startsWith('eth')) {
              score = 50;
            } else {
              score = 10;
            }
          }

          candidates.add((score: score, ip: ip));
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
    if (ip == null || token == null || port == null) return;

    void showError(String msg) {
      if (mounted) setState(() { _scanError = msg; _scanCooldown = true; });
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() { _scanError = null; _scanCooldown = false; });
      });
    }

    final String qrMode = data['mode']?.toString() ?? 'wifi';
    final String myMode =
        widget.isBothMode ? 'both' : widget.isUsbMode ? 'usb' : 'wifi';
    if (qrMode != myMode) {
      final qrLabel = qrMode == 'both'
          ? 'Via Both'
          : qrMode == 'usb'
              ? 'Via USB'
              : 'Via Wi-Fi';
      showError('Wrong QR — this is a $qrLabel code.\nOpen the $qrLabel option to use it.');
      return;
    }

    final List<String> allIps = data['ips'] != null
        ? List<String>.from(data['ips'] as List)
        : [ip.toString()];

    final String targetName = (data['name'] as String?) ?? 'Device';

    if (widget.isUsbMode && _usbPhoneIp == null) {
      showError('USB tethering is not enabled on this phone.\nTurn on USB tethering in Settings.');
      return;
    }

    _connectToFirstReachable(
      ips: allIps,
      port: port as int,
      token: token.toString(),
      targetName: targetName,
      connectionMode: myMode,
    );
  }

  void _connectToFirstReachable({
    required List<String> ips,
    required int port,
    required String token,
    required String targetName,
    required String connectionMode,
  }) async {
    setState(() {
      _isConnecting = true;
      _scanError = null;
    });

    final cm = context.read<ConnectionManager>();
    final winner = Completer<bool>();

    for (final ip in ips) {
      cm
          .connectToDevice(
            ip,
            port,
            token,
            _myDeviceName,
            targetDeviceName: targetName,
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
      connectionMode:
          widget.isBothMode ? 'both' : widget.isUsbMode ? 'usb' : 'wifi',
    );
  }

  Future<void> _openTetheringSettings() async {
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
  }

  String _formatToken(String token) {
    if (token.length == 6) {
      return '${token.substring(0, 3)} ${token.substring(3)}';
    }
    return token;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCamera = Platform.isAndroid || Platform.isIOS;
    final cm = context.watch<ConnectionManager>();

    final String myMode =
        widget.isBothMode ? 'both' : widget.isUsbMode ? 'usb' : 'wifi';

    final qrData = jsonEncode({
      'ip': _myIp,
      'port': ConnectionManager.serverFixedPort,
      'token': cm.qrToken,
      'name': _myDeviceName,
      'mode': myMode,
      if (_wifiIp != null) 'wifi_ip': _wifiIp,
      if (_usbPhoneIp != null) 'usb_ip': _usbPhoneIp,
      if (widget.isBothMode && _myAllIps.isNotEmpty) 'ips': _myAllIps,
    });

    final modeTitle = widget.isBothMode
        ? 'Connect via both'
        : widget.isUsbMode
            ? 'Connect via USB'
            : 'Connect device';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1216),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              margin: const EdgeInsets.only(top: 12, bottom: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF2E333B),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              modeTitle,
              style: const TextStyle(
                fontFamily: AppTheme.fontBricolage,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
          ),

          if (widget.isUsbMode || widget.isBothMode) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: GestureDetector(
                onTap: _openTetheringSettings,
                child: Container(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.accentLime,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.usb_rounded, color: Colors.black, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Open tethering settings',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _fetchNetworkInfo();
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Refresh network',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 18),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildSegmentedPillBar(hasCamera),
          ),

          if (_scanError != null) _buildInlineErrorBanner(),

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

  Widget _buildSegmentedPillBar(bool hasCamera) {
    final tabs = [
      if (hasCamera) 'Scan QR',
      'My QR',
      'Manual IP',
    ];

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF090B0E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1C2026), width: 1),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTabIndex = index;
                  _tabController.animateTo(index);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accentLime
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    color: isSelected
                        ? Colors.black
                        : const Color(0xFF78828A),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildInlineErrorBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF280B0B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _scanError!,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _scanError = null;
              _scanCooldown = false;
            }),
            child: const Icon(Icons.close, color: Colors.white38, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF090B0E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF1C2026), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            MobileScanner(onDetect: _handleQrDetect),

            const _ScannerReticleWidget(
              size: 210,
              cornerLength: 42,
              strokeWidth: 4.5,
              cornerRadius: 14,
              color: AppTheme.accentLime,
            ),

            if (_isConnecting)
              Container(
                color: Colors.black.withOpacity(0.85),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.accentLime),
                      SizedBox(height: 16),
                      Text(
                        'Connecting...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (!_isConnecting)
              const Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Text(
                  'Scan the Vortex QR code on the other device',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF78828A),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyQrTab(String qrData, String currentToken) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200.0,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            _myDeviceName,
            style: const TextStyle(
              fontFamily: AppTheme.fontBricolage,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'IP address',
                      style: TextStyle(
                        color: Color(0xFF78828A),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      _myIp,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if ((widget.isUsbMode || widget.isBothMode) &&
                    (_usbPhoneIp != null || _usbPeerIp != null)) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'USB IP',
                        style: TextStyle(
                          color: Color(0xFF78828A),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        _usbPeerIp ?? _usbPhoneIp ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Token',
                      style: TextStyle(
                        color: Color(0xFF78828A),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      _formatToken(currentToken),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontBricolage,
                        color: AppTheme.accentLime,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          const Text(
            'Scan this code from another device to connect\ninstantly.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF78828A),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildManualTab() {
    final token = _tokenController.text;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Target IP address',
            style: TextStyle(
              color: Color(0xFF78828A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),

          TextField(
            controller: _ipController,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            cursorColor: AppTheme.accentLime,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '0.0.0.0',
              hintStyle: TextStyle(
                color: Color(0xFF4A525A),
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1E2228), height: 1, thickness: 1),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '6-digit token',
                style: TextStyle(
                  color: Color(0xFF78828A),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${token.length}/6',
                style: const TextStyle(
                  color: Color(0xFF78828A),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          GestureDetector(
            onTap: () => _tokenFocusNode.requestFocus(),
            child: Stack(
              children: [
                Opacity(
                  opacity: 0.0,
                  child: TextField(
                    controller: _tokenController,
                    focusNode: _tokenFocusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: false,
                    decoration: const InputDecoration(
                      counterText: '',
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    final char = i < token.length ? token[i] : '';
                    final isFocused =
                        _tokenFocusNode.hasFocus && i == token.length;

                    return Container(
                      width: 44,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF14171A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFocused
                              ? AppTheme.accentLime
                              : (char.isNotEmpty
                                  ? const Color(0xFF2E333B)
                                  : const Color(0xFF1C2026)),
                          width: isFocused ? 1.5 : 1.0,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        char,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentLime,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: _isConnecting
                  ? null
                  : () {
                      final ip = _ipController.text.trim();
                      final t = _tokenController.text.trim();
                      if (ip.isEmpty || t.length != 6) return;

                      _connectToTarget(
                        ip: ip,
                        port: ConnectionManager.serverFixedPort,
                        token: t,
                        targetName: 'Device ($ip)',
                      );
                    },
              child: _isConnecting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Connect',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
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

class _ScannerReticleWidget extends StatelessWidget {
  final double size;
  final double cornerLength;
  final double strokeWidth;
  final double cornerRadius;
  final Color color;

  const _ScannerReticleWidget({
    this.size = 210,
    this.cornerLength = 42,
    this.strokeWidth = 4.5,
    this.cornerRadius = 14,
    this.color = AppTheme.accentLime,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ReticlePainter(
          cornerLength: cornerLength,
          strokeWidth: strokeWidth,
          cornerRadius: cornerRadius,
          color: color,
        ),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final double cornerLength;
  final double strokeWidth;
  final double cornerRadius;
  final Color color;

  _ReticlePainter({
    required this.cornerLength,
    required this.strokeWidth,
    required this.cornerRadius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final r = cornerRadius;
    final l = cornerLength;

    final tl = Path()
      ..moveTo(0, l)
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(l, 0);
    canvas.drawPath(tl, paint);

    final tr = Path()
      ..moveTo(w - l, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..lineTo(w, l);
    canvas.drawPath(tr, paint);

    final bl = Path()
      ..moveTo(0, h - l)
      ..lineTo(0, h - r)
      ..arcToPoint(Offset(r, h), radius: Radius.circular(r), clockwise: false)
      ..lineTo(l, h);
    canvas.drawPath(bl, paint);

    final br = Path()
      ..moveTo(w - l, h)
      ..lineTo(w - r, h)
      ..arcToPoint(Offset(w, h - r), radius: Radius.circular(r), clockwise: false)
      ..lineTo(w, h - l);
    canvas.drawPath(br, paint);
  }

  @override
  bool shouldRepaint(_ReticlePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.cornerLength != cornerLength ||
      oldDelegate.strokeWidth != strokeWidth;
}
