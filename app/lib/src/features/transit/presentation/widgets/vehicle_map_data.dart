import '../../domain/entities/tracked_vehicle.dart';

const vehicleSourceId = 'tracked-vehicle-source';
const vehicleLayerId = 'tracked-vehicle-layer';
const vehicleImageId = 'tracked-vehicle-icon';

/// GeoJSON com o único ônibus acompanhado; vazio quando não há posição.
Map<String, dynamic> vehicleFeatureCollection(GeoPosition? position) {
  return {
    'type': 'FeatureCollection',
    'features': [
      if (position != null)
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'Point',
            // GeoJSON usa [longitude, latitude].
            'coordinates': [position.longitude, position.latitude],
          },
        },
    ],
  };
}

bool vehiclePositionChanged(GeoPosition? previous, GeoPosition? current) {
  if (previous == null || current == null) return previous != current;
  return previous.latitude != current.latitude ||
      previous.longitude != current.longitude;
}
