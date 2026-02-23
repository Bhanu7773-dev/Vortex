import 'dart:io';
import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../models/storage_volume_model.dart';
import '../services/storage_service.dart';
import '../services/persistence_service.dart';
import '../views/all_files_view.dart';
import '../views/tag_files_view.dart';

class HomeViewModel extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final PersistenceService _persistenceService = PersistenceService();

  // Storage Stats
  String totalStorage = '...';
  String usedStorage = '...';
  double storagePercentage = 0.0;
  bool isLoadingStats = true;
  bool isPermissionGranted = false;
  bool isPermissionDenied = false;
  bool hasFullAccess = false;
  Map<String, bool> permissionStatus = {};
  List<StorageVolume> availableVolumes = [];

  HomeViewModel() {
    _init();
  }

  Future<void> _init() async {
    await checkAndRequestPermissions();
    _loadPersistentData();
  }

  Future<void> checkAndRequestPermissions() async {
    isPermissionGranted = await _storageService.requestStoragePermission();
    isPermissionDenied = !isPermissionGranted;
    if (isPermissionGranted) {
      loadStorageData();
    }
    notifyListeners();
  }

  // Categories Grid Data
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

  // Sections
  List<ExpandableSectionModel> sections = [
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

  Future<void> _loadPersistentData() async {
    final quickPaths = await _persistenceService.loadQuickAccessPaths();
    final tagMappings = await _persistenceService.loadTagMappings();
    _updateSections(quickPaths, tagMappings);
    notifyListeners();
  }

  void _updateSections(
    List<String> quickPaths,
    Map<String, List<String>> tagMappings,
  ) {
    sections = [
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
          ...quickPaths.map((p) {
            String name = p.split('/').last;
            if (p == '/storage/emulated/0') name = 'Internal Storage';
            return ExpandableItemModel(
              title: name,
              icon: Icons.folder,
              iconColor: Colors.blue,
            );
          }),
          ExpandableItemModel(
            title: 'Add folder',
            icon: Icons.add_circle_outline,
          ),
        ],
      ),
      ExpandableSectionModel(
        title: 'Tag',
        items: [
          ...tagMappings.entries.map(
            (e) => ExpandableItemModel(
              title: e.key,
              icon: Icons.bookmark_border,
              trailingInfo: e.value.length.toString(),
            ),
          ),
          ExpandableItemModel(title: 'Create', icon: Icons.add_circle_outline),
        ],
      ),
    ];
  }

  // Navigation helpers
  void onSectionItemTap(
    BuildContext context,
    String sectionTitle,
    String itemTitle,
  ) async {
    if (sectionTitle == 'Sources') {
      _navigateToSource(context, itemTitle);
    } else if (itemTitle == 'Add folder') {
      await _addQuickAccessFolder(context);
      _loadPersistentData();
    } else if (sectionTitle == 'Quick access') {
      _navigateToPath(
        context,
        itemTitle,
      ); // items in this section are folder names
    } else if (sectionTitle == 'Tag') {
      if (itemTitle == 'Create') {
        _createTag(context);
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TagFilesView(tagName: itemTitle)),
        );
        _loadPersistentData(); // Refresh counts when returning
      }
    }
  }

  Future<void> _addQuickAccessFolder(BuildContext context) async {
    final List<String>? selectedPaths = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AllFilesView(
          isFolderPickerMode: true,
          initialPath: availableVolumes.isNotEmpty
              ? availableVolumes.first.path
              : '/storage/emulated/0',
        ),
      ),
    );

    if (selectedPaths != null && selectedPaths.isNotEmpty) {
      final paths = await _persistenceService.loadQuickAccessPaths();
      for (final p in selectedPaths) {
        if (!paths.contains(p)) {
          paths.add(p);
        }
      }
      await _persistenceService.saveQuickAccessPaths(paths);
      _loadPersistentData(); // Refresh Home screen
    }
  }

  Future<void> removeQuickAccessByTitle(String title) async {
    final paths = await _persistenceService.loadQuickAccessPaths();
    final path = paths.firstWhere(
      (p) =>
          p.split('/').last == title ||
          (p == '/storage/emulated/0' && title == 'Internal Storage'),
      orElse: () => '',
    );
    if (path.isNotEmpty) {
      if (paths.remove(path)) {
        await _persistenceService.saveQuickAccessPaths(paths);
        _loadPersistentData();
      }
    }
  }

  Future<void> removeQuickAccessFolder(String path) async {
    final paths = await _persistenceService.loadQuickAccessPaths();
    if (paths.remove(path)) {
      await _persistenceService.saveQuickAccessPaths(paths);
      _loadPersistentData();
    }
  }

  Future<void> removeTag(String tagName) async {
    final mappings = await _persistenceService.loadTagMappings();
    if (mappings.remove(tagName) != null) {
      await _persistenceService.saveTagMappings(mappings);
      _loadPersistentData();
    }
  }

  void _navigateToPath(BuildContext context, String title) async {
    // In Quick Access, title is the folder name. We need to find the path.
    final paths = await _persistenceService.loadQuickAccessPaths();
    final path = paths.firstWhere(
      (p) =>
          p.split('/').last == title ||
          (p == '/storage/emulated/0' && title == 'Internal Storage'),
      orElse: () => '',
    );
    if (path.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AllFilesView(initialPath: path)),
      );
      _loadPersistentData();
    }
  }

  void _navigateToSource(BuildContext context, String title) async {
    String path = '';
    if (title == 'Bluetooth')
      path = '/storage/emulated/0/Bluetooth';
    else if (title == 'Downloads')
      path = '/storage/emulated/0/Download';

    if (path.isNotEmpty && Directory(path).existsSync()) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AllFilesView(initialPath: path)),
      );
      _loadPersistentData();
    } else if (path.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$title folder not found')));
    }
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
        try {
          if (entity is File) {
            _countFile(entity.path.split('.').last.toLowerCase(), counts);
          } else if (entity is Directory) {
            final name = entity.path.split('/').last;
            // Skip known fully-restricted subtrees to save time
            if (name == 'Android') continue;
            await _scanDir(entity, counts);
          }
        } catch (_) {}
      }
    } catch (_) {
      // This directory is restricted or inaccessible — skip it
    }
  }

  Future<void> _scanCategoryCounts() async {
    final volumes = await _storageService.getStorageVolumes();
    availableVolumes = volumes;

    // Index: [photos, videos, audio, docs, apks, archives]
    final counts = [0, 0, 0, 0, 0, 0];

    for (final vol in volumes) {
      final root = Directory(vol.path);
      if (await root.exists()) {
        await _scanDir(root, counts);
      }
    }

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
    permissionStatus = await _storageService.getPermissionStatus();
    hasFullAccess = await _storageService.hasAllFilesAccess();

    if (hasPermission) {
      isPermissionGranted = true;
      isPermissionDenied = false;

      double totalGB = await _storageService.getTotalDiskSpaceGB();
      double usedGB = await _storageService.getUsedDiskSpaceGB();

      totalStorage = '${totalGB.toStringAsFixed(1)} GB';
      usedStorage = '${usedGB.toStringAsFixed(1)} GB';

      if (totalGB > 0) {
        storagePercentage = usedGB / totalGB;
      }

      _scanCategoryCounts();
    } else {
      isPermissionGranted = false;
      isPermissionDenied = true;
      totalStorage = 'Permission Denied';
      usedStorage = '0 GB';
      storagePercentage = 0.0;
    }

    isLoadingStats = false;
    notifyListeners();
  }

  Future<void> _createTag(BuildContext context) async {
    final TextEditingController ctrl = TextEditingController();
    final String? tagName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Tag'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter tag name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (tagName != null && tagName.isNotEmpty) {
      final mappings = await _persistenceService.loadTagMappings();
      if (!mappings.containsKey(tagName)) {
        mappings[tagName] = [];
        await _persistenceService.saveTagMappings(mappings);
        _loadPersistentData();
      }
    }
  }
}
