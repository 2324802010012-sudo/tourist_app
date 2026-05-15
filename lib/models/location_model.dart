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
  final String bestTime;
  final String estimatedCost;
  final String suggestedRoute;
  final List<String> travelTips;
  final String mapQuery;
  final List<String> highlights;
  final String videoUrl;
  final String thumbnail;
  final List<String>? gallery;
  final List<String> relatedLocations;
  final double confidence;
  final List<PredictionCandidate> topMatches;
  final int? historyId;
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
    this.bestTime = '',
    this.estimatedCost = '',
    this.suggestedRoute = '',
    this.travelTips = const [],
    this.mapQuery = '',
    required this.highlights,
    required this.videoUrl,
    required this.thumbnail,
    this.gallery,
    required this.relatedLocations,
    this.confidence = 0,
    this.topMatches = const [],
    this.historyId,
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
      bestTime: _stringValue(source['best_time']),
      estimatedCost: _stringValue(source['estimated_cost']),
      suggestedRoute: _stringValue(source['suggested_route']),
      travelTips: _stringList(source['travel_tips']),
      mapQuery: _stringValue(source['map_query']),
      highlights: _stringList(source['highlights']),
      videoUrl: _stringValue(source['video_url']),
      thumbnail: _assetPath(_stringValue(source['thumbnail_url'])),
      gallery: galleryItems.isEmpty ? null : galleryItems,
      relatedLocations: _stringList(source['related_locations']),
      confidence: _doubleValue(source['confidence']),
      topMatches: _predictionList(source['top3'] ?? source['top_matches']),
      historyId: _nullableIntValue(source['history_id']),
      recognizedAt: _dateValue(source['recognized_at']),
    );
  }

  bool get hasAiResult => confidence >= minRecognitionConfidence;

  Location copyWith({
    double? confidence,
    List<PredictionCandidate>? topMatches,
    int? historyId,
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
      bestTime: bestTime,
      estimatedCost: estimatedCost,
      suggestedRoute: suggestedRoute,
      travelTips: travelTips,
      mapQuery: mapQuery,
      highlights: highlights,
      videoUrl: videoUrl,
      thumbnail: thumbnail,
      gallery: gallery,
      relatedLocations: relatedLocations,
      confidence: confidence ?? this.confidence,
      topMatches: topMatches ?? this.topMatches,
      historyId: historyId ?? this.historyId,
      recognizedAt: recognizedAt ?? this.recognizedAt,
    );
  }

  Map<String, dynamic> toStorageJson() {
    return {
      'id': id,
      'predicted_label': predictedLabel,
      'location_name': name,
      'province': province,
      'address': address,
      'description': description,
      'opening_hours': openingHours,
      'ticket_price': ticketPrice,
      'best_time': bestTime,
      'estimated_cost': estimatedCost,
      'suggested_route': suggestedRoute,
      'travel_tips': travelTips,
      'map_query': mapQuery,
      'highlights': highlights,
      'video_url': videoUrl,
      'thumbnail_url': thumbnail.replaceFirst('assets/', ''),
      if (gallery != null)
        'gallery': gallery!
            .map((item) => item.replaceFirst('assets/', ''))
            .toList(),
      'related_locations': relatedLocations,
      'confidence': confidence,
      if (historyId != null) 'history_id': historyId,
      'top3': topMatches
          .map(
            (item) => {
              'predicted_label': item.predictedLabel,
              'location_name': item.name,
              'province': item.province,
              'thumbnail_url': item.thumbnail.replaceFirst('assets/', ''),
              'confidence': item.confidence,
            },
          )
          .toList(),
      if (recognizedAt != null)
        'recognized_at': recognizedAt!.toIso8601String(),
    };
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

int? _nullableIntValue(Object? value) {
  if (value == null) return null;
  final parsed = _intValue(value);
  return parsed == 0 ? null : parsed;
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
