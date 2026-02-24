import 'dart:io';
import 'package:flutter/material.dart';
import '../models/file_item_model.dart';
import '../services/persistence_service.dart';
import '../theme/app_theme.dart';

class TagFilesView extends StatefulWidget {
  final String tagName;
  const TagFilesView({Key? key, required this.tagName}) : super(key: key);

  @override
  State<TagFilesView> createState() => _TagFilesViewState();
}

class _TagFilesViewState extends State<TagFilesView> {
  final PersistenceService _persistence = PersistenceService();
  List<FileItemModel> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTaggedItems();
  }

  Future<void> _loadTaggedItems() async {
    final mappings = await _persistence.loadTagMappings();
    final paths = mappings[widget.tagName] ?? [];

    List<FileItemModel> loadedItems = [];
    for (final path in paths) {
      final file = File(path);
      final dir = Directory(path);
      if (await file.exists()) {
        final stat = await file.stat();
        loadedItems.add(
          FileItemModel(
            name: path.split('/').last,
            path: path,
            isDirectory: false,
            itemCount: 0,
            modifiedDate: stat.modified,
          ),
        );
      } else if (await dir.exists()) {
        final stat = await dir.stat();
        loadedItems.add(
          FileItemModel(
            name: path.split('/').last,
            path: path,
            isDirectory: true,
            itemCount: dir.listSync().length,
            modifiedDate: stat.modified,
          ),
        );
      }
    }

    setState(() {
      _items = loadedItems;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.tagName)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(
              child: Text(
                'No items in this tag',
                style: TextStyle(color: AppTheme.textGrey),
              ),
            )
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return ListTile(
                  leading: Icon(
                    item.isDirectory ? Icons.folder : Icons.insert_drive_file,
                    color: item.isDirectory ? AppTheme.accentBlue : Colors.grey,
                  ),
                  title: Text(
                    item.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    item.isDirectory ? '${item.itemCount} items' : 'File',
                    style: const TextStyle(color: AppTheme.textGrey),
                  ),
                );
              },
            ),
    );
  }
}
