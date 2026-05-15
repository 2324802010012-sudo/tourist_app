import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'detail_screen.dart';
import 'fail_result_screen.dart';
import '../models/location_model.dart';
import '../services/history_service.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

// 🎨 THEME
const primaryGradient = LinearGradient(
  colors: [
    Color.fromARGB(255, 120, 226, 138),
    Color.fromARGB(255, 86, 167, 244),
  ],
);

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  static const int _maxImageBytes = 10 * 1024 * 1024;
  static const int _minImageBytes = 12 * 1024;

  File? _image;
  String? _imageValidationMessage;
  bool isLoading = false;

  final picker = ImagePicker();
  // 📸 PICK IMAGE
  Future<void> pickImage(ImageSource source) async {
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1800,
      );

      if (pickedFile != null) {
        final image = File(pickedFile.path);
        final validationMessage = await _validateImage(image);

        setState(() {
          _image = image;
          _imageValidationMessage = validationMessage;
          isLoading = false;
        });

        if (validationMessage != null) {
          _showSnackBar(validationMessage);
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar(
        "Không thể mở camera hoặc thư viện. Hãy kiểm tra quyền truy cập.",
      );
      debugPrint("Pick image error: $e");
    }
  }

  Future<String?> _validateImage(File file) async {
    final extension = file.path.split('.').last.toLowerCase();
    const acceptedExtensions = {'jpg', 'jpeg', 'png'};
    if (!acceptedExtensions.contains(extension)) {
      return "Ảnh cần ở định dạng JPG hoặc PNG.";
    }

    final size = await file.length();
    if (size > _maxImageBytes) {
      return "Ảnh đang lớn hơn 10MB. Vui lòng chọn ảnh nhẹ hơn.";
    }

    if (size < _minImageBytes) {
      return "Ảnh quá nhỏ hoặc chất lượng quá thấp. Vui lòng chụp/chọn ảnh rõ hơn.";
    }

    return null;
  }

  Future<void> _startRecognition() async {
    final image = _image;
    if (image == null || isLoading) return;

    final validationMessage = await _validateImage(image);
    if (!mounted) return;

    if (validationMessage != null) {
      setState(() => _imageValidationMessage = validationMessage);
      _showSnackBar(validationMessage);
      return;
    }

    setState(() {
      _imageValidationMessage = null;
      isLoading = true;
    });

    await simulateAI();
  }

  void _clearImage() {
    setState(() {
      _image = null;
      _imageValidationMessage = null;
      isLoading = false;
    });
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
              child: Container(color: Colors.black.withValues(alpha: 0.25)),
            ),
          ),

          // 📱 CONTENTS
          SafeArea(
            child: SingleChildScrollView(
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

                  SizedBox(height: _image == null ? 96 : 26),

                  // 📸 SCAN CARD
                  _scanCard(),

                  SizedBox(height: _image == null ? 70 : 24),

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
    final image = _image;
    if (image == null) return;

    try {
      final result = await ApiService.predict(image);

      if (!mounted) return;

      if (result == null) {
        setState(() => isLoading = false);
        _openFailScreen();
        return;
      }

      final label = _readLabel(result);
      final confidence = _readConfidence(result['confidence']);
      final topMatches = _readTopMatches(result);

      if (label.isEmpty || !_isConfidentResult(result, confidence)) {
        setState(() => isLoading = false);
        _openFailScreen(suggestions: topMatches);
        return;
      }

      final locations = await LocationService.loadLocationMaps();
      if (!mounted) return;

      final place = _findLocation(locations, label);

      if (place == null) {
        setState(() => isLoading = false);
        _openFailScreen(suggestions: topMatches);
        return;
      }

      final enrichedPlace = <String, dynamic>{
        ...place,
        'confidence': confidence,
        'top3': topMatches.map(_candidateToJson).toList(),
        'recognized_at': DateTime.now().toIso8601String(),
      };

      setState(() => isLoading = false);
      final savedHistory = await HistoryService.addHistory(enrichedPlace);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailScreen(data: Location.fromJson(savedHistory)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _openFailScreen();
      debugPrint('AI error: $e');
    }
  }

  String _readLabel(Map<String, dynamic> result) {
    final location = result['location'];
    final label =
        result['predicted_label'] ??
        result['label'] ??
        (location is Map ? location['predicted_label'] : '');
    return label?.toString().trim() ?? '';
  }

  double _readConfidence(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _isConfidentResult(Map<String, dynamic> result, double confidence) {
    final apiConfidence = result['is_confident'];
    if (apiConfidence is bool) {
      return apiConfidence && confidence >= Location.minRecognitionConfidence;
    }

    return confidence >= Location.minRecognitionConfidence;
  }

  List<PredictionCandidate> _readTopMatches(Map<String, dynamic> result) {
    final top3 = result['top3'];
    if (top3 is! List) return const [];

    return top3
        .whereType<Map>()
        .map(
          (item) =>
              PredictionCandidate.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.predictedLabel.isNotEmpty)
        .toList();
  }

  Map<String, dynamic>? _findLocation(
    List<Map<String, dynamic>> locations,
    String label,
  ) {
    final normalizedLabel = label.toLowerCase().trim();

    for (final location in locations) {
      final locationLabel = location['predicted_label']?.toString().trim();
      if (locationLabel?.toLowerCase() == normalizedLabel) {
        return Map<String, dynamic>.from(location);
      }
    }

    return null;
  }

  Map<String, dynamic> _candidateToJson(PredictionCandidate candidate) {
    return {
      'predicted_label': candidate.predictedLabel,
      'location_name': candidate.name,
      'province': candidate.province,
      'thumbnail_url': candidate.thumbnail.replaceFirst('assets/', ''),
      'confidence': candidate.confidence,
    };
  }

  void _openFailScreen({List<PredictionCandidate> suggestions = const []}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FailResultScreen(image: _image, suggestions: suggestions),
      ),
    );
  }

  Widget _scanCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
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
              color: Colors.white.withValues(alpha: 0.18), // 👈 glass rõ hơn
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Stack(
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
                            color: Colors.black.withValues(alpha: 0.5),
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
                if (_image != null) ...[
                  const SizedBox(height: 12),
                  _imageQualityStatus(),
                ],
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
    if (_image != null) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _outlineButton(
                  "Chụp lại",
                  Icons.camera_alt,
                  isLoading ? null : () => pickImage(ImageSource.camera),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _outlineButton(
                  "Ảnh khác",
                  Icons.photo_library,
                  isLoading ? null : () => pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _gradientButton(
            "Dùng ảnh này để nhận diện",
            Icons.auto_awesome,
            _imageValidationMessage == null && !isLoading
                ? _startRecognition
                : null,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _gradientButton(
            "Chụp ảnh",
            Icons.camera_alt,
            isLoading ? null : () => pickImage(ImageSource.camera),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _gradientButton(
            "Thư viện",
            Icons.photo,
            isLoading ? null : () => pickImage(ImageSource.gallery),
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
          color: Colors.white.withValues(alpha: 0.3),
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

  Widget _imageQualityStatus() {
    final isValid = _imageValidationMessage == null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isValid ? Icons.verified : Icons.error_outline,
            color: isValid ? const Color(0xFF2FAE66) : Colors.orange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isValid
                  ? "Ảnh đạt kiểm tra cơ bản. Hãy xác nhận nếu ảnh đủ sáng, rõ nét và lấy trọn địa điểm."
                  : _imageValidationMessage!,
              style: TextStyle(
                color: isValid ? Colors.black87 : Colors.black87,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!isLoading)
            IconButton(
              tooltip: "Bỏ ảnh",
              onPressed: _clearImage,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
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
                Colors.white.withValues(alpha: 0.25),
                Colors.white.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _gradientButton(String text, IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: onTap == null
              ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey])
              : primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(
                255,
                127,
                222,
                164,
              ).withValues(alpha: 0.4),
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

  Widget _outlineButton(String text, IconData icon, VoidCallback? onTap) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white54,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.65)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
