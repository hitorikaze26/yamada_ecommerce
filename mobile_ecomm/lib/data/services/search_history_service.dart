import 'package:shared_preferences/shared_preferences.dart';

/// Persists recent fashion search queries for the discovery experience.
class SearchHistoryService {
  SearchHistoryService._();

  static const _key = 'yamada_search_recent_v1';
  static const int _maxItems = 18;

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);
    if (raw == null) return [];
    return raw.where((e) => e.trim().isNotEmpty).toList();
  }

  static Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key)?.toList() ?? [];
    list.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    list.insert(0, q);
    while (list.length > _maxItems) {
      list.removeLast();
    }
    await prefs.setStringList(_key, list);
  }

  static Future<void> remove(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key)?.toList() ?? [];
    list.removeWhere((e) => e.toLowerCase() == query.toLowerCase());
    await prefs.setStringList(_key, list);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
