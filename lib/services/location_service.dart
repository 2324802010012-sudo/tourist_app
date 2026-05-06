import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/location_model.dart';

class LocationService {
  static Future<List<Map<String, dynamic>>> loadLocationMaps() async {
    final data = await rootBundle.loadString('assets/data/locations.json');
    final jsonResult = json.decode(data);

    return (jsonResult as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<List<Location>> loadLocations() async {
    final items = await loadLocationMaps();

    return items.map(Location.fromJson).toList();
  }

  static Future<Location?> findByLabel(String label) async {
    final normalizedLabel = label.toLowerCase().trim();
    if (normalizedLabel.isEmpty) return null;

    final locations = await loadLocations();
    for (final location in locations) {
      if (location.predictedLabel.toLowerCase().trim() == normalizedLabel) {
        return location;
      }
    }

    return null;
  }
}
