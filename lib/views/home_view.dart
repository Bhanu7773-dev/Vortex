import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:vortex/services/connection_manager.dart';
import 'package:vortex/services/transfer_service.dart';
import 'package:vortex/services/web_share_service.dart';
import 'package:vortex/theme/app_theme.dart';
import 'package:vortex/viewmodels/home_viewmodel.dart';
import 'package:vortex/views/about_view.dart';
import 'package:vortex/views/all_files_view.dart';
import 'package:vortex/views/media_list_views.dart';
import 'package:vortex/views/photos_view.dart';
import 'package:vortex/views/receive_view.dart';
import 'package:vortex/views/videos_view.dart';
import 'package:vortex/views/web_share_view.dart';

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
    if (Platform.isAndroid) return;

    try {
      final info = NetworkInfo();
      final wifiName = await info.getWifiName();
      if (wifiName != null && wifiName.isNotEmpty) {
        if (mounted) {
          setState(() {
            _networkName = wifiName.replaceAll('"', '');
          });
        }
      } else if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        if (mounted) {
          setState(() {
            _networkName = 'Local Network';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _openCategory(
    BuildContext context,
    String name,
    HomeViewModel viewModel,
  ) async {
    switch (name) {
      case 'Photos':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PhotosView()),
        );
        break;
      case 'Videos':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VideosView()),
        );
        break;
      case 'Audio':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AudioView()),
        );
        break;
      case 'Documents':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DocumentsView()),
        );
        break;
      case 'APKs':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ApksView()),
        );
        break;
      case 'Archives':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ArchivesView()),
        );
        break;
    }
    if (context.mounted) {
      viewModel.refreshCategoryCounts();
    }
  }

  String _getCategoryCount(HomeViewModel vm, String name) {
    final cat = vm.categories.firstWhere(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
      orElse: () => vm.categories.first,
    );
    final count = int.tryParse(cat.info.split(' ').first) ?? 0;
    return count > 0 ? count.toString() : (cat.info.isNotEmpty ? cat.info : '0');
  }

  String _calculateFreeSpace(HomeViewModel vm) {
    try {
      final total = _parseStorage(vm.totalStorage);
      final used = _parseStorage(vm.usedStorage);
      final free = (total - used).clamp(0.0, double.infinity);
      if (free >= 1.0) {
        return free.toStringAsFixed(1);
      } else {
        return (free * 1024).toStringAsFixed(0);
      }
    } catch (_) {
      return '0.0';
    }
  }

  double _parseStorage(String val) {
    final match =
        RegExp(r'([\d.]+)\s*(GB|MB|TB)', caseSensitive: false).firstMatch(val);
    if (match == null) return 0.0;
    final num = double.tryParse(match.group(1) ?? '0') ?? 0.0;
    final unit = match.group(2)!.toUpperCase();
    if (unit == 'TB') return num * 1024;
    if (unit == 'MB') return num / 1024;
    return num;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeViewModel>(
      create: (_) => HomeViewModel(),
      child: Scaffold(
        backgroundColor: Colors.black,
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

  Widget _buildMainContent(BuildContext context, HomeViewModel viewModel) {
    final freeSpace = _calculateFreeSpace(viewModel);
    final photoCount = _getCategoryCount(viewModel, 'Photos');
    final videoCount = _getCategoryCount(viewModel, 'Videos');
    final audioCount = _getCategoryCount(viewModel, 'Audio');
    final docCount = _getCategoryCount(viewModel, 'Documents');
    final apkCount = _getCategoryCount(viewModel, 'APKs');
    final archiveCount = _getCategoryCount(viewModel, 'Archives');

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Vortex',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(
                    children: [
                      Consumer<WebShareService>(
                        builder: (context, ws, _) {
                          return _HeaderIconButton(
                            icon: Icons.language_rounded,
                            hasGreenBadge: ws.isEnabled,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WebShareView(),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Consumer<TransferService>(
                        builder: (context, ts, _) {
                          return _HeaderIconButton(
                            icon: Icons.file_download_outlined,
                            hasGreenBadge: ts.hasActiveReceive,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ReceiveView(),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _HeaderIconButton(
                        icon: Icons.info_outline_rounded,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutView()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Consumer<ConnectionManager>(
            builder: (context, cm, _) {
              if (!cm.isLinked) return const SizedBox.shrink();
              return _buildConnectedBadge(context, cm);
            },
          ),
        ),

        SliverToBoxAdapter(
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllFilesView()),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Free space',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14171A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF22262C),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Internal storage',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.accentLime,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        freeSpace,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'GB',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'of ${viewModel.totalStorage}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const barWidth = 3.5;
                      const barGap = 3.2;
                      const unit = barWidth + barGap;
                      final numBars =
                          (constraints.maxWidth / unit).floor().clamp(10, 60);
                      final activeBars = (numBars * viewModel.storagePercentage)
                          .clamp(0, numBars)
                          .round();

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(numBars, (i) {
                          final isActive = i < activeBars;
                          return Container(
                            width: barWidth,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppTheme.accentLime
                                  : const Color(0xFF1F2228),
                              borderRadius: BorderRadius.circular(2.0),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${viewModel.usedStorage} used',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${(viewModel.storagePercentage * 100).toInt()}%',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openCategory(context, 'Photos', viewModel),
                    child: Container(
                      height: 154,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.accentLime,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(
                            Icons.photo_outlined,
                            color: Colors.black,
                            size: 28,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Photos',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                photoCount,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openCategory(context, 'Videos', viewModel),
                    child: Container(
                      height: 154,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.04),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(
                            Icons.videocam_outlined,
                            color: AppTheme.accentLime,
                            size: 28,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Videos',
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                videoCount,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildCategoryRow(
                  icon: Icons.music_note_rounded,
                  title: 'Audio',
                  count: audioCount,
                  onTap: () => _openCategory(context, 'Audio', viewModel),
                ),
                _buildDivider(),
                _buildCategoryRow(
                  icon: Icons.description_outlined,
                  title: 'Documents',
                  count: docCount,
                  onTap: () => _openCategory(context, 'Documents', viewModel),
                ),
                _buildDivider(),
                _buildCategoryRow(
                  icon: Icons.view_in_ar_outlined,
                  title: 'APKs',
                  count: apkCount,
                  onTap: () => _openCategory(context, 'APKs', viewModel),
                ),
                _buildDivider(),
                _buildCategoryRow(
                  icon: Icons.archive_outlined,
                  title: 'Archives',
                  count: archiveCount,
                  onTap: () => _openCategory(context, 'Archives', viewModel),
                  isLast: true,
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sources',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildSourcePill(
                      icon: Icons.bluetooth,
                      label: 'Bluetooth',
                      onTap: () => viewModel.onSectionItemTap(
                        context,
                        'Sources',
                        'Bluetooth',
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildSourcePill(
                      icon: Icons.file_download_outlined,
                      label: 'Downloads',
                      onTap: () => viewModel.onSectionItemTap(
                        context,
                        'Sources',
                        'Downloads',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        ...viewModel.sections
            .where((s) => s.title != 'Sources' && s.items.isNotEmpty)
            .map(
              (section) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: section.items.map((item) {
                          return GestureDetector(
                            onTap: () => viewModel.onSectionItemTap(
                              context,
                              section.title,
                              item.title,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceDark,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item.icon,
                                    size: 16,
                                    color: AppTheme.accentLime,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (item.trailingInfo.isNotEmpty &&
                                      item.trailingInfo != '0') ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '(${item.trailingInfo})',
                                      style: const TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }

  Widget _buildCategoryRow({
    required IconData icon,
    required String title,
    required String count,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accentLime, size: 21),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              count,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: const Color(0xFF16191E),
    );
  }

  Widget _buildSourcePill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.04),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.accentLime, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedBadge(BuildContext context, ConnectionManager cm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.accentLime.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.accentLime,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${cm.connectedDeviceNames.length} device linked ($_networkName)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.textMuted,
              size: 18,
            ),
          ],
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
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.folder_off_rounded,
                size: 64,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Storage Access Required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Vortex needs permission to access your files and folders.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => viewModel.checkAndRequestPermissions(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentLime,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Grant Permission',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final bool hasGreenBadge;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.hasGreenBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 21,
            ),
          ),
          if (hasGreenBadge)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.accentLime,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
