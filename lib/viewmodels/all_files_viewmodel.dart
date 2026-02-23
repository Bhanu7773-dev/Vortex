import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/file_item_model.dart';

enum SortOption { dateModified, size, filename, type }

class AllFilesViewModel extends ChangeNotifier {
  final String currentPath = '/storage/emulated/0';
  List<FileItemModel> items = [];
  bool isLoading = true;

  SortOption currentSort = SortOption.filename;
  bool isDescending = false; // Default: A-Z

  String get itemCountString {
    if (items.isEmpty) return '0 items in total';

    final folderCount = items.where((i) => i.isDirectory).length;
    final fileCount = items.length - folderCount;

    if (fileCount == 0 && folderCount > 0) {
      return '$folderCount folder${folderCount == 1 ? '' : 's'} in total';
    }

    return '${items.length} items in total';
  }

  AllFilesViewModel() {
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    isLoading = true;
    notifyListeners();

    // Check permission safely - fallback if permission wasn't fully granted beforehand
    if (await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted) {
      final dir = Directory(currentPath);

      try {
        if (await dir.exists()) {
          final entities = dir.listSync(recursive: false, followLinks: false);

          items = [];

          for (var entity in entities) {
            final isDir = entity is Directory;
            int count = 0;

            // For folders, count their immediate children
            if (isDir) {
              try {
                // Ignore hidden folders for speed or permission exceptions
                if (!entity.path.split('/').last.startsWith('.')) {
                  count = entity.listSync(recursive: false).length;
                }
              } catch (e) {
                // Permission denied for specific nested directory, skip count
              }
            }

            final stat = await entity.stat();
            final name = entity.path.split('/').last;

            // Optional: skip hidden files/directories entirely (starts with .)
            if (!name.startsWith('.')) {
              items.add(
                FileItemModel(
                  name: name,
                  path: entity.path,
                  isDirectory: isDir,
                  itemCount: count,
                  modifiedDate: stat.modified,
                  categoryHint: _inferCategory(name),
                ),
              );
            }
          }

          _applySorting();
        }
      } catch (e) {
        // Handle read error gracefully
      }
    }

    isLoading = false;
    notifyListeners();
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
}
