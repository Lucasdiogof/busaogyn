import 'dart:math' as math;

import '../../transit/domain/entities/tracked_vehicle.dart';

/// Decodifica polyline do Google (precisão 1e-5) em posições.
List<GeoPosition> decodePolyline(String encoded) {
  final out = <GeoPosition>[];
  var index = 0;
  var lat = 0;
  var lon = 0;
  int next() {
    var result = 0;
    var shift = 0;
    int byte;
    do {
      if (index >= encoded.length) {
        throw const FormatException('polyline truncada');
      }
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    // Sem `~`: no Web (dart2js) operadores bit a bit devolvem inteiros sem
    // sinal de 32 bits e `~x` viraria um positivo enorme.
    return (result & 1) != 0 ? -(result >> 1) - 1 : result >> 1;
  }

  while (index < encoded.length) {
    lat += next();
    lon += next();
    out.add(GeoPosition(latitude: lat / 1e5, longitude: lon / 1e5));
  }
  return out;
}

const _earthM = 6371008.8;
const _refLat = -16.68; // Goiânia: plano local equiretangular

({double x, double y}) _xy(GeoPosition p) {
  const k = math.pi / 180 * _earthM;
  return (
    x: p.longitude * k * math.cos(_refLat * math.pi / 180),
    y: p.latitude * k,
  );
}

/// Projeção de um ponto sobre uma linha.
class LineProjection {
  const LineProjection(this.distanceM, this.alongM, this.segment);

  /// Distância perpendicular ao trajeto.
  final double distanceM;

  /// Posição ao longo do trajeto, desde o início.
  final double alongM;
  final int segment;
}

/// Linha pré-processada para projeções repetidas (plano local; erro
/// desprezível na escala da RMTC).
class RouteLine {
  RouteLine(this.points)
    : assert(points.length >= 2),
      _xys = [for (final p in points) _xy(p)] {
    _cum.add(0);
    for (var i = 1; i < _xys.length; i++) {
      final a = _xys[i - 1];
      final b = _xys[i];
      _cum.add(
        _cum.last + math.sqrt(math.pow(b.x - a.x, 2) + math.pow(b.y - a.y, 2)),
      );
    }
  }

  final List<GeoPosition> points;
  final List<({double x, double y})> _xys;
  final _cum = <double>[];

  double get lengthM => _cum.last;

  /// Todas as passagens do trajeto a até [maxDistanceM] do ponto (um trajeto
  /// pode passar duas vezes pelo mesmo lugar: retorno, laço). Mesma regra do
  /// pipeline (`Polyline.project_all`): segmentos seguidos dentro da
  /// distância formam uma passagem, salvo salto ao longo do trajeto maior que
  /// 2x a distância (retorno em U).
  List<LineProjection> projectAll(GeoPosition position, double maxDistanceM) {
    final p = _xy(position);
    final passes = <LineProjection>[];
    LineProjection? current;
    var lastAlong = 0.0;
    for (var i = 0; i < _xys.length - 1; i++) {
      final a = _xys[i];
      final b = _xys[i + 1];
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final seg2 = dx * dx + dy * dy;
      final t = seg2 == 0
          ? 0.0
          : (((p.x - a.x) * dx + (p.y - a.y) * dy) / seg2).clamp(0.0, 1.0);
      final d = math.sqrt(
        math.pow(p.x - (a.x + t * dx), 2) + math.pow(p.y - (a.y + t * dy), 2),
      );
      if (d <= maxDistanceM) {
        final proj = LineProjection(d, _cum[i] + t * math.sqrt(seg2), i);
        if (current != null && proj.alongM - lastAlong > 2 * maxDistanceM) {
          passes.add(current);
          current = null;
        }
        if (current == null || proj.distanceM < current.distanceM) {
          current = proj;
        }
        lastAlong = proj.alongM;
      } else if (current != null) {
        passes.add(current);
        current = null;
      }
    }
    if (current != null) passes.add(current);
    return passes;
  }

  /// Ponto mais próximo do trajeto.
  LineProjection project(GeoPosition position) {
    final p = _xy(position);
    var best = const LineProjection(double.infinity, 0, 0);
    for (var i = 0; i < _xys.length - 1; i++) {
      final a = _xys[i];
      final b = _xys[i + 1];
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final seg2 = dx * dx + dy * dy;
      final t = seg2 == 0
          ? 0.0
          : (((p.x - a.x) * dx + (p.y - a.y) * dy) / seg2).clamp(0.0, 1.0);
      final cx = a.x + t * dx;
      final cy = a.y + t * dy;
      final d = math.sqrt(math.pow(p.x - cx, 2) + math.pow(p.y - cy, 2));
      if (d < best.distanceM) {
        best = LineProjection(d, _cum[i] + t * math.sqrt(seg2), i);
      }
    }
    return best;
  }

  /// Trecho do trajeto a partir de [alongM] até o fim (inclui o ponto exato).
  List<GeoPosition> sliceFrom(double alongM) {
    if (alongM <= 0) return List.unmodifiable(points);
    for (var i = 0; i < points.length - 1; i++) {
      if (_cum[i + 1] >= alongM) {
        final seg = _cum[i + 1] - _cum[i];
        final t = seg == 0 ? 0.0 : (alongM - _cum[i]) / seg;
        final a = points[i];
        final b = points[i + 1];
        return [
          GeoPosition(
            latitude: a.latitude + (b.latitude - a.latitude) * t,
            longitude: a.longitude + (b.longitude - a.longitude) * t,
          ),
          ...points.sublist(i + 1),
        ];
      }
    }
    return [points.last];
  }

  /// Trecho entre [fromM] e [toM] ao longo do trajeto (de embarque a
  /// desembarque), com as pontas interpoladas.
  List<GeoPosition> slice(double fromM, double toM) => [
    _at(fromM),
    for (var i = 1; i < points.length - 1; i++)
      if (_cum[i] > fromM && _cum[i] < toM) points[i],
    _at(toM),
  ];

  GeoPosition _at(double alongM) {
    if (alongM <= 0) return points.first;
    for (var i = 0; i < points.length - 1; i++) {
      if (_cum[i + 1] >= alongM) {
        final seg = _cum[i + 1] - _cum[i];
        final t = seg == 0 ? 0.0 : (alongM - _cum[i]) / seg;
        final a = points[i];
        final b = points[i + 1];
        return GeoPosition(
          latitude: a.latitude + (b.latitude - a.latitude) * t,
          longitude: a.longitude + (b.longitude - a.longitude) * t,
        );
      }
    }
    return points.last;
  }
}

/// Retângulo geográfico (para enquadrar a câmera).
class GeoBounds {
  const GeoBounds(this.south, this.west, this.north, this.east);

  factory GeoBounds.of(Iterable<GeoPosition> positions) {
    var s = 90.0, w = 180.0, n = -90.0, e = -180.0;
    for (final p in positions) {
      s = math.min(s, p.latitude);
      n = math.max(n, p.latitude);
      w = math.min(w, p.longitude);
      e = math.max(e, p.longitude);
    }
    return GeoBounds(s, w, n, e);
  }

  final double south;
  final double west;
  final double north;
  final double east;

  @override
  bool operator ==(Object other) =>
      other is GeoBounds &&
      other.south == south &&
      other.west == west &&
      other.north == north &&
      other.east == east;

  @override
  int get hashCode => Object.hash(south, west, north, east);
}

/// Zoom (MapLibre, tiles de 512 px) para [bounds] caber em [widthPx] x
/// [heightPx] de mapa visível, limitado a [minZoom]..[maxZoom]. Calculado
/// aqui para não depender do `fitBounds` de cada plataforma.
double fitZoom(
  GeoBounds bounds, {
  required double widthPx,
  required double heightPx,
  double minZoom = 9,
  double maxZoom = 17,
}) {
  const equator = 40075016.686;
  final lat = (bounds.north + bounds.south) / 2;
  final cosLat = math.cos(lat * math.pi / 180);
  final spanX = (bounds.east - bounds.west).abs() / 360 * equator * cosLat;
  final spanY = (bounds.north - bounds.south).abs() / 360 * equator;
  if (widthPx <= 0 || heightPx <= 0) return minZoom;
  double zoomFor(double span, double px) => span <= 0
      ? maxZoom
      : math.log(px * equator * cosLat / (512 * span)) / math.ln2;
  final zx = zoomFor(spanX, widthPx);
  // Latitude: metros por pixel também escalam com cos(lat) no Mercator.
  final zy = zoomFor(spanY, heightPx);
  return math.min(zx, zy).clamp(minZoom, maxZoom);
}

extension GeoBoundsCenter on GeoBounds {
  GeoPosition get center =>
      GeoPosition(latitude: (north + south) / 2, longitude: (east + west) / 2);
}
