import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vortex/viewmodels/all_files_viewmodel.dart';
import 'package:vortex/models/file_item_model.dart';
import 'package:vortex/models/storage_volume_model.dart';
import 'package:vortex/theme/app_theme.dart';
import 'package:vortex/widgets/tag_selection_sheet.dart';
import 'package:vortex/utils/file_opener.dart';
import 'package:vortex/services/connection_manager.dart';
import 'package:vortex/services/discovery_service.dart';
import 'package:vortex/services/transfer_service.dart';

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
                      ),
                      icon: const Icon(Icons.check),
                      backgroundColor: AppTheme.accentBlue,
                    )
                  : null,
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
                        title: Text(
                          '${viewModel.selectedPaths.length} selected',
                        ),
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
                    : _searching
                    ? AppBar(
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back),
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
                          cursorColor: Colors.white,
                          cursorWidth: 2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Search in ${viewModel.currentFolderName}…',
                            hintStyle: const TextStyle(color: Colors.white38),
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
                                color: Colors.white54,
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
                        title: Text(viewModel.currentFolderName),
                        actions: [
                          if (viewModel.availableVolumes.length > 1)
                            PopupMenuButton<StorageVolume>(
                              icon: const Icon(
                                Icons.storage,
                                color: Colors.white,
                              ),
                              tooltip: 'Switch Storage',
                              color: AppTheme.cardGrey,
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
                                                ? AppTheme.accentBlue
                                                : Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            vol.name,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? AppTheme.accentBlue
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
                                              color: AppTheme.accentBlue,
                                              size: 16,
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }).toList(),
                            ),
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
                              if (value == 'new_folder')
                                _showCreateDialog(context, viewModel, true);
                              else if (value == 'add_files')
                                _showCreateDialog(context, viewModel, false);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () => setState(() => _searching = true),
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
                              if (value == 'grid_view')
                                viewModel.toggleGridView();
                              else if (value == 'edit')
                                viewModel.toggleSelectionMode();
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
                                    color: AppTheme.accentBlue,
                                  ),
                                )
                              else
                                Icon(
                                  Icons.search,
                                  size: 16,
                                  color: AppTheme.textGrey,
                                ),
                              const SizedBox(width: 8),
                              Text(
                                viewModel.isSearchLoading
                                    ? 'Searching…  ${results.length} found'
                                    : '${results.length} results for "${viewModel.searchQuery}"',
                                style: const TextStyle(
                                  color: AppTheme.textGrey,
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
                                    color: AppTheme.textGrey,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'No results for "${viewModel.searchQuery}"',
                                    style: const TextStyle(
                                      color: AppTheme.textGrey,
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
                        color: AppTheme.accentBlue,
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
                            color: AppTheme.textGrey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'This folder is empty',
                            style: TextStyle(
                              color: AppTheme.textGrey,
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
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                viewModel.displayPath,
                style: const TextStyle(
                  color: AppTheme.accentBlue,
                  fontSize: 14,
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

  Widget _buildPasteNavBar(BuildContext context, AllFilesViewModel viewModel) {
    return BottomNavigationBar(
      backgroundColor: AppTheme.cardGrey,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white,
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
    final connectionManager = context.read<ConnectionManager>();
    final discoveryService = context.read<DiscoveryService>();
    final transferService = context.read<TransferService>();
    final selectedPaths = viewModel.selectedPaths.toList();

    // Build IP map: ConnectionManager._deviceIps is primary; fall back to
    // DiscoveryService.discoveredServices for devices that reconnected after
    // a hot-restart (where the WebSocket IP cache was lost).
    final deviceNames = connectionManager.connectedDeviceNames;
    final ipMap = <String, String?>{};
    for (final name in deviceNames) {
      String? ip = connectionManager.getDeviceIp(name);
      if (ip == null) {
        // Fuzzy match by name prefix against recently discovered devices
        final match = discoveryService.discoveredServices
            .where((d) => d.name == name || name.startsWith(d.name))
            .firstOrNull;
        ip = match?.host;
      }
      ipMap[name] = ip;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ShareSheetContent(
        transferService: transferService,
        connectionManager: connectionManager,
        selectedPaths: selectedPaths,
        connectedDeviceNames: deviceNames,
        deviceIps: ipMap,
        onSendStarted: viewModel.toggleSelectionMode,
      ),
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
        backgroundColor: AppTheme.cardGrey,
        title: const Text(
          'Delete Files?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to permanently delete ${viewModel.selectedPaths.length} item(s)? This action cannot be undone.',
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
        backgroundColor: AppTheme.cardGrey,
        title: const Text('Rename', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'New name',
            hintStyle: TextStyle(color: AppTheme.textGrey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.textGrey),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.accentBlue),
            ),
          ),
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
              style: TextStyle(color: AppTheme.accentBlue),
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
        backgroundColor: AppTheme.cardGrey,
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
                        color: AppTheme.textGrey,
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
              style: TextStyle(color: AppTheme.accentBlue),
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
        : item.categoryHint; // Or file size later

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
            if (viewModel.isSelectionMode ||
                (viewModel.isFolderPickerMode && item.isDirectory))
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

  const _FileGridItem({super.key, required this.item, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final countStr = item.isDirectory
        ? '${item.itemCount} item${item.itemCount == 1 ? '' : 's'}'
        : item.categoryHint;

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      countStr,
                      style: const TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 12,
                      ),
                    ),
                    if (viewModel.isSelectionMode) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isSelected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: isSelected
                            ? AppTheme.accentBlue
                            : AppTheme.textGrey,
                        size: 18,
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
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: isSelected ? AppTheme.accentBlue : AppTheme.textGrey,
                  size: 20,
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

class PasteProgressDialog extends StatelessWidget {
  final AllFilesViewModel viewModel;

  const PasteProgressDialog({Key? key, required this.viewModel})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardGrey,
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
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: viewModel.pasteProgress > 0
                    ? viewModel.pasteProgress
                    : null,
                backgroundColor: Colors.black,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.accentBlue,
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
            style: TextStyle(color: AppTheme.textGrey),
          ),
        ),
      ],
    );
  }
}
// ─── Share sheet ──────────────────────────────────────────────────────────────

class _ShareSheetContent extends StatefulWidget {
  final TransferService transferService;
  final ConnectionManager connectionManager;
  final List<String> selectedPaths;
  final List<String> connectedDeviceNames;
  final Map<String, String?> deviceIps; // name → ip (null = unknown)
  final VoidCallback onSendStarted;

  const _ShareSheetContent({
    required this.transferService,
    required this.connectionManager,
    required this.selectedPaths,
    required this.connectedDeviceNames,
    required this.deviceIps,
    required this.onSendStarted,
  });

  @override
  State<_ShareSheetContent> createState() => _ShareSheetContentState();
}

class _ShareSheetContentState extends State<_ShareSheetContent> {
  final Set<String> _selectedDevices = {};
  bool _sendToAll = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Pre-select all connected devices
    _selectedDevices.addAll(widget.connectedDeviceNames);
    _sendToAll = _selectedDevices.isNotEmpty &&
        _selectedDevices.length == widget.connectedDeviceNames.length;
  }

  @override
  Widget build(BuildContext context) {
    final devices = widget.connectedDeviceNames;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title row
              Row(
                children: [
                  const Icon(
                    Icons.send,
                    color: AppTheme.accentBlue,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Send via Vortex',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.selectedPaths.length} item${widget.selectedPaths.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (devices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: const [
                        Icon(
                          Icons.devices_other,
                          color: AppTheme.textGrey,
                          size: 52,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'No connected devices',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Pair with another device first using the\nLink button on the home screen.',
                          style: TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // "Send to all" row
                _DeviceRow(
                  icon: Icons.all_inclusive,
                  title: 'Send to all devices',
                  subtitle: '${devices.length} device${devices.length == 1 ? '' : 's'}',
                  isSelected: _sendToAll,
                  onTap: () => setState(() {
                    _sendToAll = !_sendToAll;
                    if (_sendToAll) {
                      _selectedDevices.addAll(devices);
                    } else {
                      _selectedDevices.clear();
                    }
                  }),
                ),
                const SizedBox(height: 6),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 6),

                // Individual device rows
                ...devices.map(
                  (name) {
                    final ip = widget.deviceIps[name];
                    final isSelected = _selectedDevices.contains(name);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _DeviceRow(
                        icon: Icons.laptop,
                        title: name,
                        subtitle: ip ?? 'IP unknown',
                        isSelected: isSelected,
                        onTap: () => setState(() {
                          if (isSelected) {
                            _selectedDevices.remove(name);
                            _sendToAll = false;
                          } else {
                            _selectedDevices.add(name);
                            _sendToAll =
                                _selectedDevices.length == devices.length;
                          }
                        }),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Send button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isSending || _selectedDevices.isEmpty
                            ? null
                            : () => _startSending(context),
                    icon:
                        _isSending
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.send, size: 18),
                    label: Text(
                      _isSending
                          ? 'Sending…'
                          : 'Send to ${_selectedDevices.length} device${_selectedDevices.length == 1 ? '' : 's'}',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.white12,
                      disabledForegroundColor: Colors.white38,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startSending(BuildContext context) async {
    setState(() => _isSending = true);

    final targets =
        _selectedDevices
            .map((name) {
              final ip = widget.deviceIps[name];
              if (ip == null) return null;
              return (
                name: name,
                ip: ip,
                port: ConnectionManager.serverFixedPort,
              );
            })
            .whereType<({String name, String ip, int port})>()
            .toList();

    if (targets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not resolve IP for selected devices. Re-pair and try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isSending = false);
      return;
    }

    // Close sheet and exit selection mode
    if (mounted) Navigator.pop(context);
    widget.onSendStarted();

    // Show transfer progress dialog
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _TransferProgressDialog(transferService: widget.transferService),
      );
    }

    // Send (blocks until all jobs complete)
    await widget.transferService.sendToDevices(
      selectedPaths: widget.selectedPaths,
      targets: targets,
      connectionManager: widget.connectionManager,
    );
  }
}

// ─── Reusable device row tile ─────────────────────────────────────────────────

class _DeviceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeviceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentBlue.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.accentBlue : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withOpacity(
                  isSelected ? 0.25 : 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.accentBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? AppTheme.accentBlue : AppTheme.textGrey,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Transfer progress dialog ─────────────────────────────────────────────────

String _fmtChannelSpeed(double bps) {
  if (bps >= 1024 * 1024) return '${(bps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  if (bps >= 1024) return '${(bps / 1024).toStringAsFixed(1)} KB/s';
  return '${bps.toStringAsFixed(0)} B/s';
}

class _TransferProgressDialog extends StatefulWidget {
  final TransferService transferService;

  const _TransferProgressDialog({required this.transferService});

  @override
  State<_TransferProgressDialog> createState() =>
      _TransferProgressDialogState();
}

class _TransferProgressDialogState extends State<_TransferProgressDialog> {
  bool _done = false; // true once all jobs complete, shows OK screen

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent back-swipe from dismissing mid-transfer
      canPop: _done,
      child: AlertDialog(
        backgroundColor: AppTheme.cardGrey,
        title: Text(
          _done ? 'On Its Way!' : 'Transferring…',
          style: const TextStyle(color: Colors.white),
        ),
        content: ListenableBuilder(
          listenable: widget.transferService,
          builder: (context, _) {
            final job = widget.transferService.activeJob;

            // ── Switch to done as soon as 100% bytes are sent ─────────────
            // (ACK / disk-flush on receiver side happens in the background)
            final allBytesSent = job == null || job.progress >= 1.0;
            if (allBytesSent && !_done) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _done = true);
                widget.transferService.dismissCompleted();
              });
            }

            if (_done || job == null || job.progress >= 1.0) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.send_rounded,
                      color: Colors.blueAccent,
                      size: 28,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Your file has been sent.\nIt will be saved on the receiver\'s device shortly.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // ── In progress ───────────────────────────────────────────────
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To: ${job.deviceName}',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  job.statusText,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!job.isComplete && !job.cancelled) ...[
                  const SizedBox(height: 4),
                  Text(
                    job.speedText,
                    style: const TextStyle(
                      color: AppTheme.accentBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Per-channel speed breakdown for multi-channel transfers
                  if (job.isMultiChannel && job.perChannelStats.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ...job.perChannelStats.map(
                      (ch) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cable_rounded,
                              size: 12,
                              color: Colors.white38,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${ch.name}: ${_fmtChannelSpeed(ch.sendSpeed)}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: job.progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.black,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.accentBlue,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(job.progress * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          ListenableBuilder(
            listenable: widget.transferService,
            builder: (context, _) {
              if (_done || widget.transferService.activeJob == null ||
                  (widget.transferService.activeJob?.progress ?? 0) >= 1.0) {
                // ── Done: show OK ────────────────────────────────────────
                return TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: AppTheme.accentBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
              // ── In-progress: show Cancel ─────────────────────────────
              return TextButton(
                onPressed: () {
                  final job = widget.transferService.activeJob;
                  if (job != null) widget.transferService.cancelJob(job.id);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.textGrey),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}