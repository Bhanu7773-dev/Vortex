import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:vortex/services/connection_manager.dart';
import 'package:vortex/services/transfer_service.dart';
import 'package:vortex/views/link_flow/connect_device_view.dart';

import 'package:vortex/views/recent_view.dart';
import 'package:vortex/views/home_view.dart';

class MainWrapperView extends StatefulWidget {
  const MainWrapperView({Key? key}) : super(key: key);

  @override
  State<MainWrapperView> createState() => _MainWrapperViewState();
}

class _MainWrapperViewState extends State<MainWrapperView> {
  int _currentIndex = 1; // Start on 'Files' tab as per original plan
  Timer? _frameTimer;

  final List<Widget> _pages = const [RecentView(), HomeView()];

  @override
  void dispose() {
    _frameTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connectionManager = context.read<ConnectionManager>();

      // Start listening on the networking port continuously
      connectionManager.startServer();

      connectionManager.onFileReceived = (relativePath, savedPath) {
        SchedulerBinding.instance.ensureVisualUpdate();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF1E1E1E),
              content: Row(
                children: [
                  const Icon(
                    Icons.download_done,
                    color: Colors.greenAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Received: $relativePath',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        });
      };

      // ── Receive-progress wiring ──────────────────────────────────────────
      final transferService = context.read<TransferService>();

      connectionManager.onFileReceiveStart = (id, relativePath, totalBytes) {
        transferService.startReceive(
          id: id,
          relativePath: relativePath,
          totalBytes: totalBytes,
        );
      };

      connectionManager.onFileReceiveProgress = (id, receivedBytes) {
        transferService.updateReceive(id: id, receivedBytes: receivedBytes);
      };

      connectionManager.onFileReceiveSaving = (id) {
        transferService.markReceiveSaving(id: id);
      };

      connectionManager.onFileReceiveComplete = (id, relativePath, savedPath) {
        transferService.completeReceive(id: id, savedPath: savedPath);
      };
    }); // end addPostFrameCallback
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
    final color = isSelected ? Colors.blue : Colors.grey;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 72,
        height: 40,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
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
            mainAxisSize: MainAxisSize.min,
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
                  Navigator.pop(context); // Close share options
                  _showConnectDevice(context); // Open QR connect UI (Wi-Fi)
                },
              ),
              _buildShareOption(
                icon: Icons.usb,
                label: 'Via USB',
                onTap: () {
                  Navigator.pop(context);
                  _showConnectDevice(
                    context,
                    isUsbMode: true,
                  ); // Open QR connect UI (USB)
                },
              ),
              _buildShareOption(
                icon: Icons.sync_alt,
                label: 'Via Both',
                onTap: () {
                  Navigator.pop(context);
                  // Add Both sharing logic here in the future
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showConnectDevice(BuildContext context, {bool isUsbMode = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.85,
            child: ConnectDeviceView(isUsbMode: isUsbMode),
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
