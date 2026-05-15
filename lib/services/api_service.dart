import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  // Đổi thành IP máy tính của bạn khi test trên điện thoại thật.
  // static const String baseUrl = 'http://10.0.2.2:8000'; // Android emulator
  // static const String baseUrl = 'http://localhost:8000'; // iOS simulator
  static const String baseUrl = 'http://192.168.101.17:8000';
  static const Duration timeout = Duration(seconds: 30);
  static const Duration jsonTimeout = Duration(seconds: 8);

  static Future<Map<String, dynamic>?> health() async {
    final decoded = await _getJson('/health', timeoutOverride: 8);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  static Future<List<Map<String, dynamic>>?> getLocations() async {
    final decoded = await _getJson('/locations');
    if (decoded is! List) return null;
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<Map<String, dynamic>?> predict(File imageFile) async {
    try {
      final uri = Uri.parse('$baseUrl/predict');
      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          contentType: _imageContentType(imageFile.path),
        ),
      );

      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        return null;
      }

      debugPrint('API error: ${response.statusCode} - ${response.body}');
    } catch (e) {
      debugPrint('Network error: $e');
    }

    return null;
  }

  static Future<bool> syncCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return false;

    final response = await _sendJson(
      'POST',
      '/users/sync',
      body: {
        'firebase_uid': user.uid,
        'email': user.email,
        'full_name': user.displayName,
        'avatar_url': user.photoURL,
        'phone_number': user.phoneNumber,
      },
    );
    return response is Map;
  }

  static Future<List<String>?> getPreferences(String firebaseUid) async {
    final decoded = await _getJson('/users/$firebaseUid/preferences');
    if (decoded is! List) return null;
    return decoded.map((item) => item.toString()).toList();
  }

  static Future<List<String>?> savePreferences(
    String firebaseUid,
    Iterable<String> preferences,
  ) async {
    final decoded = await _sendJson(
      'PUT',
      '/users/$firebaseUid/preferences',
      body: {'preferences': preferences.toList()},
    );
    if (decoded is! List) return null;
    return decoded.map((item) => item.toString()).toList();
  }

  static Future<List<String>?> getFavorites(String firebaseUid) async {
    final decoded = await _getJson('/users/$firebaseUid/favorites');
    if (decoded is! List) return null;
    return decoded.map((item) => item.toString()).toList();
  }

  static Future<bool?> isFavorite(String firebaseUid, String placeCode) async {
    final decoded = await _getJson('/users/$firebaseUid/favorites/$placeCode');
    if (decoded is Map && decoded['is_favorite'] is bool) {
      return decoded['is_favorite'] as bool;
    }
    return null;
  }

  static Future<bool?> setFavorite(
    String firebaseUid,
    String placeCode, {
    required bool favorite,
  }) async {
    final decoded = await _sendJson(
      favorite ? 'PUT' : 'DELETE',
      '/users/$firebaseUid/favorites/$placeCode',
    );
    if (decoded is Map && decoded['is_favorite'] is bool) {
      return decoded['is_favorite'] as bool;
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>?> getHistories(
    String firebaseUid,
  ) async {
    final decoded = await _getJson('/users/$firebaseUid/recognition-histories');
    if (decoded is! List) return null;
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<Map<String, dynamic>?> createHistory(
    Map<String, dynamic> item, {
    String? firebaseUid,
  }) async {
    final decoded = await _sendJson(
      'POST',
      '/recognition-histories',
      body: {
        'firebase_uid': firebaseUid,
        'predicted_label': item['predicted_label'],
        'confidence': item['confidence'],
        'is_confident':
            item['is_confident'] ??
            ((item['confidence'] is num)
                ? (item['confidence'] as num).toDouble() >= 0.7
                : false),
        'recognition_status': item['recognition_status'] ?? 'success',
        'recognized_at': item['recognized_at'],
        'image_url': item['image_url'],
        'image_hash': item['image_hash'],
        'top3': item['top3'] ?? const [],
      },
    );
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  static Future<bool> removeHistoriesForPlace(
    String firebaseUid,
    String placeCode,
  ) async {
    final decoded = await _sendJson(
      'DELETE',
      '/users/$firebaseUid/recognition-histories/$placeCode',
    );
    return decoded is Map;
  }

  static Future<bool> clearHistories(String firebaseUid) async {
    final decoded = await _sendJson(
      'DELETE',
      '/users/$firebaseUid/recognition-histories',
    );
    return decoded is Map;
  }

  static Future<Map<String, dynamic>?> submitFeedback({
    required String firebaseUid,
    required String predictedLabel,
    required String verdict,
    int? historyId,
    String? correctedLabel,
    String? feedbackContent,
  }) async {
    final decoded = await _sendJson(
      'POST',
      '/recognition-feedbacks',
      body: {
        'firebase_uid': firebaseUid,
        'predicted_label': predictedLabel,
        'corrected_label': correctedLabel,
        'history_id': historyId,
        'verdict': verdict,
        'feedback_content': feedbackContent,
      },
    );
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  static Future<dynamic> _getJson(String path, {int? timeoutOverride}) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$path'))
          .timeout(Duration(seconds: timeoutOverride ?? jsonTimeout.inSeconds));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      }
      debugPrint('GET $path failed: ${response.statusCode} - ${response.body}');
    } catch (e) {
      debugPrint('GET $path error: $e');
    }
    return null;
  }

  static Future<dynamic> _sendJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      late final http.Response response;
      final headers = {'Content-Type': 'application/json'};
      final encodedBody = body == null ? null : json.encode(body);

      if (method == 'POST') {
        response = await http
            .post(uri, headers: headers, body: encodedBody)
            .timeout(jsonTimeout);
      } else if (method == 'PUT') {
        response = await http
            .put(uri, headers: headers, body: encodedBody)
            .timeout(jsonTimeout);
      } else if (method == 'DELETE') {
        response = await http
            .delete(uri, headers: headers, body: encodedBody)
            .timeout(jsonTimeout);
      } else {
        throw ArgumentError('Unsupported method: $method');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return const {};
        return json.decode(response.body);
      }
      debugPrint(
        '$method $path failed: ${response.statusCode} - ${response.body}',
      );
    } catch (e) {
      debugPrint('$method $path error: $e');
    }
    return null;
  }

  static MediaType _imageContentType(String path) {
    final extension = path.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      _ => MediaType('application', 'octet-stream'),
    };
  }
}
