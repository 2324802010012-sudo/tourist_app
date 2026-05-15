import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class HistoryService {
  static const String key = "history";

  static String get _storageKey {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null ? "${key}_guest" : "${key}_$uid";
  }

  static Future<List<Map<String, dynamic>>> getHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final synced = await ApiService.syncCurrentUser();
      if (synced) {
        final remote = await ApiService.getHistories(user.uid);
        if (remote != null) return remote;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_storageKey) ?? [];
    return data.map((e) => json.decode(e) as Map<String, dynamic>).toList();
  }

  static Future<Map<String, dynamic>> addHistory(
    Map<String, dynamic> item,
  ) async {
    final normalizedItem = Map<String, dynamic>.from(item);
    normalizedItem['recognized_at'] ??= DateTime.now().toIso8601String();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final synced = await ApiService.syncCurrentUser();
      if (synced) {
        final remote = await ApiService.createHistory(
          normalizedItem,
          firebaseUid: user.uid,
        );
        if (remote != null) return remote;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_storageKey) ?? [];

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
    return normalizedItem;
  }

  static Future<void> removeHistory(String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final synced = await ApiService.syncCurrentUser();
      if (synced) {
        final removed = await ApiService.removeHistoriesForPlace(
          user.uid,
          name,
        );
        if (removed) return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_storageKey) ?? [];

    data.removeWhere((e) {
      final decoded = json.decode(e);
      return decoded["location_name"] == name ||
          decoded["predicted_label"] == name;
    });

    await prefs.setStringList(_storageKey, data);
  }

  static Future<void> clearHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final synced = await ApiService.syncCurrentUser();
      if (synced) {
        final cleared = await ApiService.clearHistories(user.uid);
        if (cleared) return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
