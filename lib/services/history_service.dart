import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryService {
  static const String key = "history";

  // Lấy lịch sử
  static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(key) ?? [];

    return data.map((e) => json.decode(e) as Map<String, dynamic>).toList();
  }

  // Thêm vào lịch sử
  static Future<void> addHistory(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(key) ?? [];

    // ❌ tránh trùng
    data.removeWhere((e) {
      final decoded = json.decode(e);
      return decoded["location_name"] == item["location_name"];
    });

    data.insert(0, json.encode(item)); // thêm lên đầu

    await prefs.setStringList(key, data);
  }

  // Xóa 1 item
  static Future<void> removeHistory(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(key) ?? [];

    data.removeWhere((e) {
      final decoded = json.decode(e);
      return decoded["location_name"] == name;
    });

    await prefs.setStringList(key, data);
  }

  // Xóa tất cả
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
