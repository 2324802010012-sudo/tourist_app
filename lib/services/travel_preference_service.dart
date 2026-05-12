import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final saved = prefs.getStringList(_storageKey(uid)) ?? const [];
    return saved.where(options.contains).toList();
  }

  static Future<void> save(Iterable<String> preferences) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final cleaned = preferences
        .where(options.contains)
        .toSet()
        .toList(growable: false);
    await prefs.setStringList(_storageKey(uid), cleaned);
  }
}
