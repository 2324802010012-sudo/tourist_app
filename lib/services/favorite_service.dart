import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteService {
  static const String key = "favorites";

  static String get _storageKey {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null ? "${key}_guest" : "${key}_$uid";
  }

  // Lấy danh sách id đã lưu
  static Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_storageKey) ?? [];
  }

  // Toggle (thêm/xóa)
  static Future<void> toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList(_storageKey) ?? [];

    if (favorites.contains(id)) {
      favorites.remove(id);
    } else {
      favorites.add(id);
    }

    await prefs.setStringList(_storageKey, favorites);
  }

  // Check có phải favorite không
  static Future<bool> isFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList(_storageKey) ?? [];
    return favorites.contains(id);
  }
}
