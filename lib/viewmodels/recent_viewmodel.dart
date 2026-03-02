import 'dart:io';
import 'package:flutter/material.dart';
import '../models/recent_model.dart';
import '../services/transfer_service.dart';
import 'package:intl/intl.dart';

class RecentViewModel with ChangeNotifier {
  String totalItemsText = '0 received files';
  List<RecentSectionModel> sections = [];
  bool isLoading = true;
  bool _disposed = false;
  String receiveDirPath = '';

  RecentViewModel() {
    _loadReceivedFiles();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _loadReceivedFiles() async {
    isLoading = true;
    if (!_disposed) notifyListeners();

    final receiveDir = await TransferService.getReceiveDir();
    receiveDirPath = receiveDir.path;

    final List<File> allFiles = [];
    if (await receiveDir.exists()) {
      await _scanDir(receiveDir, allFiles, depth: 0);
    }
    if (_disposed) return;

    // Cache stats
    final Map<String, FileStat> statCache = {};
    for (var file in allFiles) {
      if (_disposed) return;
      try {
        statCache[file.path] = await file.stat();
      } catch (_) {}
    }

    // Sort by modification time descending (most recent first)
    allFiles.sort((a, b) {
      final statA = statCache[a.path];
      final statB = statCache[b.path];
      if (statA == null || statB == null) return 0;
      return statB.modified.compareTo(statA.modified);
    });

    // Limit to 100 most recent
    final recentFiles = allFiles.take(100).toList();

    // Group by date
    final Map<String, List<RecentFileModel>> groups = {};
    for (final file in recentFiles) {
      try {
        final stat = statCache[file.path] ?? await file.stat();
        final dateGroup = _getDateGroup(stat.modified);

        final model = RecentFileModel(
          name: file.path.split('/').last,
          path: file.path,
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

    // Sort sections (Today, Yesterday, then by date)
    const order = ['Today', 'Yesterday'];
    sections.sort((a, b) {
      final idxA = order.indexOf(a.title);
      final idxB = order.indexOf(b.title);
      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      return 0;
    });

    int total = 0;
    for (var s in sections) total += s.itemCount;
    totalItemsText = '$total received file${total == 1 ? '' : 's'}';

    isLoading = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> _scanDir(Directory dir, List<File> out, {int depth = 0}) async {
    if (depth > 6) return;
    if (out.length > 3000) return;

    try {
      final entities = await dir
          .list(recursive: false, followLinks: false)
          .toList();
      for (final e in entities) {
        if (_disposed) return;
        final name = e.path.split('/').last;
        if (name.startsWith('.')) continue;

        try {
          if (e is File) {
            out.add(e);
          } else if (e is Directory) {
            await _scanDir(e, out, depth: depth + 1);
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
