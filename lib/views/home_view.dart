import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:vortex/services/connection_manager.dart';
import 'package:vortex/services/transfer_service.dart';
import 'package:vortex/views/receive_view.dart';
import 'package:vortex/views/about_view.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/storage_card.dart';
import '../widgets/category_grid.dart';
import '../widgets/expandable_list.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with SingleTickerProviderStateMixin {
  String _networkName = 'Wi-Fi / Hotspot';

  @override
  void initState() {
    super.initState();
    _fetchNetworkName();
  }

  Future<void> _fetchNetworkName() async {
    if (Platform.isAndroid) return;

    try {
      final info = NetworkInfo();
      final wifiName = await info.getWifiName();
      if (wifiName != null && wifiName.isNotEmpty) {
        setState(() {
          _networkName = wifiName.replaceAll('"', '');
        });
      } else if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        setState(() {
          _networkName = 'Local Network';
        });
      }
    } catch (e) {
      debugPrint('Failed to get network name: $e');
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        setState(() {
          _networkName = 'Local Network';
        });
      }
    }
  }

  void _showConnectedDevicesSheet(BuildContext context, ConnectionManager cm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Linked Devices',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              if (cm.connectedDeviceNames.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'No devices connected.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ...cm.connectedDeviceNames.map((deviceName) {
                  final mode = cm.getDeviceMode(deviceName);
                  final modeIcon = mode == 'both'
                      ? Icons.sync_alt
                      : mode == 'usb'
                      ? Icons.usb
                      : Icons.wifi;
                  final modeLabel = mode == 'both'
                      ? 'Wi-Fi + USB'
                      : mode == 'usb'
                      ? 'USB'
                      : 'Wi-Fi';
                  final modeColor = mode == 'both'
                      ? Colors.purpleAccent
                      : mode == 'usb'
                      ? Colors.orangeAccent
                      : Colors.blueAccent;
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: modeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(modeIcon, color: modeColor, size: 20),
                    ),
                    title: Text(
                      deviceName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Row(
                      children: [
                        Icon(modeIcon, size: 12, color: modeColor),
                        const SizedBox(width: 4),
                        Text(
                          modeLabel,
                          style: TextStyle(color: modeColor, fontSize: 12),
                        ),
                        if (cm.getDeviceIp(deviceName) != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              cm.getDeviceIp(deviceName)!,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      onPressed: () {
                        cm.disconnectDevice(deviceName);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.link_off, size: 20),
                      label: const Text('Unlink'),
                    ),
                  );
                }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeViewModel>(
      create: (_) => HomeViewModel(),
      child: Scaffold(
        body: Consumer<HomeViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isPermissionDenied) {
              return _buildPermissionDeniedView(viewModel);
            }
            return _buildMainContent(context, viewModel);
          },
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedView(HomeViewModel viewModel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: const Icon(
                Icons.folder_off_rounded,
                size: 64,
                color: Colors.redAccent,
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 500.ms),
            const SizedBox(height: 32),
            const Text(
              'Storage Access Required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: 12),
            Text(
              'Vortex needs permission to access your files and folders.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15),
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 400.ms),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => viewModel.checkAndRequestPermissions(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667eea).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text(
                  'Grant Permission',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 400.ms, duration: 400.ms)
                .slideY(begin: 0.3, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, HomeViewModel viewModel) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Modern App Bar
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Vortex',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .slideX(begin: -0.1, end: 0, duration: 400.ms),
                  Row(
                    children: [
                      Consumer<TransferService>(
                        builder: (context, ts, _) {
                          final hasActive = ts.hasActiveReceive;
                          return _HeaderActionButton(
                            icon: Icons.download_rounded,
                            hasNotification: hasActive,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ReceiveView()),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _HeaderActionButton(
                        icon: Icons.info_outline_rounded,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutView()),
                        ),
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .slideX(begin: 0.1, end: 0, duration: 400.ms),
                ],
              ),
            ),
          ),
        ),

        // Connection Status
        SliverToBoxAdapter(
          child: Consumer<ConnectionManager>(
            builder: (context, connectionManager, child) {
              if (!connectionManager.isLinked) return const SizedBox.shrink();
              return _buildConnectionStatus(context, connectionManager);
            },
          ),
        ),

        // Limited Access Warning
        if (!viewModel.hasFullAccess)
          SliverToBoxAdapter(
            child: _buildLimitedAccessWarning(viewModel),
          ),

        // Storage Card
        SliverToBoxAdapter(
          child: StorageCard(
            totalStorage: viewModel.totalStorage,
            usedStorage: viewModel.usedStorage,
            percentage: viewModel.storagePercentage,
          ),
        ),

        // Categories
        SliverToBoxAdapter(
          child: CategoryGrid(categories: viewModel.categories),
        ),

        // Sections
        SliverToBoxAdapter(
          child: const SizedBox(height: 16),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return ExpandableSection(section: viewModel.sections[index]);
            },
            childCount: viewModel.sections.length,
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildConnectionStatus(BuildContext context, ConnectionManager cm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () => _showConnectedDevicesSheet(context, cm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F).withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.blueAccent.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.wifi,
                  color: Colors.blueAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _networkName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${cm.connectedDeviceNames.length} device${cm.connectedDeviceNames.length != 1 ? 's' : ''} connected',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Active',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: -0.2, end: 0, duration: 400.ms);
  }

  Widget _buildLimitedAccessWarning(HomeViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.orangeAccent.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.orangeAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Limited Access',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Enable full access for all file types',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => viewModel.checkAndRequestPermissions(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Enable',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideX(begin: -0.1, end: 0, duration: 400.ms);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Welcome To';
    if (hour < 17) return 'Welcome To';
    return 'Welcome To';
  }
}

class _HeaderActionButton extends StatefulWidget {
  final IconData icon;
  final bool hasNotification;
  final VoidCallback onTap;

  const _HeaderActionButton({
    required this.icon,
    required this.onTap,
    this.hasNotification = false,
  });

  @override
  State<_HeaderActionButton> createState() => _HeaderActionButtonState();
}

class _HeaderActionButtonState extends State<_HeaderActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.icon,
                color: Colors.white.withOpacity(0.8),
                size: 22,
              ),
            ),
            if (widget.hasNotification)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade400,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
