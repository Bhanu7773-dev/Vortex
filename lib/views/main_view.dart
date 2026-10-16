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
import 'package:vortex/widgets/transfer_island.dart';
import 'package:vortex/services/web_share_service.dart';
import 'package:vortex/views/web_share_view.dart';
import 'package:vortex/theme/app_theme.dart';

class MainWrapperView extends StatefulWidget {
  const MainWrapperView({super.key});

  @override
  State<MainWrapperView> createState() => _MainWrapperViewState();
}

class _MainWrapperViewState extends State<MainWrapperView> {
  int _currentIndex = 1;
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

      connectionManager.startServer();

      final webShareService = context.read<WebShareService>();
      connectionManager.webShareHandler = webShareService.handleHttpRequest;

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
        context.read<WebShareService>().registerReceivedFile(relativePath, savedPath);
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

      connectionManager.onSenderCancelledTransfer = () {
        for (final job in List.of(transferService.receiveJobs)) {
          if (!job.isComplete && !job.cancelled) {
            transferService.cancelReceiveBySender(job.id);
          }
        }
      };

      connectionManager.onReceiverCancelledTransfer = () {
        transferService.cancelJobByReceiver();
      };

      connectionManager.onHttpUploadCancelled = () {
        webShareService.markUploadCancelled();
      };
      connectionManager.onHttpUploadStarted = () {
        webShareService.resetUploadCancelled();
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TransferIsland(),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        height: 68,
        decoration: BoxDecoration(
          color: const Color(0xFF14171A),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Center(
                child: InkWell(
                  onTap: () => setState(() => _currentIndex = 0),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: _currentIndex == 0
                      ? AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E241E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.accentLime.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_rounded,
                                color: AppTheme.accentLime,
                                size: 19,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Received',
                                style: TextStyle(
                                  color: AppTheme.accentLime,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.inbox_outlined,
                              color: Color(0xFF78828A),
                              size: 22,
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Received',
                              style: TextStyle(
                                color: Color(0xFF78828A),
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            _buildLinkButton(context),

            Expanded(
              child: Center(
                child: InkWell(
                  onTap: () => setState(() => _currentIndex = 1),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: _currentIndex == 1
                      ? AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E241E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.accentLime.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_rounded,
                                color: AppTheme.accentLime,
                                size: 19,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Files',
                                style: TextStyle(
                                  color: AppTheme.accentLime,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.folder_outlined,
                              color: Color(0xFF78828A),
                              size: 22,
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Files',
                              style: TextStyle(
                                color: Color(0xFF78828A),
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showShareOptions(context),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.accentLime,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentLime.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.cyclone_rounded,
            color: Colors.black,
            size: 28,
          ),
        ),
      ),
    );
  }

  void _showShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14171B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E333B),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const Text(
                'Connect and share',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose how to link with another device',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF78828A),
                ),
              ),
              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: _buildSquareOptionCard(
                      icon: Icons.wifi_rounded,
                      title: 'Via Wi-Fi',
                      subtitle: 'Fast wireless transfer',
                      delay: 0,
                      onTap: () {
                        Navigator.pop(context);
                        _showConnectDevice(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSquareOptionCard(
                      icon: Icons.usb_rounded,
                      title: 'Via USB',
                      subtitle: 'Stable wired connection',
                      delay: 60,
                      onTap: () {
                        Navigator.pop(context);
                        _showConnectDevice(context, isUsbMode: true);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildHeroOptionCard(
                icon: Icons.swap_horiz_rounded,
                title: 'Via both',
                subtitle: 'Maximum speed (Turbo)',
                delay: 120,
                onTap: () {
                  Navigator.pop(context);
                  _showConnectDevice(context, isBothMode: true);
                },
              ),
              const SizedBox(height: 12),

              _buildWideOptionCard(
                icon: Icons.language_rounded,
                title: 'Web share portal',
                subtitle: 'No app needed · share via browser',
                delay: 180,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WebShareView()),
                  );
                },
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 8 : 12),
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

  Widget _buildSquareOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required int delay,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0E11),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF1E2228),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: AppTheme.accentLime,
              size: 28,
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF78828A),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms, delay: delay.ms).scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 250.ms,
          delay: delay.ms,
          curve: Curves.easeOut,
        );
  }

  Widget _buildHeroOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required int delay,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.accentLime,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.black,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF43600C),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.black,
              size: 24,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms, delay: delay.ms).slideY(
          begin: 0.08,
          end: 0,
          duration: 250.ms,
          delay: delay.ms,
          curve: Curves.easeOut,
        );
  }

  Widget _buildWideOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required int delay,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0E11),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF1E2228),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppTheme.accentLime,
              size: 26,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF78828A),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF4A525A),
              size: 22,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms, delay: delay.ms).slideY(
          begin: 0.08,
          end: 0,
          duration: 250.ms,
          delay: delay.ms,
          curve: Curves.easeOut,
        );
  }
}