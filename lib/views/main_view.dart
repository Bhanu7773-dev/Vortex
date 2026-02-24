import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:vortex/services/connection_manager.dart';
import 'package:vortex/services/discovery_service.dart';
import 'package:vortex/views/link_flow/wifi_scan_view.dart';
import 'package:vortex/views/link_flow/pair_code_view.dart';
import 'package:vortex/views/recent_view.dart';
import 'package:vortex/views/home_view.dart';

class MainWrapperView extends StatefulWidget {
  const MainWrapperView({Key? key}) : super(key: key);

  @override
  State<MainWrapperView> createState() => _MainWrapperViewState();
}

class _MainWrapperViewState extends State<MainWrapperView> {
  int _currentIndex = 1; // Start on 'Files' tab as per original plan

  final List<Widget> _pages = const [RecentView(), HomeView()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connectionManager = context.read<ConnectionManager>();

      // Start listening on the networking port continuously
      connectionManager.startServer().then((_) async {
        final port = connectionManager.serverPort;
        if (port != null && mounted) {
          String deviceName = 'Vortex Device';
          try {
            final deviceInfo = DeviceInfoPlugin();
            if (Platform.isAndroid) {
              final androidInfo = await deviceInfo.androidInfo;
              deviceName = androidInfo.model;
            } else if (Platform.isIOS) {
              final iosInfo = await deviceInfo.iosInfo;
              deviceName = iosInfo.name;
            } else if (Platform.isLinux) {
              final linuxInfo = await deviceInfo.linuxInfo;
              deviceName = linuxInfo.prettyName;
            } else if (Platform.isWindows) {
              final windowsInfo = await deviceInfo.windowsInfo;
              deviceName = windowsInfo.computerName;
            } else if (Platform.isMacOS) {
              final macInfo = await deviceInfo.macOsInfo;
              deviceName = macInfo.computerName;
            }
          } catch (e) {
            debugPrint('Failed to get device name: $e');
          }

          if (!mounted) return;
          // Broadcast our presence continuously so others can find us
          context.read<DiscoveryService>().registerService(
            deviceName,
            connectionManager.deviceId,
            port,
          );
        }
      });

      connectionManager.onIncomingLinkRequest = (deviceName, pairCode) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PairCodeView(
              isInitiator: false,
              targetDeviceName: deviceName,
              incomingCode: pairCode,
            ),
          ),
        );
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        backgroundColor: Colors.blue, // Themed blue colored
        onPressed: () {
          _showShareOptions(context);
        },
        child: const Icon(Icons.link, color: Colors.white), // Link icon
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(icon: Icons.access_time, label: 'Recent', index: 0),
            const SizedBox(width: 48), // Add space in the middle
            _buildNavItem(icon: Icons.folder, label: 'Files', index: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    // Explicitly use blue for the selected color instead of primaryColor which might be black in the current theme
    final color = isSelected ? Colors.blue : Colors.grey;
    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 6.0,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize:
                MainAxisSize.min, // To make the bottom sheet wrap its content
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Share Options',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildShareOption(
                icon: Icons.wifi,
                label: 'Via Wi-Fi',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WifiScanView()),
                  );
                },
              ),
              _buildShareOption(
                icon: Icons.usb,
                label: 'Via USB',
                onTap: () {
                  Navigator.pop(context);
                  // Add USB sharing logic
                },
              ),
              _buildShareOption(
                icon: Icons.sync_alt, // Represents "both" or connection
                label: 'Via Both',
                onTap: () {
                  Navigator.pop(context);
                  // Add Both sharing logic
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.blue),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
