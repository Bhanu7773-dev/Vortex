class RecentFileModel {
  final String name;
  final String size;
  final String type;
  final String dateGroup; // 'Today', '1 day ago', etc.

  RecentFileModel({
    required this.name,
    required this.size,
    required this.type,
    required this.dateGroup,
  });
}

class RecentSectionModel {
  final String title;
  final int itemCount;
  final List<RecentFileModel> files;

  RecentSectionModel({
    required this.title,
    required this.itemCount,
    required this.files,
  });
}
