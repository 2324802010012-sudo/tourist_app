class PredictionCandidate {
  final String predictedLabel;
  final String name;
  final String province;
  final String thumbnail;
  final double confidence;

  const PredictionCandidate({
    required this.predictedLabel,
    required this.name,
    required this.province,
    required this.thumbnail,
    required this.confidence,
  });

  factory PredictionCandidate.fromJson(Map<String, dynamic> json) {
    final location = _mapValue(json['location']);
    final label = _stringValue(
      json['predicted_label'] ?? json['label'] ?? location['predicted_label'],
    );

    return PredictionCandidate(
      predictedLabel: label,
      name: _stringValue(
        json['location_name'] ??
            json['name'] ??
            location['location_name'] ??
            location['name'],
        fallback: label,
      ),
      province: _stringValue(json['province'] ?? location['province']),
      thumbnail: _assetPath(
        _stringValue(
          json['thumbnail_url'] ??
              json['image_url'] ??
              location['thumbnail_url'] ??
              location['image_url'],
        ),
      ),
      confidence: _doubleValue(json['confidence']),
    );
  }
}

class Location {
  static const double minRecognitionConfidence = 0.7;

  final int id;
  final String predictedLabel;
  final String name;
  final String province;
  final String address;
  final String description;
  final String openingHours;
  final String ticketPrice;
  final List<String> highlights;
  final String videoUrl;
  final String thumbnail;
  final List<String>? gallery;
  final List<String> relatedLocations;
  final double confidence;
  final List<PredictionCandidate> topMatches;
  final DateTime? recognizedAt;

  Location({
    required this.id,
    required this.predictedLabel,
    required this.name,
    required this.province,
    required this.address,
    required this.description,
    required this.openingHours,
    required this.ticketPrice,
    required this.highlights,
    required this.videoUrl,
    required this.thumbnail,
    this.gallery,
    required this.relatedLocations,
    this.confidence = 0,
    this.topMatches = const [],
    this.recognizedAt,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    final embeddedLocation = _mapValue(json['location']);
    final source = <String, dynamic>{...embeddedLocation, ...json};
    final galleryItems = _stringList(
      source['gallery'],
    ).map(_assetPath).toList();

    return Location(
      id: _intValue(source['id']),
      predictedLabel: _stringValue(
        source['predicted_label'] ?? source['label'],
      ),
      name: _stringValue(
        source['location_name'] ?? source['name'],
        fallback: _stringValue(source['predicted_label'] ?? source['label']),
      ),
      province: _stringValue(source['province']),
      address: _stringValue(source['address']),
      description: _stringValue(source['description']),
      openingHours: _stringValue(source['opening_hours']),
      ticketPrice: _stringValue(source['ticket_price']),
      highlights: _stringList(source['highlights']),
      videoUrl: _stringValue(source['video_url']),
      thumbnail: _assetPath(_stringValue(source['thumbnail_url'])),
      gallery: galleryItems.isEmpty ? null : galleryItems,
      relatedLocations: _stringList(source['related_locations']),
      confidence: _doubleValue(source['confidence']),
      topMatches: _predictionList(source['top3'] ?? source['top_matches']),
      recognizedAt: _dateValue(source['recognized_at']),
    );
  }

  bool get hasAiResult => confidence >= minRecognitionConfidence;

  Location copyWith({
    double? confidence,
    List<PredictionCandidate>? topMatches,
    DateTime? recognizedAt,
  }) {
    return Location(
      id: id,
      predictedLabel: predictedLabel,
      name: name,
      province: province,
      address: address,
      description: description,
      openingHours: openingHours,
      ticketPrice: ticketPrice,
      highlights: highlights,
      videoUrl: videoUrl,
      thumbnail: thumbnail,
      gallery: gallery,
      relatedLocations: relatedLocations,
      confidence: confidence ?? this.confidence,
      topMatches: topMatches ?? this.topMatches,
      recognizedAt: recognizedAt ?? this.recognizedAt,
    );
  }
}

Map<String, dynamic> _mapValue(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _doubleValue(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _stringValue(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

DateTime? _dateValue(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

List<PredictionCandidate> _predictionList(Object? value) {
  if (value is! List) return const [];

  return value
      .whereType<Map>()
      .map(
        (item) => PredictionCandidate.fromJson(Map<String, dynamic>.from(item)),
      )
      .where((item) => item.predictedLabel.isNotEmpty)
      .toList();
}

String _assetPath(String path) {
  if (path.isEmpty || path.startsWith('assets/')) return path;
  return 'assets/$path';
}
