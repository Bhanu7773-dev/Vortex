class FileItemModel {
  final String name;
  final String path;
  final bool isDirectory;
  final int itemCount;
  final DateTime modifiedDate;
  final String categoryHint;

  FileItemModel({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.itemCount,
    required this.modifiedDate,
    this.categoryHint = '',
  });
}
