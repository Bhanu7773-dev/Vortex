import 'package:flutter/material.dart';
import '../models/recent_model.dart';

class RecentViewModel extends ChangeNotifier {
  final String totalItemsText = '188 items in total';

  final List<RecentSectionModel> sections = [
    RecentSectionModel(
      title: 'Today',
      itemCount: 2,
      files: [
        RecentFileModel(
          name: 'Screenshot_2...3c400d.jpg',
          size: '194 KB',
          type: 'Pictures',
          dateGroup: 'Today',
        ),
        RecentFileModel(
          name: 'Screenshot_2...3c400d.jpg',
          size: '190 KB',
          type: 'Pictures',
          dateGroup: 'Today',
        ),
      ],
    ),
    RecentSectionModel(
      title: '1 day ago',
      itemCount: 11,
      files: [
        RecentFileModel(
          name: 'Screenshot_2...5d7980.jpg',
          size: '493 KB',
          type: 'Pictures',
          dateGroup: '1 day ago',
        ),
        RecentFileModel(
          name: 'VID_2026022...0.mp4',
          size: '2.2 MB',
          type: 'Movies',
          dateGroup: '1 day ago',
        ),
        RecentFileModel(
          name: 'IMG20260222174642.jpg',
          size: '4.6 MB',
          type: 'DCIM',
          dateGroup: '1 day ago',
        ),
        RecentFileModel(
          name: 'Veloxis Logo',
          size: '1.1 MB',
          type: 'Pictures',
          dateGroup: '1 day ago',
        ),
        RecentFileModel(
          name: 'Veloxis Banner',
          size: '1.4 MB',
          type: 'Pictures',
          dateGroup: '1 day ago',
        ),
        RecentFileModel(
          name: 'Chef Video.mp4',
          size: '12 MB',
          type: 'Movies',
          dateGroup: '1 day ago',
        ),
      ],
    ),
  ];
}
