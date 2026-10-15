import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/share_sheet.dart';
import 'package:provider/provider.dart';
import '../viewmodels/photos_viewmodel.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────
//  Photos - Album Grid screen
// ─────────────────────────────────────────────
class PhotosView extends StatelessWidget {
  const PhotosView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PhotosViewModel>(
      create: (_) => PhotosViewModel(),
      child: Consumer<PhotosViewModel>(
        builder: (context, viewModel, _) {
          final albums = viewModel.albums;
          final featuredAlbum = albums.isNotEmpty ? albums.first : null;
          final gridAlbums =
              albums.length > 1 ? albums.sublist(1) : <PhotoAlbum>[];

          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: 68,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              titleSpacing: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Photos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${albums.length} album${albums.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Color(0xFF78828A),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            body: viewModel.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.accentLime,
                    ),
                  )
                : albums.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          size: 72,
                          color: Color(0xFF78828A),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No photos found',
                          style: TextStyle(
                            color: Color(0xFF78828A),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      if (featuredAlbum != null)
                        SliverToBoxAdapter(
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PhotoAlbumDetailView(album: featuredAlbum),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Large Hero Banner Card
                                  Container(
                                    height: 200,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF14171B),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Image.file(
                                      featuredAlbum.coverPhoto,
                                      fit: BoxFit.cover,
                                      cacheWidth: 800,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: const Color(0xFF14171B),
                                        child: const Center(
                                          child: Icon(
                                            Icons.image_outlined,
                                            color: Color(0xFF2E333B),
                                            size: 54,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  // Title + Bold Lime Count Row
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          featuredAlbum.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${featuredAlbum.count}',
                                        style: const TextStyle(
                                          color: AppTheme.accentLime,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (gridAlbums.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.72,
                                ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final album = gridAlbums[index];
                                return _AlbumCard(
                                  album: album,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PhotoAlbumDetailView(album: album),
                                    ),
                                  ),
                                );
                              },
                              childCount: gridAlbums.length,
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final PhotoAlbum album;
  final VoidCallback onTap;
  const _AlbumCard({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF14171B),
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(
                album.coverPhoto,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: 320,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF14171B),
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: Color(0xFF2E333B),
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${album.count}',
            style: const TextStyle(
              color: Color(0xFF78828A),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Photo Album Detail - 5-col grid + premium selection
// ─────────────────────────────────────────────
class PhotoAlbumDetailView extends StatelessWidget {
  final PhotoAlbum album;
  const PhotoAlbumDetailView({Key? key, required this.album}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PhotoAlbumDetailViewModel>(
      create: (_) => PhotoAlbumDetailViewModel(album.folderPath),
      child: Consumer<PhotoAlbumDetailViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            backgroundColor: Colors.black,
            extendBodyBehindAppBar: vm.isSelectionMode,
            appBar: _buildAppBar(context, vm),
            body: vm.isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: Colors.blue.shade400,
                    ),
                  )
                : vm.photos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          size: 80,
                          color: Colors.white54,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No photos here',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      GridView.builder(
                        padding: EdgeInsets.only(
                          top: vm.isSelectionMode
                              ? kToolbarHeight +
                                    MediaQuery.of(context).padding.top
                              : 0,
                          bottom: vm.isSelectionMode ? 100 : 0,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              crossAxisSpacing: 2,
                              mainAxisSpacing: 2,
                            ),
                        itemCount: vm.photos.length,
                        itemBuilder: (context, index) {
                          final file = vm.photos[index];
                          final isSelected = vm.selectedPaths.contains(
                            file.path,
                          );

                          return GestureDetector(
                            onTap: () {
                              if (vm.isSelectionMode) {
                                vm.toggleSelection(file.path);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _PhotoFullScreenView(
                                      photos: vm.photos,
                                      initialIndex: index,
                                    ),
                                  ),
                                );
                              }
                            },
                            onLongPress: () {
                              if (!vm.isSelectionMode) {
                                HapticFeedback.mediumImpact();
                                vm.enterSelectionWith(file.path);
                              } else {
                                vm.toggleSelection(file.path);
                              }
                            },
                            child: _PhotoTile(
                              file: file,
                              isSelected: isSelected,
                              inSelectionMode: vm.isSelectionMode,
                            ),
                          );
                        },
                      ),
                      // Premium floating bottom action bar
                      if (vm.isSelectionMode)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: MediaQuery.of(context).padding.bottom + 12,
                          child: _PremiumSelectionBar(vm: vm, context: context),
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    PhotoAlbumDetailViewModel vm,
  ) {
    if (vm.isSelectionMode) {
      return AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
          onPressed: vm.cancelSelection,
        ),
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            vm.selectedPaths.isEmpty
                ? 'Select items'
                : '${vm.selectedPaths.length} selected',
            key: ValueKey(vm.selectedPaths.length),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: vm.selectAll,
            child: Text(
              'Select all',
              style: TextStyle(
                color: Colors.blue.shade400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            album.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${album.count} items',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
          onPressed: vm.toggleSelectionMode,
          tooltip: 'Select',
        ),
      ],
    );
  }
}

// ─── Premium photo tile ───────────────────────
class _PhotoTile extends StatelessWidget {
  final File file;
  final bool isSelected;
  final bool inSelectionMode;
  const _PhotoTile({
    required this.file,
    required this.isSelected,
    required this.inSelectionMode,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      foregroundDecoration: isSelected
          ? BoxDecoration(
              color: Colors.black38,
              border: Border.all(color: Colors.blue.shade400, width: 2.5),
            )
          : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            file,
            fit: BoxFit.cover,
            cacheWidth: 180,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.white.withOpacity(0.05),
              child: const Icon(
                Icons.broken_image,
                color: Colors.white54,
                size: 16,
              ),
            ),
          ),
          if (inSelectionMode)
            Positioned(
              top: 4,
              right: 4,
              child: AnimatedScale(
                scale: inSelectionMode ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.elasticOut,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? Colors.blue.shade400
                        : Colors.black.withOpacity(0.35),
                    border: Border.all(
                      color: isSelected ? Colors.blue.shade400 : Colors.white,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.blue.shade400.withOpacity(0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 13,
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Premium floating selection action bar ────
class _PremiumSelectionBar extends StatelessWidget {
  final PhotoAlbumDetailViewModel vm;
  final BuildContext context;
  const _PremiumSelectionBar({required this.vm, required this.context});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BarAction(
            icon: Icons.share_rounded,
            label: 'Share',
            onTap: () {
              showVortexShareSheet(
                context,
                vm.selectedPaths.toList(),
                onSendStarted: vm.cancelSelection,
              );
            },
          ),
          Container(width: 1, height: 36, color: Colors.white12),
          _BarAction(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: Colors.redAccent,
            enabled: vm.selectedPaths.isNotEmpty,
            onTap: () => _confirmDelete(context, vm),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, PhotoAlbumDetailViewModel vm) {
    showDialog(
      context: ctx,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Photos?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Permanently delete ${vm.selectedPaths.length} photo(s)? This cannot be undone.',
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialog);
              vm.deleteSelected();
            },
            child: Text(
              'Delete',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool enabled;
  const _BarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : color.withOpacity(0.35);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: effectiveColor, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: effectiveColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Full Screen Viewer with swipe & back button
// ─────────────────────────────────────────────
class _PhotoFullScreenView extends StatefulWidget {
  final List<File> photos;
  final int initialIndex;
  const _PhotoFullScreenView({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_PhotoFullScreenView> createState() => _PhotoFullScreenViewState();
}

class _PhotoFullScreenViewState extends State<_PhotoFullScreenView> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _barsVisible = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _barsVisible = !_barsVisible),
        child: Stack(
          children: [
            // Swipeable photo pager
            PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemCount: widget.photos.length,
              itemBuilder: (_, index) {
                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5.0,
                  child: Center(
                    child: Image.file(
                      widget.photos[index],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 80,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Top bar with back button
            AnimatedSlide(
              offset: _barsVisible ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: _barsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          Text(
                            '${_currentIndex + 1} / ${widget.photos.length}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                offset: _barsVisible ? Offset.zero : const Offset(0, 1),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: AnimatedOpacity(
                  opacity: _barsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.share_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.info_outline_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () => _showInfo(context),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red,
                              ),
                              onPressed: () => _confirmDelete(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context) {
    final file = widget.photos[_currentIndex];
    final stat = file.statSync();
    final sizeKB = stat.size / 1024;
    final sizeMB = sizeKB / 1024;
    final sizeStr = sizeMB >= 1
        ? '${sizeMB.toStringAsFixed(2)} MB'
        : '${sizeKB.toStringAsFixed(1)} KB';
    final date = stat.modified;
    final dateStr =
        '${date.day}/${date.month}/${date.year}  ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    final name = file.path.split('/').last;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'File info',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'Name', value: name),
            _InfoRow(label: 'Size', value: sizeStr),
            _InfoRow(label: 'Modified', value: dateStr),
            _InfoRow(label: 'Path', value: file.path, small: true),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Photo?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This photo will be permanently deleted.',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              final file = widget.photos[_currentIndex];
              Navigator.pop(ctx);
              try {
                await file.delete();
              } catch (_) {}
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(
              'Delete',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool small;
  const _InfoRow({
    required this.label,
    required this.value,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: small ? 12 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
