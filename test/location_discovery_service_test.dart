import 'package:flutter_test/flutter_test.dart';
import 'package:tourist_app/models/location_model.dart';
import 'package:tourist_app/services/location_discovery_service.dart';

void main() {
  test('normalize removes Vietnamese accents for search', () {
    expect(LocationDiscoveryService.normalize('Đà Nẵng'), 'da nang');
    expect(
      LocationDiscoveryService.normalize('Phố cổ Hội-An'),
      'pho co hoi an',
    );
  });

  test('search matches province without accents', () {
    final results = LocationDiscoveryService.searchLocations([
      _cauVang,
      _hoGuom,
    ], query: 'da nang');

    expect(results.map((item) => item.predictedLabel), contains('cau_vang'));
  });

  test('recommendations use travel preferences', () {
    final results = LocationDiscoveryService.recommendedLocations(
      [_cauVang, _hoGuom],
      {'Trải nghiệm tiết kiệm'},
      limit: 1,
    );

    expect(results.single.predictedLabel, 'ho_guom');
  });
}

final _cauVang = Location(
  id: 8,
  predictedLabel: 'cau_vang',
  name: 'Cầu Vàng',
  province: 'Đà Nẵng',
  address: 'Bà Nà Hills, Đà Nẵng',
  description: 'Công trình check-in nổi tiếng trên cao.',
  openingHours: '8:00 - 18:30',
  ticketPrice: 'Có thu phí',
  estimatedCost: '900.000đ/người',
  highlights: const ['Check-in nổi tiếng', 'Khung cảnh trên cao'],
  videoUrl: 'videos/cau_vang.mp4',
  thumbnail: 'assets/images/cau_vang.jpg',
  relatedLocations: const [],
);

final _hoGuom = Location(
  id: 1,
  predictedLabel: 'ho_guom',
  name: 'Hồ Gươm',
  province: 'Hà Nội',
  address: 'Quận Hoàn Kiếm, Hà Nội',
  description: 'Không gian văn hóa lịch sử ở trung tâm Hà Nội.',
  openingHours: 'Cả ngày',
  ticketPrice: 'Miễn phí',
  estimatedCost: '0-150.000đ/người',
  highlights: const ['Phố đi bộ', 'Không gian trung tâm'],
  videoUrl: 'videos/ho_guom.mp4',
  thumbnail: 'assets/images/ho_guom.jpg',
  relatedLocations: const [],
);
