import 'dart:math' as math;

import 'package:busaogyn/src/features/catalog/domain/route_match.dart';
import 'package:busaogyn/src/features/catalog/domain/stop_sequence.dart';
import 'package:busaogyn/src/features/catalog/domain/transit_catalog.dart';
import 'package:busaogyn/src/features/catalog/domain/trip_planner.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_fixture.dart';

/// Rede SINTÉTICA (metros a leste/norte de um ponto fictício):
///
///   A ─ B ─ C ─ D ─ E      linha 100 (ida A→C, volta C→A; variante 100-2 A→X→C)
///             └ F (100 m)  linha 200: C→D→E   · linha 300: F→G (baldeação a pé)
///             └ H (300 m)  linha 400: H→I     (longe demais para baldear)
///                          linha 500: C→J     (sequência só "partial")
///                          linha 600: K→L→K→M (passa duas vezes em K)
///                          linha 700: A→E     (pontos de posição incerta)
const _pos = <String, (double, double)>{
  'A': (0, 0),
  'B': (1000, 0),
  'C': (2000, 0),
  'D': (3000, 0),
  'E': (4000, 0),
  'X': (1000, 400),
  'F': (2000, 100),
  'G': (2000, 1100),
  'H': (2000, -300),
  'I': (2000, -1300),
  'J': (2500, 800),
  'K': (6000, 0),
  'L': (7000, 0),
  'M': (8000, 0),
  'Z': (9000, 9000),
  'N': (5000, 1000),
  'P1': (3000, -2000),
  'P2': (3050, -2000),
  'Q': (3050, -3000),
};

/// Plataformas da mesma estação de corredor (P1, P2) e um terminal (TA).
const _kinds = {'P1': CatalogStopKind.station, 'P2': CatalogStopKind.station};

(double, double) _ll(String id) {
  final (x, y) = _pos[id]!;
  return (-16.70 + y / 111195, -49.30 + x / (111195 * 0.958));
}

TransitCatalog _network() {
  final shapes = <CatalogShape>[];
  final sequences = <StopSequence>[];
  void route(
    String variant,
    String dir,
    List<String> stops, {
    SequenceStatus status = SequenceStatus.estimated,
    double? rho = 0.9,
    Set<String> medium = const {},
    String? evidence,
  }) {
    final id = '$variant$dir';
    shapes.add(
      CatalogShape(
        id: id,
        lineId: variant.split('-').first,
        variantId: variant,
        direction: dir,
        encoded: encodePolyline([for (final s in stops) _ll(s)]),
      ),
    );
    var along = 0.0;
    final parts = <String>[];
    for (var i = 0; i < stops.length; i++) {
      if (i > 0) {
        final (x1, y1) = _pos[stops[i - 1]]!;
        final (x2, y2) = _pos[stops[i]]!;
        along += math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));
      }
      parts.add(
        '${stops[i]},${along.round()},${medium.contains(stops[i]) ? 'm' : 'h'}',
      );
    }
    sequences.add(
      StopSequence(
        shapeId: id,
        status: status,
        encoded: parts.join(';'),
        streetRho: rho,
        evidence: evidence,
      ),
    );
  }

  route('100-1', 'i', ['A', 'B', 'C']);
  route('100-1', 'v', ['C', 'B', 'A']);
  route('100-2', 'i', ['A', 'X', 'C']);
  route('200-1', 'i', ['C', 'D', 'E']);
  route('300-1', 'i', ['F', 'G'], rho: null);
  route('400-1', 'i', ['H', 'I']);
  route('500-1', 'i', ['C', 'J'], status: SequenceStatus.partial);
  route('600-1', 'i', ['K', 'L', 'K', 'M']);
  route('700-1', 'i', ['A', 'E'], medium: {'A'});
  // Só alcançável com duas baldeações a partir de B (ver testes).
  route('800-1', 'i', ['E', 'N']);
  // Ordem conferida, mas lista incompleta ('ordered'): o planejador usa.
  route(
    '950-1',
    'i',
    ['D', 'P1'],
    status: SequenceStatus.ordered,
    evidence: 'corredor',
    medium: {'P1'},
  );
  route('960-1', 'i', ['P2', 'Q'], medium: {'P2'});

  final base = fixtureCatalog();
  return TransitCatalog(
    version: base.version,
    lines: const [],
    variants: const [],
    stops: [
      for (final MapEntry(key: id, value: _) in _pos.entries)
        CatalogStop(
          id: id,
          kind: _kinds[id] ?? CatalogStopKind.ped,
          latitude: _ll(id).$1,
          longitude: _ll(id).$2,
          group: _kinds.containsKey(id) ? 'eixo:ESTACAO X' : null,
        ),
    ],
    shapes: shapes,
    sequences: sequences,
  );
}

void main() {
  final planner = TripPlanner(_network());

  List<String> keys(TripPlan p) => [for (final o in p.options) o.key];

  test('grafo: só sequências estimated entram', () {
    expect(
      planner.routeCount,
      11,
    ); // 500-1i (partial) fora; 950 (ordered) entra
    expect(planner.covers('J'), isFalse);
    expect(planner.covers('C'), isTrue);
    expect(planner.lineCount, 9); // 500 (partial) fora
  });

  test('origem = destino, ponto inexistente e sem cobertura', () {
    expect(planner.plan('A', 'A').status, TripPlanStatus.sameStop);
    expect(planner.plan('nada', 'A').status, TripPlanStatus.unknownStop);
    expect(planner.plan('Z', 'A').status, TripPlanStatus.noCoverageOrigin);
    expect(planner.plan('A', 'J').status, TripPlanStatus.noCoverageDestination);
  });

  test('direta no sentido certo; variantes da mesma linha viram uma só', () {
    final p = planner.plan('A', 'C');
    expect(p.status, TripPlanStatus.ok);
    expect(keys(p), ['100']);
    final o = p.options.single;
    expect(o.reliability, TripReliability.reliable);
    expect(o.legs.single.shape.direction, 'i');
    expect(o.legs.single.stops, 2);
    expect(o.legs.single.distanceM, closeTo(2000, 2));
    expect(o.legs.single.path.length, greaterThanOrEqualTo(2));
  });

  test('sentido invertido usa a volta, nunca a ida', () {
    final p = planner.plan('C', 'A');
    expect(p.options.single.legs.single.shape.id, '100-1v');
    // B→A: a ida (A→B→C) não serve; só a volta.
    expect(
      planner
          .plan('B', 'A')
          .options
          .every((o) => o.legs.every((l) => l.shape.direction == 'v')),
      isTrue,
    );
  });

  test('baldeação no mesmo ponto é confiável e vem antes da estimada', () {
    final p = planner.plan('A', 'E');
    // Confiável com 1 baldeação antes da direta estimada (700: posição incerta).
    expect(keys(p), ['100>200', '700']);
    final t = p.options.first;
    expect(t.reliability, TripReliability.reliable);
    expect((t.transfers, t.walkM), (1, 0));
    expect(t.legs.first.alight.stopId, 'C');
    expect(t.legs.last.board.stopId, 'C');
    expect(p.options.last.cautions, [TripCaution.uncertainStop]);
  });

  test('baldeação a pé curta é só estimada e avisada', () {
    final p = planner.plan('A', 'G');
    final o = p.options.single;
    expect(o.key, '100>300');
    expect(o.walkM, closeTo(100, 3));
    expect(o.reliability, TripReliability.estimated);
    expect(o.cautions, contains(TripCaution.walkUnverified));
    expect(o.cautions, contains(TripCaution.orderNotCrossChecked));
  });

  test(
    'ponto próximo demais longe (300 m) e sequência parcial não conectam',
    () {
      expect(planner.plan('A', 'I').status, TripPlanStatus.noRoute);
      expect(
        planner.plan('B', 'J').status,
        TripPlanStatus.noCoverageDestination,
      );
    },
  );

  test('passagem repetida: embarca na passagem certa e avisa', () {
    final p = planner.plan('K', 'M');
    final leg = p.options.single.legs.single;
    expect(leg.boardIndex, 2); // a 2ª passagem por K (trecho mais curto)
    expect(p.options.single.cautions, contains(TripCaution.repeatedPass));
    // L→K: K depois de L, na mesma volta.
    expect(planner.plan('L', 'K').options.single.legs.single.stops, 1);
  });

  test('duas baldeações só quando não há opção mais simples', () {
    // B→N: nenhuma direta nem com 1 baldeação; com 2, no mesmo ponto.
    final p = planner.plan('B', 'N');
    expect(keys(p), ['100>200>800', '100>700>800']);
    final best = p.options.first;
    expect((best.transfers, best.walkM), (2, 0));
    expect(best.reliability, TripReliability.reliable);
    expect(best.legs.map((l) => l.board.stopId), ['B', 'C', 'E']);
    // A→N tem opção com 1 baldeação: não oferece 2.
    expect(
      planner.plan('A', 'N').options.every((o) => o.transfers <= 1),
      isTrue,
    );
  });

  test('estação: mesma estação e associação inferida sempre sinalizadas', () {
    final o = planner.plan('D', 'Q').options.single;
    expect(o.key, '950>960');
    expect(o.walkM, closeTo(50, 3));
    expect(o.cautions, contains(TripCaution.sameStation));
    expect(o.cautions, contains(TripCaution.inferredHub));
    expect(o.cautions, isNot(contains(TripCaution.walkUnverified)));
    expect(o.reliability, TripReliability.estimated);
  });

  test('ordered entra no planejador, não nos próximos pontos', () {
    final seq = _network().sequenceOf('950-1i')!;
    expect(seq.ordered, isTrue);
    expect(seq.evidence, 'corredor');
    final match = RouteMatch(
      RouteMatchLevel.confirmed,
      RouteMatchReason.confirmed,
      alongM: 0,
    );
    expect(nextStopsFor(match, seq).reason, NextStopsReason.sequenceUnreliable);
  });

  test('desempenho: rede sintética grande dentro do limite', () {
    final rnd = math.Random(7);
    final shapes = <CatalogShape>[];
    final sequences = <StopSequence>[];
    final stops = <CatalogStop>[
      for (var i = 0; i < 3000; i++)
        CatalogStop(
          id: '$i',
          kind: CatalogStopKind.ped,
          latitude: -16.7 + rnd.nextDouble() * 0.2,
          longitude: -49.3 + rnd.nextDouble() * 0.2,
        ),
    ];
    for (var r = 0; r < 220; r++) {
      final ids = [for (var k = 0; k < 32; k++) '${rnd.nextInt(3000)}'];
      shapes.add(
        CatalogShape(
          id: 'S$r',
          lineId: 'L$r',
          variantId: 'L$r-1',
          direction: 'i',
          encoded: encodePolyline([(-16.7, -49.3), (-16.6, -49.2)]),
        ),
      );
      sequences.add(
        StopSequence(
          shapeId: 'S$r',
          status: SequenceStatus.estimated,
          encoded: [
            for (var k = 0; k < ids.length; k++) '${ids[k]},${k * 300},h',
          ].join(';'),
          streetRho: 0.9,
        ),
      );
    }
    final big = TripPlanner(
      TransitCatalog(
        version: fixtureCatalog().version,
        lines: const [],
        variants: const [],
        stops: stops,
        shapes: shapes,
        sequences: sequences,
      ),
    );
    final sw = Stopwatch()..start();
    for (var q = 0; q < 300; q++) {
      final p = big.plan('${rnd.nextInt(3000)}', '${rnd.nextInt(3000)}');
      expect(p.options.length, lessThanOrEqualTo(plannerMaxOptions));
    }
    // ~1 ms por busca nesta máquina; folga larga para CI.
    expect(sw.elapsedMilliseconds, lessThan(3000));
  });
}
