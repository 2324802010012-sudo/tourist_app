import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/location_model.dart';

class LocationService {
  static Future<List<Location>> loadLocations() async {
    final data = await rootBundle.loadString('assets/data/locations.json');

    final jsonResult = json.decode(data);

    return (jsonResult as List).map((e) => Location.fromJson(e)).toList();
  }
}
