import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/file_item_model.dart';
import '../models/storage_volume_model.dart';
import '../services/persistence_service.dart';
import '../services/storage_service.dart';

enum SortOption { dateModified, size, filename, type }

class AllFilesViewModel extends ChangeNotifier {
  String currentPath;
  String rootPath;
  List<StorageVolume> availableVolumes = [];
  final StorageService _storageService = StorageService();
  List<String> pathHistory = [];
  bool isFolderPickerMode;
  final PersistenceService _persistenceService = PersistenceService();

  AllFilesViewModel({String? initialPath, this.isFolderPickerMode = false})
    : currentPath = initialPath ?? '/storage/emulated/0',
      rootPath = '/storage/emulated/0' {
    if (initialPath != null) {
      // Try to determine the root from initialPath
      if (!initialPath.startsWith('/storage/emulated/0')) {
        final parts = initialPath.split('/');
        if (parts.length > 2 && parts[1] == 'storage') {
          rootPath = '/storage/${parts[2]}';
        }
      }
    }
    _init();
  }

  Future<void> _init() async {
    availableVolumes = await _storageService.getStorageVolumes();
    // Refresh rootPath from the detected volumes for accuracy
    final currentVol = availableVolumes.firstWhere(
      (v) => currentPath.startsWith(v.path),
      orElse: () => availableVolumes.isNotEmpty
          ? availableVolumes.first
          : StorageVolume(
              path: '/storage/emulated/0',
              name: 'Internal Storage',
              isInternal: true,
            ),
    );
    rootPath = currentVol.path;
    _loadDirectory();
  }

  void switchStorage(StorageVolume volume) {
    pathHistory.clear();
    rootPath = volume.path;
    currentPath = volume.path;
    _loadDirectory();
  }

  Future<void> tagSelectedItems(String tagName) async {
    for (final path in selectedPaths) {
      await _persistenceService.addPathToTag(tagName, path);
    }
    // Clear selected paths and exit selection mode after tagging
    selectedPaths.clear();
    isSelectionMode = false;
    notifyListeners();
  }

  String get currentFolderName {
    if (currentPath == rootPath) {
      final vol = availableVolumes.firstWhere(
        (v) => v.path == rootPath,
        orElse: () =>
            StorageVolume(path: rootPath, name: 'Storage', isInternal: true),
      );
      return vol.name;
    }
    return currentPath.split('/').last;
  }

  String get displayPath {
    final vol = availableVolumes.firstWhere(
      (v) => v.path == rootPath,
      orElse: () =>
          StorageVolume(path: rootPath, name: 'Storage', isInternal: true),
    );

    String relativePath = currentPath;
    if (currentPath.startsWith(rootPath)) {
      relativePath = currentPath.substring(rootPath.length);
    }

    List<String> parts = relativePath
        .split('/')
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.length > 3) {
      parts = parts.sublist(parts.length - 3);
      return '${vol.name}/../${parts.join('/')}';
    } else if (parts.isNotEmpty) {
      return '${vol.name}/${parts.join('/')}';
    }
    return vol.name;
  }

  List<FileItemModel> items = [];
  Map<String, List<FileItemModel>> _cachedDirectories = {};
  bool isLoading = true;

  SortOption currentSort = SortOption.filename;
  bool isDescending = false; // Default: A-Z

  bool isGridView = false;
  bool isSelectionMode = false;
  Set<String> selectedPaths = {};

  // Clipboard State
  List<String> clipboardPaths = [];
  bool isCut = false;
  bool isPasteMode = false;

  // Paste Progress & Cancellation State
  bool isPasting = false;
  double pasteProgress = 0.0;
  String pasteStatus = '';
  bool _cancelRequested = false;
  List<String> _pastedDestinationPaths = [];
  int _totalItemsToPaste = 0;
  int _itemsPasted = 0;

  // Search State
  bool isSearchMode = false;
  String searchQuery = '';
  List<FileItemModel> searchResults = [];
  bool isSearchLoading = false;
  bool _searchCancelled = false;

  String get itemCountString {
    if (items.isEmpty) return '0 items in total';

    final folderCount = items.where((i) => i.isDirectory).length;
    final fileCount = items.length - folderCount;

    if (fileCount == 0 && folderCount > 0) {
      return '$folderCount folder${folderCount == 1 ? '' : 's'} in total';
    }

    return '${items.length} items in total';
  }

  /// Deep-search recursively from [currentPath], filtering by [query].
  /// Each matching file/folder is appended to [searchResults] live.
  Future<void> deepSearch(String query) async {
    _searchCancelled = true; // Cancel any previous search run
    await Future.delayed(
      const Duration(milliseconds: 50),
    ); // Let previous loop cancel
    _searchCancelled = false;

    searchQuery = query;
    searchResults = [];
    isSearchLoading = true;
    isSearchMode = true;
    notifyListeners();

    if (query.trim().isEmpty) {
      isSearchLoading = false;
      notifyListeners();
      return;
    }

    final q = query.toLowerCase();
    await _deepScanForSearch(Directory(currentPath), q);

    if (!_searchCancelled) {
      isSearchLoading = false;
      notifyListeners();
    }
  }

  Future<void> _deepScanForSearch(Directory dir, String q) async {
    if (_searchCancelled) return;
    try {
      // Use async list() to avoid blocking the UI thread
      final entities = await dir
          .list(recursive: false, followLinks: false)
          .toList();
      for (final entity in entities) {
        if (_searchCancelled) return;
        final name = entity.path.split('/').last;
        if (name.startsWith('.')) continue;
        if (name.toLowerCase().contains(q)) {
          final isDir = entity is Directory;
          int count = 0;
          DateTime modified = DateTime.now();
          try {
            final stat = await entity.stat(); // async stat
            modified = stat.modified;
          } catch (_) {}
          if (isDir) {
            try {
              count = (await entity.list(recursive: false).length);
            } catch (_) {}
          }
          searchResults = List.from(searchResults)
            ..add(
              FileItemModel(
                name: name,
                path: entity.path,
                isDirectory: isDir,
                itemCount: count,
                modifiedDate: modified,
                categoryHint: isDir ? '' : _inferCategory(name),
              ),
            );
          // Batch: notify every 15 results, not per-match
          if (searchResults.length % 15 == 0) notifyListeners();
        }
        if (entity is Directory && entity.path.split('/').last != 'Android') {
          await _deepScanForSearch(entity, q);
        }
        // Yield to event loop periodically to keep UI responsive
        await Future.delayed(Duration.zero);
      }
    } catch (_) {}
  }

  void clearSearch() {
    _searchCancelled = true;
    isSearchMode = false;
    searchQuery = '';
    searchResults = [];
    isSearchLoading = false;
    notifyListeners();
  }

  Future<void> _loadDirectory() async {
    // 1. Serve from cache instantly if available
    if (_cachedDirectories.containsKey(currentPath)) {
      items = _cachedDirectories[currentPath]!;
      isLoading = false;
      notifyListeners();
    } else {
      items = []; // Ensure previous folder data is cleared before loading
      isLoading = true;
      notifyListeners();
    }

    // 2. Fetch fresh data quietly in background
    if (await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted) {
      final dir = Directory(currentPath);

      try {
        if (await dir.exists()) {
          List<FileItemModel> freshItems = [];

          try {
            final stream = dir.list(recursive: false, followLinks: false);
            await for (final entity in stream) {
              try {
                final type = await FileSystemEntity.type(entity.path);
                final isDir = type == FileSystemEntityType.directory;
                int count = 0;

                if (isDir) {
                  try {
                    if (!entity.path.split('/').last.startsWith('.')) {
                      count = (entity as Directory)
                          .listSync(recursive: false)
                          .length;
                    }
                  } catch (e) {
                    // skip count if listing fails
                  }
                }

                DateTime modified = DateTime.now();
                try {
                  final stat = await entity.stat();
                  modified = stat.modified;
                } catch (_) {}

                final name = entity.path.split('/').last;

                if (!name.startsWith('.')) {
                  freshItems.add(
                    FileItemModel(
                      name: name,
                      path: entity.path,
                      isDirectory: isDir,
                      itemCount: count,
                      modifiedDate: modified,
                      categoryHint: _inferCategory(name),
                    ),
                  );
                }
              } catch (e) {
                // skip individual failed entities
              }
            }
          } catch (e) {
            debugPrint('Error listing directory: $e');
          }

          items = freshItems;
          _applySorting();

          // 3. Update cache
          _cachedDirectories[currentPath] = List.from(items);
        }
      } catch (e) {
        // Handle gracefully
      }
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> deleteSelectedFiles() async {
    if (selectedPaths.isEmpty) return;

    for (final path in selectedPaths) {
      try {
        if (await FileSystemEntity.type(path) ==
            FileSystemEntityType.directory) {
          await Directory(path).delete(recursive: true);
        } else {
          await File(path).delete();
        }
      } catch (e) {
        debugPrint('Failed to delete $path: $e');
      }
    }

    // Remove them locally to preserve scroll state
    items.removeWhere((item) => selectedPaths.contains(item.path));
    _cachedDirectories[currentPath] = List.from(items);

    selectedPaths.clear();
    isSelectionMode = false;
    notifyListeners();
  }

  Future<String?> renameSelected(String newName) async {
    if (selectedPaths.length != 1) return 'Select exactly one item to rename.';

    final oldPath = selectedPaths.first;
    final parentDir = File(oldPath).parent.path;
    final newPath = '$parentDir/$newName';

    if (await FileSystemEntity.type(newPath) != FileSystemEntityType.notFound) {
      return 'A file or folder with this name already exists.';
    }

    try {
      final type = await FileSystemEntity.type(oldPath);
      if (type == FileSystemEntityType.directory) {
        await Directory(oldPath).rename(newPath);
      } else {
        await File(oldPath).rename(newPath);
      }

      // Preserve scroll state
      final itemIndex = items.indexWhere((element) => element.path == oldPath);
      if (itemIndex != -1) {
        final oldItem = items[itemIndex];
        items[itemIndex] = FileItemModel(
          name: newName,
          path: newPath,
          isDirectory: oldItem.isDirectory,
          itemCount: oldItem.itemCount,
          modifiedDate: DateTime.now(),
          categoryHint: _inferCategory(newName),
        );
        _applySorting();
        _cachedDirectories[currentPath] = List.from(items);
      }

      selectedPaths.clear();
      isSelectionMode = false;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to rename: $e';
    }
  }

  Future<Map<String, String>?> getDetailsForSelected() async {
    if (selectedPaths.length != 1) return null;

    final path = selectedPaths.first;
    final type = await FileSystemEntity.type(path);
    final stat = await FileStat.stat(path);

    Map<String, String> details = {
      'Name': path.split('/').last,
      'Path': path,
      'Modified': formatDateString(stat.modified),
    };

    if (type == FileSystemEntityType.directory) {
      details['Type'] = 'Folder';
      try {
        final dir = Directory(path);
        int totalItems = 0;
        await for (var _ in dir.list(recursive: true, followLinks: false)) {
          totalItems++;
        }
        details['Items inside'] = totalItems.toString();
      } catch (e) {
        details['Items inside'] = 'Unknown (Permission denied)';
      }
    } else {
      details['Type'] = 'File';
      details['Size'] = _formatBytes(stat.size);
    }

    // Unselect automatically after retrieving stats
    selectedPaths.clear();
    isSelectionMode = false;
    notifyListeners();

    return details;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }

  String _inferCategory(String folderName) {
    switch (folderName.toLowerCase()) {
      case 'download':
      case 'downloads':
        return 'download';
      case 'documents':
        return 'document';
      default:
        return '';
    }
  }

  String formatDateString(DateTime date) {
    return DateFormat('d MMMM y').format(date); // e.g. "13 December 2025"
  }

  void setSortOption(SortOption option) {
    if (currentSort == option) {
      isDescending = !isDescending; // Toggle direction if same option clicked
    } else {
      currentSort = option;
      isDescending = false; // Reset to ascending for new sort type
    }
    _applySorting();
    notifyListeners();
  }

  void _applySorting() {
    items.sort((a, b) {
      // Always keep folders first regardless of sort direction, unless sorting strictly by "type" maybe?
      // Standard file managers usually keep folders grouped at the top.
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      int result = 0;
      switch (currentSort) {
        case SortOption.filename:
          result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case SortOption.dateModified:
          result = a.modifiedDate.compareTo(b.modifiedDate);
          break;
        case SortOption.size:
          // We don't have direct size stored yet, fallback to name or add size to FileItemModel later.
          // For now, size will just fall through to name inside items of the same type.
          result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case SortOption.type:
          if (a.isDirectory && b.isDirectory) {
            result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          } else {
            // Extract extension for simple type sort
            final extA = a.name.split('.').last.toLowerCase();
            final extB = b.name.split('.').last.toLowerCase();
            result = extA.compareTo(extB);
            // If same type, sort by name
            if (result == 0) {
              result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            }
          }
          break;
      }

      return isDescending ? -result : result;
    });
  }

  Future<void> createNewFolder(String folderName) async {
    if (folderName.trim().isEmpty) return;

    final newDirPath = '$currentPath/${folderName.trim()}';
    final directory = Directory(newDirPath);

    try {
      if (!await directory.exists()) {
        await directory.create();
        await _loadDirectory(); // Refresh the list
      }
    } catch (e) {
      // Handle permission or creation errors
      debugPrint('Failed to create folder: $e');
    }
  }

  Future<void> createNewFile(String fileName) async {
    if (fileName.trim().isEmpty) return;

    final newFilePath = '$currentPath/${fileName.trim()}';
    final file = File(newFilePath);

    try {
      if (!await file.exists()) {
        await file.create();
        await _loadDirectory(); // Refresh the list
      }
    } catch (e) {
      // Handle permission or creation errors
      debugPrint('Failed to create file: $e');
    }
  }

  void toggleGridView() {
    isGridView = !isGridView;
    notifyListeners();
  }

  void toggleSelectionMode() {
    isSelectionMode = !isSelectionMode;
    if (!isSelectionMode) {
      selectedPaths.clear();
    }
    notifyListeners();
  }

  void toggleSelection(String path) {
    if (selectedPaths.contains(path)) {
      selectedPaths.remove(path);
    } else {
      selectedPaths.add(path);
    }
    notifyListeners();
  }

  void selectAll() {
    selectedPaths = items.map((e) => e.path).toSet();
    notifyListeners();
  }

  void clearSelection() {
    selectedPaths.clear();
    notifyListeners();
  }

  // --- Navigation Methods ---

  void navigateTo(String path) {
    pathHistory.add(currentPath);
    currentPath = path;
    _loadDirectory(); // Reactively reloads the list using the new currentPath
  }

  bool goBack() {
    if (pathHistory.isNotEmpty) {
      currentPath = pathHistory.removeLast();
      _loadDirectory();
      return true; // Handled back navigation
    }
    return false; // Did not handle (e.g., at root, OS should close app/tab)
  }

  // --- Clipboard & Paste Methods ---

  void copySelected() {
    clipboardPaths = selectedPaths.toList();
    isCut = false;
    isPasteMode = true;
    toggleSelectionMode(); // Exit selection UI
  }

  void cutSelected() {
    clipboardPaths = selectedPaths.toList();
    isCut = true;
    isPasteMode = true;
    toggleSelectionMode(); // Exit selection UI
  }

  void cancelPaste() {
    clipboardPaths.clear();
    isPasteMode = false;
    isCut = false;
    notifyListeners();
  }

  void cancelOngoingPaste() {
    _cancelRequested = true;
    notifyListeners();
  }

  Future<int> _countTotalItems(List<String> paths) async {
    int count = 0;
    for (final path in paths) {
      if (await FileSystemEntity.type(path) == FileSystemEntityType.file) {
        count++;
      } else if (await FileSystemEntity.type(path) ==
          FileSystemEntityType.directory) {
        count++; // count the directory itself
        try {
          // recursively count contents
          await for (var _ in Directory(path).list(recursive: true)) {
            count++;
          }
        } catch (_) {}
      }
    }
    return count;
  }

  void _updateProgress(String currentFile) {
    _itemsPasted++;
    pasteStatus = 'Pasting: $currentFile';
    if (_totalItemsToPaste > 0) {
      pasteProgress = _itemsPasted / _totalItemsToPaste;
    }
    notifyListeners();
  }

  Future<String?> pasteClipboard() async {
    if (clipboardPaths.isEmpty) return null;

    isPasting = true;
    pasteProgress = 0.0;
    pasteStatus = 'Calculating...';
    _cancelRequested = false;
    _pastedDestinationPaths.clear();
    _itemsPasted = 0;
    notifyListeners();

    try {
      _totalItemsToPaste = await _countTotalItems(clipboardPaths);

      for (final srcPath in clipboardPaths) {
        if (_cancelRequested) break;

        final entityName = srcPath.split('/').last;
        final destPath = '$currentPath/$entityName';

        // Duplicate Check Requirement
        if (await FileSystemEntity.type(destPath) !=
            FileSystemEntityType.notFound) {
          throw Exception('"$entityName" already exists here.');
        }

        final fileType = await FileSystemEntity.type(srcPath);

        if (fileType == FileSystemEntityType.file) {
          if (isCut) {
            await File(srcPath).rename(destPath);
          } else {
            await File(srcPath).copy(destPath);
          }
          _pastedDestinationPaths.add(destPath);
          _updateProgress(entityName);
        } else if (fileType == FileSystemEntityType.directory) {
          if (isCut) {
            try {
              await Directory(srcPath).rename(destPath);
              _pastedDestinationPaths.add(destPath);
              _updateProgress(entityName);
            } catch (e) {
              await Directory(destPath).create(recursive: true);
              _pastedDestinationPaths.add(destPath);
              _updateProgress(entityName);

              await _copyDirectory(Directory(srcPath), Directory(destPath));
              if (!_cancelRequested) {
                await Directory(srcPath).delete(recursive: true);
              }
            }
          } else {
            await Directory(destPath).create(recursive: true);
            _pastedDestinationPaths.add(destPath);
            _updateProgress(entityName);

            await _copyDirectory(Directory(srcPath), Directory(destPath));
          }
        }
      }

      if (_cancelRequested) {
        pasteStatus = 'Cancelling... Rolling back.';
        notifyListeners();
        // Rollback
        for (final pastedPath in _pastedDestinationPaths) {
          try {
            if (await FileSystemEntity.type(pastedPath) ==
                FileSystemEntityType.directory) {
              await Directory(pastedPath).delete(recursive: true);
            } else {
              await File(pastedPath).delete();
            }
          } catch (_) {}
        }
        isPasting = false;
        notifyListeners();
        return 'Pasting cancelled.';
      }

      // Success, cleanup state
      isPasting = false;
      cancelPaste();
      await _loadDirectory();
      return null; // Return null on success
    } catch (e) {
      isPasting = false;
      notifyListeners();
      debugPrint('Paste Error: $e');
      if (e.toString().contains('already exists here.')) {
        return e.toString().replaceAll('Exception: ', '');
      }
      return 'Failed to Paste: $e';
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (var entity in source.list(recursive: false)) {
      if (_cancelRequested) return;

      final name = entity.path.split('/').last;
      if (entity is Directory) {
        var newDir = Directory('${destination.path}/$name');
        await newDir.create(recursive: true);
        _updateProgress(name);
        await _copyDirectory(entity, newDir);
      } else if (entity is File) {
        await entity.copy('${destination.path}/$name');
        _updateProgress(name);
      }
    }
  }
}
