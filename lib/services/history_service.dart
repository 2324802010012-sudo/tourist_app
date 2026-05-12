import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryService {
  static const String key = "history";

  static String get _storageKey {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null ? "${key}_guest" : "${key}_$uid";
  }

  // Lấy lịch sử
  static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_storageKey) ?? [];

    return data.map((e) => json.decode(e) as Map<String, dynamic>).toList();
  }

  // Thêm vào lịch sử
  static Future<void> addHistory(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_storageKey) ?? [];
    final normalizedItem = Map<String, dynamic>.from(item);
    normalizedItem['recognized_at'] ??= DateTime.now().toIso8601String();

    // Tránh trùng địa điểm, lần quét mới nhất luôn nằm đầu danh sách.
    data.removeWhere((e) {
      final decoded = json.decode(e);
      return decoded["predicted_label"] == normalizedItem["predicted_label"] ||
          decoded["location_name"] == normalizedItem["location_name"];
    });

    data.insert(0, json.encode(normalizedItem));
    if (data.length > 50) {
      data.removeRange(50, data.length);
    }

    await prefs.setStringList(_storageKey, data);
  }

  // Xóa 1 item
  static Future<void> removeHistory(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_storageKey) ?? [];

    data.removeWhere((e) {
      final decoded = json.decode(e);
      return decoded["location_name"] == name ||
          decoded["predicted_label"] == name;
    });

    await prefs.setStringList(_storageKey, data);
  }

  // Xóa tất cả
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
