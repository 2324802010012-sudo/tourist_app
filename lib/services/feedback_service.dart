import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/location_model.dart';

class FeedbackService {
  static const String key = "recognition_feedback";

  static Future<void> submitFeedback({
    required Location location,
    required String verdict,
    required String userId,
    String? userEmail,
    String? correctedLabel,
    String? note,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(key) ?? [];
    final resultKey = [
      userId,
      location.predictedLabel,
      location.recognizedAt?.toIso8601String() ?? 'manual-detail',
    ].join('|');

    data.removeWhere((raw) {
      final item = json.decode(raw);
      return item is Map && item['result_key'] == resultKey;
    });

    data.insert(
      0,
      json.encode({
        'result_key': resultKey,
        'user_id': userId,
        'user_email': userEmail,
        'predicted_label': location.predictedLabel,
        'location_name': location.name,
        'confidence': location.confidence,
        'verdict': verdict,
        'corrected_label': correctedLabel,
        'note': note?.trim(),
        'created_at': DateTime.now().toIso8601String(),
      }),
    );

    await prefs.setStringList(key, data);
  }

  static Future<List<Map<String, dynamic>>> getFeedbacks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(key) ?? [];
    return data
        .map((raw) => json.decode(raw))
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
