import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/share_sheet.dart';
import 'package:provider/provider.dart';
import '../viewmodels/photos_viewmodel.dart';
import '../theme/app_theme.dart';

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
                      color: AppTheme.accentLime,
                    ),
                  )
                : vm.photos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
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
                        padding: EdgeInsets.fromLTRB(
                          12,
                          vm.isSelectionMode
                              ? kToolbarHeight +
                                    MediaQuery.of(context).padding.top +
                                    8
                              : 12,
                          12,
                          vm.isSelectionMode ? 110 : 20,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
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
                                    builder: (_) => PhotoFullScreenView(
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
                      if (vm.isSelectionMode)
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: MediaQuery.of(context).padding.bottom + 16,
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
            child: Container(color: Colors.black.withOpacity(0.75)),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
          onPressed: vm.cancelSelection,
        ),
        title: Text(
          vm.selectedPaths.isEmpty
              ? 'Select items'
              : '${vm.selectedPaths.length} selected',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: vm.selectAll,
            child: const Text(
              'Select all',
              style: TextStyle(
                color: AppTheme.accentLime,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppTheme.accentLime : Colors.transparent,
          width: 2.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13.5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              file,
              fit: BoxFit.cover,
              cacheWidth: 260,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF181B19),
                child: const Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white24,
                  size: 20,
                ),
              ),
            ),
            if (inSelectionMode)
              Positioned(
                top: 6,
                right: 6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppTheme.accentLime
                        : Colors.black.withOpacity(0.35),
                    border: isSelected
                        ? null
                        : Border.all(color: Colors.white70, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.black,
                          size: 14,
                          weight: 700,
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PremiumSelectionBar extends StatelessWidget {
  final PhotoAlbumDetailViewModel vm;
  final BuildContext context;
  const _PremiumSelectionBar({required this.vm, required this.context});

  @override
  Widget build(BuildContext context) {
    final hasSelection = vm.selectedPaths.isNotEmpty;

    return Container(
      height: 66,
      decoration: BoxDecoration(
        color: const Color(0xFF141715),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFF262A28), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.65),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: hasSelection
                  ? () {
                      showVortexShareSheet(
                        context,
                        vm.selectedPaths.toList(),
                        onSendStarted: vm.cancelSelection,
                      );
                    }
                  : null,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(36),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.share_outlined,
                    color: hasSelection
                        ? AppTheme.accentLime
                        : const Color(0xFF454B47),
                    size: 21,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Share',
                    style: TextStyle(
                      color: hasSelection
                          ? AppTheme.accentLime
                          : const Color(0xFF454B47),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 32, color: const Color(0xFF262A28)),
          Expanded(
            child: InkWell(
              onTap: hasSelection ? () => _confirmDelete(context, vm) : null,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(36),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    color: hasSelection
                        ? const Color(0xFFFF5252)
                        : const Color(0xFF454B47),
                    size: 21,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Delete',
                    style: TextStyle(
                      color: hasSelection
                          ? const Color(0xFFFF5252)
                          : const Color(0xFF454B47),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, PhotoAlbumDetailViewModel vm) {
    showDialog(
      context: ctx,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xFF141715),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF262A28), width: 1),
        ),
        title: const Text(
          'Delete Photos?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Permanently delete ${vm.selectedPaths.length} photo(s)? This cannot be undone.',
          style: const TextStyle(color: Color(0xFF78828A), fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
            ),
            onPressed: () {
              Navigator.pop(dialog);
              vm.deleteSelected();
            },
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class PhotoFullScreenView extends StatefulWidget {
  final List<File> photos;
  final int initialIndex;
  const PhotoFullScreenView({
    Key? key,
    required this.photos,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<PhotoFullScreenView> createState() => _PhotoFullScreenViewState();
}

class _PhotoFullScreenViewState extends State<PhotoFullScreenView> {
  late final PageController _pageController;
  late final ValueNotifier<int> _currentIndexNotifier;
  late List<File> _photos;

  int get _currentIndex => _currentIndexNotifier.value;

  @override
  void initState() {
    super.initState();
    _photos = List<File>.from(widget.photos);
    final initial = widget.initialIndex.clamp(0, _photos.isNotEmpty ? _photos.length - 1 : 0);
    _currentIndexNotifier = ValueNotifier<int>(initial);
    _pageController = PageController(initialPage: initial);
    _pageController.addListener(_onPageScroll);
  }

  void _onPageScroll() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page;
    if (page == null) return;
    final target = page.round().clamp(0, _photos.isNotEmpty ? _photos.length - 1 : 0);
    if (target != _currentIndexNotifier.value) {
      _currentIndexNotifier.value = target;
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _currentIndexNotifier.dispose();
    super.dispose();
  }

  void _sharePhoto(BuildContext context) {
    if (_photos.isEmpty) return;
    final file = _photos[_currentIndex];
    showVortexShareSheet(context, [file.path]);
  }

  void _showInfo(BuildContext context) {
    if (_photos.isEmpty) return;
    final file = _photos[_currentIndex];
    final stat = file.statSync();
    final sizeKB = stat.size / 1024;
    final sizeMB = sizeKB / 1024;
    final sizeStr = sizeMB >= 1
        ? '${sizeMB.toStringAsFixed(1)} MB'
        : '${sizeKB.toStringAsFixed(1)} KB';
    final date = stat.modified;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final name = file.path.split(Platform.pathSeparator).last;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121513),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3F3C),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'FILE INFO',
                  style: TextStyle(
                    color: Color(0xFF78828A),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFF1E2220), height: 28, thickness: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Size',
                      style: TextStyle(
                        color: Color(0xFF78828A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      sizeStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF1E2220), height: 28, thickness: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Modified',
                      style: TextStyle(
                        color: Color(0xFF78828A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF1E2220), height: 28, thickness: 1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Path',
                      style: TextStyle(
                        color: Color(0xFF78828A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        file.path,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: file.path));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Path copied to clipboard',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: const Color(0xFF1C1F1D),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161917),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFF262A28), width: 1.2),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Copy path',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    if (_photos.isEmpty) return;
    final file = _photos[_currentIndex];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141715),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF262A28), width: 1),
        ),
        title: const Text(
          'Delete Photo?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: const Text(
          'This photo will be permanently deleted from your device.',
          style: TextStyle(color: Color(0xFF78828A), fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await file.delete();
              } catch (_) {}
              if (!mounted) return;
              setState(() {
                final curr = _currentIndex;
                _photos.removeAt(curr);
                if (_photos.isEmpty) {
                  Navigator.pop(context);
                } else {
                  final newIndex = curr >= _photos.length ? _photos.length - 1 : curr;
                  _currentIndexNotifier.value = newIndex;
                  if (_pageController.hasClients) {
                    _pageController.jumpToPage(newIndex);
                  }
                }
              });
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildTallyBar(int current) {
    final total = _photos.length;
    if (total <= 1) return const SizedBox(height: 24);

    const maxVisibleTicks = 25;
    int start = 0;
    int end = total;
    if (total > maxVisibleTicks) {
      start = (current - maxVisibleTicks ~/ 2).clamp(0, total - maxVisibleTicks);
      end = start + maxVisibleTicks;
    }

    return IgnorePointer(
      child: SizedBox(
        height: 24,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(end - start, (idx) {
            final actualIndex = start + idx;
            final isCurrent = actualIndex == current;
            return AnimatedContainer(
              key: ValueKey('tally_$actualIndex'),
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              width: 3.2,
              height: isCurrent ? 20.0 : 12.0,
              margin: const EdgeInsets.symmetric(horizontal: 2.2),
              decoration: BoxDecoration(
                color: isCurrent ? AppTheme.accentLime : const Color(0xFF262C27),
                borderRadius: BorderRadius.circular(2.0),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_photos.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0E0D),
        body: Center(
          child: Text(
            'No photos',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E0D),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  ValueListenableBuilder<int>(
                    valueListenable: _currentIndexNotifier,
                    builder: (context, current, _) {
                      return RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${current + 1} ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: '/ ${_photos.length}',
                              style: const TextStyle(
                                color: Color(0xFF78828A),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
                onPageChanged: (i) {
                  if (_currentIndexNotifier.value != i) {
                    _currentIndexNotifier.value = i;
                  }
                },
                itemCount: _photos.length,
                itemBuilder: (_, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        color: const Color(0xFF141715),
                        child: _PhotoItem(
                          key: ValueKey(_photos[index].path),
                          file: _photos[index],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<int>(
              valueListenable: _currentIndexNotifier,
              builder: (context, current, _) => _buildTallyBar(current),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                height: 66,
                decoration: BoxDecoration(
                  color: const Color(0xFF141715),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: const Color(0xFF262A28), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.55),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.share_outlined,
                      label: 'Share',
                      color: AppTheme.accentLime,
                      onTap: () => _sharePhoto(context),
                    ),
                    _buildActionButton(
                      icon: Icons.info_outline_rounded,
                      label: 'Info',
                      color: const Color(0xFF38BDF8),
                      onTap: () => _showInfo(context),
                    ),
                    _buildActionButton(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      color: const Color(0xFFFF5252),
                      onTap: () => _confirmDelete(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoItem extends StatefulWidget {
  final File file;
  const _PhotoItem({Key? key, required this.file}) : super(key: key);

  @override
  State<_PhotoItem> createState() => _PhotoItemState();
}

class _PhotoItemState extends State<_PhotoItem> {
  double _scale = 1.0;
  Offset _panOffset = Offset.zero;

  void _toggleZoom() {
    setState(() {
      if (_scale > 1.0) {
        _scale = 1.0;
        _panOffset = Offset.zero;
      } else {
        _scale = 2.2;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget img = Center(
      child: Image.file(
        widget.file,
        fit: BoxFit.contain,
        cacheWidth: 1200,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(
            Icons.broken_image_rounded,
            color: Colors.white24,
            size: 64,
          ),
        ),
      ),
    );

    if (_scale > 1.0) {
      return GestureDetector(
        onDoubleTap: _toggleZoom,
        onPanUpdate: (d) => setState(() => _panOffset += d.delta),
        child: ClipRect(
          child: Transform.translate(
            offset: _panOffset,
            child: Transform.scale(
              scale: _scale,
              child: img,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onDoubleTap: _toggleZoom,
      child: img,
    );
  }
}
