import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../theme/app_theme.dart';

class HomeViewModel extends ChangeNotifier {
  // Storage Stats
  final String totalStorage = '64.0 GB';
  final String usedStorage = '56.5 GB';
  final double storagePercentage = 56.5 / 64.0;

  // Categories Grid Data
  final List<CategoryModel> categories = [
    CategoryModel(
      name: 'Photos',
      icon: Icons.image,
      iconColor: Colors.blue,
      info: '185',
    ),
    CategoryModel(
      name: 'Videos',
      icon: Icons.video_camera_back,
      iconColor: Colors.purpleAccent,
      info: '47',
    ),
    CategoryModel(
      name: 'Audio',
      icon: Icons.music_note,
      iconColor: Colors.orange,
      info: '13',
    ),
    CategoryModel(
      name: 'Documents',
      icon: Icons.insert_drive_file,
      iconColor: Colors.lightBlue,
      info: '73',
    ),
    CategoryModel(
      name: 'APKs',
      icon: Icons.android,
      iconColor: Colors.green,
      info: '2',
    ),
    CategoryModel(
      name: 'Archives',
      icon: Icons.inventory_2,
      iconColor: Colors.brown,
      info: '10',
    ),
    CategoryModel(
      name: 'Apps',
      icon: Icons.grid_view,
      iconColor: AppTheme.accentBlue,
      info: '53',
      badgeCount: 10,
    ),
  ];

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
