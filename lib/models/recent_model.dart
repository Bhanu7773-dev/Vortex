class RecentFileModel {
  final String name;
  final String path;
  final String size;
  final String type;
  final String dateGroup;

  RecentFileModel({
    required this.name,
    required this.path,
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
