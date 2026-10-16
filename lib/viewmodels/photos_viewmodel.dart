import 'dart:io';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class PhotoAlbum {
  final String name;
  final String folderPath;
  final File coverPhoto;
  final int count;

  const PhotoAlbum({
    required this.name,
    required this.folderPath,
    required this.coverPhoto,
    required this.count,
  });
}

class PhotosViewModel extends ChangeNotifier {
  static const _photoExts = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
    'tiff',
  };

  List<PhotoAlbum> albums = [];
  bool isLoading = true;
  bool _disposed = false;

  PhotosViewModel() {
    _loadAlbums();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _loadAlbums() async {
    isLoading = true;
    if (!_disposed) notifyListeners();

    final Map<String, List<File>> folderMap = {};

    final volumes = await StorageService().getStorageVolumes();
    for (final vol in volumes) {
      if (_disposed) return;
      final root = Directory(vol.path);
      if (await root.exists()) {
        await _scanForAlbums(root, folderMap);
      }
    }

    if (_disposed) return;

    final result = <PhotoAlbum>[];
    for (final entry in folderMap.entries) {
      if (entry.value.isNotEmpty) {
        result.add(
          PhotoAlbum(
            name: entry.key.split('/').last,
            folderPath: entry.key,
            coverPhoto: entry.value.first,
            count: entry.value.length,
          ),
        );
      }
    }

    result.sort((a, b) => b.count.compareTo(a.count));

    albums = result;
    isLoading = false;
    if (!_disposed) notifyListeners();
  }

  static const _kSkipDirs = {
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

  Future<void> _scanForAlbums(
    Directory dir,
    Map<String, List<File>> map, {
    int depth = 0,
  }) async {
    final maxDepth = Platform.isAndroid ? 20 : 4;
    if (depth > maxDepth) return;
    try {
      final List<FileSystemEntity> children = await dir
          .list(recursive: false, followLinks: false)
          .toList();

      final photos = children
          .whereType<File>()
          .where(
            (f) => _photoExts.contains(f.path.split('.').last.toLowerCase()),
          )
          .toList();

      if (photos.isNotEmpty) {
        map[dir.path] = photos;
      }

      for (final child in children.whereType<Directory>()) {
        try {
          final name = child.path.split('/').last;
          if (!Platform.isAndroid && name.startsWith('.')) continue;
          if (_kSkipDirs.contains(name)) continue;
          await _scanForAlbums(child, map, depth: depth + 1);
        } catch (_) {}
      }
    } catch (_) {}
  }
}

/// ViewModel for a single album's photo grid
class PhotoAlbumDetailViewModel extends ChangeNotifier {
  static const _photoExts = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
    'tiff',
  };

  final String folderPath;
  List<File> photos = [];
  bool isLoading = true;

  bool isSelectionMode = false;
  final Set<String> selectedPaths = {};
  bool _disposed = false;

  PhotoAlbumDetailViewModel(this.folderPath) {
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

    final dir = Directory(folderPath);
    final found = <File>[];
    try {
      await for (final entity in dir.list(
        recursive: false,
        followLinks: false,
      )) {
        if (_disposed) return;
        if (entity is File) {
          final ext = entity.path.split('.').last.toLowerCase();
          if (_photoExts.contains(ext)) found.add(entity);
        }
      }
    } catch (_) {}

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
    photos = found;
    isLoading = false;
    if (!_disposed) notifyListeners();
  }

  void toggleSelectionMode() {
    isSelectionMode = !isSelectionMode;
    if (!isSelectionMode) selectedPaths.clear();
    if (!_disposed) notifyListeners();
  }

  void toggleSelection(String path) {
    if (selectedPaths.contains(path)) {
      selectedPaths.remove(path);
      if (selectedPaths.isEmpty) isSelectionMode = false;
    } else {
      selectedPaths.add(path);
    }
    if (!_disposed) notifyListeners();
  }

  void selectAll() {
    selectedPaths.addAll(photos.map((f) => f.path));
    if (!_disposed) notifyListeners();
  }

  void cancelSelection() {
    selectedPaths.clear();
    isSelectionMode = false;
    if (!_disposed) notifyListeners();
  }

  void enterSelectionWith(String path) {
    isSelectionMode = true;
    selectedPaths.add(path);
    if (!_disposed) notifyListeners();
  }

  Future<void> deleteSelected() async {
    for (final path in selectedPaths) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    photos.removeWhere((f) => selectedPaths.contains(f.path));
    selectedPaths.clear();
    isSelectionMode = false;
    if (!_disposed) notifyListeners();
  }
}
