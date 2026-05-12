import '../models/location_model.dart';
import 'travel_preference_service.dart';

class LocationDiscoveryService {
  static const allProvincesLabel = "Tất cả";

  static final Map<String, List<String>> _preferenceKeywords = {
    "Di sản lịch sử": [
      "di tích",
      "lịch sử",
      "văn hóa",
      "kiến trúc",
      "cổ kính",
      "quốc tử giám",
      "lăng",
      "dinh",
      "phố cổ",
      "công trình tôn giáo",
    ],
    "Thiên nhiên": [
      "thiên nhiên",
      "biển",
      "núi",
      "hang",
      "đảo",
      "vịnh",
      "sinh thái",
      "thuyền",
      "cảnh quan",
      "trên cao",
    ],
    "Check-in": [
      "check-in",
      "biểu tượng",
      "đèn lồng",
      "chụp ảnh",
      "ngắm cảnh",
      "độc đáo",
      "nổi tiếng",
      "trung tâm",
      "cao tầng",
    ],
    "Ẩm thực": [
      "ẩm thực",
      "món ăn",
      "ăn uống",
      "chợ",
      "cà phê",
      "đồ uống",
      "địa phương",
    ],
    "Gia đình": [
      "khu vui chơi",
      "cả ngày",
      "thoải mái",
      "đi bộ",
      "tham quan",
      "dịch vụ",
      "cáp treo",
      "show diễn",
    ],
    "Trải nghiệm tiết kiệm": [
      "miễn phí",
      "0-",
      "gửi xe",
      "đi bộ",
      "vé",
      "tham quan",
      "tiết kiệm",
    ],
  };

  static List<Location> searchLocations(
    List<Location> locations, {
    String query = '',
    Set<String> preferences = const {},
    String province = allProvincesLabel,
    bool preferenceOnly = false,
  }) {
    final normalizedQuery = normalize(query);
    final normalizedProvince = normalize(province);
    final hasProvinceFilter =
        normalizedProvince.isNotEmpty &&
        normalizedProvince != normalize(allProvincesLabel);

    if (normalizedQuery.isEmpty &&
        preferences.isEmpty &&
        !hasProvinceFilter &&
        !preferenceOnly) {
      return locations;
    }

    final scored = <_ScoredLocation>[];
    for (final location in locations) {
      if (hasProvinceFilter &&
          normalize(location.province) != normalizedProvince) {
        continue;
      }

      final queryScore = _queryScore(location, normalizedQuery);
      final preferenceScore = scoreByPreferences(location, preferences);

      if (normalizedQuery.isNotEmpty && queryScore == 0) continue;
      if (preferenceOnly && preferences.isNotEmpty && preferenceScore == 0) {
        continue;
      }

      final score =
          queryScore +
          preferenceScore +
          (hasProvinceFilter ? 35 : 0) +
          _featuredScore(location);

      if (score > 0) {
        scored.add(_ScoredLocation(location, score));
      }
    }

    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.location.name.compareTo(b.location.name);
    });

    return scored.map((item) => item.location).toList();
  }

  static List<Location> recommendedLocations(
    List<Location> locations,
    Set<String> preferences, {
    int limit = 6,
  }) {
    final scored = locations
        .map(
          (location) => _ScoredLocation(
            location,
            scoreByPreferences(location, preferences) +
                _featuredScore(location),
          ),
        )
        .toList();

    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.location.id.compareTo(b.location.id);
    });

    return scored.take(limit).map((item) => item.location).toList();
  }

  static List<String> provinces(List<Location> locations) {
    final values = locations
        .map((location) => location.province.trim())
        .where((province) => province.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return [allProvincesLabel, ...values];
  }

  static int scoreByPreferences(Location location, Set<String> preferences) {
    var score = 0;
    for (final preference in preferences) {
      score += _preferenceScore(location, preference);
    }
    return score;
  }

  static List<String> matchReasons(
    Location location,
    Set<String> preferences, {
    int limit = 2,
  }) {
    final reasons = preferences
        .where((preference) => _preferenceScore(location, preference) > 0)
        .toList();
    return reasons.take(limit).toList(growable: false);
  }

  static String normalize(String input) {
    var text = input.toLowerCase().trim();
    const replacements = {
      'à': 'a',
      'á': 'a',
      'ạ': 'a',
      'ả': 'a',
      'ã': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ậ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ặ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'è': 'e',
      'é': 'e',
      'ẹ': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ệ': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ì': 'i',
      'í': 'i',
      'ị': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ò': 'o',
      'ó': 'o',
      'ọ': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ộ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ợ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ụ': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ự': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỵ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'đ': 'd',
    };

    replacements.forEach((from, to) {
      text = text.replaceAll(from, to);
    });

    return text.replaceAll(RegExp(r'[_\-\s]+'), ' ');
  }

  static int _queryScore(Location location, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return 0;

    final name = normalize(location.name);
    final province = normalize(location.province);
    final address = normalize(location.address);
    final label = normalize(location.predictedLabel);
    final highlights = normalize(location.highlights.join(' '));
    final description = normalize(location.description);
    final allText = normalize(_searchText(location));
    var score = 0;

    if (name == normalizedQuery) score += 120;
    if (name.startsWith(normalizedQuery)) score += 90;
    if (name.contains(normalizedQuery)) score += 70;
    if (label.contains(normalizedQuery)) score += 55;
    if (province.contains(normalizedQuery)) score += 45;
    if (address.contains(normalizedQuery)) score += 35;
    if (highlights.contains(normalizedQuery)) score += 35;
    if (description.contains(normalizedQuery)) score += 20;

    for (final token in normalizedQuery.split(' ')) {
      if (token.length < 2) continue;
      if (allText.contains(token)) score += 8;
    }

    return score;
  }

  static int _preferenceScore(Location location, String preference) {
    if (!TravelPreferenceService.options.contains(preference)) return 0;

    final text = normalize(_searchText(location));
    final keywords = _preferenceKeywords[preference] ?? const [];
    var score = 0;

    for (final keyword in keywords) {
      if (text.contains(normalize(keyword))) score += 18;
    }

    if (preference == "Trải nghiệm tiết kiệm") {
      final ticket = normalize(location.ticketPrice);
      final cost = normalize(location.estimatedCost);
      if (ticket.contains("mien phi") || cost.startsWith("0 ")) score += 35;
      if (cost.contains("100.000") || cost.contains("150.000")) score += 10;
    }

    if (preference == "Gia đình" &&
        normalize(location.openingHours).contains("ca ngay")) {
      score += 12;
    }

    return score;
  }

  static int _featuredScore(Location location) {
    return location.highlights.length + (location.videoUrl.isNotEmpty ? 4 : 0);
  }

  static String _searchText(Location location) {
    return [
      location.name,
      location.predictedLabel,
      location.province,
      location.address,
      location.description,
      location.openingHours,
      location.ticketPrice,
      location.bestTime,
      location.estimatedCost,
      location.suggestedRoute,
      ...location.travelTips,
      ...location.highlights,
    ].join(' ');
  }
}

class _ScoredLocation {
  final Location location;
  final int score;

  const _ScoredLocation(this.location, this.score);
}
