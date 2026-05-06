import 'package:flutter_test/flutter_test.dart';
import 'package:tourist_app/models/location_model.dart';

void main() {
  test('Location.fromJson keeps AI confidence and top predictions', () {
    final location = Location.fromJson({
      'id': 8,
      'predicted_label': 'cau_vang',
      'location_name': 'Cầu Vàng',
      'province': 'Đà Nẵng',
      'address': 'Bà Nà Hills, Đà Nẵng',
      'description': 'Công trình biểu tượng trên núi.',
      'opening_hours': '8:00 - 18:30',
      'ticket_price': '350.000-450.000đ',
      'highlights': ['Check-in', 'Cảnh quan'],
      'video_url': 'videos/cau_vang.mp4',
      'thumbnail_url': 'images/cau_vang.jpg',
      'confidence': 0.91,
      'top3': [
        {
          'predicted_label': 'cau_vang',
          'location_name': 'Cầu Vàng',
          'confidence': 0.91,
        },
        {
          'predicted_label': 'ba_na_hills',
          'location_name': 'Bà Nà Hills',
          'confidence': 0.07,
        },
      ],
    });

    expect(location.thumbnail, 'assets/images/cau_vang.jpg');
    expect(location.confidence, 0.91);
    expect(location.hasAiResult, isTrue);
    expect(location.topMatches, hasLength(2));
    expect(location.topMatches.first.name, 'Cầu Vàng');
  });

  test('Location treats confidence below 70 percent as unrecognized', () {
    final location = Location.fromJson({
      'id': 8,
      'predicted_label': 'cau_vang',
      'location_name': 'Cầu Vàng',
      'thumbnail_url': 'images/cau_vang.jpg',
      'confidence': 0.69,
      'top3': [
        {
          'predicted_label': 'cau_vang',
          'location_name': 'Cầu Vàng',
          'confidence': 0.69,
        },
      ],
    });

    expect(Location.minRecognitionConfidence, 0.7);
    expect(location.hasAiResult, isFalse);
  });
}
