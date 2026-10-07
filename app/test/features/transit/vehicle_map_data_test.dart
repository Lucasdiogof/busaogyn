import 'package:busaogyn/src/core/config/map_config.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/vehicle_map_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a = GeoPosition(latitude: -16.68, longitude: -49.25);

  test('MapConfig usa OpenFreeMap Liberty por padrão', () {
    expect(MapConfig.styleUrl, 'https://tiles.openfreemap.org/styles/liberty');
  });

  test('GeoJSON do ônibus usa [longitude, latitude]', () {
    final fc = vehicleFeatureCollection(a);
    final feature = (fc['features'] as List).single as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>;

    expect(geometry['type'], 'Point');
    expect(geometry['coordinates'], [-49.25, -16.68]);
  });

  test('GeoJSON fica vazio sem posição', () {
    expect(vehicleFeatureCollection(null)['features'], isEmpty);
  });

  test('detecta mudança de coordenada', () {
    const same = GeoPosition(latitude: -16.68, longitude: -49.25);
    const moved = GeoPosition(latitude: -16.69, longitude: -49.25);

    expect(vehiclePositionChanged(a, same), isFalse);
    expect(vehiclePositionChanged(a, moved), isTrue);
    expect(vehiclePositionChanged(null, a), isTrue);
    expect(vehiclePositionChanged(null, null), isFalse);
  });
}
