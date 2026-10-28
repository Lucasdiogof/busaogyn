/// Amostra de viagens REAIS por categoria (cidades, Eixo, BRT, terminais,
/// variantes) para validação por evidência. Só roda com o catálogo local de
/// desenvolvimento; grava em `../data/cmtc/reports/route_samples.json` (fora do
/// Git), que `data/cmtc/pipeline/route_validation.py` confere contra o
/// cadastro oficial. Nenhum dado real fica no código.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:busaogyn/src/features/catalog/data/catalog_codec.dart';
import 'package:busaogyn/src/features/catalog/domain/transit_catalog.dart';
import 'package:busaogyn/src/features/catalog/domain/trip_planner.dart';
import 'package:flutter_test/flutter_test.dart';

final _payload = File('dev_catalog/cmtc_catalog_payload.g.dart');
final _skip = _payload.existsSync()
    ? null
    : 'catálogo de desenvolvimento ausente (normal fora da máquina autorizada)';

void main() {
  test('amostras de viagens reais por categoria', () {
    final text = _payload.readAsStringSync();
    final catalog = decodeCatalog(
      text.substring(text.indexOf("r'''") + 4, text.lastIndexOf("'''")),
    );
    final planner = TripPlanner(catalog);
    final graph = [
      for (final s in catalog.stops)
        if (planner.covers(s.id)) s,
    ]..sort((a, b) => a.id.compareTo(b.id));
    bool city(CatalogStop s, String name) =>
        (s.city ?? '').toUpperCase().contains(name);
    bool corridor(CatalogStop s, String c) => (s.group ?? '').startsWith('$c:');
    final goiania = graph
        .where((s) => city(s, 'GOI') && city(s, 'NIA') && !city(s, 'APARECIDA'))
        .toList();
    final categories = <String, (List<CatalogStop>, List<CatalogStop>)>{
      'Goiânia → Goiânia': (goiania, goiania),
      'Aparecida de Goiânia → Goiânia': (
        graph.where((s) => city(s, 'APARECIDA')).toList(),
        goiania,
      ),
      'Senador Canedo → Goiânia': (
        graph.where((s) => city(s, 'SENADOR CANEDO')).toList(),
        goiania,
      ),
      'Trindade → Goiânia': (
        graph.where((s) => city(s, 'TRINDADE')).toList(),
        goiania,
      ),
      'Goianira → Goiânia': (
        graph.where((s) => city(s, 'GOIANIRA')).toList(),
        goiania,
      ),
      'Estação do Eixo → qualquer': (
        graph.where((s) => corridor(s, 'eixo')).toList(),
        graph,
      ),
      'qualquer → Estação do BRT': (
        graph,
        graph.where((s) => corridor(s, 'brt')).toList(),
      ),
      'Terminal → qualquer': (
        graph.where((s) => s.kind == CatalogStopKind.terminal).toList(),
        graph,
      ),
    };
    final rnd = math.Random(2026);
    final out = <Map<String, Object?>>[];
    final summary = <String, String>{};
    for (final MapEntry(key: name, value: (from, to)) in categories.entries) {
      if (from.isEmpty || to.isEmpty) {
        summary[name] = 'sem pontos no grafo';
        continue;
      }
      var tried = 0;
      var found = 0;
      final variantsSeen = <String>{};
      while (tried < 300 && found < 4) {
        tried++;
        final o = from[rnd.nextInt(from.length)];
        final d = to[rnd.nextInt(to.length)];
        final plan = planner.plan(o.id, d.id);
        if (plan.status != TripPlanStatus.ok) continue;
        final best = plan.options.first;
        found++;
        variantsSeen.addAll(best.legs.map((l) => l.shape.variantId));
        out.add({
          'category': name,
          'origin': o.id,
          'destination': d.id,
          'reliability': best.reliability.name,
          'transfers': best.transfers,
          'walkM': best.walkM,
          'cautions': [for (final c in best.cautions) c.name],
          'alternatives': plan.options.length,
          'legs': [
            for (final l in best.legs)
              {
                'line': l.shape.lineId,
                'variant': l.shape.variantId,
                'direction': l.shape.direction,
                'shape': l.shape.id,
                'board': l.board.stopId,
                'alight': l.alight.stopId,
                'boardAlongM': l.board.alongM,
                'alightAlongM': l.alight.alongM,
                'stops': l.stops,
                'path': [
                  for (var i = l.boardIndex; i <= l.alightIndex; i++)
                    l.sequence.entries[i].stopId,
                ],
                'evidence': l.sequence.evidence,
              },
          ],
        });
      }
      summary[name] =
          '$found com rota em $tried tentativas; variantes: ${variantsSeen.length}';
    }
    final file = File('../data/cmtc/reports/route_samples.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        const JsonEncoder.withIndent(
          ' ',
        ).convert({'summary': summary, 'samples': out}),
      );
    // ignore: avoid_print
    print('${file.path}: ${out.length} viagens\n$summary');
    expect(out, isNotEmpty);
  }, skip: _skip);
}
