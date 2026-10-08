import '../../domain/entities/tracked_vehicle.dart';
import '../../domain/models/observed_movement.dart' show geoDistanceMeters;
import 'vehicle_map_data.dart' show vehiclePositionChanged;

/// Duração da transição visual entre duas posições reais consecutivas.
const markerTransitionDuration = Duration(milliseconds: 700);

/// Acima desta distância o marcador troca de lugar sem percorrer o mapa.
///
/// A consulta do acompanhado é de ~15 s e a dos secundários de ~30 s; um
/// ônibus urbano anda no máximo algumas centenas de metros nesse intervalo.
/// 1.000 m cobre o salto legítimo de uma consulta perdida e descarta saltos
/// que são retomada após pausa, troca de veículo ou dado inválido.
const maxAnimatedJumpMeters = 1000.0;

/// Abaixo disto a diferença é ruído de GPS: troca direta, sem animar.
const minAnimatedMoveMeters = 2.0;

/// Distância entre duas coordenadas, em metros (a mesma do movimento
/// observado).
double distanceMeters(GeoPosition a, GeoPosition b) => geoDistanceMeters(a, b);

/// Se vale animar de [from] até [to].
bool shouldAnimateMove(GeoPosition from, GeoPosition to) {
  final distance = distanceMeters(from, to);
  return distance >= minAnimatedMoveMeters && distance <= maxAnimatedJumpMeters;
}

/// Posição entre [from] e [to] para `t` em [0, 1].
///
/// `t` é limitado ao intervalo: nunca passa de [to] (sem extrapolação) e em
/// `t >= 1` devolve exatamente [to].
GeoPosition interpolatePosition(GeoPosition from, GeoPosition to, double t) {
  if (t >= 1) return to;
  if (t <= 0) return from;
  final eased = t * t * (3 - 2 * t);
  return GeoPosition(
    latitude: from.latitude + (to.latitude - from.latitude) * eased,
    longitude: from.longitude + (to.longitude - from.longitude) * eased,
  );
}

class _Segment {
  _Segment(this.from, this.to, this.startedAt);

  final GeoPosition from;
  final GeoPosition to;
  final Duration startedAt;
}

/// Posição exibida de cada marcador, com transição A → B entre duas
/// coordenadas realmente recebidas. Não prevê movimento: ao chegar em B o
/// marcador para até a próxima amostra. Puro e dirigido por tempo explícito,
/// para ser testado sem relógio nem mapa.
class VehicleMotion {
  VehicleMotion({this.duration = markerTransitionDuration});

  final Duration duration;
  final _shown = <String, GeoPosition>{};
  final _segments = <String, _Segment>{};

  GeoPosition? shown(String id) => _shown[id];

  Iterable<String> get ids => _shown.keys;

  bool get animating => _segments.isNotEmpty;

  Iterable<String> get animatingIds => _segments.keys;

  /// Define a última posição real de [id] em [now]. `null` remove o marcador.
  void setTarget(String id, GeoPosition? target, Duration now) {
    if (target == null) {
      remove(id);
      return;
    }
    final current = _shown[id];
    final pending = _segments[id];
    // Mesma amostra de novo (ex.: só mudou o estado "antigo"): não reinicia.
    if (pending != null && !vehiclePositionChanged(pending.to, target)) return;
    if (pending == null &&
        current != null &&
        !vehiclePositionChanged(current, target)) {
      return;
    }
    if (current == null || !shouldAnimateMove(current, target)) {
      _shown[id] = target;
      _segments.remove(id);
      return;
    }
    // Nova amostra no meio de uma transição: parte de onde o marcador está.
    _segments[id] = _Segment(current, target, now);
  }

  void remove(String id) {
    _shown.remove(id);
    _segments.remove(id);
  }

  void retainOnly(Set<String> keep) {
    for (final id in _shown.keys.toList()) {
      if (!keep.contains(id)) remove(id);
    }
  }

  void clear() {
    _shown.clear();
    _segments.clear();
  }

  /// Avança as transições até [now]; `true` se ainda há alguma em curso.
  bool tick(Duration now) {
    for (final id in _segments.keys.toList()) {
      final segment = _segments[id]!;
      final elapsed = (now - segment.startedAt).inMicroseconds;
      final t = elapsed / duration.inMicroseconds;
      _shown[id] = interpolatePosition(segment.from, segment.to, t);
      if (t >= 1) _segments.remove(id);
    }
    return _segments.isNotEmpty;
  }
}
