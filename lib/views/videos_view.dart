import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../viewmodels/media_viewmodels.dart';
import '../utils/file_opener.dart';
import '../widgets/share_sheet.dart';
import '../widgets/video_player_view.dart';
import '../theme/app_theme.dart';

class _VideoThumb extends StatefulWidget {
  final File file;
  final double size;
  const _VideoThumb({required this.file, this.size = 160});
  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  Uint8List? _bytes;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: widget.file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: widget.size.toInt(),
        quality: 60,
      );
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _tried = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _tried = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_tried) {
      return Container(
        color: const Color(0xFF14171B),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.accentLime,
            ),
          ),
        ),
      );
    }
    if (_bytes == null) {
      return Container(
        color: const Color(0xFF14171B),
        child: const Center(
          child: Icon(
            Icons.videocam_outlined,
            color: Color(0xFF2E333B),
            size: 32,
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(_bytes!, fit: BoxFit.cover),
        Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}

class VideosView extends StatelessWidget {
  const VideosView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VideosViewModel(),
      child: Consumer<VideosViewModel>(
        builder: (context, vm, _) {
          final albums = vm.albums;
          final featuredAlbum = albums.isNotEmpty ? albums.first : null;
          final gridAlbums =
              albums.length > 1 ? albums.sublist(1) : <VideoAlbum>[];

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
                    'Videos',
                    style: TextStyle(
                      fontFamily: AppTheme.fontBricolage,
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${albums.length} album${albums.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Color(0xFF78828A),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            body: vm.isLoading
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
                          Icons.videocam_off_outlined,
                          size: 72,
                          color: Color(0xFF78828A),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No videos found',
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
                                    VideoAlbumDetailView(album: featuredAlbum),
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
                                    child: _VideoThumb(
                                      file: featuredAlbum.coverFile,
                                      size: 800,
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
                                return GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          VideoAlbumDetailView(album: album),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF14171B),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: _VideoThumb(
                                            file: album.coverFile,
                                            size: 320,
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

class VideoAlbumDetailView extends StatelessWidget {
  final VideoAlbum album;
  const VideoAlbumDetailView({Key? key, required this.album}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<VideoAlbumDetailViewModel>(
      create: (_) => VideoAlbumDetailViewModel(album.folderPath),
      child: Consumer<VideoAlbumDetailViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            backgroundColor: Colors.black,
            extendBodyBehindAppBar: vm.isSelectionMode,
            appBar: _buildAppBar(context, vm),
            body: vm.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.accentLime,
                    ),
                  )
                : vm.videos.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.videocam_off_outlined,
                          size: 80,
                          color: Colors.white54,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No videos here',
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
                        itemCount: vm.videos.length,
                        itemBuilder: (context, index) {
                          final file = vm.videos[index];
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
                                    builder: (_) => VideoPlayerView(
                                      videoPath: file.path,
                                      title: file.path.split(Platform.pathSeparator).last,
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
                            child: _VideoTile(
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
    VideoAlbumDetailViewModel vm,
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
              fontFamily: AppTheme.fontBricolage,
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            '${album.count} items',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
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

class _VideoTile extends StatelessWidget {
  final File file;
  final bool isSelected;
  final bool inSelectionMode;
  const _VideoTile({
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
            _VideoThumb(
              file: file,
              size: 260,
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
  final VideoAlbumDetailViewModel vm;
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

  void _confirmDelete(BuildContext ctx, VideoAlbumDetailViewModel vm) {
    showDialog(
      context: ctx,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xFF141715),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF262A28), width: 1),
        ),
        title: const Text(
          'Delete Selected Videos?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          'Permanently delete ${vm.selectedPaths.length} video(s)? This cannot be undone.',
          style: const TextStyle(color: Color(0xFF78828A), fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
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
            onPressed: () {
              Navigator.pop(dialog);
              vm.deleteSelected();
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
