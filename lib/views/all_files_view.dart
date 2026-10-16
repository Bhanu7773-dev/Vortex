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
  final bool isFilePickerMode;
  const AllFilesView({
    Key? key,
    this.initialPath,
    this.isFolderPickerMode = false,
    this.isFilePickerMode = false,
  }) : super(key: key);
  @override
  State<AllFilesView> createState() => _AllFilesViewState();
}

class _AllFilesViewState extends State<AllFilesView> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searching = false;
  Timer? _debounce;

  final GlobalKey _addBtnKey = GlobalKey();
  final GlobalKey _moreBtnKey = GlobalKey();
  bool _isAddMenuOpen = false;
  bool _isMoreMenuOpen = false;

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
        isFilePickerMode: widget.isFilePickerMode,
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
              floatingActionButton: viewModel.isFilePickerMode
                  ? FloatingActionButton.extended(
                      onPressed: viewModel.selectedPaths.isEmpty
                          ? null
                          : () {
                              Navigator.pop(
                                context,
                                viewModel.selectedPaths.toList(),
                              );
                            },
                      label: Text(
                        viewModel.selectedPaths.isEmpty
                            ? 'Select files'
                            : 'Add ${viewModel.selectedPaths.length} file${viewModel.selectedPaths.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: viewModel.selectedPaths.isEmpty
                              ? const Color(0xFF78828A)
                              : Colors.black,
                          fontWeight: FontWeight.w700,
                          fontFamily: AppTheme.fontInstrument,
                        ),
                      ),
                      icon: Icon(
                        Icons.check_rounded,
                        color: viewModel.selectedPaths.isEmpty
                            ? const Color(0xFF78828A)
                            : Colors.black,
                        size: 22,
                      ),
                      backgroundColor: viewModel.selectedPaths.isEmpty
                          ? const Color(0xFF1E2220)
                          : AppTheme.accentLime,
                    )
                  : (viewModel.isFolderPickerMode
                      ? FloatingActionButton.extended(
                          onPressed: () {
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
                      : null),
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: viewModel.isFilePickerMode
                    ? AppBar(
                        backgroundColor: Colors.black,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        leading: IconButton(
                          icon: Icon(
                            viewModel.pathHistory.isNotEmpty
                                ? Icons.arrow_back
                                : Icons.close_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            if (viewModel.pathHistory.isNotEmpty) {
                              viewModel.goBack();
                            } else {
                              Navigator.pop(context);
                            }
                          },
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              viewModel.selectedPaths.isEmpty
                                  ? (viewModel.currentPath == viewModel.rootPath
                                      ? 'Internal storage'
                                      : viewModel.currentFolderName)
                                  : '${viewModel.selectedPaths.length} selected',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontBricolage,
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              viewModel.selectedPaths.isEmpty
                                  ? 'Tap files to select'
                                  : 'Tap tick button when done',
                              style: const TextStyle(
                                color: Color(0xFF78828A),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          if (viewModel.selectedPaths.isNotEmpty)
                            TextButton(
                              onPressed: () => viewModel.clearSelection(),
                              child: const Text(
                                'Clear',
                                style: TextStyle(
                                  color: Color(0xFF78828A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          TextButton(
                            onPressed: () => viewModel.selectAllFiles(),
                            child: const Text(
                              'Select all',
                              style: TextStyle(
                                color: AppTheme.accentLime,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      )
                    : viewModel.isSelectionMode
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
                            setState(() {});
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
                            fontFamily: AppTheme.fontBricolage,
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: GestureDetector(
                              key: _addBtnKey,
                              onTap: () => _openAddMenu(context, viewModel),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _isAddMenuOpen
                                      ? const Color(0xFF1E2320)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.add,
                                  color: _isAddMenuOpen
                                      ? AppTheme.accentLime
                                      : Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.search,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: () => setState(() => _searching = true),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 2, right: 6),
                            child: GestureDetector(
                              key: _moreBtnKey,
                              onTap: () => _openMoreMenu(context, viewModel),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _isMoreMenuOpen
                                      ? const Color(0xFF1E2320)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.more_vert,
                                  color: _isMoreMenuOpen
                                      ? AppTheme.accentLime
                                      : Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              bottomNavigationBar: viewModel.isPasteMode
                  ? _buildPasteNavBar(context, viewModel)
                  : (viewModel.isFilePickerMode
                      ? null
                      : (viewModel.isSelectionMode
                          ? _buildSelectionNavBar(context, viewModel)
                          : null)),
              body: Builder(
                builder: (context) {
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
                              padding: EdgeInsets.fromLTRB(
                                16.0,
                                0,
                                16.0,
                                viewModel.isSelectionMode ||
                                        viewModel.isPasteMode
                                    ? 96.0
                                    : 24.0,
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
                          : SliverPadding(
                              padding: EdgeInsets.only(
                                bottom: viewModel.isSelectionMode ||
                                        viewModel.isPasteMode
                                    ? 96.0
                                    : 24.0,
                              ),
                              sliver: SliverList(
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
                                            .ms,
                                      );
                                }, childCount: viewModel.items.length),
                              ),
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

  void _openAddMenu(BuildContext context, AllFilesViewModel viewModel) {
    setState(() => _isAddMenuOpen = true);
    final renderBox =
        _addBtnKey.currentContext?.findRenderObject() as RenderBox?;
    final offset =
        renderBox?.localToGlobal(Offset.zero) ?? const Offset(200, 80);
    final size = renderBox?.size ?? const Size(38, 38);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AddMenu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
          children: [
            Positioned(
              top: offset.dy + size.height + 6,
              right: MediaQuery.of(context).size.width - offset.dx - size.width,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161917),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF262A28),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.65),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAddMenuItem(
                        icon: Icons.create_new_folder_outlined,
                        label: 'New folder',
                        onTap: () {
                          Navigator.pop(ctx);
                          _showCreateDialog(context, viewModel, true);
                        },
                      ),
                      _buildAddMenuItem(
                        icon: Icons.note_add_outlined,
                        label: 'Add files',
                        onTap: () {
                          Navigator.pop(ctx);
                          _showCreateDialog(context, viewModel, false);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    ).then((_) {
      if (mounted) setState(() => _isAddMenuOpen = false);
    });
  }

  Widget _buildAddMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accentLime, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMoreMenu(BuildContext context, AllFilesViewModel viewModel) {
    setState(() => _isMoreMenuOpen = true);
    final renderBox =
        _moreBtnKey.currentContext?.findRenderObject() as RenderBox?;
    final offset =
        renderBox?.localToGlobal(Offset.zero) ?? const Offset(250, 80);
    final size = renderBox?.size ?? const Size(38, 38);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'MoreMenu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
          children: [
            Positioned(
              top: offset.dy + size.height + 6,
              right: 14,
              child: Material(
                color: Colors.transparent,
                child: StatefulBuilder(
                  builder: (context, setMenuState) {
                    final isGrid = viewModel.isGridView;
                    return Container(
                      width: 205,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161917),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF262A28),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.65),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 10),
                            child: Text(
                              'VIEW',
                              style: TextStyle(
                                color: Color(0xFF78828A),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1210),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF222624),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (isGrid) {
                                        viewModel.toggleGridView();
                                        setMenuState(() {});
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: !isGrid
                                            ? AppTheme.accentLime
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.menu_rounded,
                                            size: 18,
                                            color: !isGrid
                                                ? Colors.black
                                                : const Color(0xFF78828A),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'List',
                                            style: TextStyle(
                                              color: !isGrid
                                                  ? Colors.black
                                                  : const Color(0xFF78828A),
                                              fontSize: 13,
                                              fontWeight: !isGrid
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (!isGrid) {
                                        viewModel.toggleGridView();
                                        setMenuState(() {});
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isGrid
                                            ? AppTheme.accentLime
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.grid_view_rounded,
                                            size: 18,
                                            color: isGrid
                                                ? Colors.black
                                                : const Color(0xFF78828A),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Grid',
                                            style: TextStyle(
                                              color: isGrid
                                                  ? Colors.black
                                                  : const Color(0xFF78828A),
                                              fontSize: 13,
                                              fontWeight: isGrid
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(
                              color: Color(0xFF262A28),
                              height: 1,
                              thickness: 1,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              viewModel.toggleSelectionMode();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 8,
                              ),
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.edit_outlined,
                                    color: AppTheme.accentLime,
                                    size: 20,
                                  ),
                                  SizedBox(width: 14),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    ).then((_) {
      if (mounted) setState(() => _isMoreMenuOpen = false);
    });
  }

  void _showCreateDialog(
    BuildContext context,
    AllFilesViewModel viewModel,
    bool isFolder,
  ) {
    final TextEditingController controller = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161917),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFF262A28), width: 1),
              ),
              titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 22),
              actionsPadding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
              title: Row(
                children: [
                  Icon(
                    isFolder
                        ? Icons.create_new_folder_outlined
                        : Icons.note_add_outlined,
                    color: AppTheme.accentLime,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isFolder ? 'New folder' : 'New file',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1210),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: errorMessage != null
                            ? Colors.red
                            : const Color(0xFF262A28),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      cursorColor: AppTheme.accentLime,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: isFolder ? 'Folder name' : 'file.txt',
                        hintStyle: const TextStyle(
                          color: Color(0xFF78828A),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFFF5252),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF78828A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      if (isFolder) {
                        viewModel.createNewFolder(name);
                        Navigator.pop(context);
                      } else {
                        if (!name.contains('.')) {
                          setDialogState(() {
                            errorMessage =
                                'File must have an extension (e.g. .txt)';
                          });
                        } else {
                          viewModel.createNewFile(name);
                          Navigator.pop(context);
                        }
                      }
                    } else {
                      setDialogState(() {
                        errorMessage = 'Name cannot be empty';
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentLime,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Create',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          height: 68,
          padding: const EdgeInsets.all(5.0),
          decoration: BoxDecoration(
            color: const Color(0xFF141715),
            borderRadius: BorderRadius.circular(38),
            border: Border.all(color: const Color(0xFF262A28), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.65),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => viewModel.cancelPaste(),
                borderRadius: BorderRadius.circular(32),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Cancel',
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
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) =>
                          PasteProgressDialog(viewModel: viewModel),
                    );
                    final error = await viewModel.pasteClipboard();
                    if (context.mounted && Navigator.canPop(context)) {
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
                  },
                  child: Container(
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.accentLime,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.assignment_outlined,
                          color: Colors.black,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Paste here',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionNavBar(
    BuildContext context,
    AllFilesViewModel viewModel,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            color: const Color(0xFF141715),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFF262A28), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.65),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSelectionBarItem(
                icon: Icons.share_outlined,
                label: 'Share',
                color: AppTheme.accentLime,
                onTap: () => _showShareSheet(context, viewModel),
              ),
              _buildSelectionBarItem(
                icon: Icons.bookmark_border_rounded,
                label: 'Tag',
                color: Colors.white,
                onTap: () => _showTagSelectionSheet(context, viewModel),
              ),
              _buildSelectionBarItem(
                icon: Icons.copy_rounded,
                label: 'Copy',
                color: Colors.white,
                onTap: () => viewModel.copySelected(),
              ),
              _buildSelectionBarItem(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: const Color(0xFFFF5252),
                onTap: () => _showDeleteConfirmationDialog(context, viewModel),
              ),
              _buildSelectionBarItem(
                icon: Icons.more_vert_rounded,
                label: 'More',
                color: Colors.white,
                onTap: () => _showMoreBottomSheet(context, viewModel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionBarItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
        backgroundColor: const Color(0xFF161917),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF262A28), width: 1),
        ),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 22),
        actionsPadding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
        title: Row(
          children: const [
            Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFFF5252),
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              'Delete permanently?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete ${viewModel.selectedPaths.length} item(s)? This action cannot be undone.',
          style: const TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF78828A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              viewModel.deleteSelectedFiles();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreBottomSheet(BuildContext context, AllFilesViewModel viewModel) {
    final count = viewModel.selectedPaths.length;
    String title = 'Selected';
    String subtitle = '$count selected';

    if (count == 1) {
      final firstPath = viewModel.selectedPaths.first;
      final item = viewModel.items.cast<FileItemModel?>().firstWhere(
        (element) => element?.path == firstPath,
        orElse: () => null,
      );
      title = firstPath.split('/').last;
      if (item != null) {
        if (item.isDirectory) {
          subtitle = '1 selected · ${item.itemCount} items';
        } else {
          subtitle =
              '1 selected · ${item.categoryHint.isNotEmpty ? item.categoryHint : 'File'}';
        }
      } else {
        subtitle = '1 selected';
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: const BoxDecoration(
            color: Color(0xFF141715),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFF262A28), width: 1),
              left: BorderSide(color: Color(0xFF262A28), width: 1),
              right: BorderSide(color: Color(0xFF262A28), width: 1),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3F3D),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontBricolage,
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF78828A),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionSquircleCard(
                        icon: Icons.content_cut_rounded,
                        label: 'Cut',
                        onTap: () {
                          Navigator.pop(context);
                          viewModel.cutSelected();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionSquircleCard(
                        icon: Icons.info_outline_rounded,
                        label: 'Details',
                        onTap: () {
                          Navigator.pop(context);
                          _showDetailsDialog(context, viewModel);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionSquircleCard(
                        icon: Icons.edit_outlined,
                        label: 'Rename',
                        onTap: () {
                          Navigator.pop(context);
                          _showRenameDialog(context, viewModel);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionSquircleCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1F1D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF262A28), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.accentLime, size: 24),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, AllFilesViewModel viewModel) {
    if (viewModel.selectedPaths.length != 1) return;

    final currentName = viewModel.selectedPaths.first.split('/').last;
    final textController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161917),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF262A28), width: 1),
        ),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 22),
        actionsPadding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
        title: Row(
          children: const [
            Icon(Icons.edit_outlined, color: AppTheme.accentLime, size: 24),
            SizedBox(width: 12),
            Text(
              'Rename',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1210),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF262A28), width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: textController,
            autofocus: true,
            cursorColor: AppTheme.accentLime,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              hintText: 'New name',
              hintStyle: TextStyle(color: Color(0xFF78828A), fontSize: 14),
              border: InputBorder.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF78828A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.accentLime,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
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

    final name = details['Name'] ?? 'Details';
    final isFolder = details['Type'] == 'Folder';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF141715),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFF262A28), width: 1),
              left: BorderSide(color: Color(0xFF262A28), width: 1),
              right: BorderSide(color: Color(0xFF262A28), width: 1),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3F3D),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2220),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isFolder
                            ? Icons.folder_rounded
                            : Icons.insert_drive_file_rounded,
                        color: const Color(0xFF78828A),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DETAILS',
                            style: TextStyle(
                              color: Color(0xFF78828A),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            name,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontBricolage,
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(
                  color: Color(0xFF222624),
                  height: 1,
                  thickness: 1,
                ),
                const SizedBox(height: 12),
                if (details.containsKey('Path'))
                  _buildDetailRow('Path', details['Path']!),
                if (details.containsKey('Modified'))
                  _buildDetailRow('Modified', details['Modified']!),
                if (details.containsKey('Type'))
                  _buildDetailRow('Type', details['Type']!),
                if (details.containsKey('Items inside'))
                  _buildDetailRow('Items inside', details['Items inside']!)
                else if (details.containsKey('Size'))
                  _buildDetailRow('Size', details['Size']!),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentLime,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF78828A),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
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
            if (viewModel.isFilePickerMode) {
              if (item.isDirectory) {
                viewModel.navigateTo(item.path);
              } else {
                viewModel.toggleSelection(item.path);
              }
            } else if (viewModel.isSelectionMode ||
                (viewModel.isFolderPickerMode && item.isDirectory)) {
              viewModel.toggleSelection(item.path);
            } else if (item.isDirectory) {
              viewModel.navigateTo(item.path);
            } else {
              FileOpener.openFile(context, item.path);
            }
          },
          onLongPress: () {
            if (!viewModel.isFilePickerMode && !viewModel.isSelectionMode) {
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
                if (viewModel.isFilePickerMode)
                  if (item.isDirectory)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF4A525A),
                      size: 20,
                    )
                  else
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? AppTheme.accentLime
                          : const Color(0xFF4A525A),
                      size: 22,
                    )
                else if (viewModel.isSelectionMode ||
                    (viewModel.isFolderPickerMode && item.isDirectory))
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? AppTheme.accentLime
                        : const Color(0xFF4A525A),
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
        if (viewModel.isFilePickerMode) {
          if (item.isDirectory) {
            viewModel.navigateTo(item.path);
          } else {
            viewModel.toggleSelection(item.path);
          }
        } else if (viewModel.isSelectionMode ||
            (viewModel.isFolderPickerMode && item.isDirectory)) {
          viewModel.toggleSelection(item.path);
        } else if (item.isDirectory) {
          viewModel.navigateTo(item.path);
        } else {
          FileOpener.openFile(context, item.path);
        }
      },
      onLongPress: () {
        if (!viewModel.isFilePickerMode && !viewModel.isSelectionMode) {
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
                    if (viewModel.isSelectionMode ||
                        (viewModel.isFilePickerMode && !item.isDirectory)) ...[
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
            if (viewModel.isFilePickerMode && !item.isDirectory)
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
      backgroundColor: const Color(0xFF161917),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF262A28), width: 1),
      ),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 22),
      actionsPadding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
      title: Row(
        children: const [
          Icon(Icons.content_paste_rounded, color: AppTheme.accentLime, size: 24),
          SizedBox(width: 12),
          Text(
            'Pasting files',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      content: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                viewModel.pasteStatus,
                style: const TextStyle(color: Color(0xFF78828A), fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: viewModel.pasteProgress > 0
                      ? viewModel.pasteProgress
                      : null,
                  backgroundColor: const Color(0xFF0F1210),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.accentLime,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${(viewModel.pasteProgress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
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
            style: TextStyle(
              color: Color(0xFF78828A),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
