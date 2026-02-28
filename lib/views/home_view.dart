import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:vortex/services/connection_manager.dart';
import 'package:vortex/services/transfer_service.dart';
import 'package:vortex/views/receive_view.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/storage_card.dart';
import '../widgets/category_grid.dart';
import '../widgets/expandable_list.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  String _networkName = 'Wi-Fi / Hotspot';

  @override
  void initState() {
    super.initState();
    _fetchNetworkName();
  }

  Future<void> _fetchNetworkName() async {
    // WifiManager.getConnectionInfo() (used internally by network_info_plus) is
    // a synchronous Android IPC binder call that can block the platform thread
    // for several seconds on many devices, causing dropped frames and ANRs.
    // The SSID label is cosmetic, so we simply skip the call on Android.
    if (Platform.isAndroid) return;

    try {
      final info = NetworkInfo();
      final wifiName = await info.getWifiName();
      if (wifiName != null && wifiName.isNotEmpty) {
        setState(() {
          // Remove potential exact quotes around SSID
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
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                    leading: CircleAvatar(
                      backgroundColor: modeColor.withOpacity(0.2),
                      child: Icon(modeIcon, color: modeColor),
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
        appBar: AppBar(
          title: const Text('Vortex'),
          actions: [
            Consumer<TransferService>(
              builder: (context, ts, _) {
                final hasActive = ts.hasActiveReceive;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Incoming files',
                      icon: const Icon(Icons.download_rounded),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReceiveView()),
                      ),
                    ),
                    if (hasActive)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF121212),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        body: Consumer<HomeViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isPermissionDenied) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.security_outlined,
                        size: 80,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Permission Required',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Vortex needs storage access to show your files. Please grant permission in settings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () => viewModel.checkAndRequestPermissions(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Grant Permission'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return CustomScrollView(
              slivers: [
                if (!viewModel.hasFullAccess)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orangeAccent,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orangeAccent,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Limited Access Detected',
                                  style: TextStyle(
                                    color: Colors.orangeAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Android 11+ requires "All Files Access" to manage archives, APKs, and documents. Currently, only media folders may be visible.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () =>
                                viewModel.checkAndRequestPermissions(),
                            child: const Text('Enable All Files Access'),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Consumer<ConnectionManager>(
                    builder: (context, connectionManager, child) {
                      if (!connectionManager.isLinked)
                        return const SizedBox.shrink();

                      // We use Consumer for DiscoveryService just to get the network name if possible,
                      // but mostly to show the connected state.
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.wifi,
                                          color: Colors.blue,
                                          size: 16,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Network',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _networkName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _showConnectedDevicesSheet(
                                  context,
                                  connectionManager,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.green.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.link,
                                            color: Colors.green,
                                            size: 16,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Linked Devices',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        connectionManager
                                                    .connectedDeviceNames
                                                    .length ==
                                                1
                                            ? connectionManager
                                                  .connectedDeviceNames
                                                  .first
                                            : '${connectionManager.connectedDeviceNames.first} +${connectionManager.connectedDeviceNames.length - 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: StorageCard(
                    totalStorage: viewModel.totalStorage,
                    usedStorage: viewModel.usedStorage,
                    percentage: viewModel.storagePercentage,
                  ),
                ),
                SliverToBoxAdapter(
                  child: CategoryGrid(categories: viewModel.categories),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return ExpandableSection(
                      section: viewModel.sections[index],
                    );
                  }, childCount: viewModel.sections.length),
                ),
                // Padding for FAB area
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            );
          },
        ),
      ),
    );
  }
}
