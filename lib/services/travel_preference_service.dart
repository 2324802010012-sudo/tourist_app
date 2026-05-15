import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class TravelPreferenceService {
  static const List<String> options = [
    "Di sản lịch sử",
    "Thiên nhiên",
    "Check-in",
    "Ẩm thực",
    "Gia đình",
    "Trải nghiệm tiết kiệm",
  ];

  static String _storageKey(String? uid) {
    return uid == null ? "travel_preferences_guest" : "travel_preferences_$uid";
  }

  static Future<List<String>> load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final synced = await ApiService.syncCurrentUser();
      if (synced) {
        final remote = await ApiService.getPreferences(user.uid);
        if (remote != null) {
          return remote.where(options.contains).toList();
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final uid = user?.uid;
    final saved = prefs.getStringList(_storageKey(uid)) ?? const [];
    return saved.where(options.contains).toList();
  }

  static Future<void> save(Iterable<String> preferences) async {
    final user = FirebaseAuth.instance.currentUser;
    final cleaned = preferences
        .where(options.contains)
        .toSet()
        .toList(growable: false);

    if (user != null) {
      final synced = await ApiService.syncCurrentUser();
      if (synced) {
        final remote = await ApiService.savePreferences(user.uid, cleaned);
        if (remote != null) return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final uid = user?.uid;
    await prefs.setStringList(_storageKey(uid), cleaned);
  }
}
