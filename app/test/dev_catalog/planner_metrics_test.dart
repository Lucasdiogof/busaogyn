/// Métricas e exemplos do planejador com o catálogo REAL de desenvolvimento.
///
/// Lê `dev_catalog/cmtc_catalog_payload.g.dart` em tempo de execução (fora do
/// Git; gerado por `data/cmtc/pipeline/export_catalog.py`). Sem o arquivo
/// (CI, clones públicos), os testes são pulados. Nenhum dado real fica no
/// código: os exemplos são escolhidos do próprio catálogo.
///
///     flutter test test/dev_catalog/planner_metrics_test.dart
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:busaogyn/src/features/catalog/data/catalog_codec.dart';
import 'package:busaogyn/src/features/catalog/domain/stop_sequence.dart';
import 'package:busaogyn/src/features/catalog/domain/transit_catalog.dart';
import 'package:busaogyn/src/features/catalog/domain/trip_planner.dart';
import 'package:flutter_test/flutter_test.dart';

final _payload = File('dev_catalog/cmtc_catalog_payload.g.dart');
final _skip = _payload.existsSync()
    ? null
    : 'catálogo de desenvolvimento ausente (normal fora da máquina autorizada)';

TransitCatalog _load() {
  final text = _payload.readAsStringSync();
  return decodeCatalog(
    text.substring(text.indexOf("r'''") + 4, text.lastIndexOf("'''")),
  );
}

String _pct(int a, int b) => '${(100 * a / b).toStringAsFixed(1)}%';

void main() {
  late TransitCatalog catalog;
  late TripPlanner planner;

  setUpAll(() {
    if (_skip != null) return;
    final sw = Stopwatch()..start();
    catalog = _load();
    final decode = sw.elapsedMilliseconds;
    sw.reset();
    planner = TripPlanner(catalog);
    // ignore: avoid_print
    print(
      'decode=${decode}ms grafo=${sw.elapsedMilliseconds}ms '
      'trajetos=${planner.routeCount} pontos=${planner.stopCount} '
      'arestas=${planner.edgeCount} linhas=${planner.lineCount}',
    );
  });

  test('exemplos reais: direta no sentido certo, nunca ao contrário', () {
    final (shape, seq) = planner.routes.firstWhere(
      (r) =>
          r.$2.entries.length >= 6 &&
          r.$2.entries.every((e) => e.level == StopLevel.high) &&
          {for (final e in r.$2.entries) e.stopId}.length ==
              r.$2.entries.length,
    );
    final a = seq.entries[1].stopId;
    final b = seq.entries[5].stopId;
    final forward = planner.plan(a, b);
    expect(forward.status, TripPlanStatus.ok);
    expect(
      forward.options.any(
        (o) => o.transfers == 0 && o.legs.single.shape.id == shape.id,
      ),
      isTrue,
    );
    // Ao contrário, ESTE trajeto nunca serve (pode haver outro, ex.: volta).
    final back = planner.plan(b, a);
    expect(
      back.options.any((o) => o.legs.any((l) => l.shape.id == shape.id)),
      isFalse,
    );
  }, skip: _skip);

  test('cobertura e desempenho em amostras reproduzíveis', () {
    final graphStops = [
      for (final s in catalog.stops)
        if (planner.covers(s.id)) s.id,
    ]..sort();
    final allStops = [
      for (final s in catalog.stops)
        if (s.latitude != null) s.id,
    ]..sort();
    // ignore: avoid_print
    print(
      'baldeações possíveis: mesmo ponto=${planner.sameStopTransferPoints} '
      'a pé (pares <= ${plannerMaxWalkM.toInt()} m)=${planner.walkTransferPairs}',
    );
    for (final (name, pool) in [
      ('pontos do grafo', graphStops),
      ('todos os pontos', allStops),
    ]) {
      final rnd = math.Random(42);
      final counts = <String, int>{};
      final times = <int>[];
      var truncated = 0;
      const n = 500;
      for (var k = 0; k < n; k++) {
        final o = pool[rnd.nextInt(pool.length)];
        final d = pool[rnd.nextInt(pool.length)];
        final sw = Stopwatch()..start();
        final plan = planner.plan(o, d);
        times.add(sw.elapsedMicroseconds);
        if (plan.truncated) truncated++;
        final key = plan.status != TripPlanStatus.ok
            ? plan.status.name
            : '${plan.options.first.reliability.name}-'
                  '${plan.options.first.transfers}b';
        counts[key] = (counts[key] ?? 0) + 1;
      }
      times.sort();
      final ok = counts.entries
          .where((e) => e.key.contains('-'))
          .fold(0, (a, e) => a + e.value);
      // ignore: avoid_print
      print(
        '[$name] n=$n com rota=${_pct(ok, n)} $counts truncadas=$truncated '
        'busca: mediana=${times[n ~/ 2] / 1000}ms '
        'p95=${times[(n * 0.95).floor()] / 1000}ms max=${times.last / 1000}ms',
      );
      expect(times[(n * 0.95).floor()], lessThan(250000)); // < 250 ms
    }
  }, skip: _skip);
}
