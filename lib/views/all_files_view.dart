import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vortex/theme/app_theme.dart';
import 'package:vortex/viewmodels/all_files_viewmodel.dart';
import 'package:vortex/models/file_item_model.dart';
import 'package:vortex/models/storage_volume_model.dart';
import 'package:vortex/widgets/tag_selection_sheet.dart';
import 'package:vortex/utils/file_opener.dart';
import 'package:vortex/widgets/share_sheet.dart';

class AllFilesView extends StatefulWidget {
  final String? initialPath;
  final bool isFolderPickerMode;
  const AllFilesView({
    Key? key,
    this.initialPath,
    this.isFolderPickerMode = false,
  }) : super(key: key);
  @override
  State<AllFilesView> createState() => _AllFilesViewState();
}

class _AllFilesViewState extends State<AllFilesView> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AllFilesViewModel>(
      create: (_) => AllFilesViewModel(
        initialPath: widget.initialPath,
        isFolderPickerMode: widget.isFolderPickerMode,
      ),
      child: Consumer<AllFilesViewModel>(
        builder: (context, viewModel, child) {
          return PopScope(
            canPop: viewModel.pathHistory.isEmpty,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) {
                viewModel.goBack();
              }
            },
            child: Scaffold(
              backgroundColor: Colors.black,
              floatingActionButton: viewModel.isFolderPickerMode
                  ? FloatingActionButton.extended(
                      onPressed: () {
                        // Return list of selected paths, or current path if none selected
                        if (viewModel.selectedPaths.isEmpty) {
                          Navigator.pop(context, [viewModel.currentPath]);
                        } else {
                          Navigator.pop(
                            context,
                            viewModel.selectedPaths.toList(),
                          );
                        }
                      },
                      label: Text(
                        viewModel.selectedPaths.isEmpty
                            ? 'Add this folder'
                            : 'Add ${viewModel.selectedPaths.length} folders',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: const Icon(Icons.check, color: Colors.black),
                      backgroundColor: AppTheme.accentLime,
                    )
                  : null,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: viewModel.isSelectionMode
                    ? AppBar(
                        backgroundColor: Colors.black,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        leadingWidth: 80,
                        leading: TextButton(
                          onPressed: () => viewModel.toggleSelectionMode(),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppTheme.accentLime,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Text(
                          '${viewModel.selectedPaths.length} selected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        centerTitle: true,
                        actions: [
                          TextButton(
                            onPressed: () => viewModel.selectAll(),
                            child: const Text(
                              'Select all',
                              style: TextStyle(
                                color: AppTheme.accentLime,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      )
                    : _searching
                    ? AppBar(
                        backgroundColor: Colors.black,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            setState(() => _searching = false);
                            _searchCtrl.clear();
                            viewModel.clearSearch();
                          },
                        ),
                        title: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          autofocus: true,
                          cursorColor: AppTheme.accentLime,
                          cursorWidth: 2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Search in ${viewModel.currentFolderName}…',
                            hintStyle: const TextStyle(color: Color(0xFF78828A)),
                            border: InputBorder.none,
                          ),
                          onChanged: (q) {
                            _debounce?.cancel();
                            _debounce = Timer(
                              const Duration(milliseconds: 350),
                              () {
                                viewModel.deepSearch(q);
                              },
                            );
                            setState(() {}); // rebuild X button instantly
                          },
                        ),
                        actions: [
                          if (_searchCtrl.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 20,
                                color: Color(0xFF78828A),
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                viewModel.deepSearch('');
                                setState(() {});
                              },
                            ),
                        ],
                      )
                    : AppBar(
                        backgroundColor: Colors.black,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        centerTitle: false,
                        leading: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () {
                            if (viewModel.pathHistory.isNotEmpty) {
                              viewModel.goBack();
                            } else {
                              Navigator.maybePop(context);
                            }
                          },
                        ),
                        titleSpacing: 0,
                        title: Text(
                          viewModel.currentPath == viewModel.rootPath
                              ? 'Internal storage'
                              : viewModel.currentFolderName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        actions: [
                          if (viewModel.availableVolumes.length > 1)
                            PopupMenuButton<StorageVolume>(
                              icon: const Icon(
                                Icons.storage,
                                color: Colors.white,
                              ),
                              tooltip: 'Switch Storage',
                              color: const Color(0xFF16191E),
                              position: PopupMenuPosition.under,
                              popUpAnimationStyle: AnimationStyle(
                                curve: Curves.easeOut,
                                duration: const Duration(milliseconds: 180),
                              ),
                              onSelected: (vol) => viewModel.switchStorage(vol),
                              itemBuilder: (context) =>
                                  viewModel.availableVolumes.map((vol) {
                                    final isSelected =
                                        viewModel.rootPath == vol.path;
                                    return PopupMenuItem<StorageVolume>(
                                      value: vol,
                                      child: Row(
                                        children: [
                                          Icon(
                                            vol.isInternal
                                                ? Icons.phone_android
                                                : Icons.sd_card,
                                            color: isSelected
                                                ? AppTheme.accentLime
                                                : Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            vol.name,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? AppTheme.accentLime
                                                  : Colors.white,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.check,
                                              color: AppTheme.accentLime,
                                              size: 16,
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }).toList(),
                            ),
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 24,
                            ),
                            color: const Color(0xFF16191E),
                            position: PopupMenuPosition.under,
                            popUpAnimationStyle: AnimationStyle(
                              curve: Curves.easeOut,
                              duration: const Duration(milliseconds: 180),
                            ),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'new_folder',
                                child: Text(
                                  'New folder',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'add_files',
                                child: Text(
                                  'Add files',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
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
                            icon: const Icon(
                              Icons.search,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: () => setState(() => _searching = true),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 24,
                            ),
                            color: const Color(0xFF16191E),
                            position: PopupMenuPosition.under,
                            popUpAnimationStyle: AnimationStyle(
                              curve: Curves.easeOut,
                              duration: const Duration(milliseconds: 180),
                            ),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'grid_view',
                                child: Text(
                                  viewModel.isGridView
                                      ? 'List view'
                                      : 'Grid view',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text(
                                  'Edit',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
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
              bottomNavigationBar: viewModel.isPasteMode
                  ? _buildPasteNavBar(context, viewModel)
                  : viewModel.isSelectionMode
                  ? _buildSelectionNavBar(context, viewModel)
                  : null,
              body: Builder(
                builder: (context) {
                  // ── Search mode ──
                  if (viewModel.isSearchMode) {
                    final results = viewModel.searchResults;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                          child: Row(
                            children: [
                              if (viewModel.isSearchLoading)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.accentLime,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.search,
                                  size: 16,
                                  color: Color(0xFF78828A),
                                ),
                              const SizedBox(width: 8),
                              Text(
                                viewModel.isSearchLoading
                                    ? 'Searching…  ${results.length} found'
                                    : '${results.length} results for "${viewModel.searchQuery}"',
                                style: const TextStyle(
                                  color: Color(0xFF78828A),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (results.isEmpty && !viewModel.isSearchLoading)
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.search_off,
                                    size: 70,
                                    color: Color(0xFF78828A),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'No results for "${viewModel.searchQuery}"',
                                    style: const TextStyle(
                                      color: Color(0xFF78828A),
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (context, i) => _FileListItem(
                                key: ValueKey(results[i].path),
                                item: results[i],
                                viewModel: viewModel,
                              ),
                            ),
                          ),
                      ],
                    );
                  }

                  // ── Normal browse mode ──
                  if (viewModel.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.accentLime,
                      ),
                    );
                  }

                  if (viewModel.items.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_off_outlined,
                            size: 80,
                            color: Colors.white54,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'This folder is empty',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                        ],
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
                                        key: ValueKey(
                                          viewModel.items[index].path,
                                        ),
                                        item: viewModel.items[index],
                                        viewModel: viewModel,
                                      )
                                      .animate(
                                        key: ValueKey(
                                          '${viewModel.items[index].path}_anim',
                                        ),
                                      )
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
                                      key: ValueKey(
                                        viewModel.items[index].path,
                                      ),
                                      item: viewModel.items[index],
                                      viewModel: viewModel,
                                    )
                                    .animate(
                                      key: ValueKey(
                                        '${viewModel.items[index].path}_anim',
                                      ),
                                    )
                                    .fade(duration: 300.ms)
                                    .slideX(
                                      begin: 0.1,
                                      end: 0,
                                      curve: Curves.easeOut,
                                      delay: (10 * index)
                                          .ms, // quick staggered load
                                    );
                              }, childCount: viewModel.items.length),
                            ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(AllFilesViewModel viewModel) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (viewModel.currentPath != viewModel.rootPath)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  viewModel.displayPath,
                  style: const TextStyle(
                    color: Color(0xFF78828A),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  viewModel.itemCountString,
                  style: const TextStyle(
                    color: Color(0xFF78828A),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                PopupMenuButton<SortOption>(
                  color: const Color(0xFF16191E),
                  elevation: 6,
                  position: PopupMenuPosition.under,
                  popUpAnimationStyle: AnimationStyle(
                    curve: Curves.easeOut,
                    duration: const Duration(milliseconds: 180),
                  ),
                  onSelected: (option) {
                    viewModel.setSortOption(option);
                  },
                  itemBuilder: (context) {
                    return SortOption.values.map((option) {
                      final isSelected = viewModel.currentSort == option;
                      final textMapping = {
                        SortOption.filename: 'Name',
                        SortOption.dateModified: 'Date modified',
                        SortOption.size: 'Size',
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
                                    ? AppTheme.accentLime
                                    : Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                viewModel.isDescending
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                color: AppTheme.accentLime,
                                size: 16,
                              ),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getSortText(viewModel.currentSort),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        viewModel.isDescending
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: AppTheme.accentLime,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  String _getSortText(SortOption option) {
    switch (option) {
      case SortOption.filename:
        return 'Name';
      case SortOption.dateModified:
        return 'Date modified';
      case SortOption.size:
        return 'Size';
      case SortOption.type:
        return 'Type';
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
              backgroundColor: const Color(0xFF16191E),
              title: Text(
                'New $typeName',
                style: const TextStyle(color: Colors.white),
              ),
              content: TextField(
                controller: _controller,
                autofocus: true,
                cursorColor: AppTheme.accentLime,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter $typeName name',
                  hintStyle: const TextStyle(color: Colors.white54),
                  errorText: errorMessage,
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4A525A)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.accentLime),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
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
                    style: TextStyle(
                      color: AppTheme.accentLime,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPasteNavBar(BuildContext context, AllFilesViewModel viewModel) {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF0E1114),
      selectedItemColor: AppTheme.accentLime,
      unselectedItemColor: const Color(0xFF78828A),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.close), label: 'Cancel'),
        BottomNavigationBarItem(icon: Icon(Icons.paste), label: 'Paste'),
      ],
      onTap: (index) async {
        if (index == 0) {
          viewModel.cancelPaste();
        } else if (index == 1) {
          // Show progress dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => PasteProgressDialog(viewModel: viewModel),
          );

          final error = await viewModel.pasteClipboard();

          // Close progress dialog
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          if (error != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  error,
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.red.shade800,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      },
    );
  }

  Widget _buildSelectionNavBar(
    BuildContext context,
    AllFilesViewModel viewModel,
  ) {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF0E1114),
      selectedItemColor: AppTheme.accentLime,
      unselectedItemColor: const Color(0xFF78828A),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.share), label: 'Share'),
        BottomNavigationBarItem(
          icon: Icon(Icons.bookmark_border),
          label: 'Tag',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.copy), label: 'Copy'),
        BottomNavigationBarItem(
          icon: Icon(Icons.delete_outline),
          label: 'Delete',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.more_vert), label: 'More'),
      ],
      onTap: (index) {
        if (index == 0) {
          _showShareSheet(context, viewModel);
        } else if (index == 1) {
          _showTagSelectionSheet(context, viewModel);
        } else if (index == 2) {
          viewModel.copySelected();
        } else if (index == 3) {
          _showDeleteConfirmationDialog(context, viewModel);
        } else if (index == 4) {
          _showMoreBottomSheet(context, viewModel);
        }
      },
    );
  }

  void _showShareSheet(BuildContext context, AllFilesViewModel viewModel) {
    showVortexShareSheet(
      context,
      viewModel.selectedPaths.toList(),
      onSendStarted: viewModel.toggleSelectionMode,
    );
  }

  void _showTagSelectionSheet(
    BuildContext context,
    AllFilesViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TagSelectionSheet(
        onTagSelected: (tagName) {
          viewModel.tagSelectedItems(tagName);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Items added to tag: $tagName')),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    AllFilesViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Delete Files?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to permanently delete ${viewModel.selectedPaths.length} item(s)? This action cannot be undone.',
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              viewModel.deleteSelectedFiles();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showMoreBottomSheet(BuildContext context, AllFilesViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Cut', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  viewModel.cutSelected();
                },
              ),
              const Divider(color: Colors.grey, height: 1),
              ListTile(
                title: const Text(
                  'Details',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDetailsDialog(context, viewModel);
                },
              ),
              const Divider(color: Colors.grey, height: 1),
              ListTile(
                title: const Text(
                  'Rename',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(context, viewModel);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, AllFilesViewModel viewModel) {
    if (viewModel.selectedPaths.length != 1) return;

    final currentName = viewModel.selectedPaths.first.split('/').last;
    final textController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16191E),
        title: const Text('Rename', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textController,
          autofocus: true,
          cursorColor: AppTheme.accentLime,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'New name',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF4A525A)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.accentLime),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newName = textController.text.trim();
              if (newName.isNotEmpty && newName != currentName) {
                Navigator.pop(ctx);
                final error = await viewModel.renameSelected(newName);
                if (error != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error), backgroundColor: Colors.red),
                  );
                }
              } else {
                Navigator.pop(ctx);
              }
            },
            child: const Text(
              'Ok',
              style: TextStyle(
                color: AppTheme.accentLime,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(
    BuildContext context,
    AllFilesViewModel viewModel,
  ) async {
    final details = await viewModel.getDetailsForSelected();
    if (details == null || !context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16191E),
        title: const Text('Details', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: details.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.key,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.value,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Ok',
              style: TextStyle(
                color: AppTheme.accentLime,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileListItem extends StatelessWidget {
  final FileItemModel item;
  final AllFilesViewModel viewModel;

  const _FileListItem({super.key, required this.item, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final dateStr = viewModel.formatDateString(item.modifiedDate);
    final countStr = item.isDirectory
        ? '${item.itemCount} item${item.itemCount == 1 ? '' : 's'}'
        : (item.categoryHint.isNotEmpty ? item.categoryHint : 'File');
    final subtitle = '$countStr · $dateStr';

    final isSelected = viewModel.selectedPaths.contains(item.path);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            if (viewModel.isSelectionMode ||
                (viewModel.isFolderPickerMode && item.isDirectory)) {
              viewModel.toggleSelection(item.path);
            } else if (item.isDirectory) {
              viewModel.navigateTo(item.path);
            } else {
              FileOpener.openFile(context, item.path);
            }
          },
          onLongPress: () {
            if (!viewModel.isSelectionMode) {
              viewModel.toggleSelectionMode();
              viewModel.toggleSelection(item.path);
            }
          },
          child: Container(
            color: isSelected ? Colors.white.withOpacity(0.06) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 13.0),
            child: Row(
              children: [
                _buildIcon(),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF78828A),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (viewModel.isSelectionMode ||
                    (viewModel.isFolderPickerMode && item.isDirectory))
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    color: isSelected ? AppTheme.accentLime : const Color(0xFF4A525A),
                    size: 22,
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF4A525A),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
        const Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFF14171B),
        ),
      ],
    );
  }

  Widget _buildIcon() {
    if (item.isDirectory) {
      final hasItems = item.itemCount > 0;
      final folderColor = hasItems ? AppTheme.accentLime : const Color(0xFF4A525A);
      return Icon(
        Icons.folder_rounded,
        color: folderColor,
        size: 34,
      );
    }

    return const Icon(
      Icons.insert_drive_file_rounded,
      color: Color(0xFF78828A),
      size: 30,
    );
  }
}

class _FileGridItem extends StatelessWidget {
  final FileItemModel item;
  final AllFilesViewModel viewModel;

  const _FileGridItem({super.key, required this.item, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final countStr = item.isDirectory
        ? '${item.itemCount} item${item.itemCount == 1 ? '' : 's'}'
        : (item.categoryHint.isNotEmpty ? item.categoryHint : 'File');

    final isSelected = viewModel.selectedPaths.contains(item.path);

    return InkWell(
      onTap: () {
        if (viewModel.isSelectionMode ||
            (viewModel.isFolderPickerMode && item.isDirectory)) {
          viewModel.toggleSelection(item.path);
        } else if (item.isDirectory) {
          viewModel.navigateTo(item.path);
        } else {
          FileOpener.openFile(context, item.path);
        }
      },
      onLongPress: () {
        if (!viewModel.isSelectionMode) {
          viewModel.toggleSelectionMode();
          viewModel.toggleSelection(item.path);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.06) : const Color(0xFF0E1114),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accentLime : const Color(0xFF1A1F26),
            width: isSelected ? 1.5 : 1,
          ),
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
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      countStr,
                      style: const TextStyle(
                        color: Color(0xFF78828A),
                        fontSize: 12,
                      ),
                    ),
                    if (viewModel.isSelectionMode) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? AppTheme.accentLime
                            : const Color(0xFF4A525A),
                        size: 16,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (viewModel.isFolderPickerMode && item.isDirectory)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: isSelected ? AppTheme.accentLime : const Color(0xFF4A525A),
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (item.isDirectory) {
      final hasItems = item.itemCount > 0;
      final folderColor = hasItems ? AppTheme.accentLime : const Color(0xFF4A525A);
      return Icon(Icons.folder_rounded, color: folderColor, size: 48);
    }

    return const Icon(
      Icons.insert_drive_file_rounded,
      color: Color(0xFF78828A),
      size: 44,
    );
  }
}

class PasteProgressDialog extends StatelessWidget {
  final AllFilesViewModel viewModel;

  const PasteProgressDialog({Key? key, required this.viewModel})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF16191E),
      title: const Text('Pasting Files', style: TextStyle(color: Colors.white)),
      content: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                viewModel.pasteStatus,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: viewModel.pasteProgress > 0
                    ? viewModel.pasteProgress
                    : null,
                backgroundColor: const Color(0xFF14171B),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.accentLime,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${(viewModel.pasteProgress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            viewModel.cancelOngoingPaste();
          },
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ],
    );
  }
}

