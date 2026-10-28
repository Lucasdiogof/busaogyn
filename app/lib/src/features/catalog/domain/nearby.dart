import '../../transit/domain/entities/tracked_vehicle.dart';
import '../../transit/domain/models/observed_movement.dart';
import 'network_geojson.dart';
import 'transit_catalog.dart';

/// Ponto do catálogo e a distância em LINHA RETA até a posição (não é a
/// distância a pé: não há dados de calçadas nem de travessias).
typedef NearbyStop = ({CatalogStop stop, int meters});

/// Pontos com coordenada até [radiusM] da posição, do mais perto ao mais
/// longe. Busca local; a posição não sai do aparelho.
List<NearbyStop> nearbyStops(
  TransitCatalog catalog,
  GeoPosition at, {
  int limit = 8,
  double radiusM = 1000,
}) {
  final found = <NearbyStop>[];
  for (final stop in catalog.stops) {
    final p = stopPosition(stop);
    if (p == null) continue;
    final d = geoDistanceMeters(at, p);
    if (d <= radiusM) found.add((stop: stop, meters: d.round()));
  }
  found.sort((a, b) => a.meters.compareTo(b.meters));
  return found.length <= limit ? found : found.sublist(0, limit);
}
