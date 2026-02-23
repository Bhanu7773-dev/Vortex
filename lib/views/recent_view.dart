import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/recent_model.dart';
import '../viewmodels/recent_viewmodel.dart';
import '../theme/app_theme.dart';

class RecentView extends StatelessWidget {
  const RecentView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RecentViewModel>(
      create: (_) => RecentViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recent'),
          actions: [
            IconButton(icon: const Icon(Icons.search), onPressed: () {}),
            IconButton(
              icon: const Icon(Icons.list_alt),
              onPressed: () {},
            ), // Layout switch
            IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
          ],
        ),
        body: Consumer<RecentViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.accentBlue),
              );
            }
            if (viewModel.sections.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      size: 80,
                      color: AppTheme.textGrey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No recent files',
                      style: TextStyle(color: AppTheme.textGrey, fontSize: 16),
                    ),
                  ],
                ),
              );
            }
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      viewModel.totalItemsText,
                      style: const TextStyle(
                        color: AppTheme.textGrey,
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
                                childAspectRatio:
                                    0.75, // Taller for the text below
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return _RecentItemCard(file: section.files[index])
                                .animate(
                                  key: ValueKey('${section.title}_$index'),
                                )
                                .fade()
                                .slideY(
                                  begin: 0.1,
                                  end: 0,
                                  duration: 400.ms,
                                  delay: (50 * index)
                                      .ms, // Stagger based on grid pos
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
      color: AppTheme
          .backgroundBlack, // Solid black to mask scrolling items underneath
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(
            section.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 16, color: Colors.white30),
          const SizedBox(width: 12),
          Text(
            '${section.itemCount} items',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          const Icon(
            Icons.keyboard_arrow_up,
            color: AppTheme.textGrey,
            size: 24,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.cardGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(
                Icons.image, // Placeholder icon
                color: Colors.white24,
                size: 40,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          file.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
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
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
          ),
        ),
        Center(
          child: Text(
            file.type,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
