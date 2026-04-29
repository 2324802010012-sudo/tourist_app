import '../models/location_model.dart';

class AIMatchService {
  static Location? findLocation(String label, List<Location> locations) {
    String normalize(String text) {
      return text
          .toLowerCase()
          .replaceAll("_", " ")
          .replaceAll("-", " ")
          .trim();
    }

    final input = normalize(label);

    for (var loc in locations) {
      final target = normalize(loc.predictedLabel);

      if (input.contains(target) || target.contains(input)) {
        return loc;
      }
    }

    return null;
  }
}
