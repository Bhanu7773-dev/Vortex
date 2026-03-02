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

      // Cross-side cancel notifications
      connectionManager.onSenderCancelledTransfer = () {
        // Mark all active (non-complete) receive jobs as cancelled by sender.
        for (final job in List.of(transferService.receiveJobs)) {
          if (!job.isComplete && !job.cancelled) {
            transferService.cancelReceiveBySender(job.id);
          }
        }
      };

      connectionManager.onReceiverCancelledTransfer = () {
        transferService.cancelJobByReceiver();
      };
    }); // end addPostFrameCallback
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        border: Border(
          top: BorderSide(color: Color(0xFF1E1E1E), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              Expanded(
                child: _buildNavItem(
                  icon: Icons.inbox_outlined,
                  selectedIcon: Icons.inbox_rounded,
                  label: 'Received',
                  index: 0,
                ),
              ),
              _buildLinkButton(context),
              Expanded(
                child: _buildNavItem(
                  icon: Icons.folder_outlined,
                  selectedIcon: Icons.folder_rounded,
                  label: 'Files',
                  index: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      splashColor: Colors.blue.withOpacity(0.08),
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF1A3A5C)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? Colors.blue.shade300 : const Color(0xFF6B6B6B),
              size: 22,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blue.shade300 : const Color(0xFF6B6B6B),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showShareOptions(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.35),
              blurRadius: 18,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.cyclone_rounded,
          color: Colors.white,
          size: 44,
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