import 'dart:io';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';

// Dirs to skip on every platform during recursive media scans.
const _kSkipDirs = {
  'Android',
  '.cache',
  '.local',
  '.config',
  '.mozilla',
  '.npm',
  '.pub-cache',
  '.dart',
  '.pub',
  '.gradle',
  '.android',
  '.flutter',
  '.git',
  'node_modules',
  'proc',
  'sys',
  'dev',
  'run',
  'snap',
  'AppData',
  r'$Recycle.Bin',
  'Windows',
  'Program Files',
  'Program Files (x86)',
  'ProgramData',
};

const int _kMaxDepthDesktop = 4;
const int _kMaxDepthAndroid = 20;

// ─── Model ───────────────────────────────────
class VideoAlbum {
  final String name;
  final String folderPath;
  final File coverFile; // first video file (used for placeholder)
  final int count;
  const VideoAlbum({
    required this.name,
    required this.folderPath,
    required this.coverFile,
    required this.count,
  });
}

// ─── Album-list ViewModel ─────────────────────
class VideosViewModel extends ChangeNotifier {
  static const _exts = {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
    '3gp',
    'm4v',
  };

  List<VideoAlbum> albums = [];
  bool isLoading = true;
  bool _disposed = false;

  VideosViewModel() {
    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _load() async {
    isLoading = true;
    if (!_disposed) notifyListeners();
    final map = <String, List<File>>{};
    final volumes = await StorageService().getStorageVolumes();
    for (final vol in volumes) {
      if (_disposed) return;
      await _scanDir(Directory(vol.path), map);
    }
    if (_disposed) return;
    albums =
        map.entries
            .where((e) => e.value.isNotEmpty)
            .map(
              (e) => VideoAlbum(
                name: e.key.split('/').last,
                folderPath: e.key,
                coverFile: e.value.first,
                count: e.value.length,
              ),
            )
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
    isLoading = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> _scanDir(
    Directory dir,
    Map<String, List<File>> map, {
    int depth = 0,
  }) async {
    final maxDepth = Platform.isAndroid ? _kMaxDepthAndroid : _kMaxDepthDesktop;
    if (depth > maxDepth) return;
    try {
      final children = await dir
          .list(recursive: false, followLinks: false)
          .toList();
      final videos = children
          .whereType<File>()
          .where((f) => _exts.contains(f.path.split('.').last.toLowerCase()))
          .toList();
      if (videos.isNotEmpty) map[dir.path] = videos;
      for (final sub in children.whereType<Directory>()) {
        try {
          final name = sub.path.split('/').last;
          if (!Platform.isAndroid && name.startsWith('.')) continue;
          if (_kSkipDirs.contains(name)) continue;
          await _scanDir(sub, map, depth: depth + 1);
        } catch (_) {}
      }
    } catch (_) {}
  }
}

// ─── Detail ViewModel ─────────────────────────
class VideoAlbumDetailViewModel extends ChangeNotifier {
  static const _exts = {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
    '3gp',
    'm4v',
  };
  final String folderPath;
  List<File> videos = [];
  bool isLoading = true;
  bool isSelectionMode = false;
  final Set<String> selectedPaths = {};
  bool _disposed = false;

  VideoAlbumDetailViewModel(this.folderPath) {
    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _load() async {
    isLoading = true;
    if (!_disposed) notifyListeners();
    try {
      final found = <File>[];
      await for (final e in Directory(
        folderPath,
      ).list(recursive: false, followLinks: false)) {
        if (_disposed) return;
        if (e is File && _exts.contains(e.path.split('.').last.toLowerCase()))
          found.add(e);
      }
      if (_disposed) return;

      final Map<String, FileStat> statCache = {};
      for (var f in found) {
        if (_disposed) return;
        try {
          statCache[f.path] = await f.stat();
        } catch (_) {}
      }

      found.sort((a, b) {
        final statA = statCache[a.path];
        final statB = statCache[b.path];
        if (statA == null || statB == null) return 0;
        return statB.modified.compareTo(statA.modified);
      });
      videos = found;
    } catch (_) {}
    if (_disposed) return;
    isLoading = false;
    if (!_disposed) notifyListeners();
  }

  void enterSelectionWith(String path) {
    isSelectionMode = true;
    selectedPaths.add(path);
    if (!_disposed) notifyListeners();
  }

  void toggleSelectionMode() {
    isSelectionMode = !isSelectionMode;
    if (!isSelectionMode) selectedPaths.clear();
    if (!_disposed) notifyListeners();
  }

  void toggleSelection(String path) {
    selectedPaths.contains(path)
        ? selectedPaths.remove(path)
        : selectedPaths.add(path);
    if (selectedPaths.isEmpty) isSelectionMode = false;
    if (!_disposed) notifyListeners();
  }

  void selectAll() {
    selectedPaths.addAll(videos.map((f) => f.path));
    if (!_disposed) notifyListeners();
  }

  void cancelSelection() {
    selectedPaths.clear();
    isSelectionMode = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> deleteSelected() async {
    for (final p in selectedPaths) {
      try {
        await File(p).delete();
      } catch (_) {}
    }
    videos.removeWhere((f) => selectedPaths.contains(f.path));
    selectedPaths.clear();
    isSelectionMode = false;
    if (!_disposed) notifyListeners();
  }
}

// ─── Media list ViewModel (Audio / Archives / APKs) ─
class MediaFileItem {
  final File file;
  final String name;
  final String ext;
  final int sizeBytes;
  final DateTime modified;

  MediaFileItem(this.file, this.sizeBytes, this.modified)
    : name = file.path.split('/').last,
      ext = file.path.split('.').last.toLowerCase();

  String get nameWithoutExt {
    final lastDot = name.lastIndexOf('.');
    return lastDot > 0 ? name.substring(0, lastDot) : name;
  }

  String get sizeLabel {
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  String get dateLabel {
    return '${modified.day} ${_monthName(modified.month)} ${modified.year}';
  }

  static String _monthName(int m) => [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m - 1];
}

typedef _FileItem = MediaFileItem;

class MediaListViewModel extends ChangeNotifier {
  final Set<String> _exts;
  final String rootPath;

  List<_FileItem> _allItems = [];
  List<_FileItem> filteredItems = [];
  bool isLoading = true;
  String activeFilter = 'All';
  bool isSelectionMode = false;
  final Set<String> selectedPaths = {};
  bool _disposed = false;

  MediaListViewModel(this._exts, {this.rootPath = '/storage/emulated/0'}) {
    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _load() async {
    isLoading = true;
    if (!_disposed) notifyListeners();
    final found = <_FileItem>[];
    final volumes = await StorageService().getStorageVolumes();
    for (final vol in volumes) {
      if (_disposed) return;
      await _scanDir(Directory(vol.path), found);
    }
    if (_disposed) return;
    found.sort((a, b) => b.modified.compareTo(a.modified));
    _allItems = found;
    filteredItems = found;
    isLoading = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> _scanDir(
    Directory dir,
    List<_FileItem> out, {
    int depth = 0,
  }) async {
    final maxDepth = Platform.isAndroid ? _kMaxDepthAndroid : _kMaxDepthDesktop;
    if (depth > maxDepth) return;
    try {
      await for (final e in dir.list(recursive: false, followLinks: false)) {
        try {
          if (e is File &&
              _exts.contains(e.path.split('.').last.toLowerCase())) {
            final stat = await e.stat();
            out.add(_FileItem(e, stat.size, stat.modified));
          } else if (e is Directory) {
            final name = e.path.split('/').last;
            if (!Platform.isAndroid && name.startsWith('.')) continue;
            if (_kSkipDirs.contains(name)) continue;
            await _scanDir(e, out, depth: depth + 1);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  String searchQuery = '';

  void applyFilter(String filter) {
    activeFilter = filter;
    _refilter();
  }

  void applySearch(String query) {
    searchQuery = query;
    _refilter();
  }

  void _refilter() {
    var base = _allItems;
    if (activeFilter != 'All') {
      final af = activeFilter.toLowerCase();
      base = base.where((f) {
        final ext = f.ext.toLowerCase();
        if (af == 'doc') return ext == 'doc' || ext == 'docx';
        if (af == 'xls') return ext == 'xls' || ext == 'xlsx';
        if (af == 'ppt') return ext == 'ppt' || ext == 'pptx';
        if (af == 'txt') return ext == 'txt' || ext == 'rtf' || ext == 'odt';
        return ext == af;
      }).toList();
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      base = base.where((f) => f.name.toLowerCase().contains(q)).toList();
    }
    filteredItems = base;
    if (!_disposed) notifyListeners();
  }

  void enterSelectionWith(String path) {
    isSelectionMode = true;
    selectedPaths.add(path);
    if (!_disposed) notifyListeners();
  }

  void toggleSelectionMode() {
    isSelectionMode = !isSelectionMode;
    if (!isSelectionMode) selectedPaths.clear();
    if (!_disposed) notifyListeners();
  }

  void toggleSelection(String path) {
    selectedPaths.contains(path)
        ? selectedPaths.remove(path)
        : selectedPaths.add(path);
    if (selectedPaths.isEmpty) isSelectionMode = false;
    if (!_disposed) notifyListeners();
  }

  void selectAll() {
    selectedPaths.addAll(filteredItems.map((f) => f.file.path));
    if (!_disposed) notifyListeners();
  }

  void cancelSelection() {
    selectedPaths.clear();
    isSelectionMode = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> deleteSelected() async {
    for (final p in selectedPaths) {
      try {
        await File(p).delete();
      } catch (_) {}
    }
    _allItems.removeWhere((f) => selectedPaths.contains(f.file.path));
    filteredItems.removeWhere((f) => selectedPaths.contains(f.file.path));
    selectedPaths.clear();
    isSelectionMode = false;
    if (!_disposed) notifyListeners();
  }
}
