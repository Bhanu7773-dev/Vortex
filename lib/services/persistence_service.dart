import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PersistenceService {
  static const _keyQuickAccess = 'quick_access_paths';
  static const _keyTags = 'tag_mappings';

  Future<void> saveQuickAccessPaths(List<String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyQuickAccess, paths);
  }

  Future<List<String>> loadQuickAccessPaths() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyQuickAccess) ?? [];
  }

  Future<void> saveTagMappings(Map<String, List<String>> mappings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTags, jsonEncode(mappings));
  }

  Future<Map<String, List<String>>> loadTagMappings() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyTags);
    if (data == null) return {};
    try {
      final Map<String, dynamic> decoded = jsonDecode(data);
      return decoded.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> addPathToTag(String tagName, String path) async {
    final mappings = await loadTagMappings();
    final paths = mappings[tagName] ?? [];
    if (!paths.contains(path)) {
      paths.add(path);
      mappings[tagName] = paths;
      await saveTagMappings(mappings);
    }
  }
}
