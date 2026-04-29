import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // 👇 Đổi thành IP máy tính của bạn khi test trên điện thoại thật
  // Dùng localhost nếu test trên emulator Android
  static const String baseUrl = 'http://10.0.2.2:8000'; // Android emulator
  // static const String baseUrl = 'http://localhost:8000'; // iOS simulator
  // static const String baseUrl = 'http://192.168.x.x:8000'; // Điện thoại thật

  static Future<Map<String, dynamic>?> predict(File imageFile) async {
    try {
      final uri = Uri.parse('$baseUrl/predict');
      final request = http.MultipartRequest('POST', uri);
      
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      ));

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Network error: $e');
      return null;
    }
  }
}