import 'dart:io';
import 'package:flutter/material.dart';

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

  PhotosViewModel() {
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    isLoading = true;
    notifyListeners();

    final root = Directory('/storage/emulated/0');
    // Map from folder path -> list of photo files in that folder (non-recursive)
    final Map<String, List<File>> folderMap = {};

    await _scanForAlbums(root, folderMap);

    // Build album list — only folders that have at least 1 photo
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

    // Sort by count descending (most photos first)
    result.sort((a, b) => b.count.compareTo(a.count));

    albums = result;
    isLoading = false;
    notifyListeners();
  }

  Future<void> _scanForAlbums(
    Directory dir,
    Map<String, List<File>> map,
  ) async {
    try {
      final List<FileSystemEntity> children = await dir
          .list(recursive: false, followLinks: false)
          .toList();

      // Collect photos at this level
      final photos = children
          .whereType<File>()
          .where(
            (f) => _photoExts.contains(f.path.split('.').last.toLowerCase()),
          )
          .toList();

      final subDirs = children
          .whereType<Directory>()
          .where((d) => d.path.split('/').last != 'Android')
          .toList();

      if (photos.isNotEmpty) {
        map[dir.path] = photos;
      }

      // Recurse into subdirs
      for (final subDir in subDirs) {
        await _scanForAlbums(subDir, map);
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

  PhotoAlbumDetailViewModel(this.folderPath) {
    _load();
  }

  Future<void> _load() async {
    isLoading = true;
    notifyListeners();

    final dir = Directory(folderPath);
    final found = <File>[];
    try {
      await for (final entity in dir.list(
        recursive: false,
        followLinks: false,
      )) {
        if (entity is File) {
          final ext = entity.path.split('.').last.toLowerCase();
          if (_photoExts.contains(ext)) found.add(entity);
        }
      }
    } catch (_) {}

    found.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    photos = found;
    isLoading = false;
    notifyListeners();
  }

  void toggleSelectionMode() {
    isSelectionMode = !isSelectionMode;
    if (!isSelectionMode) selectedPaths.clear();
    notifyListeners();
  }

  void toggleSelection(String path) {
    if (selectedPaths.contains(path)) {
      selectedPaths.remove(path);
      if (selectedPaths.isEmpty) isSelectionMode = false;
    } else {
      selectedPaths.add(path);
    }
    notifyListeners();
  }

  void selectAll() {
    selectedPaths.addAll(photos.map((f) => f.path));
    notifyListeners();
  }

  void cancelSelection() {
    selectedPaths.clear();
    isSelectionMode = false;
    notifyListeners();
  }

  void enterSelectionWith(String path) {
    isSelectionMode = true;
    selectedPaths.add(path);
    notifyListeners();
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
    notifyListeners();
  }
}
