import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class FavoriteService {
  static const String key = "favorites";

  static String get _storageKey {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null ? "${key}_guest" : "${key}_$uid";
  }

  static Future<List<String>> getFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final synced = await ApiService.syncCurrentUser();
      if (synced) {
        final remote = await ApiService.getFavorites(user.uid);
        if (remote != null) return remote;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_storageKey) ?? [];
  }

  static Future<void> toggleFavorite(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final synced = await ApiService.syncCurrentUser();
      if (synced) {
        final current = await ApiService.isFavorite(user.uid, id);
        if (current != null) {
          await ApiService.setFavorite(user.uid, id, favorite: !current);
          return;
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_storageKey) ?? [];

    if (favorites.contains(id)) {
      favorites.remove(id);
    } else {
      favorites.add(id);
    }

    await prefs.setStringList(_storageKey, favorites);
  }

  static Future<bool> isFavorite(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final synced = await ApiService.syncCurrentUser();
      if (synced) {
        final remote = await ApiService.isFavorite(user.uid, id);
        if (remote != null) return remote;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_storageKey) ?? [];
    return favorites.contains(id);
  }
}
