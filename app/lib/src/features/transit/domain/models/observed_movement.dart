import 'dart:math' as math;

import '../entities/tracked_vehicle.dart';

/// Deslocamento mínimo (desde a última âncora) para recalcular a direção;
/// abaixo disso é ruído de GPS de um ônibus parado ou quase parado.
const observedHeadingMinMeters = 8.0;

/// Entre duas posições mais distantes que isto não há movimento observável
/// (consulta perdida, retomada após pausa, dado inválido): a direção não é
/// atualizada e o rastro recomeça, sem linha atravessando o mapa.
const observedJumpMaxMeters = 1000.0;

/// Deslocamento mínimo para o rastro ganhar um ponto novo.
const observedTrailMinMeters = 2.0;

/// Posições reais guardadas no rastro (~5 min com consultas de 15 s).
const observedTrailMaxPoints = 20;

const _earthRadiusMeters = 6371000.0;

double _rad(double degrees) => degrees * math.pi / 180;

/// Distância de grande círculo (haversine) em metros.
double geoDistanceMeters(GeoPosition a, GeoPosition b) {
  final dLat = _rad(b.latitude - a.latitude);
  final dLon = _rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.latitude)) *
          math.cos(_rad(b.latitude)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * _earthRadiusMeters * math.asin(math.min(1, math.sqrt(h)));
}

/// Azimute inicial de [from] para [to] (fórmula geodésica de grande
/// círculo), em graus no intervalo [0, 360): 0 = norte, 90 = leste.
double initialBearingDegrees(GeoPosition from, GeoPosition to) {
  final lat1 = _rad(from.latitude);
  final lat2 = _rad(to.latitude);
  final dLon = _rad(to.longitude - from.longitude);
  final y = math.sin(dLon) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  final degrees = math.atan2(y, x) * 180 / math.pi;
  return (degrees + 360) % 360;
}

/// Diferença angular assinada de [from] para [to] pelo menor caminho, em
/// (-180, 180]: 359° → 1° é +2°, não -358°.
double shortestAngleDelta(double from, double to) {
  final delta = ((to - from) % 360 + 360) % 360;
  return delta > 180 ? delta - 360 : delta;
}

/// Ângulo entre [from] e [to] para `t` em [0, 1], pelo menor arco, normalizado
/// em [0, 360).
double interpolateAngle(double from, double to, double t) {
  final clamped = t.clamp(0.0, 1.0);
  final value = from + shortestAngleDelta(from, to) * clamped;
  return (value % 360 + 360) % 360;
}

/// Movimento recente OBSERVADO do ônibus acompanhado, montado só com
/// posições realmente recebidas da API nesta sessão.
///
/// - `observedHeading`: direção do último deslocamento observado. Não é o
///   sentido oficial da linha (a fonte não informa direção).
/// - `observedTrail`: posições reais recentes, da mais antiga para a mais
///   nova. Não é rota nem itinerário: só o passado observado.
class ObservedMovement {
  const ObservedMovement({
    this.observedHeading,
    this.observedTrail = const [],
    this.anchor,
    this.lastSampleAt,
  });

  static const empty = ObservedMovement();

  /// Graus a partir do norte, sentido horário; `null` até haver
  /// deslocamento suficiente entre duas posições reais.
  final double? observedHeading;
  final List<GeoPosition> observedTrail;

  /// Posição real usada no último cálculo de direção.
  final GeoPosition? anchor;

  /// Instante (`fetchedAt` da API) da última amostra aceita.
  final DateTime? lastSampleAt;

  /// Incorpora uma posição real recebida em [sampledAt].
  ///
  /// Ignora a amostra quando ela é antiga (`stale` da API), não tem instante
  /// válido ou não é mais nova que a anterior (o mesmo snapshot em cache).
  ObservedMovement observe(
    GeoPosition position, {
    required DateTime? sampledAt,
    required bool stale,
  }) {
    if (stale || sampledAt == null) return this;
    final previousAt = lastSampleAt;
    if (previousAt != null && !sampledAt.isAfter(previousAt)) return this;

    final last = observedTrail.isEmpty ? null : observedTrail.last;
    if (last == null) {
      // Primeira posição: sem direção conhecida.
      return ObservedMovement(
        observedTrail: [position],
        anchor: position,
        lastSampleAt: sampledAt,
      );
    }

    if (geoDistanceMeters(last, position) > observedJumpMaxMeters) {
      // Salto: recomeça o rastro e mantém a direção anterior.
      return ObservedMovement(
        observedHeading: observedHeading,
        observedTrail: [position],
        anchor: position,
        lastSampleAt: sampledAt,
      );
    }

    var trail = observedTrail;
    if (geoDistanceMeters(last, position) >= observedTrailMinMeters) {
      trail = [...observedTrail, position];
      if (trail.length > observedTrailMaxPoints) {
        trail = trail.sublist(trail.length - observedTrailMaxPoints);
      }
    }

    var heading = observedHeading;
    var anchor = this.anchor ?? last;
    final moved = geoDistanceMeters(anchor, position);
    if (moved > observedJumpMaxMeters) {
      // Âncora longe demais para medir direção: recomeça daqui, sem girar.
      // Sem isso ela ficaria para trás e a direção nunca mais mudaria.
      anchor = position;
    } else if (moved >= observedHeadingMinMeters) {
      heading = initialBearingDegrees(anchor, position);
      anchor = position;
    }

    return ObservedMovement(
      observedHeading: heading,
      observedTrail: List.unmodifiable(trail),
      anchor: anchor,
      lastSampleAt: sampledAt,
    );
  }
}
