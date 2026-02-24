import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../viewmodels/media_viewmodels.dart';
import '../theme/app_theme.dart';
import '../utils/file_opener.dart';

// ─── Shared thumbnail widget for a video file ──
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
      if (mounted)
        setState(() {
          _bytes = bytes;
          _tried = true;
        });
    } catch (_) {
      if (mounted) setState(() => _tried = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_tried) {
      return Container(
        color: const Color(0xFF1A1A2E),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white24,
            ),
          ),
        ),
      );
    }
    if (_bytes == null) {
      return Container(
        color: const Color(0xFF1A1A2E),
        child: const Center(
          child: Icon(
            Icons.play_circle_outline,
            color: Colors.white38,
            size: 32,
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(_bytes!, fit: BoxFit.cover),
        const Center(
          child: Icon(
            Icons.play_circle_fill,
            color: Colors.white60,
            size: 28,
            shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
          ),
        ),
      ],
    );
  }
}

// ─── Album Grid ──────────────────────────────
class VideosView extends StatelessWidget {
  const VideosView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VideosViewModel(),
      child: Consumer<VideosViewModel>(
        builder: (context, vm, _) => Scaffold(
          backgroundColor: AppTheme.backgroundBlack,
          appBar: AppBar(
            backgroundColor: AppTheme.backgroundBlack,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Videos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [],
          ),
          body: vm.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentBlue),
                )
              : vm.albums.isEmpty
              ? _emptyState(Icons.videocam_off_outlined, 'No videos found')
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: vm.albums.length,
                  itemBuilder: (context, i) {
                    final album = vm.albums[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoAlbumDetailView(album: album),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _VideoThumb(
                                file: album.coverFile,
                                size: 300,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            album.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${album.count}',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

// ─── Album Detail: 5-col grid ────────────────
class VideoAlbumDetailView extends StatelessWidget {
  final VideoAlbum album;
  const VideoAlbumDetailView({Key? key, required this.album}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VideoAlbumDetailViewModel(album.folderPath),
      child: Consumer<VideoAlbumDetailViewModel>(
        builder: (context, vm, _) => Scaffold(
          backgroundColor: Colors.black,
          appBar: vm.isSelectionMode
              ? _selBar(
                  context,
                  vm,
                  '${vm.selectedPaths.length} selected',
                  vm.cancelSelection,
                  vm.selectAll,
                )
              : AppBar(
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
                        '${vm.videos.length} items',
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                      ),
                      onPressed: vm.toggleSelectionMode,
                    ),
                  ],
                ),
          body: vm.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentBlue),
                )
              : vm.videos.isEmpty
              ? _emptyState(Icons.videocam_off_outlined, 'No videos here')
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
                      itemCount: vm.videos.length,
                      itemBuilder: (context, i) {
                        final file = vm.videos[i];
                        final sel = vm.selectedPaths.contains(file.path);
                        return GestureDetector(
                          onTap: () {
                            if (vm.isSelectionMode) {
                              vm.toggleSelection(file.path);
                            } else {
                              FileOpener.openFile(context, file.path);
                            }
                          },
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            if (!vm.isSelectionMode)
                              vm.enterSelectionWith(file.path);
                            else
                              vm.toggleSelection(file.path);
                          },
                          child: _GridTile(
                            isSelected: sel,
                            inSelectionMode: vm.isSelectionMode,
                            child: _VideoThumb(file: file, size: 180),
                          ),
                        );
                      },
                    ),
                    if (vm.isSelectionMode)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: MediaQuery.of(context).padding.bottom + 12,
                        child: _ActionBar(
                          onShare: () {},
                          onDelete: vm.selectedPaths.isEmpty
                              ? null
                              : () => _deleteDialog(
                                  context,
                                  vm.selectedPaths.length,
                                  vm.deleteSelected,
                                ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared helpers (also exported for reuse)
// ─────────────────────────────────────────────

Widget _emptyState(IconData icon, String label) => Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 80, color: AppTheme.textGrey),
      const SizedBox(height: 16),
      Text(
        label,
        style: const TextStyle(color: AppTheme.textGrey, fontSize: 16),
      ),
    ],
  ),
);

AppBar _selBar(
  BuildContext context,
  dynamic vm,
  String title,
  VoidCallback onClose,
  VoidCallback onAll,
) => AppBar(
  backgroundColor: AppTheme.cardGrey,
  leading: IconButton(
    icon: const Icon(Icons.close, color: Colors.white),
    onPressed: onClose,
  ),
  title: Text(
    title,
    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
  ),
  actions: [
    TextButton(
      onPressed: onAll,
      child: const Text(
        'Select all',
        style: TextStyle(
          color: AppTheme.accentBlue,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  ],
);

void _deleteDialog(BuildContext context, int count, VoidCallback onConfirm) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Delete?',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Text(
        'Permanently delete $count item(s)?',
        style: const TextStyle(color: AppTheme.textGrey, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppTheme.textGrey),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            onConfirm();
          },
          child: const Text(
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

class _GridTile extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final bool inSelectionMode;
  const _GridTile({
    required this.child,
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
              border: Border.all(color: AppTheme.accentBlue, width: 2.5),
            )
          : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (inSelectionMode)
            Positioned(
              top: 4,
              right: 4,
              child: AnimatedScale(
                scale: 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.elasticOut,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppTheme.accentBlue : Colors.black54,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.accentBlue.withOpacity(0.5),
                              blurRadius: 6,
                            ),
                          ]
                        : [],
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 12,
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

class _ActionBar extends StatelessWidget {
  final VoidCallback onShare;
  final VoidCallback? onDelete;
  const _ActionBar({required this.onShare, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    decoration: BoxDecoration(
      color: AppTheme.cardGrey,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white10),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionBtn(icon: Icons.share_rounded, label: 'Share', onTap: onShare),
        Container(width: 1, height: 36, color: Colors.white12),
        _ActionBtn(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          color: Colors.redAccent,
          enabled: onDelete != null,
          onTap: onDelete ?? () {},
        ),
      ],
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool enabled;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
    this.enabled = true,
  });
  @override
  Widget build(BuildContext context) {
    final c = enabled ? color : color.withOpacity(0.35);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: c, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
