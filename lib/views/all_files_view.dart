import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vortex/viewmodels/all_files_viewmodel.dart';
import 'package:vortex/models/file_item_model.dart';
import 'package:vortex/theme/app_theme.dart';

class AllFilesView extends StatelessWidget {
  const AllFilesView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AllFilesViewModel>(
      create: (_) => AllFilesViewModel(),
      child: Consumer<AllFilesViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: viewModel.isSelectionMode
                  ? AppBar(
                      leadingWidth: 80,
                      leading: TextButton(
                        onPressed: () => viewModel.toggleSelectionMode(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppTheme.accentBlue,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      title: Text('${viewModel.selectedPaths.length} selected'),
                      centerTitle: true,
                      actions: [
                        TextButton(
                          onPressed: () => viewModel.selectAll(),
                          child: const Text(
                            'Select all',
                            style: TextStyle(
                              color: AppTheme.accentBlue,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    )
                  : AppBar(
                      title: const Text('All files'),
                      actions: [
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.add),
                          color: AppTheme.cardGrey,
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'new_folder',
                              child: Text(
                                'New folder',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'add_files',
                              child: Text(
                                'Add files',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'new_folder') {
                              _showCreateDialog(context, viewModel, true);
                            } else if (value == 'add_files') {
                              _showCreateDialog(context, viewModel, false);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {},
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          color: AppTheme.cardGrey,
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'grid_view',
                              child: Text(
                                viewModel.isGridView
                                    ? 'List view'
                                    : 'Grid view',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text(
                                'Edit',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'settings',
                              child: Text(
                                'Settings',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'grid_view') {
                              viewModel.toggleGridView();
                            } else if (value == 'edit') {
                              viewModel.toggleSelectionMode();
                            }
                          },
                        ),
                      ],
                    ),
            ),
            bottomNavigationBar: viewModel.isSelectionMode
                ? _buildBottomNavBar(context, viewModel)
                : null,
            body: Builder(
              builder: (context) {
                if (viewModel.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.accentBlue,
                    ),
                  );
                }

                return CustomScrollView(
                  slivers: [
                    _buildHeader(viewModel),
                    viewModel.isGridView
                        ? SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: 0.85,
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                return _FileGridItem(
                                      item: viewModel.items[index],
                                      viewModel: viewModel,
                                    )
                                    .animate()
                                    .fade(duration: 300.ms)
                                    .scaleXY(
                                      begin: 0.9,
                                      end: 1.0,
                                      curve: Curves.easeOut,
                                      delay: (10 * index).ms,
                                    );
                              }, childCount: viewModel.items.length),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              return _FileListItem(
                                    item: viewModel.items[index],
                                    viewModel: viewModel,
                                  )
                                  .animate()
                                  .fade(duration: 300.ms)
                                  .slideX(
                                    begin: 0.1,
                                    end: 0,
                                    curve: Curves.easeOut,
                                    delay:
                                        (10 * index).ms, // quick staggered load
                                  );
                            }, childCount: viewModel.items.length),
                          ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(AllFilesViewModel viewModel) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Text(
                'All files',
                style: TextStyle(
                  color: AppTheme.accentBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  viewModel.itemCountString,
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 14,
                  ),
                ),
                PopupMenuButton<SortOption>(
                  color: AppTheme.cardGrey,
                  onSelected: (option) {
                    viewModel.setSortOption(option);
                  },
                  itemBuilder: (context) {
                    return SortOption.values.map((option) {
                      final isSelected = viewModel.currentSort == option;
                      final textMapping = {
                        SortOption.dateModified: 'Date modified',
                        SortOption.size: 'Size',
                        SortOption.filename: 'Filename',
                        SortOption.type: 'Type',
                      };
                      return PopupMenuItem<SortOption>(
                        value: option,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              textMapping[option]!,
                              style: TextStyle(
                                color: isSelected
                                    ? AppTheme.accentBlue
                                    : Colors.white,
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                viewModel.isDescending
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: AppTheme.accentBlue,
                                size: 16,
                              ),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  child: Row(
                    children: [
                      Text(
                        _getSortText(viewModel.currentSort),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      Icon(
                        viewModel.isDescending
                            ? Icons.arrow_drop_down
                            : Icons.arrow_drop_up,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _getSortText(SortOption option) {
    switch (option) {
      case SortOption.dateModified:
        return 'Date modified';
      case SortOption.size:
        return 'Size';
      case SortOption.filename:
        return 'Filename';
      case SortOption.type:
        return 'Type';
      default:
        return 'Filename';
    }
  }

  void _showCreateDialog(
    BuildContext context,
    AllFilesViewModel viewModel,
    bool isFolder,
  ) {
    final TextEditingController _controller = TextEditingController();
    final String typeName = isFolder ? "folder" : "file";
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardGrey,
              title: Text(
                'New $typeName',
                style: const TextStyle(color: Colors.white),
              ),
              content: TextField(
                controller: _controller,
                autofocus: true,
                cursorColor: AppTheme.accentBlue,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter $typeName name',
                  hintStyle: const TextStyle(color: AppTheme.textGrey),
                  errorText: errorMessage,
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.accentBlue),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.accentBlue),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.textGrey),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final name = _controller.text.trim();
                    if (name.isNotEmpty) {
                      if (isFolder) {
                        viewModel.createNewFolder(name);
                        Navigator.pop(context);
                      } else {
                        if (!name.contains('.')) {
                          setState(() {
                            errorMessage =
                                'File must have an extension (e.g. .txt)';
                          });
                        } else {
                          viewModel.createNewFile(name);
                          Navigator.pop(context);
                        }
                      }
                    } else {
                      setState(() {
                        errorMessage = 'Name cannot be empty';
                      });
                    }
                  },
                  child: const Text(
                    'Create',
                    style: TextStyle(color: AppTheme.accentBlue),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBottomNavBar(BuildContext context, AllFilesViewModel viewModel) {
    return BottomNavigationBar(
      backgroundColor: AppTheme.cardGrey,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.share), label: 'Share'),
        BottomNavigationBarItem(
          icon: Icon(Icons.bookmark_border),
          label: 'Tag',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.drive_file_move_outline),
          label: 'Move',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.delete_outline),
          label: 'Delete',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.more_vert), label: 'More'),
      ],
      onTap: (index) {
        if (index == 4) {
          _showMoreBottomSheet(context, viewModel);
        }
      },
    );
  }

  void _showMoreBottomSheet(BuildContext context, AllFilesViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text(
                  'Copy',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context),
              ),
              const Divider(color: Colors.grey, height: 1),
              ListTile(
                title: const Text(
                  'Details',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context),
              ),
              const Divider(color: Colors.grey, height: 1),
              ListTile(
                title: const Text(
                  'Compress',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context),
              ),
              const Divider(color: Colors.grey, height: 1),
              ListTile(
                title: const Text(
                  'Rename',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context),
              ),
              const Divider(color: Colors.grey, height: 1),
              ListTile(
                title: const Text(
                  'Create Home screen shortcut',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FileListItem extends StatelessWidget {
  final FileItemModel item;
  final AllFilesViewModel viewModel;

  const _FileListItem({required this.item, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final dateStr = viewModel.formatDateString(item.modifiedDate);
    final countStr = item.isDirectory
        ? '${item.itemCount} item${item.itemCount == 1 ? '' : 's'}'
        : item.categoryHint; // Or file size later

    final isSelected = viewModel.selectedPaths.contains(item.path);

    return InkWell(
      onTap: () {
        if (viewModel.isSelectionMode) {
          viewModel.toggleSelection(item.path);
        } else {
          // Navigation into sub-folders later
        }
      },
      child: Container(
        color: isSelected ? AppTheme.cardGrey : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            _buildIcon(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$countStr  |  $dateStr',
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (viewModel.isSelectionMode)
              Icon(
                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                color: isSelected ? AppTheme.accentBlue : AppTheme.textGrey,
              )
            else
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textGrey,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    // Generate the blue folder icon like the screenshot
    IconData centerIcon = Icons.folder;
    Color iconColor = AppTheme.accentBlue; // Light cyan/blue folder

    if (item.categoryHint == 'download') {
      // centerIcon = Icons.download_rounded; // Removed custom icon
    } else if (item.categoryHint == 'document') {
      // centerIcon = Icons.description; // Removed custom icon
    }

    if (!item.isDirectory) {
      centerIcon = Icons.insert_drive_file;
      iconColor = Colors.grey;
    }

    return Icon(centerIcon, color: iconColor, size: 48);
  }
}

class _FileGridItem extends StatelessWidget {
  final FileItemModel item;
  final AllFilesViewModel viewModel;

  const _FileGridItem({required this.item, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final countStr = item.isDirectory
        ? '${item.itemCount} item${item.itemCount == 1 ? '' : 's'}'
        : item.categoryHint;

    final isSelected = viewModel.selectedPaths.contains(item.path);

    return InkWell(
      onTap: () {
        if (viewModel.isSelectionMode) {
          viewModel.toggleSelection(item.path);
        } else {
          // Navigate inside
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.cardGrey : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppTheme.accentBlue, width: 2)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIcon(),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  countStr,
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (viewModel.isSelectionMode)
              Positioned(
                bottom: 8,
                right: 8,
                child: Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: isSelected ? AppTheme.accentBlue : AppTheme.textGrey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData centerIcon = Icons.folder;
    Color iconColor = AppTheme.accentBlue;

    if (!item.isDirectory) {
      centerIcon = Icons.insert_drive_file;
      iconColor = Colors.grey;
    }

    return Icon(centerIcon, color: iconColor, size: 56);
  }
}
