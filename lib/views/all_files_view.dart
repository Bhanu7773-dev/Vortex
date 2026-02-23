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
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Builder(
            builder: (context) {
              final viewModel = Provider.of<AllFilesViewModel>(
                context,
                listen: false,
              );
              return AppBar(
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
                  IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    color: AppTheme.cardGrey,
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'grid_view',
                        child: Text(
                          'Grid view',
                          style: TextStyle(color: Colors.white),
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
                    onSelected: (value) {},
                  ),
                ],
              );
            },
          ),
        ),
        body: Consumer<AllFilesViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.accentBlue),
              );
            }

            return CustomScrollView(
              slivers: [
                _buildHeader(viewModel),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
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
                          delay: (10 * index).ms, // quick staggered load
                        );
                  }, childCount: viewModel.items.length),
                ),
              ],
            );
          },
        ),
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

    return InkWell(
      onTap: () {
        // Navigation into sub-folders later
      },
      child: Padding(
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
            const Icon(Icons.chevron_right, color: AppTheme.textGrey, size: 20),
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
