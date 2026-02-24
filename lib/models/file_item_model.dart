class FileItemModel {
  final String name;
  final String path;
  final bool isDirectory;
  final int itemCount; // Valid if isDirectory == true
  final DateTime modifiedDate;
  final String categoryHint; // e.g. 'Downloads', 'Documents' for custom icons

  FileItemModel({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.itemCount,
    required this.modifiedDate,
    this.categoryHint = '',
  });
}
