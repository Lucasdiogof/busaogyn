import 'package:flutter/foundation.dart';

import '../../transit/domain/entities/tracked_vehicle.dart';
import 'route_geometry.dart';
import 'route_match.dart';
import 'transit_catalog.dart';
import 'trip_planner.dart';

/// GeoJSON das camadas da rede (pontos, trajetos) para o MapLibre. Puro e
/// testável: nenhuma dependência do plugin do mapa.
Map<String, dynamic> featureCollection(List<Map<String, dynamic>> features) => {
  'type': 'FeatureCollection',
  'features': features,
};

const emptyCollection = <String, dynamic>{
  'type': 'FeatureCollection',
  'features': <Map<String, dynamic>>[],
};

List<double> _lonLat(GeoPosition p) => [p.longitude, p.latitude];

Map<String, dynamic> _point(GeoPosition p, Map<String, dynamic> props) => {
  'type': 'Feature',
  'properties': props,
  'geometry': {'type': 'Point', 'coordinates': _lonLat(p)},
};

Map<String, dynamic> _line(
  List<GeoPosition> points,
  Map<String, dynamic> props,
) => {
  'type': 'Feature',
  'properties': props,
  'geometry': {
    'type': 'LineString',
    'coordinates': [for (final p in points) _lonLat(p)],
  },
};

GeoPosition? stopPosition(CatalogStop stop) {
  final lat = stop.latitude;
  final lon = stop.longitude;
  return lat == null || lon == null
      ? null
      : GeoPosition(latitude: lat, longitude: lon);
}

/// Todos os pontos com coordenada; o MapLibre agrupa (cluster) e só desenha
/// o que está na tela (fonte GeoJSON é fatiada em tiles internamente).
Map<String, dynamic> stopsCollection(TransitCatalog catalog) =>
    featureCollection([
      for (final stop in catalog.stops)
        if (stopPosition(stop) case final p?)
          _point(p, {'id': stop.id, 'kind': stop.kind.name}),
    ]);

/// Trajetos da linha. `active` marca o trajeto escolhido (variante +
/// sentido); os demais ficam esmaecidos. `dir`: 'i', 'v' ou '-'.
Map<String, dynamic> routeCollection(
  List<CatalogShape> shapes,
  String? activeShapeId,
) => featureCollection([
  for (final s in shapes)
    _line(s.points, {
      'id': s.id,
      'variant': s.variantId,
      'dir': s.direction ?? '-',
      'active': s.id == activeShapeId,
    }),
]);

/// Início e fim do trajeto ativo (terminais/extremos do desenho oficial).
Map<String, dynamic> routeEndsCollection(CatalogShape? shape) => shape == null
    ? emptyCollection
    : featureCollection([
        _point(shape.points.first, {'end': 'start'}),
        _point(shape.points.last, {'end': 'end'}),
      ]);

/// Pontos oficialmente associados à linha (sem ordem).
Map<String, dynamic> lineStopsCollection(
  TransitCatalog catalog,
  String? lineId,
) => lineId == null
    ? emptyCollection
    : featureCollection([
        for (final stop in catalog.stopsOf(lineId))
          if (stopPosition(stop) case final p?) _point(p, {'id': stop.id}),
      ]);

Map<String, dynamic> selectedStopCollection(CatalogStop? stop) {
  final p = stop == null ? null : stopPosition(stop);
  return p == null
      ? emptyCollection
      : featureCollection([
          _point(p, {'id': stop!.id}),
        ]);
}

/// Trajeto do ônibus acompanhado: o percurso oficial total ('official') e o
/// trecho futuro estimado ('future'). Vazio sem associação confirmada.
Map<String, dynamic> trackRouteCollection(RouteMatch? match) {
  if (match == null || !match.confirmed || match.shape == null) {
    return emptyCollection;
  }
  return featureCollection([
    _line(match.shape!.points, {'kind': 'official'}),
    if (match.future.length >= 2) _line(match.future, {'kind': 'future'}),
  ]);
}

/// Viagem planejada (ESTIMATIVA, não rastreamento): trechos de ônibus
/// ('leg1'/'leg2', com 'dir' do trajeto), caminhada ('walk') e os pontos de
/// origem, baldeação e destino.
Map<String, dynamic> planCollection(
  TransitCatalog catalog,
  TripOption? option,
) {
  if (option == null) return emptyCollection;
  final legs = option.legs;
  GeoPosition? at(String id) {
    final stop = catalog.stop(id);
    return stop == null ? null : stopPosition(stop);
  }

  final points = [
    (legs.first.board.stopId, 'origin'),
    if (legs.length == 2) ...[
      (legs.first.alight.stopId, 'transfer'),
      if (legs.last.board.stopId != legs.first.alight.stopId)
        (legs.last.board.stopId, 'transfer'),
    ],
    (legs.last.alight.stopId, 'destination'),
  ];
  final walkFrom = legs.length == 2 ? at(legs.first.alight.stopId) : null;
  final walkTo = legs.length == 2 ? at(legs.last.board.stopId) : null;
  return featureCollection([
    for (var i = 0; i < legs.length; i++)
      _line(legs[i].path, {
        'kind': 'leg${i + 1}',
        'line': legs[i].shape.lineId,
      }),
    if (option.walkM > 0 && walkFrom != null && walkTo != null)
      _line([walkFrom, walkTo], {'kind': 'walk'}),
    for (final (id, kind) in points)
      if (at(id) case final p?) _point(p, {'id': id, 'kind': kind}),
  ]);
}

/// Pedido de câmera; [serial] muda a cada pedido para repetir o mesmo foco.
@immutable
class MapFocus {
  const MapFocus.point(this.serial, GeoPosition this.point, {this.zoom = 16})
    : bounds = null;
  const MapFocus.bounds(this.serial, GeoBounds this.bounds)
    : point = null,
      zoom = 0;

  final int serial;
  final GeoPosition? point;
  final GeoBounds? bounds;
  final double zoom;
}

/// Tudo o que o mapa precisa da rede. Cada coleção mantém a identidade
/// enquanto não muda: o mapa só reenvia ao nativo o que mudou.
@immutable
class NetworkOverlay {
  const NetworkOverlay({
    required this.stops,
    this.route = emptyCollection,
    this.routeEnds = emptyCollection,
    this.routeStops = emptyCollection,
    this.selectedStop = emptyCollection,
    this.trackRoute = emptyCollection,
    this.plan = emptyCollection,
    this.focus,
  });

  final Map<String, dynamic> stops;
  final Map<String, dynamic> route;
  final Map<String, dynamic> routeEnds;
  final Map<String, dynamic> routeStops;
  final Map<String, dynamic> selectedStop;
  final Map<String, dynamic> trackRoute;

  /// Viagem planejada selecionada (planejador).
  final Map<String, dynamic> plan;
  final MapFocus? focus;
}

/// Monta o [NetworkOverlay] reaproveitando coleções que não mudaram
/// (a de pontos é montada uma vez por catálogo).
class NetworkOverlayBuilder {
  NetworkOverlayBuilder(this.catalog) : _stops = stopsCollection(catalog);

  final TransitCatalog catalog;
  final Map<String, dynamic> _stops;

  (String?, String?)? _routeKey;
  var _route = emptyCollection;
  var _routeEnds = emptyCollection;
  var _routeStops = emptyCollection;
  String? _selectedKey;
  var _selected = emptyCollection;
  Object? _trackKey;
  var _track = emptyCollection;
  TripOption? _planKey;
  var _plan = emptyCollection;

  NetworkOverlay build({
    String? selectedStopId,
    String? routeLineId,
    String? routeShapeId,
    RouteMatch? trackMatch,
    TripOption? plan,
    MapFocus? focus,
  }) {
    if (!identical(plan, _planKey)) {
      _planKey = plan;
      _plan = planCollection(catalog, plan);
    }
    final routeKey = (routeLineId, routeShapeId);
    if (routeKey != _routeKey) {
      _routeKey = routeKey;
      final shapes = routeLineId == null
          ? const <CatalogShape>[]
          : catalog.shapesOf(routeLineId);
      final active = shapes.where((s) => s.id == routeShapeId).firstOrNull;
      _route = routeLineId == null
          ? emptyCollection
          : routeCollection(shapes, routeShapeId);
      _routeEnds = routeEndsCollection(active);
      _routeStops = lineStopsCollection(catalog, routeLineId);
    }
    if (selectedStopId != _selectedKey) {
      _selectedKey = selectedStopId;
      _selected = selectedStopCollection(catalog.stop(selectedStopId));
    }
    // Só redesenha o trajeto do ônibus quando o trecho futuro muda.
    final trackKey = trackMatch == null || !trackMatch.confirmed
        ? null
        : (trackMatch.shape!.id, trackMatch.alongM?.round());
    if (trackKey != _trackKey) {
      _trackKey = trackKey;
      _track = trackRouteCollection(trackMatch);
    }
    return NetworkOverlay(
      // Com um trajeto ou uma viagem no mapa, os pontos gerais saem (só os
      // da linha ou da viagem ficam).
      stops: routeLineId == null && plan == null ? _stops : emptyCollection,
      route: _route,
      routeEnds: _routeEnds,
      routeStops: _routeStops,
      selectedStop: _selected,
      trackRoute: _track,
      plan: _plan,
      focus: focus,
    );
  }
}
