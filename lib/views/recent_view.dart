import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/recent_model.dart';
import '../viewmodels/recent_viewmodel.dart';
import '../utils/file_opener.dart';
import 'all_files_view.dart';

class RecentView extends StatelessWidget {
  const RecentView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RecentViewModel>(
      create: (_) => RecentViewModel(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text(
            'Received Files',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          actions: [
            Consumer<RecentViewModel>(
              builder: (context, vm, _) => IconButton(
                icon: const Icon(Icons.folder_open_rounded),
                tooltip: 'Open Vortex folder',
                onPressed: vm.receiveDirPath.isEmpty
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AllFilesView(initialPath: vm.receiveDirPath),
                          ),
                        ),
              ),
            ),
          ],
        ),
        body: Consumer<RecentViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isLoading) {
              return Center(
                child: CircularProgressIndicator(color: Colors.blue.shade400),
              );
            }
            if (viewModel.sections.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        Icons.move_to_inbox_rounded,
                        size: 64,
                        color: Colors.teal.shade300,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No received files yet',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Files received via Vortex will appear here',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms);
            }
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      viewModel.totalItemsText,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                ...viewModel.sections.map((section) {
                  return SliverMainAxisGroup(
                    slivers: [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _RecentSectionHeaderDelegate(
                          section: section,
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12.0,
                                mainAxisSpacing: 16.0,
                                childAspectRatio: 0.75,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return _RecentItemCard(file: section.files[index])
                                .animate(
                                  key: ValueKey('${section.title}_$index'),
                                )
                                .fadeIn(duration: 400.ms, delay: (50 * index).ms)
                                .slideY(
                                  begin: 0.1,
                                  end: 0,
                                  duration: 400.ms,
                                  curve: Curves.easeOut,
                                );
                          }, childCount: section.files.length),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RecentSectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final RecentSectionModel section;

  _RecentSectionHeaderDelegate({required this.section});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.purple.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            section.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${section.itemCount}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          Icon(
            Icons.keyboard_arrow_up_rounded,
            color: Colors.white.withOpacity(0.4),
            size: 22,
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 56.0;

  @override
  double get minExtent => 56.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}

class _RecentItemCard extends StatelessWidget {
  final RecentFileModel file;

  const _RecentItemCard({required this.file});

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'heic':
      case 'bmp':
        return Icons.image_rounded;
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
      case 'webm':
      case '3gp':
        return Icons.video_file_rounded;
      case 'mp3':
      case 'aac':
      case 'wav':
      case 'flac':
      case 'm4a':
      case 'ogg':
        return Icons.audio_file_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip_rounded;
      case 'apk':
        return Icons.android_rounded;
      case 'doc':
      case 'docx':
      case 'txt':
      case 'odt':
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'heic':
      case 'bmp':
        return Colors.blue;
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
      case 'webm':
      case '3gp':
        return Colors.purple;
      case 'mp3':
      case 'aac':
      case 'wav':
      case 'flac':
      case 'm4a':
      case 'ogg':
        return Colors.orange;
      case 'pdf':
        return Colors.red;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Colors.amber;
      case 'apk':
        return Colors.green;
      default:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = file.type.toLowerCase().replaceAll('.', '');
    final iconColor = _colorForType(ext);
    return GestureDetector(
      onTap: () => FileOpener.openFile(context, file.path),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: iconColor.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  _iconForType(ext),
                  color: iconColor.withOpacity(0.7),
                  size: 36,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            file.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              file.size,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
