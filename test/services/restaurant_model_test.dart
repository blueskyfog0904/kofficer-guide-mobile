import 'package:flutter_test/flutter_test.dart';
import 'package:kofficer_guide/models/restaurant.dart';

void main() {
  group('Restaurant Model Test', () {
    test('fromJson should parse valid JSON correctly', () {
      final json = {
        'id': '123',
        'name': 'Test Restaurant',
        'region_id': 'reg1',
        'is_active': true,
        'latitude': 37.5,
        'longitude': 127.0,
      };

      final restaurant = Restaurant.fromJson(json);

      expect(restaurant.id, '123');
      expect(restaurant.name, 'Test Restaurant');
      expect(restaurant.regionId, 'reg1');
      expect(restaurant.isActive, true);
      expect(restaurant.latitude, 37.5);
      expect(restaurant.longitude, 127.0);
    });

    test('fromJson should handle null optional fields', () {
      final json = {
        'id': '123',
        'name': 'Test Restaurant',
        'region_id': 'reg1',
        // missing optional fields
      };

      final restaurant = Restaurant.fromJson(json);

      expect(restaurant.id, '123');
      expect(restaurant.title, null);
      expect(restaurant.isActive, false); // default
    });
  });
}

