import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../models/location_model.dart';
import '../services/favorite_service.dart';
import '../services/feedback_service.dart';
import '../services/location_service.dart';
import 'auth/login_screen.dart';
import 'full_gallery_screen.dart';

const primaryGradient = LinearGradient(
  colors: [Color(0xFF2FAE66), Color(0xFF27C6DA)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const softBg = Color(0xFFF5F6FA);

class _InfoItem {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _InfoItem(this.icon, this.title, this.value, this.color);
}

class DetailScreen extends StatefulWidget {
  final Location data;

  const DetailScreen({super.key, required this.data});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  VideoPlayerController? _controller;
  int currentIndex = 0;
  bool isFav = false;
  bool isLoadingRelated = true;
  bool isVideoFailed = false;
  bool isIntroExpanded = false;
  List<String> imageAssets = [];
  List<Location> relatedLocations = [];
  List<Location> allLocations = [];

  @override
  void initState() {
    super.initState();
    _loadFavorite();
    _loadImageAssets();
    _loadRelatedLocations();
    _setupVideo();
  }

  Future<void> _loadImageAssets() async {
    try {
      final manifest = await rootBundle.loadString('AssetManifest.json');
      final decoded = json.decode(manifest);
      if (decoded is! Map) return;

      final assets = decoded.keys
          .whereType<String>()
          .where((path) => path.startsWith('assets/images/'))
          .where((path) => RegExp(r'\.(jpg|jpeg|png|webp)$').hasMatch(path))
          .toList()
        ..sort();

      if (mounted) {
        setState(() => imageAssets = assets);
      }
    } catch (e) {
      debugPrint("Image manifest load error: $e");
    }
  }

  Future<void> _setupVideo() async {
    final video = widget.data.videoUrl;
    if (video.isEmpty) return;

    final controller = VideoPlayerController.asset("assets/$video");
    _controller = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("Video load error: $e");
      if (mounted) {
        setState(() => isVideoFailed = true);
      }
    }
  }

  Future<void> _loadFavorite() async {
    final fav = await FavoriteService.isFavorite(widget.data.predictedLabel);
    if (mounted) {
      setState(() => isFav = fav);
    }
  }

  Future<void> _loadRelatedLocations() async {
    final loadedLocations = await LocationService.loadLocations();
    final relatedIds = widget.data.relatedLocations.toSet();

    if (!mounted) return;

    setState(() {
      allLocations = loadedLocations;
      relatedLocations = loadedLocations
          .where((location) => relatedIds.contains(location.predictedLabel))
          .toList();
      isLoadingRelated = false;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.predictedLabel != widget.data.predictedLabel) {
      isIntroExpanded = false;
      currentIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final gallery = _displayGallery(data);

    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        title: Text(
          data.hasAiResult ? "Kết quả nhận diện" : "Chi tiết địa điểm",
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            tooltip: isFav ? "Bỏ yêu thích" : "Lưu yêu thích",
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.red : Colors.black54,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            tooltip: "Chia sẻ thông tin",
            icon: const Icon(Icons.ios_share),
            onPressed: _copyTravelInfo,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _mediaViewer(gallery),
            const SizedBox(height: 16),
            _titleBlock(data),
            const SizedBox(height: 14),
            _actionPanel(),
            const SizedBox(height: 16),
            _infoPanel(data),
            if (data.hasAiResult) ...[
              const SizedBox(height: 16),
              _aiPanel(data),
            ],
            const SizedBox(height: 20),
            _sectionTitle("Giới thiệu", Icons.menu_book),
            const SizedBox(height: 8),
            _introDescription(data.description),
            if (data.highlights.isNotEmpty) ...[
              const SizedBox(height: 18),
              _highlightChips(data.highlights),
            ],
            const SizedBox(height: 20),
            _travelAssistantPanel(data),
            const SizedBox(height: 20),
            _gallerySection(gallery),
            const SizedBox(height: 22),
            _relatedSection(),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2FAE66),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.camera_alt),
                label: const Text(
                  "Quét địa điểm khác",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaViewer(List<String> gallery) {
    if (gallery.isEmpty) return const SizedBox.shrink();

    final controller = _controller;
    final isVideoReady = controller != null && controller.value.isInitialized;
    final isPlaying = isVideoReady && controller.value.isPlaying;
    final safeIndex = currentIndex.clamp(0, gallery.length - 1).toInt();
    final mediaText = isVideoFailed
        ? "Video chưa tải"
        : isVideoReady
        ? "Video tự phát"
        : "Ảnh địa điểm";

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: isVideoReady ? controller.value.aspectRatio : 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isVideoReady)
              GestureDetector(
                onTap: _toggleVideo,
                child: VideoPlayer(controller),
              )
            else
              Image.asset(gallery[safeIndex], fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.62),
                  ],
                ),
              ),
            ),
            if (isVideoReady && !isPlaying)
              Center(
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.22),
                    fixedSize: const Size(76, 76),
                  ),
                  onPressed: _toggleVideo,
                  icon: const Icon(
                    Icons.play_arrow,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              ),
            if (isVideoReady)
              Positioned(
                left: 14,
                right: 14,
                bottom: 56,
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFF2FAE66),
                    bufferedColor: Colors.white54,
                    backgroundColor: Colors.black38,
                  ),
                ),
              ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Row(
                children: [
                  _mediaBadge(
                    isVideoFailed
                        ? Icons.error_outline
                        : isVideoReady
                        ? Icons.smart_display
                        : Icons.image,
                    mediaText,
                  ),
                  const Spacer(),
                  if (isVideoReady)
                    IconButton.filled(
                      tooltip: isPlaying ? "Tạm dừng" : "Phát video",
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.45),
                      ),
                      onPressed: _toggleVideo,
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleBlock(Location data) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.name,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.place, size: 17, color: Color(0xFF2FAE66)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      data.address,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (data.hasAiResult) ...[
          const SizedBox(width: 12),
          _confidenceBox(data.confidence),
        ],
      ],
    );
  }

  Widget _confidenceBox(double confidence) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            "Tin cậy",
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            "${(confidence * 100).toStringAsFixed(1)}%",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionPanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final secondaryColumns = constraints.maxWidth < 330 ? 2 : 3;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5ECE5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _primaryAction(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      isFav ? "Đã yêu thích" : "Yêu thích",
                      isFav ? Colors.red : Colors.pink,
                      _toggleFavorite,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _primaryAction(
                      Icons.directions,
                      "Chỉ đường",
                      Colors.blue,
                      _openDirections,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: secondaryColumns,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: secondaryColumns == 2 ? 2.8 : 2.0,
                children: [
                  _secondaryAction(
                    Icons.play_circle,
                    "Video",
                    Colors.deepPurple,
                    _playVideo,
                  ),
                  _secondaryAction(
                    Icons.rate_review,
                    "Phản hồi",
                    Colors.teal,
                    _showFeedbackSheet,
                  ),
                  _secondaryAction(
                    Icons.ios_share,
                    "Chia sẻ",
                    Colors.green,
                    _copyTravelInfo,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _primaryAction(
    IconData icon,
    String text,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Ink(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secondaryAction(
    IconData icon,
    String text,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAF7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5ECE5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoPanel(Location data) {
    final items = [
      _InfoItem(Icons.location_city, "Khu vực", data.province, Colors.indigo),
      _InfoItem(
        Icons.access_time,
        "Giờ mở cửa",
        data.openingHours,
        Colors.green,
      ),
      _InfoItem(
        Icons.confirmation_num,
        "Giá vé",
        data.ticketPrice,
        Colors.orange,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 390 ? 1 : 3;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5ECE5)),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: columns == 1 ? 72 : 92,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return _infoItem(
                item.icon,
                item.title,
                item.value,
                item.color,
                horizontal: columns == 1,
              );
            },
          ),
        );
      },
    );
  }

  Widget _infoItem(
    IconData icon,
    String title,
    String value,
    Color color, {
    required bool horizontal,
  }) {
    final displayValue = value.isEmpty ? "Đang cập nhật" : value;

    if (horizontal) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    displayValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              displayValue,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiPanel(Location data) {
    final matches = data.topMatches;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EDF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Phân tích AI", Icons.auto_awesome),
          const SizedBox(height: 12),
          if (matches.isEmpty)
            _predictionRow(
              name: data.name,
              confidence: data.confidence,
              isBest: true,
            )
          else
            ...matches
                .take(3)
                .map(
                  (candidate) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _predictionRow(
                      name: candidate.name,
                      confidence: candidate.confidence,
                      isBest: candidate.predictedLabel == data.predictedLabel,
                    ),
                  ),
                ),
          const SizedBox(height: 2),
          Text(
            "Ứng dụng chỉ xác nhận địa điểm khi độ tin cậy từ ${(Location.minRecognitionConfidence * 100).toStringAsFixed(0)}% trở lên. Nếu ảnh chưa đúng, hãy quét lại bằng góc chụp rõ hơn.",
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _predictionRow({
    required String name,
    required double confidence,
    required bool isBest,
  }) {
    final safeConfidence = confidence.clamp(0, 1).toDouble();

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isBest
                ? const Color(0xFF2FAE66).withValues(alpha: 0.12)
                : Colors.grey.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isBest ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isBest ? const Color(0xFF2FAE66) : Colors.grey,
            size: 19,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: safeConfidence,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE9EDF2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isBest ? const Color(0xFF2FAE66) : const Color(0xFF27C6DA),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          "${(safeConfidence * 100).toStringAsFixed(0)}%",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _introDescription(String description) {
    final shouldCollapse = description.trim().length > 180;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          description,
          maxLines: shouldCollapse && !isIntroExpanded ? 6 : null,
          overflow: shouldCollapse && !isIntroExpanded
              ? TextOverflow.ellipsis
              : TextOverflow.visible,
          style: const TextStyle(fontSize: 15, height: 1.45),
        ),
        if (shouldCollapse) ...[
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() => isIntroExpanded = !isIntroExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isIntroExpanded ? "Thu gọn" : "Xem thêm",
                    style: const TextStyle(
                      color: Color(0xFF1FAD62),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isIntroExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: const Color(0xFF1FAD62),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _highlightChips(List<String> highlights) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: highlights
          .map(
            (highlight) => Chip(
              avatar: const Icon(
                Icons.star,
                size: 16,
                color: Color(0xFFFFA000),
              ),
              label: Text(highlight),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE7E9EE)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _travelAssistantPanel(Location data) {
    final relatedNames = relatedLocations
        .map((location) => location.name)
        .toList();
    final schedule = data.bestTime.isNotEmpty
        ? "Thời gian phù hợp: ${data.bestTime}."
        : data.openingHours.isEmpty
        ? "Nên kiểm tra giờ mở cửa trước khi xuất phát."
        : "Thời gian phù hợp: ${data.openingHours}.";
    final ticket = data.estimatedCost.isNotEmpty
        ? "Dự trù chi phí: ${data.estimatedCost}."
        : data.ticketPrice.isEmpty
        ? "Giá vé đang cập nhật, hãy kiểm tra trước khi mua vé."
        : "Dự trù chi phí: ${data.ticketPrice}.";
    final route = data.suggestedRoute.isNotEmpty
        ? "Tuyến gợi ý: ${data.suggestedRoute}."
        : relatedNames.isEmpty
        ? "Có thể kết hợp thêm các điểm gần khu vực ${data.province}."
        : "Có thể kết hợp: ${relatedNames.join(', ')}.";
    final highlights = data.highlights.take(3).toList();
    final highlightText = highlights.isEmpty
        ? "Dành thời gian quan sát toàn cảnh và các góc chụp nổi bật."
        : "Đừng bỏ lỡ: ${highlights.join(', ')}.";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EDF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Trợ lý du lịch", Icons.explore),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _assistantActionButton(
                Icons.directions,
                "Chỉ đường",
                _openDirections,
              ),
              _assistantActionButton(
                Icons.event_note,
                "Lịch trình",
                _showItinerarySheet,
              ),
              _assistantActionButton(
                Icons.restaurant,
                "Ăn uống",
                () => _openNearbySearch("quán ăn"),
              ),
              _assistantActionButton(
                Icons.hotel,
                "Khách sạn",
                () => _openNearbySearch("khách sạn"),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _travelTipLine(Icons.auto_awesome, highlightText),
          _travelTipLine(Icons.schedule, schedule),
          _travelTipLine(Icons.payments, ticket),
          _travelTipLine(Icons.route, route),
          ...data.travelTips
              .take(3)
              .map((tip) => _travelTipLine(Icons.tips_and_updates, tip)),
        ],
      ),
    );
  }

  Widget _assistantActionButton(
    IconData icon,
    String text,
    VoidCallback onTap,
  ) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1F8A56),
        side: const BorderSide(color: Color(0xFFDCE9E2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _travelTipLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2FAE66)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
        ],
      ),
    );
  }

  List<String> _displayGallery(Location data) {
    final labelImages = imageAssets
        .where((path) => _isLocationImage(path, data.predictedLabel))
        .toList();

    final candidateImages = _locationImageCandidates(data.predictedLabel);
    final galleryImages = labelImages.length <= 1
        ? candidateImages
        : labelImages;

    galleryImages.sort(
      (a, b) => _imageSortKey(a, data).compareTo(_imageSortKey(b, data)),
    );

    final images = <String>{
      if (data.thumbnail.isNotEmpty) data.thumbnail,
      ...?data.gallery,
      ...galleryImages,
    };

    return images.toList();
  }

  bool _isLocationImage(String path, String predictedLabel) {
    final name = path.split('/').last.toLowerCase();
    final label = predictedLabel.toLowerCase();
    final extensionIndex = name.lastIndexOf('.');
    if (extensionIndex <= 0 || !name.startsWith(label)) return false;

    final suffix = name.substring(label.length, extensionIndex);
    return suffix.isEmpty || RegExp(r'^_?\d+$').hasMatch(suffix);
  }

  List<String> _locationImageCandidates(String predictedLabel) {
    final label = predictedLabel.toLowerCase();
    final base = 'assets/images/$label';
    final numberedSeparator = RegExp(r'\d$').hasMatch(label) ? '_' : '';

    return [
      '$base.jpg',
      for (var index = 1; index <= 5; index++)
        '$base$numberedSeparator$index.jpg',
    ];
  }

  int _imageSortKey(String path, Location data) {
    final name = path.split('/').last.toLowerCase();
    final label = data.predictedLabel.toLowerCase();
    final extensionIndex = name.lastIndexOf('.');
    final suffix = name.substring(label.length, extensionIndex);
    if (suffix.isEmpty) return 0;
    return int.tryParse(suffix.replaceFirst('_', '')) ?? 999;
  }

  Widget _gallerySection(List<String> gallery) {
    if (gallery.isEmpty) return const SizedBox.shrink();

    final safeIndex = currentIndex.clamp(0, gallery.length - 1).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Thư viện ảnh", Icons.photo_library),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Image.asset(
                gallery[safeIndex],
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${safeIndex + 1}/${gallery.length}",
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: gallery.length > 4 ? 5 : gallery.length,
            itemBuilder: (context, index) {
              if (index == 4 && gallery.length > 5) {
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullGalleryScreen(gallery: gallery),
                      ),
                    );
                  },
                  child: Ink(
                    width: 86,
                    decoration: BoxDecoration(
                      gradient: primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        "+${gallery.length - 4}\nXem thêm",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return GestureDetector(
                onTap: () => setState(() => currentIndex = index),
                child: _thumb(gallery[index], isActive: safeIndex == index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _thumb(String path, {required bool isActive}) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      width: 82,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFF2FAE66) : Colors.transparent,
          width: 2,
        ),
        image: DecorationImage(image: AssetImage(path), fit: BoxFit.cover),
      ),
    );
  }

  Widget _relatedSection() {
    if (isLoadingRelated) {
      return const Center(child: CircularProgressIndicator());
    }

    if (relatedLocations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Địa điểm liên quan", Icons.near_me),
        const SizedBox(height: 10),
        SizedBox(
          height: 178,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: relatedLocations.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final location = relatedLocations[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  _controller?.pause();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailScreen(data: location),
                    ),
                  );
                },
                child: Ink(
                  width: 154,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: Image.asset(
                          location.thumbnail,
                          height: 96,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              location.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              location.province,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2FAE66)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _toggleFavorite() async {
    if (!_requireLogin("lưu địa điểm yêu thích")) return;

    await FavoriteService.toggleFavorite(widget.data.predictedLabel);
    if (mounted) {
      setState(() => isFav = !isFav);
      _showSnackBar(isFav ? "Đã lưu yêu thích" : "Đã bỏ yêu thích");
    }
  }

  bool _requireLogin(String feature) {
    if (FirebaseAuth.instance.currentUser != null) return true;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cần đăng nhập"),
        content: Text("Bạn cần đăng nhập để $feature."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Để sau"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text("Đăng nhập"),
          ),
        ],
      ),
    );

    return false;
  }

  void _toggleVideo() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  void _playVideo() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      _showSnackBar("Địa điểm này chưa có video.");
      return;
    }

    controller.play();
    setState(() {});
  }

  String get _mapsQuery {
    if (widget.data.mapQuery.isNotEmpty) return widget.data.mapQuery;
    return widget.data.address.isEmpty ? widget.data.name : widget.data.address;
  }

  Future<void> _launchMapsUri(Uri uri, String failMessage) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      _showSnackBar(failMessage);
    }
  }

  Future<void> _openDirections() async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': _mapsQuery,
    });

    await _launchMapsUri(uri, "Không mở được chỉ đường.");
  }

  Future<void> _openNearbySearch(String keyword) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': "$keyword gần $_mapsQuery",
    });

    await _launchMapsUri(uri, "Không mở được bản đồ.");
  }

  void _showItinerarySheet() {
    final data = widget.data;
    final relatedNames = relatedLocations.map((location) => location.name);
    final highlightText = data.highlights.isEmpty
        ? data.description
        : "Ưu tiên ${data.highlights.take(3).join(', ')}.";
    final relatedText = relatedNames.isEmpty
        ? data.suggestedRoute.isNotEmpty
              ? data.suggestedRoute
              : "Sau khi tham quan, tìm thêm điểm gần ${data.province} nếu còn thời gian."
        : "Có thể đi tiếp ${relatedNames.join(', ')}.";
    final arrivalText = data.bestTime.isEmpty
        ? "Mở chỉ đường và ưu tiên đến sớm để có thời gian tham quan thoải mái."
        : "Nên đi vào ${data.bestTime.toLowerCase()}";

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Lịch trình gợi ý tại ${data.name}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                _itineraryStep(
                  Icons.directions_walk,
                  "Đến địa điểm",
                  arrivalText,
                ),
                _itineraryStep(
                  Icons.photo_camera,
                  "Tham quan chính",
                  highlightText,
                ),
                _itineraryStep(
                  Icons.restaurant,
                  "Nghỉ và ăn uống",
                  "Tìm quán ăn gần khu vực ${data.province} sau khi tham quan.",
                ),
                _itineraryStep(Icons.near_me, "Kết hợp tuyến", relatedText),
                if (data.travelTips.isNotEmpty)
                  _itineraryStep(
                    Icons.tips_and_updates,
                    "Lưu ý",
                    data.travelTips.take(2).join(' '),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _itineraryStep(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF2FAE66).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF2FAE66), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(color: Colors.black54, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFeedbackSheet() async {
    if (!_requireLogin("gửi phản hồi kết quả nhận dạng")) return;

    final noteController = TextEditingController();
    final noteFocusNode = FocusNode();
    var verdict = "correct";
    var correctedLabel = widget.data.predictedLabel;
    var isSaving = false;
    final selectableLocations = allLocations.isEmpty
        ? <Location>[widget.data]
        : allLocations;

    final sent = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              if (isSaving) return;

              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                Navigator.of(sheetContext).pop(false);
                return;
              }

              FocusScope.of(context).unfocus();
              final note = noteController.text;

              setSheetState(() => isSaving = true);
              try {
                await FeedbackService.submitFeedback(
                  location: widget.data,
                  verdict: verdict,
                  userId: user.uid,
                  userEmail: user.email,
                  correctedLabel: verdict == "wrong" ? correctedLabel : null,
                  note: note,
                );

                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop(true);
                }
              } catch (e) {
                if (sheetContext.mounted) {
                  setSheetState(() => isSaving = false);
                }
                if (mounted) {
                  _showSnackBar("Không gửi được phản hồi. Vui lòng thử lại.");
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Phản hồi kết quả ${widget.data.name}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text("Kết quả đúng"),
                          selected: verdict == "correct",
                          onSelected: (_) {
                            setSheetState(() => verdict = "correct");
                          },
                        ),
                        ChoiceChip(
                          label: const Text("Kết quả sai"),
                          selected: verdict == "wrong",
                          onSelected: (_) {
                            setSheetState(() => verdict = "wrong");
                          },
                        ),
                        ChoiceChip(
                          label: const Text("Chỉ mang tính tham khảo"),
                          selected: verdict == "uncertain",
                          onSelected: (_) {
                            setSheetState(() => verdict = "uncertain");
                          },
                        ),
                      ],
                    ),
                    if (verdict == "wrong") ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: correctedLabel,
                        decoration: const InputDecoration(
                          labelText: "Địa điểm đúng hơn",
                          border: OutlineInputBorder(),
                        ),
                        items: selectableLocations
                            .map(
                              (location) => DropdownMenuItem(
                                value: location.predictedLabel,
                                child: Text(location.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => correctedLabel = value);
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextField(
                      controller: noteController,
                      focusNode: noteFocusNode,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: "Ghi chú thêm",
                        hintText: "Ví dụ: ảnh bị lệch góc, địa điểm đúng là...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2FAE66),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: isSaving ? null : submit,
                        icon: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(isSaving ? "Đang gửi..." : "Gửi phản hồi"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      noteFocusNode.dispose();
      noteController.dispose();
    });

    if (sent == true && mounted) {
      _showSnackBar("Cảm ơn bạn, phản hồi đã được ghi nhận.");
    }
  }

  Future<void> _copyTravelInfo() async {
    final data = widget.data;
    final relatedNames = relatedLocations
        .map((location) => location.name)
        .toList();
    final text = [
      data.name,
      data.address,
      data.description,
      "Điểm nổi bật: ${data.highlights.join(', ')}",
      "Giờ mở cửa: ${data.openingHours}",
      "Giá vé: ${data.ticketPrice}",
      if (data.bestTime.isNotEmpty) "Thời gian phù hợp: ${data.bestTime}",
      if (data.estimatedCost.isNotEmpty)
        "Chi phí dự kiến: ${data.estimatedCost}",
      if (data.suggestedRoute.isNotEmpty) "Tuyến gợi ý: ${data.suggestedRoute}",
      if (data.travelTips.isNotEmpty) "Lưu ý: ${data.travelTips.join(' ')}",
      if (relatedNames.isNotEmpty) "Có thể kết hợp: ${relatedNames.join(', ')}",
    ].where((item) => item.trim().isNotEmpty).join('\n');

    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      _showSnackBar("Đã sao chép thông tin du lịch.");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
