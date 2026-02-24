import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodels/media_viewmodels.dart';
import '../theme/app_theme.dart';
import '../utils/file_opener.dart';

// ══════════════════════════════════════════════
//  AUDIO VIEW
// ══════════════════════════════════════════════
class AudioView extends StatefulWidget {
  const AudioView({Key? key}) : super(key: key);
  @override
  State<AudioView> createState() => _AudioViewState();
}

class _AudioViewState extends State<AudioView> {
  static const _exts = {
    'mp3',
    'wav',
    'flac',
    'aac',
    'ogg',
    'm4a',
    'wma',
    'opus',
  };
  static const _filters = ['All', 'MP3', 'OPUS', 'WAV', 'M4A', 'FLAC', 'AAC'];
  final _searchFocus = FocusNode();
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MediaListViewModel(_exts),
      child: Consumer<MediaListViewModel>(
        builder: (context, vm, _) => Scaffold(
          backgroundColor: AppTheme.backgroundBlack,
          appBar: _buildAppBar(context, vm),
          body: vm.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentBlue),
                )
              : Column(
                  children: [
                    _FilterBar(
                      filters: _filters,
                      active: vm.activeFilter,
                      onSelect: vm.applyFilter,
                    ),
                    _StatsRow(
                      count: vm.filteredItems.length,
                      label: 'items in total',
                    ),
                    vm.filteredItems.isEmpty
                        ? Expanded(
                            child: _EmptyState(
                              icon: Icons.music_off,
                              label: _searching && _searchCtrl.text.isNotEmpty
                                  ? 'No results for "${_searchCtrl.text}"'
                                  : 'No audio files',
                            ),
                          )
                        : Expanded(
                            child: _FileList(
                              items: vm.filteredItems,
                              selectedPaths: vm.selectedPaths,
                              isSelectionMode: vm.isSelectionMode,
                              onTap: (path) {
                                if (vm.isSelectionMode) {
                                  vm.toggleSelection(path);
                                } else {
                                  FileOpener.openFile(context, path);
                                }
                              },
                              onLongPress: (path) {
                                HapticFeedback.mediumImpact();
                                if (!vm.isSelectionMode)
                                  vm.enterSelectionWith(path);
                                else
                                  vm.toggleSelection(path);
                              },
                              iconBuilder: (item) => _Icon(
                                color: Colors.red,
                                bg: Colors.red.withOpacity(0.12),
                                icon: Icons.music_note,
                              ),
                            ),
                          ),
                    if (vm.isSelectionMode)
                      _BottomActionBar(
                        onShare: () {},
                        onDelete: vm.selectedPaths.isEmpty
                            ? null
                            : () => _showDeleteDialog(
                                context,
                                vm.selectedPaths.length,
                                vm.deleteSelected,
                              ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    MediaListViewModel vm,
  ) {
    if (vm.isSelectionMode) {
      return AppBar(
        backgroundColor: AppTheme.cardGrey,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: vm.cancelSelection,
        ),
        title: Text(
          '${vm.selectedPaths.length} selected',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: vm.selectAll,
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
    }
    if (_searching) {
      return AppBar(
        backgroundColor: AppTheme.backgroundBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() => _searching = false);
            _searchCtrl.clear();
            vm.applySearch('');
          },
        ),
        title: TextField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          autofocus: true,
          cursorColor: Colors.white,
          cursorWidth: 2,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Search audio…',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
          ),
          onChanged: vm.applySearch,
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () {
                _searchCtrl.clear();
                vm.applySearch('');
                setState(() {});
              },
            ),
        ],
      );
    }
    return AppBar(
      backgroundColor: AppTheme.backgroundBlack,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Audio',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () => setState(() => _searching = true),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════
//  ARCHIVES VIEW
// ══════════════════════════════════════════════
class ArchivesView extends StatefulWidget {
  const ArchivesView({Key? key}) : super(key: key);
  @override
  State<ArchivesView> createState() => _ArchivesViewState();
}

class _ArchivesViewState extends State<ArchivesView> {
  static const _exts = {
    'zip',
    'rar',
    '7z',
    'tar',
    'gz',
    'bz2',
    'xz',
    'jar',
    'iso',
  };
  static const _filters = ['All', 'ZIP', 'RAR', '7Z', 'TAR', 'JAR'];
  static const Map<String, Color> _colors = {
    'zip': Color(0xFFD4A046),
    '7z': Color(0xFF6B8CFF),
    'rar': Color(0xFF9C7BD6),
    'tar': Color(0xFFE87040),
    'gz': Color(0xFFE87040),
    'jar': Color(0xFF4CAF50),
  };
  final _searchFocus = FocusNode();
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MediaListViewModel(_exts),
      child: Consumer<MediaListViewModel>(
        builder: (context, vm, _) => Scaffold(
          backgroundColor: AppTheme.backgroundBlack,
          appBar: _buildAppBar(context, vm),
          body: vm.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentBlue),
                )
              : Column(
                  children: [
                    _FilterBar(
                      filters: _filters,
                      active: vm.activeFilter,
                      onSelect: vm.applyFilter,
                    ),
                    _StatsRow(
                      count: vm.filteredItems.length,
                      label: 'items in total',
                    ),
                    vm.filteredItems.isEmpty
                        ? Expanded(
                            child: _EmptyState(
                              icon: Icons.inventory_2_outlined,
                              label: _searching && _searchCtrl.text.isNotEmpty
                                  ? 'No results for "${_searchCtrl.text}"'
                                  : 'No archives found',
                            ),
                          )
                        : Expanded(
                            child: _FileList(
                              items: vm.filteredItems,
                              selectedPaths: vm.selectedPaths,
                              isSelectionMode: vm.isSelectionMode,
                              onTap: (path) {
                                if (vm.isSelectionMode) {
                                  vm.toggleSelection(path);
                                } else {
                                  FileOpener.openFile(context, path);
                                }
                              },
                              onLongPress: (path) {
                                HapticFeedback.mediumImpact();
                                if (!vm.isSelectionMode)
                                  vm.enterSelectionWith(path);
                                else
                                  vm.toggleSelection(path);
                              },
                              subtitleMaxLines: 2,
                              iconBuilder: (item) {
                                final c =
                                    _colors[item.ext] ?? AppTheme.textGrey;
                                return _ArchiveIcon(ext: item.ext, color: c);
                              },
                            ),
                          ),
                    if (vm.isSelectionMode)
                      _BottomActionBar(
                        onShare: () {},
                        onDelete: vm.selectedPaths.isEmpty
                            ? null
                            : () => _showDeleteDialog(
                                context,
                                vm.selectedPaths.length,
                                vm.deleteSelected,
                              ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    MediaListViewModel vm,
  ) {
    if (vm.isSelectionMode) {
      return AppBar(
        backgroundColor: AppTheme.cardGrey,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: vm.cancelSelection,
        ),
        title: Text(
          '${vm.selectedPaths.length} selected',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: vm.selectAll,
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
    }
    if (_searching) {
      return AppBar(
        backgroundColor: AppTheme.backgroundBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() => _searching = false);
            _searchCtrl.clear();
            vm.applySearch('');
          },
        ),
        title: TextField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          autofocus: true,
          cursorColor: Colors.white,
          cursorWidth: 2,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Search archives…',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
          ),
          onChanged: vm.applySearch,
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () {
                _searchCtrl.clear();
                vm.applySearch('');
                setState(() {});
              },
            ),
        ],
      );
    }
    return AppBar(
      backgroundColor: AppTheme.backgroundBlack,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Archives',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () => setState(() => _searching = true),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════
//  APKs VIEW
// ══════════════════════════════════════════════
class ApksView extends StatefulWidget {
  const ApksView({Key? key}) : super(key: key);
  @override
  State<ApksView> createState() => _ApksViewState();
}

class _ApksViewState extends State<ApksView> {
  static const _exts = {'apk', 'aab', 'xapk'};
  final _searchFocus = FocusNode();
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MediaListViewModel(_exts),
      child: Consumer<MediaListViewModel>(
        builder: (context, vm, _) => Scaffold(
          backgroundColor: AppTheme.backgroundBlack,
          appBar: _buildAppBar(context, vm),
          body: vm.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentBlue),
                )
              : Column(
                  children: [
                    _StatsRow(
                      count: vm.filteredItems.length,
                      label: 'APK files',
                    ),
                    vm.filteredItems.isEmpty
                        ? Expanded(
                            child: _EmptyState(
                              icon: Icons.android,
                              label: _searching && _searchCtrl.text.isNotEmpty
                                  ? 'No results for "${_searchCtrl.text}"'
                                  : 'No APK files',
                            ),
                          )
                        : Expanded(
                            child: _FileList(
                              items: vm.filteredItems,
                              selectedPaths: vm.selectedPaths,
                              isSelectionMode: vm.isSelectionMode,
                              onTap: (path) {
                                if (vm.isSelectionMode) {
                                  vm.toggleSelection(path);
                                } else {
                                  FileOpener.openFile(context, path);
                                }
                              },
                              onLongPress: (path) {
                                HapticFeedback.mediumImpact();
                                if (!vm.isSelectionMode)
                                  vm.enterSelectionWith(path);
                                else
                                  vm.toggleSelection(path);
                              },
                              iconBuilder: (_) => _Icon(
                                color: Colors.green,
                                bg: Colors.green.withOpacity(0.12),
                                icon: Icons.android,
                                size: 28,
                                radius: 10,
                              ),
                              trailingBuilder: (item, selected) =>
                                  vm.isSelectionMode
                                  ? null
                                  : Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.green.withOpacity(0.4),
                                        ),
                                      ),
                                      child: const Text(
                                        'INSTALL',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                    if (vm.isSelectionMode)
                      _BottomActionBar(
                        onShare: () {},
                        onDelete: vm.selectedPaths.isEmpty
                            ? null
                            : () => _showDeleteDialog(
                                context,
                                vm.selectedPaths.length,
                                vm.deleteSelected,
                              ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    MediaListViewModel vm,
  ) {
    if (vm.isSelectionMode) {
      return AppBar(
        backgroundColor: AppTheme.cardGrey,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: vm.cancelSelection,
        ),
        title: Text(
          '${vm.selectedPaths.length} selected',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: vm.selectAll,
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
    }
    if (_searching) {
      return AppBar(
        backgroundColor: AppTheme.backgroundBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() => _searching = false);
            _searchCtrl.clear();
            vm.applySearch('');
          },
        ),
        title: TextField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          autofocus: true,
          cursorColor: Colors.white,
          cursorWidth: 2,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Search APKs…',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
          ),
          onChanged: vm.applySearch,
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () {
                _searchCtrl.clear();
                vm.applySearch('');
                setState(() {});
              },
            ),
        ],
      );
    }
    return AppBar(
      backgroundColor: AppTheme.backgroundBlack,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'APKs',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () => setState(() => _searching = true),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════
//  DOCUMENTS VIEW
// ══════════════════════════════════════════════
class DocumentsView extends StatefulWidget {
  const DocumentsView({Key? key}) : super(key: key);
  @override
  State<DocumentsView> createState() => _DocumentsViewState();
}

class _DocumentsViewState extends State<DocumentsView> {
  static const _exts = {
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'rtf',
    'odt',
    'ofd',
    'csv',
  };
  static const _filters = ['All', 'PDF', 'DOC', 'XLS', 'PPT', 'TXT'];
  static const Map<String, Color> _colors = {
    'pdf': Colors.red,
    'doc': Color(0xFF2B5EBE),
    'docx': Color(0xFF2B5EBE),
    'xls': Color(0xFF1E7145),
    'xlsx': Color(0xFF1E7145),
    'ppt': Color(0xFFCB4B16),
    'pptx': Color(0xFFCB4B16),
    'txt': Colors.blueGrey,
    'csv': Color(0xFF1E7145),
  };
  static const Map<String, IconData> _icons = {
    'pdf': Icons.picture_as_pdf,
    'xls': Icons.table_chart,
    'xlsx': Icons.table_chart,
    'ppt': Icons.slideshow,
    'pptx': Icons.slideshow,
  };
  static const Map<String, String> _filterMap = {
    'PDF': 'pdf',
    'DOC': 'docx',
    'XLS': 'xlsx',
    'PPT': 'pptx',
    'TXT': 'txt',
  };
  final _searchFocus = FocusNode();
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MediaListViewModel(_exts),
      child: Consumer<MediaListViewModel>(
        builder: (context, vm, _) => Scaffold(
          backgroundColor: AppTheme.backgroundBlack,
          appBar: _buildAppBar(context, vm),
          body: vm.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentBlue),
                )
              : Column(
                  children: [
                    _FilterBar(
                      filters: _filters,
                      active: vm.activeFilter,
                      onSelect: (f) => vm.applyFilter(
                        f == 'All' ? 'All' : (_filterMap[f] ?? f.toLowerCase()),
                      ),
                    ),
                    _StatsRow(
                      count: vm.filteredItems.length,
                      label: 'items in total',
                    ),
                    vm.filteredItems.isEmpty
                        ? Expanded(
                            child: _EmptyState(
                              icon: Icons.folder_open_outlined,
                              label: _searching && _searchCtrl.text.isNotEmpty
                                  ? 'No results for "${_searchCtrl.text}"'
                                  : 'No documents found',
                            ),
                          )
                        : Expanded(
                            child: _FileList(
                              items: vm.filteredItems,
                              selectedPaths: vm.selectedPaths,
                              isSelectionMode: vm.isSelectionMode,
                              onTap: (path) {
                                if (vm.isSelectionMode) {
                                  vm.toggleSelection(path);
                                } else {
                                  FileOpener.openFile(context, path);
                                }
                              },
                              onLongPress: (path) {
                                HapticFeedback.mediumImpact();
                                if (!vm.isSelectionMode)
                                  vm.enterSelectionWith(path);
                                else
                                  vm.toggleSelection(path);
                              },
                              subtitleMaxLines: 2,
                              iconBuilder: (item) {
                                final c =
                                    _colors[item.ext] ?? AppTheme.textGrey;
                                return _Icon(
                                  color: c,
                                  bg: c.withOpacity(0.12),
                                  icon:
                                      _icons[item.ext] ??
                                      Icons.insert_drive_file,
                                );
                              },
                            ),
                          ),
                    if (vm.isSelectionMode)
                      _BottomActionBar(
                        onShare: () {},
                        onDelete: vm.selectedPaths.isEmpty
                            ? null
                            : () => _showDeleteDialog(
                                context,
                                vm.selectedPaths.length,
                                vm.deleteSelected,
                              ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    MediaListViewModel vm,
  ) {
    if (vm.isSelectionMode) {
      return AppBar(
        backgroundColor: AppTheme.cardGrey,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: vm.cancelSelection,
        ),
        title: Text(
          '${vm.selectedPaths.length} selected',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: vm.selectAll,
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
    }
    if (_searching) {
      return AppBar(
        backgroundColor: AppTheme.backgroundBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() => _searching = false);
            _searchCtrl.clear();
            vm.applySearch('');
          },
        ),
        title: TextField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          autofocus: true,
          cursorColor: Colors.white,
          cursorWidth: 2,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Search documents…',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
          ),
          onChanged: vm.applySearch,
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () {
                _searchCtrl.clear();
                vm.applySearch('');
                setState(() {});
              },
            ),
        ],
      );
    }
    return AppBar(
      backgroundColor: AppTheme.backgroundBlack,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Documents',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () => setState(() => _searching = true),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════
//  SHARED WIDGETS
// ══════════════════════════════════════════════

void _showDeleteDialog(
  BuildContext context,
  int count,
  VoidCallback onConfirm,
) {
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

class _FilterBar extends StatelessWidget {
  final List<String> filters;
  final String active;
  final void Function(String) onSelect;
  const _FilterBar({
    required this.filters,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: filters.length,
        itemBuilder: (_, i) {
          final f = filters[i];
          final on =
              f == active || (active != 'All' && f.toLowerCase() == active);
          return GestureDetector(
            onTap: () => onSelect(f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: on ? AppTheme.accentBlue : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                f,
                style: TextStyle(
                  color: on ? AppTheme.accentBlue : AppTheme.textGrey,
                  fontWeight: on ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int count;
  final String label;
  const _StatsRow({required this.count, required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '$count $label',
        style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyState({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 80, color: AppTheme.textGrey),
        const SizedBox(height: 16),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textGrey, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _Icon extends StatelessWidget {
  final Color color, bg;
  final IconData icon;
  final double size;
  final double radius;
  const _Icon({
    required this.color,
    required this.bg,
    required this.icon,
    this.size = 24,
    this.radius = 8,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Icon(icon, color: color, size: size),
  );
}

class _ArchiveIcon extends StatelessWidget {
  final String ext;
  final Color color;
  const _ArchiveIcon({required this.ext, required this.color});
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.folder_zip_outlined, color: color, size: 26),
      ),
      Positioned(
        bottom: -2,
        right: -4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            '.${ext.toUpperCase()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 7,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ],
  );
}

class _FileList extends StatelessWidget {
  final List<dynamic> items;
  final Set<String> selectedPaths;
  final bool isSelectionMode;
  final void Function(String) onTap;
  final void Function(String) onLongPress;
  final Widget Function(dynamic item) iconBuilder;
  final Widget? Function(dynamic item, bool selected)? trailingBuilder;
  final int subtitleMaxLines;

  const _FileList({
    required this.items,
    required this.selectedPaths,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.iconBuilder,
    this.trailingBuilder,
    this.subtitleMaxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Colors.white10, indent: 68),
      itemBuilder: (context, i) {
        final item = items[i];
        final path = item.file.path as String;
        final selected = selectedPaths.contains(path);
        return GestureDetector(
          onTap: () => onTap(path),
          onLongPress: () => onLongPress(path),
          child: Container(
            color: selected
                ? AppTheme.accentBlue.withOpacity(0.12)
                : Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: iconBuilder(item),
              title: Text(
                item.name as String,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: subtitleMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${item.sizeLabel}  |  ${item.dateLabel}',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
              ),
              trailing: isSelectionMode
                  ? Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected ? AppTheme.accentBlue : AppTheme.textGrey,
                    )
                  : (trailingBuilder != null
                        ? trailingBuilder!(item, selected)
                        : null),
            ),
          ),
        );
      },
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final VoidCallback onShare;
  final VoidCallback? onDelete;
  const _BottomActionBar({required this.onShare, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
    height: 64 + MediaQuery.of(context).padding.bottom,
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
    decoration: const BoxDecoration(
      color: AppTheme.cardGrey,
      border: Border(top: BorderSide(color: Colors.white10)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Btn(icon: Icons.share_rounded, label: 'Share', onTap: onShare),
        Container(width: 1, height: 36, color: Colors.white12),
        _Btn(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          color: Colors.redAccent,
          onTap: onDelete ?? () {},
          enabled: onDelete != null,
        ),
      ],
    ),
  );
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool enabled;
  const _Btn({
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
