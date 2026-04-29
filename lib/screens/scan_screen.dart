import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'detail_screen.dart';
import 'dart:math';
import 'fail_result_screen.dart';
import '../models/location_model.dart';
import '../services/history_service.dart';
import '../services/api_service.dart';

// 🎨 THEME
const primaryGradient = LinearGradient(
  colors: [
    Color.fromARGB(255, 120, 226, 138),
    Color.fromARGB(255, 86, 167, 244),
  ],
);

class ScanScreen extends StatefulWidget {
  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  File? _image;
  bool isLoading = false;

  final picker = ImagePicker();
  // 📸 PICK IMAGE
  Future<void> pickImage(ImageSource source) async {
    try {
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          isLoading = true;
        });

        await simulateAI();
      }
    } catch (e) {
      setState(() => isLoading = false);
      print("Pick image error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🖼️ BACKGROUND
          Positioned.fill(
            child: Image.asset("assets/images/bg_scan.png", fit: BoxFit.cover),
          ),

          // 🌫️ LÀM MỜ BACKGROUND (QUAN TRỌNG)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 8),
              child: Container(color: Colors.black.withOpacity(0.25)),
            ),
          ),

          // 📱 CONTENTS
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                children: [
                  // 🔙 HEADER
                  Row(
                    children: [
                      _glassIcon(Icons.arrow_back, () {
                        Navigator.pop(context);
                      }),
                      SizedBox(width: 10),
                      Text(
                        "Scan",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  // 👉 ĐẨY XUỐNG
                  Spacer(),

                  // 📸 SCAN CARD
                  _scanCard(),

                  SizedBox(height: 70),

                  // 📘 GUIDE
                  _guideCard(),

                  SizedBox(height: 30),

                  // 🔘 BUTTON
                  _buttons(),

                  SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🤖 AI
  Future<void> simulateAI() async {
  try {
    // 🌐 Gọi API thật thay vì đọc JSON giả
    final result = await ApiService.predict(_image!);

    if (result == null) {
      // Không kết nối được server
      setState(() => isLoading = false);
      Navigator.push(context,
        MaterialPageRoute(builder: (_) => FailResultScreen(image: _image)));
      return;
    }

    final String label = result['predicted_label'] ?? '';
    final double confidence = (result['confidence'] ?? 0.0).toDouble();

    // Ngưỡng tin cậy: dưới 60% thì coi là thất bại
    if (label.isEmpty || confidence < 0.6) {
      setState(() => isLoading = false);
      Navigator.push(context,
        MaterialPageRoute(builder: (_) => FailResultScreen(image: _image)));
      return;
    }

    // 📍 Load locations từ assets để map sang Location object
    String locationsData = await DefaultAssetBundle.of(context)
        .loadString('assets/data/locations.json');
    List locations = json.decode(locationsData);

    final place = locations.firstWhere(
      (item) => item['predicted_label'] == label,
      orElse: () => null,
    );

    if (place != null && place.isNotEmpty) {
      place['confidence'] = confidence;

      setState(() => isLoading = false);
      await HistoryService.addHistory(place);

      Navigator.push(context,
        MaterialPageRoute(
          builder: (_) => DetailScreen(data: Location.fromJson(place)),
        ));
    } else {
      setState(() => isLoading = false);
      Navigator.push(context,
        MaterialPageRoute(builder: (_) => FailResultScreen(image: _image)));
    }
  } catch (e) {
    setState(() => isLoading = false);
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => FailResultScreen(image: _image)));
    print('AI error: $e');
  }
}

  Widget _scanCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18), // 👈 glass rõ hơn
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Stack(
              children: [
                // 📸 IMAGE BOX
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color.fromARGB(77, 251, 250, 250),
                    ),
                  ),
                  child: _image != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.file(_image!, fit: BoxFit.cover),
                        )
                      : _emptyView(),
                ),

                // 🔄 LOADING OVERLAY
                if (isLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 10),
                            Text(
                              "Đang nhận diện...",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _guideCard() {
    return _glassCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hướng dẫn",
                  style: TextStyle(
                    color: const Color.fromARGB(255, 4, 4, 4),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                _guide("📸", "Chụp rõ địa điểm"),
                _guide("🌤️", "Tránh ánh sáng xấu"),
                _guide("📍", "Chụp toàn cảnh"),
              ],
            ),
          ),
          Icon(
            Icons.map,
            color: const Color.fromARGB(179, 18, 18, 18),
            size: 50,
          ),
        ],
      ),
    );
  }

  Widget _buttons() {
    return Row(
      children: [
        Expanded(
          child: _gradientButton(
            "Chụp ảnh",
            Icons.camera_alt,
            () => pickImage(ImageSource.camera),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _gradientButton(
            "Thư viện",
            Icons.photo,
            () => pickImage(ImageSource.gallery),
          ),
        ),
      ],
    );
  }

  Widget _glassIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _emptyView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.camera_alt,
          size: 40,
          color: const Color.fromARGB(179, 126, 224, 141),
        ),
        SizedBox(height: 10),
        Text("Chưa có ảnh", style: TextStyle(color: Colors.white)),
        Text(
          "Chụp hoặc chọn ảnh để bắt đầu",
          style: TextStyle(
            color: const Color.fromARGB(153, 5, 5, 5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _guide(String icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(icon),
          SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _gradientButton(String text, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 127, 222, 164).withOpacity(0.4),
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
