import 'dart:io';

import 'package:flutter/material.dart';

import '../models/location_model.dart';
import '../services/history_service.dart';
import '../services/location_service.dart';
import 'detail_screen.dart';

class FailResultScreen extends StatefulWidget {
  final File? image;
  final List<PredictionCandidate> suggestions;

  const FailResultScreen({super.key, this.image, this.suggestions = const []});

  @override
  State<FailResultScreen> createState() => _FailResultScreenState();
}

class _FailResultScreenState extends State<FailResultScreen> {
  late final Future<List<Location>> _suggestionsFuture;

  @override
  void initState() {
    super.initState();
    _suggestionsFuture = _loadSuggestions();
  }

  Future<List<Location>> _loadSuggestions() async {
    final locations = await LocationService.loadLocations();

    if (widget.suggestions.isEmpty) {
      return locations.take(3).toList();
    }

    final matchedLocations = <Location>[];

    for (final candidate in widget.suggestions) {
      for (final location in locations) {
        if (location.predictedLabel == candidate.predictedLabel) {
          matchedLocations.add(
            location.copyWith(
              confidence: candidate.confidence,
              topMatches: widget.suggestions,
            ),
          );
          break;
        }
      }
    }

    return matchedLocations.isEmpty
        ? locations.take(3).toList()
        : matchedLocations;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text("Không nhận diện được"),
        actions: const [
          Icon(Icons.travel_explore, color: Colors.black54),
          SizedBox(width: 12),
        ],
      ),
      body: FutureBuilder<List<Location>>(
        future: _suggestionsFuture,
        builder: (context, snapshot) {
          final suggestions = snapshot.data ?? const <Location>[];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _resultPreview(),
                const SizedBox(height: 18),
                _retryActions(context),
                const SizedBox(height: 24),
                const Text(
                  "Ảnh chưa đạt ngưỡng nhận diện",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  "Ứng dụng chỉ xác nhận địa điểm khi độ tin cậy từ ${(Location.minRecognitionConfidence * 100).toStringAsFixed(0)}% trở lên. Bạn có thể thử ảnh rõ hơn hoặc tham khảo các địa điểm gần giống bên dưới.",
                  style: const TextStyle(color: Colors.black54, height: 1.35),
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else
                  _suggestionList(suggestions),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _resultPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 260,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.image != null
                ? Image.file(widget.image!, fit: BoxFit.cover)
                : Image.asset(
                    "assets/images/bannerfail.png",
                    fit: BoxFit.cover,
                  ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
            const Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Không nhận diện được",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Chụp chính diện, đủ sáng và lấy trọn điểm du lịch. Dưới 70% độ tin cậy sẽ không được xem là kết quả nhận diện.",
                    style: TextStyle(color: Colors.white70, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _retryActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF27C6DA)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.camera_alt, color: Color(0xFF2FAE66)),
            label: const Text(
              "Chụp lại",
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2FAE66),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.photo_library),
            label: const Text("Ảnh khác"),
          ),
        ),
      ],
    );
  }

  Widget _suggestionList(List<Location> suggestions) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 188,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final location = suggestions[index];

          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              final selectedLocation = location.copyWith(
                topMatches: widget.suggestions,
                recognizedAt: DateTime.now(),
              );

              final savedHistory = await HistoryService.addHistory(
                selectedLocation.toStorageJson(),
              );
              if (!context.mounted) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DetailScreen(data: Location.fromJson(savedHistory)),
                ),
              );
            },
            child: Ink(
              width: 158,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    child: Stack(
                      children: [
                        Image.asset(
                          location.thumbnail,
                          height: 102,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        if (location.confidence > 0)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: _confidenceBadge(location.confidence),
                          ),
                      ],
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
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: Color(0xFF2FAE66),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                location.province,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _confidenceBadge(double confidence) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "${(confidence * 100).toStringAsFixed(0)}%",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
