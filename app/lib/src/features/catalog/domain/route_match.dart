import '../../transit/domain/entities/tracked_vehicle.dart';
import '../../transit/domain/models/observed_movement.dart';
import 'route_geometry.dart';
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

  /// Avanço pelo trajeto muito maior que o deslocamento real: a projeção
  /// pulou para outra passagem do trajeto.
  gpsJump,

  /// O trajeto passa duas vezes pelo trecho e as posições não decidem qual.
  repeatedSection,
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

/// Avanço máximo pelo trajeto entre duas amostras: 1,5x o deslocamento em
/// linha reta + 300 m (curvas e retornos).
const _detourFactor = 1.5;
const _detourSlackM = 300.0;

/// Cadeias coerentes que terminam a até 50 m uma da outra apontam o mesmo
/// lugar (geometria sinuosa perto da amostra): não é ambiguidade.
const _convergeM = 50.0;

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

/// O destino casa com algum trecho da denominação (inclusive um do meio,
/// como "ST AEROPORTO" em "T. Cruzeiro / St. Aeroporto / Eixo T-8").
bool destinationOnItinerary(String? destination, String? variantName) {
  if (destination == null || variantName == null) return false;
  final dest = _words(destination);
  return variantName
      .split('/')
      .any((p) => _words(p).intersection(dest).isNotEmpty);
}

/// Associa o ônibus acompanhado a um trajeto oficial do catálogo.
///
/// Regras, em ordem (qualquer falha encerra sem desenhar nada):
/// 1. a linha (`routeId`) precisa ter trajetos no catálogo;
/// 2. o `routeName` da RMTC precisa ser igual à DENOMINAÇÃO de exatamente
///    uma variante do cadastro;
/// 3. o destino da RMTC precisa apontar um sentido (extremo final = ida,
///    inicial = volta) e existir exatamente um trajeto dessa variante nesse
///    sentido; se o destino casa com um trecho do meio (ou com os dois
///    extremos), decide o deslocamento: vale o sentido em que, de ida e volta,
///    só um é coerente com as posições observadas;
/// 4. a posição atual (não expirada) e as posições observadas precisam estar
///    a até [routeMatchMaxDistanceM] do trajeto;
/// 5. as posições observadas precisam avançar pelo menos
///    [routeMatchMinProgressM] no sentido do trajeto, sem recuar nem saltar;
///    em trecho percorrido duas vezes, só vale se uma única sequência de
///    passagens for coerente.
///
/// As mesmas regras estão em `data/cmtc/pipeline/cmtc/tracking.py` (avaliação
/// com veículos reais); mudar aqui exige mudar lá.
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
  final points = [...trail];
  if (points.isEmpty || points.last != position) points.add(position);
  final direction = directionByDestination(destination, variant.name);
  if (direction == null) {
    if (!destinationOnItinerary(destination, variant.name)) {
      return const RouteMatch(
        RouteMatchLevel.ambiguous,
        RouteMatchReason.directionUnknown,
      );
    }
    return _byMovement([
      for (final s in shapes)
        if (s.variantId == variant.id) s,
    ], points);
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
  final (along, failure) = _chain(shape.line, points);
  if (along == null) {
    return RouteMatch(RouteMatchLevel.ambiguous, failure!, shape: shape);
  }
  final current = along.last;
  if (along.last - along.first < routeMatchMinProgressM) {
    return RouteMatch(
      RouteMatchLevel.pending,
      RouteMatchReason.waitingMovement,
      shape: shape,
      alongM: current,
    );
  }
  return RouteMatch(
    RouteMatchLevel.confirmed,
    RouteMatchReason.confirmed,
    shape: shape,
    alongM: current,
    future: shape.line.sliceFrom(current),
  );
}

/// Sentido decidido pelo deslocamento: confirma só se, entre ida e volta,
/// exatamente um sentido é coerente com as posições e já avançou
/// [routeMatchMinProgressM]; o outro precisa ser incoerente (contrário, fora
/// do trajeto ou com salto).
RouteMatch _byMovement(List<CatalogShape> shapes, List<GeoPosition> points) {
  final ida = [
    for (final s in shapes)
      if (s.direction == 'i') s,
  ];
  final volta = [
    for (final s in shapes)
      if (s.direction == 'v') s,
  ];
  if (ida.length != 1 || volta.length != 1) {
    return const RouteMatch(
      RouteMatchLevel.ambiguous,
      RouteMatchReason.directionUnknown,
    );
  }
  final coherent = [
    for (final s in [ida.single, volta.single])
      if (_chain(s.line, points).$1 case final along?) (s, along),
  ];
  // Os dois coerentes: parado ainda (aguarda) ou, já andando, indecidível.
  final undecided =
      coherent.isEmpty ||
      coherent.any((c) => c.$2.last - c.$2.first >= routeMatchMinProgressM);
  if (coherent.length != 1) {
    return undecided
        ? const RouteMatch(
            RouteMatchLevel.ambiguous,
            RouteMatchReason.directionUnknown,
          )
        : RouteMatch(
            RouteMatchLevel.pending,
            RouteMatchReason.waitingMovement,
            // Só para nomear a variante no aviso; pendente não desenha nada.
            shape: ida.single,
          );
  }
  final (shape, along) = coherent.single;
  final current = along.last;
  if (along.last - along.first < routeMatchMinProgressM) {
    return RouteMatch(
      RouteMatchLevel.pending,
      RouteMatchReason.waitingMovement,
      shape: shape,
      alongM: current,
    );
  }
  return RouteMatch(
    RouteMatchLevel.confirmed,
    RouteMatchReason.confirmed,
    shape: shape,
    alongM: current,
    future: shape.line.sliceFrom(current),
  );
}

/// Posições ao longo do trajeto com continuidade: cada amostra fica na
/// passagem mais próxima à frente da anterior. Cada passagem da 1ª amostra
/// inicia uma cadeia; vale se as coerentes terminam no mesmo lugar (até
/// [_convergeM]).
(List<double>?, RouteMatchReason?) _chain(
  RouteLine line,
  List<GeoPosition> points,
) {
  final candidates = [
    for (final p in points) line.projectAll(p, routeMatchMaxDistanceM),
  ];
  if (candidates.any((c) => c.isEmpty)) {
    return (null, RouteMatchReason.offRoute);
  }
  final chains = <List<double>>[];
  RouteMatchReason? failure;
  for (final start in candidates.first) {
    final along = [start.alongM];
    var ok = true;
    for (var i = 1; i < candidates.length; i++) {
      final ahead = [
        for (final p in candidates[i])
          if (p.alongM >= along.last - _backTolerance) p.alongM,
      ];
      if (ahead.isEmpty) {
        failure = RouteMatchReason.movingBackwards;
        ok = false;
        break;
      }
      final step = ahead.reduce((a, b) => a < b ? a : b);
      final limit =
          geoDistanceMeters(points[i - 1], points[i]) * _detourFactor +
          _detourSlackM;
      if (step - along.last > limit) {
        failure = RouteMatchReason.gpsJump;
        ok = false;
        break;
      }
      along.add(step);
    }
    if (ok) chains.add(along);
  }
  if (chains.isEmpty) return (null, failure);
  final ends = [for (final c in chains) c.last];
  final spread =
      ends.reduce((a, b) => a > b ? a : b) -
      ends.reduce((a, b) => a < b ? a : b);
  if (spread > _convergeM) return (null, RouteMatchReason.repeatedSection);
  // Convergem: vale a de menor avanço (a mais conservadora para confirmar).
  return (
    chains.reduce((a, b) => (a.last - a.first) <= (b.last - b.first) ? a : b),
    null,
  );
}
