import '../../domain/entities/map_vehicle.dart';
import '../../domain/entities/tracked_vehicle.dart';

/// Ônibus acompanhado: fonte, halo e símbolo próprios (prioridade visual).
const vehicleSourceId = 'tracked-vehicle-source';
const vehicleLayerId = 'tracked-vehicle-layer';
const vehicleHaloLayerId = 'tracked-vehicle-halo';

/// Rastro observado do ônibus acompanhado: posições reais recentes ligadas
/// por uma linha discreta. Não é rota nem itinerário.
const observedTrailSourceId = 'busao-observed-trail';
const observedTrailLayerId = 'busao-observed-trail-line';

/// Outros ônibus do ponto: uma única coleção GeoJSON atualizada no lugar,
/// sem recriar layers a cada amostra de GPS.
const secondarySourceId = 'busao-map-vehicles';
const secondaryLayerId = 'busao-map-vehicles-layer';

/// Uma imagem por variante visual (ver `MarkerVariant`).
const busImageIds = <MarkerVariant, String>{
  MarkerVariant.tracked: 'bus-tracked',
  MarkerVariant.secondary: 'bus-secondary',
  MarkerVariant.stale: 'bus-stale',
};

Map<String, dynamic> _collection(List<Map<String, dynamic>> features) => {
  'type': 'FeatureCollection',
  'features': features,
};

Map<String, dynamic> _point(
  GeoPosition position,
  Map<String, dynamic> properties, {
  Object? id,
}) {
  return {
    'type': 'Feature',
    'id': ?id,
    'properties': properties,
    'geometry': {
      'type': 'Point',
      // GeoJSON usa [longitude, latitude].
      'coordinates': [position.longitude, position.latitude],
    },
  };
}

/// GeoJSON do ônibus acompanhado; vazio quando não há posição.
///
/// [heading] é a direção observada exibida (graus a partir do norte); sem
/// ela o desenho fica com a frente para cima.
Map<String, dynamic> vehicleFeatureCollection(
  GeoPosition? position, {
  bool stale = false,
  double? heading,
}) {
  return _collection([
    if (position != null)
      _point(position, {
        'stale': stale,
        'variant': (stale ? MarkerVariant.stale : MarkerVariant.tracked).name,
        'heading': heading ?? 0,
      }),
  ]);
}

/// GeoJSON do rastro observado; precisa de pelo menos duas posições reais.
Map<String, dynamic> observedTrailFeatureCollection(List<GeoPosition> trail) {
  return _collection([
    if (trail.length >= 2)
      {
        'type': 'Feature',
        'properties': <String, dynamic>{},
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final position in trail)
              [position.longitude, position.latitude],
          ],
        },
      },
  ]);
}

/// GeoJSON dos secundários na posição exibida de cada um ([shown]); quem não
/// tem posição exibida fica de fora. O `id` é o número do veículo, para o
/// toque saber qual ônibus foi escolhido.
Map<String, dynamic> secondaryFeatureCollection(
  List<MapVehicle> vehicles,
  GeoPosition? Function(String vehicleNumber) shown,
) {
  return _collection([
    for (final vehicle in vehicles)
      if (shown(vehicle.vehicleNumber) case final position?)
        _point(position, {
          'vehicleNumber': vehicle.vehicleNumber,
          'routeId': vehicle.routeId,
          'stale': vehicle.stale,
          'variant': vehicle.visual.markerVariant.name,
        }, id: vehicle.vehicleNumber),
  ]);
}

bool vehiclePositionChanged(GeoPosition? previous, GeoPosition? current) {
  if (previous == null || current == null) return previous != current;
  return previous.latitude != current.latitude ||
      previous.longitude != current.longitude;
}
