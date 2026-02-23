import 'dart:io';
import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../services/storage_service.dart';

class HomeViewModel extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  // Storage Stats
  String totalStorage = '...';
  String usedStorage = '...';
  double storagePercentage = 0.0;
  bool isLoadingStats = true;

  // Categories Grid Data (starts with placeholders, updated after scan)
  List<CategoryModel> categories = [
    CategoryModel(
      name: 'Photos',
      icon: Icons.image,
      iconColor: Colors.blue,
      info: '...',
    ),
    CategoryModel(
      name: 'Videos',
      icon: Icons.video_camera_back,
      iconColor: Colors.purpleAccent,
      info: '...',
    ),
    CategoryModel(
      name: 'Audio',
      icon: Icons.music_note,
      iconColor: Colors.orange,
      info: '...',
    ),
    CategoryModel(
      name: 'Documents',
      icon: Icons.insert_drive_file,
      iconColor: Colors.lightBlue,
      info: '...',
    ),
    CategoryModel(
      name: 'APKs',
      icon: Icons.android,
      iconColor: Colors.green,
      info: '...',
    ),
    CategoryModel(
      name: 'Archives',
      icon: Icons.inventory_2,
      iconColor: Colors.brown,
      info: '...',
    ),
  ];

  HomeViewModel() {
    loadStorageData();
  }

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
    'svg',
  };
  static const _videoExts = {
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
  static const _audioExts = {
    'mp3',
    'wav',
    'flac',
    'aac',
    'ogg',
    'm4a',
    'wma',
    'opus',
    'amr',
  };
  static const _docExts = {
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'csv',
    'odt',
    'ods',
    'odp',
    'rtf',
    'epub',
  };
  static const _apkExts = {'apk', 'aab', 'xapk'};
  static const _archiveExts = {
    'zip',
    'rar',
    '7z',
    'tar',
    'gz',
    'bz2',
    'xz',
    'iso',
    'dmg',
  };

  void _countFile(String ext, List<int> out) {
    if (_photoExts.contains(ext)) {
      out[0]++;
    } else if (_videoExts.contains(ext)) {
      out[1]++;
    } else if (_audioExts.contains(ext)) {
      out[2]++;
    } else if (_docExts.contains(ext)) {
      out[3]++;
    } else if (_apkExts.contains(ext)) {
      out[4]++;
    } else if (_archiveExts.contains(ext)) {
      out[5]++;
    }
  }

  Future<void> _scanDir(Directory dir, List<int> counts) async {
    try {
      await for (final entity in dir.list(
        recursive: false,
        followLinks: false,
      )) {
        if (entity is File) {
          _countFile(entity.path.split('.').last.toLowerCase(), counts);
        } else if (entity is Directory) {
          final name = entity.path.split('/').last;
          // Skip known fully-restricted subtrees to save time
          if (name == 'Android') continue;
          await _scanDir(entity, counts);
        }
      }
    } catch (_) {
      // This directory is restricted or inaccessible — skip it
    }
  }

  Future<void> _scanCategoryCounts() async {
    final root = Directory('/storage/emulated/0');
    if (!await root.exists()) return;

    // Index: [photos, videos, audio, docs, apks, archives]
    final counts = [0, 0, 0, 0, 0, 0];
    await _scanDir(root, counts);

    categories = [
      CategoryModel(
        name: 'Photos',
        icon: Icons.image,
        iconColor: Colors.blue,
        info: counts[0].toString(),
      ),
      CategoryModel(
        name: 'Videos',
        icon: Icons.video_camera_back,
        iconColor: Colors.purpleAccent,
        info: counts[1].toString(),
      ),
      CategoryModel(
        name: 'Audio',
        icon: Icons.music_note,
        iconColor: Colors.orange,
        info: counts[2].toString(),
      ),
      CategoryModel(
        name: 'Documents',
        icon: Icons.insert_drive_file,
        iconColor: Colors.lightBlue,
        info: counts[3].toString(),
      ),
      CategoryModel(
        name: 'APKs',
        icon: Icons.android,
        iconColor: Colors.green,
        info: counts[4].toString(),
      ),
      CategoryModel(
        name: 'Archives',
        icon: Icons.inventory_2,
        iconColor: Colors.brown,
        info: counts[5].toString(),
      ),
    ];
    notifyListeners();
  }

  Future<void> loadStorageData() async {
    isLoadingStats = true;
    notifyListeners();

    bool hasPermission = await _storageService.requestStoragePermission();

    if (hasPermission) {
      double totalGB = await _storageService.getTotalDiskSpaceGB();
      double usedGB = await _storageService.getUsedDiskSpaceGB();

      totalStorage = '${totalGB.toStringAsFixed(1)} GB';
      usedStorage = '${usedGB.toStringAsFixed(1)} GB';

      if (totalGB > 0) {
        storagePercentage = usedGB / totalGB;
      }

      // Kick off category scan in parallel — UI updates automatically when done
      _scanCategoryCounts();
    } else {
      totalStorage = 'Permission Denied';
      usedStorage = '0 GB';
      storagePercentage = 0.0;
    }

    isLoadingStats = false;
    notifyListeners();
  }

  // Expandable Sections Data
  final List<ExpandableSectionModel> sections = [
    ExpandableSectionModel(
      title: 'Sources',
      items: [
        ExpandableItemModel(
          title: 'Bluetooth',
          icon: Icons.bluetooth,
          iconColor: Colors.blue,
        ),
        ExpandableItemModel(
          title: 'Downloads',
          icon: Icons.download,
          iconColor: Colors.green,
        ),
      ],
    ),
    ExpandableSectionModel(
      title: 'Quick access',
      items: [
        ExpandableItemModel(
          title: 'Add folder',
          icon: Icons.add_circle_outline,
        ),
      ],
    ),
    ExpandableSectionModel(
      title: 'Tag',
      items: [
        ExpandableItemModel(
          title: 'Important',
          icon: Icons.bookmark_border,
          trailingInfo: '0',
        ),
        ExpandableItemModel(
          title: 'Work',
          icon: Icons.bookmark_border,
          trailingInfo: '0',
        ),
        ExpandableItemModel(
          title: 'Study',
          icon: Icons.bookmark_border,
          trailingInfo: '0',
        ),
        ExpandableItemModel(
          title: 'Life',
          icon: Icons.bookmark_border,
          trailingInfo: '0',
        ),
        ExpandableItemModel(title: 'Create', icon: Icons.add_circle_outline),
      ],
    ),
  ];
}
