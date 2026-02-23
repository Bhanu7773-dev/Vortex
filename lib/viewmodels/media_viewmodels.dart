import 'dart:io';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';

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

  VideosViewModel() {
    _load();
  }

  Future<void> _load() async {
    isLoading = true;
    notifyListeners();
    final map = <String, List<File>>{};
    final volumes = await StorageService().getStorageVolumes();
    for (final vol in volumes) {
      await _scanDir(Directory(vol.path), map);
    }
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
    notifyListeners();
  }

  Future<void> _scanDir(Directory dir, Map<String, List<File>> map) async {
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
          if (name == 'Android') {
            final media = Directory('${sub.path}/media');
            if (media.existsSync()) await _scanDir(media, map);
          } else {
            await _scanDir(sub, map);
          }
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

  VideoAlbumDetailViewModel(this.folderPath) {
    _load();
  }

  Future<void> _load() async {
    isLoading = true;
    notifyListeners();
    try {
      final found = <File>[];
      await for (final e in Directory(
        folderPath,
      ).list(recursive: false, followLinks: false)) {
        if (e is File && _exts.contains(e.path.split('.').last.toLowerCase()))
          found.add(e);
      }
      found.sort((a, b) {
        try {
          return b.statSync().modified.compareTo(a.statSync().modified);
        } catch (_) {
          return 0;
        }
      });
      videos = found;
    } catch (_) {}
    isLoading = false;
    notifyListeners();
  }

  void enterSelectionWith(String path) {
    isSelectionMode = true;
    selectedPaths.add(path);
    notifyListeners();
  }

  void toggleSelectionMode() {
    isSelectionMode = !isSelectionMode;
    if (!isSelectionMode) selectedPaths.clear();
    notifyListeners();
  }

  void toggleSelection(String path) {
    selectedPaths.contains(path)
        ? selectedPaths.remove(path)
        : selectedPaths.add(path);
    if (selectedPaths.isEmpty) isSelectionMode = false;
    notifyListeners();
  }

  void selectAll() {
    selectedPaths.addAll(videos.map((f) => f.path));
    notifyListeners();
  }

  void cancelSelection() {
    selectedPaths.clear();
    isSelectionMode = false;
    notifyListeners();
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
    notifyListeners();
  }
}

// ─── Media list ViewModel (Audio / Archives / APKs) ─
class _FileItem {
  final File file;
  final String name;
  final String ext;
  final int sizeBytes;
  final DateTime modified;
  _FileItem(this.file)
    : name = file.path.split('/').last,
      ext = file.path.split('.').last.toLowerCase(),
      sizeBytes = _safeSize(file),
      modified = _safeModified(file);

  static int _safeSize(File f) {
    try {
      return f.statSync().size;
    } catch (_) {
      return 0;
    }
  }

  static DateTime _safeModified(File f) {
    try {
      return f.statSync().modified;
    } catch (_) {
      return DateTime.now();
    }
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

class MediaListViewModel extends ChangeNotifier {
  final Set<String> _exts;
  final String rootPath;

  List<_FileItem> _allItems = [];
  List<_FileItem> filteredItems = [];
  bool isLoading = true;
  String activeFilter = 'All';
  bool isSelectionMode = false;
  final Set<String> selectedPaths = {};

  MediaListViewModel(this._exts, {this.rootPath = '/storage/emulated/0'}) {
    _load();
  }

  Future<void> _load() async {
    isLoading = true;
    notifyListeners();
    final found = <_FileItem>[];
    final volumes = await StorageService().getStorageVolumes();
    for (final vol in volumes) {
      await _scanDir(Directory(vol.path), found);
    }
    found.sort((a, b) => b.modified.compareTo(a.modified));
    _allItems = found;
    filteredItems = found;
    isLoading = false;
    notifyListeners();
  }

  Future<void> _scanDir(Directory dir, List<_FileItem> out) async {
    try {
      await for (final e in dir.list(recursive: false, followLinks: false)) {
        try {
          if (e is File &&
              _exts.contains(e.path.split('.').last.toLowerCase())) {
            out.add(_FileItem(e));
          } else if (e is Directory) {
            final name = e.path.split('/').last;
            if (name == 'Android') {
              final media = Directory('${e.path}/media');
              if (media.existsSync()) await _scanDir(media, out);
            } else {
              await _scanDir(e, out);
            }
          }
        } catch (_) {
          // Skip problematic item and continue scanning
        }
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
    var base = activeFilter == 'All'
        ? _allItems
        : _allItems.where((f) => f.ext == activeFilter.toLowerCase()).toList();
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      base = base.where((f) => f.name.toLowerCase().contains(q)).toList();
    }
    filteredItems = base;
    notifyListeners();
  }

  void enterSelectionWith(String path) {
    isSelectionMode = true;
    selectedPaths.add(path);
    notifyListeners();
  }

  void toggleSelectionMode() {
    isSelectionMode = !isSelectionMode;
    if (!isSelectionMode) selectedPaths.clear();
    notifyListeners();
  }

  void toggleSelection(String path) {
    selectedPaths.contains(path)
        ? selectedPaths.remove(path)
        : selectedPaths.add(path);
    if (selectedPaths.isEmpty) isSelectionMode = false;
    notifyListeners();
  }

  void selectAll() {
    selectedPaths.addAll(filteredItems.map((f) => f.file.path));
    notifyListeners();
  }

  void cancelSelection() {
    selectedPaths.clear();
    isSelectionMode = false;
    notifyListeners();
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
    notifyListeners();
  }
}
