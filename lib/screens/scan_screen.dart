import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/location_model.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import '../services/location_service.dart';
import 'detail_screen.dart';
import 'fail_result_screen.dart';

const _vietnamGreen = Color(0xFF1F8A56);
const _deepGreen = Color(0xFF0E4F32);
const _paper = Color(0xFFF7F4EA);
const _surface = Colors.white;
const _ink = Color(0xFF17221B);
const _softGreen = Color(0xFFE8F2DC);
const _goldLine = Color(0xFFEEDFB8);
const _mutedText = Color(0xFF5E625D);

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
      backgroundColor: _paper,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/images/bg_scan.png", fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _ScanBackgroundPainter()),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _header(),
                          const SizedBox(height: 34),
                          _scanCard(),
                          const SizedBox(height: 18),
                          _guideCard(),
                          const SizedBox(height: 16),
                          _buttons(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _header() {
    return Row(
      children: [
        _roundIconButton(Icons.arrow_back, () => Navigator.pop(context)),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Quét AI",
                style: TextStyle(
                  color: _deepGreen,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Nhận diện địa điểm",
                style: TextStyle(
                  color: _mutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scanCard() {
    return _paperCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7EC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _goldLine.withValues(alpha: 0.8)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _image != null
                      ? Image.file(_image!, fit: BoxFit.cover)
                      : CustomPaint(
                          painter: _ScanLakePainter(),
                          child: _emptyView(),
                        ),
                ),
              ),
              const Positioned.fill(child: IgnorePointer(child: _CornerFrame())),
              if (isLoading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _deepGreen.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text(
                            "Đang nhận diện...",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
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
    );
  }

  Widget _guideCard() {
    return _paperCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Hướng dẫn",
                  style: TextStyle(
                    color: _deepGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Icon(Icons.map_outlined, color: _vietnamGreen, size: 36),
            ],
          ),
          const SizedBox(height: 10),
          _guide(
            Icons.photo_camera_outlined,
            "Chụp rõ địa điểm",
            "Giữ máy chắc tay, lấy nét vào công trình hoặc cảnh chính.",
          ),
          _guide(
            Icons.wb_sunny_outlined,
            "Tránh ánh sáng xấu",
            "Ưu tiên ánh sáng tự nhiên, không chụp ngược nắng hoặc quá tối.",
          ),
          _guide(
            Icons.location_on_outlined,
            "Chụp toàn cảnh",
            "Để địa danh nằm trọn trong khung, hạn chế người hoặc vật che khuất.",
            showDivider: false,
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
              const SizedBox(width: 12),
              Expanded(
                child: _outlineButton(
                  "Ảnh khác",
                  Icons.photo_library,
                  isLoading ? null : () => pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
        const SizedBox(width: 12),
        Expanded(
          child: _outlineButton(
            "Thư viện",
            Icons.photo,
            isLoading ? null : () => pickImage(ImageSource.gallery),
          ),
        ),
      ],
    );
  }

  Widget _roundIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: _surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Icon(icon, color: _vietnamGreen, size: 26),
      ),
    );
  }

  Widget _emptyView() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CameraSeal(),
        SizedBox(height: 12),
        Text(
          "Chưa có ảnh",
          style: TextStyle(
            color: _deepGreen,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: 4),
        Text(
          "Chụp hoặc chọn ảnh để bắt đầu",
          textAlign: TextAlign.center,
          style: TextStyle(color: _mutedText, fontSize: 12),
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
        color: _softGreen.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _vietnamGreen.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isValid ? Icons.verified : Icons.error_outline,
            color: isValid ? _vietnamGreen : Colors.orange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isValid
                  ? "Ảnh đạt kiểm tra cơ bản. Hãy xác nhận nếu ảnh đủ sáng, rõ nét và lấy trọn địa điểm."
                  : _imageValidationMessage!,
              style: const TextStyle(
                color: _ink,
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

  Widget _guide(
    IconData icon,
    String title,
    String subtitle, {
    bool showDivider = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: _softGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _vietnamGreen, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _mutedText,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                  if (showDivider) ...[
                    const SizedBox(height: 8),
                    Divider(
                      height: 1,
                      color: _goldLine.withValues(alpha: 0.55),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paperCard({required Widget child, required EdgeInsets padding}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _gradientButton(String text, IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade400 : _vietnamGreen,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: _vietnamGreen.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
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
        foregroundColor: _vietnamGreen,
        disabledForegroundColor: Colors.black38,
        backgroundColor: Colors.white.withValues(alpha: 0.72),
        side: BorderSide(color: _vietnamGreen.withValues(alpha: 0.65)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _CameraSeal extends StatelessWidget {
  const _CameraSeal();

  @override
  Widget build(BuildContext context) {
    return Container(
        width: 64,
        height: 64,
      decoration: BoxDecoration(
        color: _softGreen.withValues(alpha: 0.8),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.camera_alt, size: 34, color: _vietnamGreen),
    );
  }
}

class _CornerFrame extends StatelessWidget {
  const _CornerFrame();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CornerFramePainter());
  }
}

class _ScanBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _paper.withValues(alpha: 0.72),
          _paper.withValues(alpha: 0.58),
          _paper.withValues(alpha: 0.5),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    final greenPaint = Paint()..color = _vietnamGreen.withValues(alpha: 0.08);
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.9), 88, greenPaint);

    final birdPaint = Paint()
      ..color = const Color(0xFFB7A35E).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (final bird in [
      Offset(size.width * 0.42, 132),
      Offset(size.width * 0.52, 146),
      Offset(size.width * 0.57, 130),
    ]) {
      final path = Path()
        ..moveTo(bird.dx - 5, bird.dy)
        ..quadraticBezierTo(bird.dx, bird.dy - 4, bird.dx + 5, bird.dy);
      canvas.drawPath(path, birdPaint);
    }

    final cloudPaint = Paint()
      ..color = const Color(0xFFDCC797).withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final cloud = Path()
      ..moveTo(size.width * 0.43, 88)
      ..cubicTo(size.width * 0.48, 70, size.width * 0.52, 96, size.width * 0.56, 78)
      ..cubicTo(size.width * 0.6, 62, size.width * 0.61, 104, size.width * 0.66, 86);
    canvas.drawPath(cloud, cloudPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanLakePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFBF0), Color(0xFFF1F5E8)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, skyPaint);

    final mountainPaint = Paint()
      ..color = _vietnamGreen.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final mountains = Path()
      ..moveTo(0, size.height * 0.56)
      ..lineTo(size.width * 0.18, size.height * 0.34)
      ..lineTo(size.width * 0.28, size.height * 0.49)
      ..lineTo(size.width * 0.39, size.height * 0.3)
      ..lineTo(size.width * 0.55, size.height * 0.55)
      ..lineTo(size.width * 0.7, size.height * 0.38)
      ..lineTo(size.width * 0.82, size.height * 0.54)
      ..lineTo(size.width, size.height * 0.35)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(mountains, mountainPaint);

    final lakePaint = Paint()..color = Colors.white.withValues(alpha: 0.58);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.58, size.width, size.height * 0.24),
      lakePaint,
    );

    final pagodaPaint = Paint()..color = _deepGreen.withValues(alpha: 0.24);
    final pagodaBase = Rect.fromLTWH(
      size.width * 0.72,
      size.height * 0.38,
      size.width * 0.16,
      size.height * 0.22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pagodaBase, const Radius.circular(3)),
      pagodaPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        pagodaBase.left - 8,
        pagodaBase.top + 16,
        pagodaBase.width + 16,
        7,
      ),
      pagodaPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        pagodaBase.left - 12,
        pagodaBase.top + 52,
        pagodaBase.width + 24,
        8,
      ),
      pagodaPaint,
    );

    final linePaint = Paint()
      ..color = _goldLine.withValues(alpha: 0.36)
      ..strokeWidth = 1;
    for (var y = size.height * 0.62; y < size.height * 0.8; y += 18) {
      canvas.drawLine(Offset(size.width * 0.18, y), Offset(size.width * 0.82, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CornerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _goldLine.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const inset = 18.0;
    const length = 52.0;

    void corner(double x, double y, bool right, bool bottom) {
      final sx = right ? -1.0 : 1.0;
      final sy = bottom ? -1.0 : 1.0;
      final path = Path()
        ..moveTo(x, y + sy * length)
        ..lineTo(x, y)
        ..lineTo(x + sx * length, y);
      canvas.drawPath(path, paint);

      final small = Path()
        ..moveTo(x + sx * 12, y + sy * 38)
        ..lineTo(x + sx * 12, y + sy * 12)
        ..lineTo(x + sx * 38, y + sy * 12);
      canvas.drawPath(small, paint);
    }

    corner(inset, inset, false, false);
    corner(size.width - inset, inset, true, false);
    corner(inset, size.height - inset, false, true);
    corner(size.width - inset, size.height - inset, true, true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
