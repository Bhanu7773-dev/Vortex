import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

      // ── Show snackbar on this device when any peer connects ──────────────
      connectionManager.onConnectionEstablished = () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final devices = context.read<ConnectionManager>().connectedDeviceNames;
          final name = devices.isNotEmpty ? devices.last : 'A device';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF1E3A2F),
              content: Row(
                children: [
                  const Icon(Icons.link, color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$name connected',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        });
      };

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

      connectionManager.onFileReceiveError = (id, error) {
        transferService.completeReceive(
          id: id,
          savedPath: '',
          hasError: true,
        );
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
      backgroundColor: const Color(0xFF1C1C1E),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Connect & Share',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how to link with another device',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 24),
              _buildAnimatedShareOption(
                icon: Icons.wifi,
                label: 'Via Wi-Fi',
                subtitle: 'Fast wireless transfer',
                color: const Color(0xFF4ECDC4),
                delay: 0,
                onTap: () {
                  Navigator.pop(context);
                  _showConnectDevice(context);
                },
              ),
              const SizedBox(height: 12),
              _buildAnimatedShareOption(
                icon: Icons.usb,
                label: 'Via USB',
                subtitle: 'Stable wired connection',
                color: const Color(0xFFFFB347),
                delay: 80,
                onTap: () {
                  Navigator.pop(context);
                  _showConnectDevice(context, isUsbMode: true);
                },
              ),
              const SizedBox(height: 12),
              _buildAnimatedShareOption(
                icon: Icons.sync_alt,
                label: 'Via Both',
                subtitle: 'Maximum speed',
                color: const Color(0xFF9B59B6),
                delay: 160,
                onTap: () {
                  Navigator.pop(context);
                  _showConnectDevice(context, isBothMode: true);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showConnectDevice(BuildContext context,
      {bool isUsbMode = false, bool isBothMode = false}) {
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
            child: ConnectDeviceView(
              isUsbMode: isUsbMode,
              isBothMode: isBothMode,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedShareOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required int delay,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.3),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: delay.ms).slideX(
          begin: 0.1,
          end: 0,
          duration: 300.ms,
          delay: delay.ms,
          curve: Curves.easeOut,
        );
  }
}
