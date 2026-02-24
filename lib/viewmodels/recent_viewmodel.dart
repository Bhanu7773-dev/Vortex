import 'dart:io';
import 'package:flutter/material.dart';
import '../models/recent_model.dart';
import '../services/storage_service.dart';
import 'package:intl/intl.dart';

class RecentViewModel with ChangeNotifier {
  String totalItemsText = '0 items in total';
  List<RecentSectionModel> sections = [];
  bool isLoading = true;

  RecentViewModel() {
    _loadRecentFiles();
  }

  Future<void> _loadRecentFiles() async {
    isLoading = true;
    notifyListeners();

    final List<File> allFiles = [];
    final volumes = await StorageService().getStorageVolumes();

    for (final vol in volumes) {
      final root = Directory(vol.path);
      if (await root.exists()) {
        await _scanDir(root, allFiles);
      }
    }

    // Sort by modification time descending
    allFiles.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );

    // Limit to 100 most recent files for performance
    final recentFiles = allFiles.take(100).toList();

    // Group by date
    final Map<String, List<RecentFileModel>> groups = {};
    for (final file in recentFiles) {
      try {
        final stat = file.statSync();
        final dateGroup = _getDateGroup(stat.modified);

        final model = RecentFileModel(
          name: file.path.split('/').last,
          size: _formatSize(stat.size),
          type: file.path.split('.').last.toUpperCase(),
          dateGroup: dateGroup,
        );

        groups.putIfAbsent(dateGroup, () => []).add(model);
      } catch (_) {}
    }

    sections = groups.entries
        .map(
          (e) => RecentSectionModel(
            title: e.key,
            itemCount: e.value.length,
            files: e.value,
          ),
        )
        .toList();

    // Sort sections (Today, Yesterday, etc.) - Actually the order of groups usually follows the sorted files
    // But to be sure:
    const order = ['Today', 'Yesterday'];
    sections.sort((a, b) {
      final idxA = order.indexOf(a.title);
      final idxB = order.indexOf(b.title);
      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      return 0; // Or compare by actual dates if needed
    });

    int total = 0;
    for (var s in sections) total += s.itemCount;
    totalItemsText = '$total items in total';

    isLoading = false;
    notifyListeners();
  }

  Future<void> _scanDir(Directory dir, List<File> out) async {
    try {
      final entities = await dir
          .list(recursive: false, followLinks: false)
          .toList();
      for (final e in entities) {
        try {
          if (e is File) {
            out.add(e);
          } else if (e is Directory) {
            final name = e.path.split('/').last;
            if (name == 'Android') {
              final media = Directory('${e.path}/media');
              if (media.existsSync()) await _scanDir(media, out);
            } else {
              await _scanDir(e, out);
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  String _getDateGroup(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.day == yesterday.day &&
        date.month == yesterday.month &&
        date.year == yesterday.year) {
      return 'Yesterday';
    }
    return DateFormat('MMMM d, yyyy').format(date);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }
}
