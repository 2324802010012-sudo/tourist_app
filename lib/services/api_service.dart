import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  // 👇 Đổi thành IP máy tính của bạn khi test trên điện thoại thật
  // Dùng localhost nếu test trên emulator Android
  //static const String baseUrl = 'http://10.0.2.2:8000'; // Android emulator
  //static const String baseUrl = 'http://localhost:8000'; // iOS simulator
  static const String baseUrl = 'http://192.168.101.17:8000'; // Điện thoại thật
  static const Duration timeout = Duration(seconds: 30);

  static Future<Map<String, dynamic>?> health() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (e) {
      debugPrint('Health check error: $e');
    }

    return null;
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
      } else {
        debugPrint('API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Network error: $e');
      return null;
    }
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
