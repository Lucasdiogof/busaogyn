import '../../transit/domain/entities/tracked_vehicle.dart';
import 'text_search.dart';
import 'transit_catalog.dart';

/// Resultado da associação do ônibus acompanhado a um trajeto oficial.
enum RouteMatchLevel {
  /// Todas as evidências concordam: o percurso futuro pode ser desenhado
  /// (sempre rotulado como estimado).
  confirmed,

  /// Variante e sentido identificados, mas o ônibus ainda não andou o
  /// bastante para confirmar pela geometria. Nada é desenhado.
  pending,

  /// Evidências insuficientes ou conflitantes. Nada é desenhado.
  ambiguous,

  /// Sem dado para tentar (catálogo sem trajeto, sem posição atual).
  unavailable,
}

/// Motivo legível (traduzido na interface).
enum RouteMatchReason {
  confirmed,
  noShapes,
  noPosition,
  routeNameMissing,
  routeNameNoMatch,
  routeNameSeveral,
  directionUnknown,
  shapeMissing,
  offRoute,
  waitingMovement,
  movingBackwards,
}

class RouteMatch {
  const RouteMatch(
    this.level,
    this.reason, {
    this.shape,
    this.alongM,
    this.future = const [],
  });

  final RouteMatchLevel level;
  final RouteMatchReason reason;

  /// Trajeto oficial associado (variante + sentido), quando identificado.
  final CatalogShape? shape;

  /// Posição atual projetada ao longo do trajeto.
  final double? alongM;

  /// Trecho do trajeto à frente do ônibus (só com [RouteMatchLevel.confirmed]).
  final List<GeoPosition> future;

  bool get confirmed => level == RouteMatchLevel.confirmed;
}

/// Distância máxima entre o GPS e o trajeto para considerar o ônibus nele.
const routeMatchMaxDistanceM = 50.0;

/// Avanço mínimo observado ao longo do trajeto para confirmar o sentido.
const routeMatchMinProgressM = 20.0;

/// Recuo tolerado entre duas amostras (ruído de GPS).
const _backTolerance = 15.0;

Set<String> _words(String? text) => {
  for (final w in searchTokens(text))
    if (w.length >= 3 && w != 'terminal') w,
};

String _key(String? text) => (_words(text).toList()..sort()).join(' ');

/// 'i' se o destino casa com o último trecho da denominação ('A / … / B'),
/// 'v' se casa com o primeiro; `null` se não casa ou casa com os dois.
String? directionByDestination(String? destination, String? variantName) {
  if (destination == null || variantName == null) return null;
  final parts = [
    for (final p in variantName.split('/'))
      if (p.trim().isNotEmpty) p,
  ];
  if (parts.length < 2) return null;
  final dest = _words(destination);
  final first = _words(parts.first).intersection(dest).isNotEmpty;
  final last = _words(parts.last).intersection(dest).isNotEmpty;
  if (first == last) return null;
  return last ? 'i' : 'v';
}

/// Associa o ônibus acompanhado a um trajeto oficial do catálogo.
///
/// Regras, em ordem (qualquer falha encerra sem desenhar nada):
/// 1. a linha (`routeId`) precisa ter trajetos no catálogo;
/// 2. o `routeName` da RMTC precisa ser igual à DENOMINAÇÃO de exatamente
///    uma variante do cadastro;
/// 3. o destino da RMTC precisa apontar um sentido (extremo final = ida,
///    inicial = volta) e existir exatamente um trajeto dessa variante nesse
///    sentido;
/// 4. a posição atual (não expirada) e as posições observadas precisam estar
///    a até [routeMatchMaxDistanceM] do trajeto;
/// 5. as posições observadas precisam avançar pelo menos
///    [routeMatchMinProgressM] no sentido do trajeto, sem recuar.
RouteMatch matchTrackedRoute({
  required TransitCatalog catalog,
  required String? routeId,
  required String? routeName,
  required String? destination,
  required GeoPosition? position,
  List<GeoPosition> trail = const [],
}) {
  if (routeId == null) {
    return const RouteMatch(
      RouteMatchLevel.unavailable,
      RouteMatchReason.noShapes,
    );
  }
  final shapes = catalog.shapesOf(routeId);
  if (shapes.isEmpty) {
    return const RouteMatch(
      RouteMatchLevel.unavailable,
      RouteMatchReason.noShapes,
    );
  }
  if (position == null) {
    return const RouteMatch(
      RouteMatchLevel.unavailable,
      RouteMatchReason.noPosition,
    );
  }
  if (routeName == null || routeName.trim().isEmpty) {
    return const RouteMatch(
      RouteMatchLevel.ambiguous,
      RouteMatchReason.routeNameMissing,
    );
  }

  final key = _key(routeName);
  final variants = [
    for (final v in catalog.variantsOf(routeId))
      if (_key(v.name) == key) v,
  ];
  if (variants.isEmpty) {
    return const RouteMatch(
      RouteMatchLevel.ambiguous,
      RouteMatchReason.routeNameNoMatch,
    );
  }
  if (variants.length > 1) {
    return const RouteMatch(
      RouteMatchLevel.ambiguous,
      RouteMatchReason.routeNameSeveral,
    );
  }
  final variant = variants.single;
  final direction = directionByDestination(destination, variant.name);
  if (direction == null) {
    return const RouteMatch(
      RouteMatchLevel.ambiguous,
      RouteMatchReason.directionUnknown,
    );
  }
  final candidates = [
    for (final s in shapes)
      if (s.variantId == variant.id && s.direction == direction) s,
  ];
  if (candidates.length != 1) {
    return const RouteMatch(
      RouteMatchLevel.ambiguous,
      RouteMatchReason.shapeMissing,
    );
  }
  final shape = candidates.single;
  final line = shape.line;

  final current = line.project(position);
  if (current.distanceM > routeMatchMaxDistanceM) {
    return RouteMatch(
      RouteMatchLevel.ambiguous,
      RouteMatchReason.offRoute,
      shape: shape,
    );
  }
  final along = <double>[];
  for (final p in trail) {
    final projection = line.project(p);
    if (projection.distanceM > routeMatchMaxDistanceM) {
      return RouteMatch(
        RouteMatchLevel.ambiguous,
        RouteMatchReason.offRoute,
        shape: shape,
      );
    }
    along.add(projection.alongM);
  }
  if (along.isEmpty || along.last != current.alongM) along.add(current.alongM);
  for (var i = 1; i < along.length; i++) {
    if (along[i] < along[i - 1] - _backTolerance) {
      return RouteMatch(
        RouteMatchLevel.ambiguous,
        RouteMatchReason.movingBackwards,
        shape: shape,
      );
    }
  }
  if (along.last - along.first < routeMatchMinProgressM) {
    return RouteMatch(
      RouteMatchLevel.pending,
      RouteMatchReason.waitingMovement,
      shape: shape,
      alongM: current.alongM,
    );
  }
  return RouteMatch(
    RouteMatchLevel.confirmed,
    RouteMatchReason.confirmed,
    shape: shape,
    alongM: current.alongM,
    future: line.sliceFrom(current.alongM),
  );
}
