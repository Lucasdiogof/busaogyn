import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../transit/domain/entities/tracked_vehicle.dart';
import '../../transit/domain/models/observed_movement.dart';
import 'stop_sequence.dart';
import 'transit_catalog.dart';

/// Planejador de viagens OFFLINE sobre as sequências estimadas (ADR-0005:
/// só em desenvolvimento).
///
/// Grafo: os nós são pontos; as arestas são as passagens consecutivas de
/// um trajeto (variante + sentido) com sequência `estimated`. Trajetos
/// `partial`/`none` não entram: pertencer a uma linha não prova ordem.
/// Embarque e desembarque só valem na ordem do trajeto (índice crescente).
///
/// Baldeação: no MESMO ponto, ou a pé até [plannerMaxWalkM] em linha reta,
/// sempre com aviso (travessia, calçada e acessibilidade não são conhecidas).
/// Nunca entre variantes da mesma linha. Duas baldeações só quando não há
/// viagem direta nem com uma baldeação, e só no mesmo ponto (sem caminhada).

/// Caminhada máxima numa baldeação (linha reta entre os pontos).
const plannerMaxWalkM = 150.0;

/// Alternativas devolvidas, no máximo.
const plannerMaxOptions = 6;

/// Teto de combinações examinadas numa busca (evita explosão).
const plannerMaxExpansions = 200000;

enum TripReliability {
  /// Todos os trechos com ordem conferida contra os logradouros oficiais,
  /// pontos de embarque/desembarque de confiança alta, sem passagem
  /// repetida e baldeação no mesmo ponto.
  reliable,

  /// Plausível pela geometria, mas com algo inferido (ver [TripCaution]).
  estimated,
}

/// O que faz uma alternativa ser só "estimada".
enum TripCaution {
  /// Ordem do trajeto sem conferência com os logradouros oficiais.
  orderNotCrossChecked,

  /// Embarque ou desembarque com posição incerta na sequência.
  uncertainStop,

  /// O trajeto passa duas vezes pelo ponto.
  repeatedPass,

  /// Baldeação a pé: travessia, calçada e acessibilidade não verificadas.
  walkUnverified,

  /// Embarque, desembarque ou baldeação em estação de corredor ou terminal:
  /// associação à linha inferida (não há relação oficial ponto-linha).
  inferredHub,

  /// Troca entre plataformas da mesma estação de corredor (mesmo nome na
  /// pasta oficial do corredor); qual plataforma atende cada sentido não é
  /// informado.
  sameStation,
}

enum TripPlanStatus {
  ok,
  sameStop,
  unknownStop,
  noCoverageOrigin,
  noCoverageDestination,
  noRoute,
}

/// Um trecho de ônibus: embarque e desembarque num trajeto.
@immutable
class TripLeg {
  const TripLeg(
    this.shape,
    this.sequence,
    this.boardIndex,
    this.alightIndex, {
    this.hub = false,
  });

  final CatalogShape shape;
  final StopSequence sequence;
  final int boardIndex;
  final int alightIndex;

  /// Embarque ou desembarque em estação/terminal (associação inferida).
  final bool hub;

  SequenceEntry get board => sequence.entries[boardIndex];
  SequenceEntry get alight => sequence.entries[alightIndex];

  /// Paradas estimadas percorridas (sem contar a de embarque).
  int get stops => alightIndex - boardIndex;

  /// Extensão pelo trajeto (m), da posição estimada de um ponto à do outro.
  int get distanceM => alight.alongM - board.alongM;

  List<TripCaution> get cautions => [
    if (!sequence.streetValidated) TripCaution.orderNotCrossChecked,
    if (board.level != StopLevel.high || alight.level != StopLevel.high)
      TripCaution.uncertainStop,
    if (_repeated(board.stopId) || _repeated(alight.stopId))
      TripCaution.repeatedPass,
    if (hub) TripCaution.inferredHub,
  ];

  bool _repeated(String stopId) =>
      sequence.entries.where((e) => e.stopId == stopId).length > 1;

  /// Geometria do trecho no trajeto oficial (simplificado para desenho).
  List<GeoPosition> get path =>
      shape.line.slice(board.alongM.toDouble(), alight.alongM.toDouble());
}

@immutable
class TripOption {
  TripOption(this.legs, {this.walkM = 0, this.sameStation = false})
    : assert(legs.isNotEmpty && legs.length <= 3);

  /// Baldeação entre plataformas da mesma estação de corredor.
  final bool sameStation;

  final List<TripLeg> legs;

  /// Caminhada da baldeação (0 = mesmo ponto).
  final int walkM;

  int get transfers => legs.length - 1;
  int get distanceM => legs.fold(0, (sum, l) => sum + l.distanceM);

  late final List<TripCaution> cautions = {
    for (final l in legs) ...l.cautions,
    if (sameStation)
      TripCaution.sameStation
    else if (walkM > 0)
      TripCaution.walkUnverified,
  }.toList();

  TripReliability get reliability =>
      cautions.isEmpty ? TripReliability.reliable : TripReliability.estimated;

  int get _uncertain => legs.fold(
    0,
    (n, l) =>
        n + [l.board, l.alight].where((e) => e.level != StopLevel.high).length,
  );

  /// Mesmas linhas (base) na mesma ordem: alternativas equivalentes.
  String get key => legs.map((l) => l.shape.lineId).join('>');

  /// Ordem do spec: confiável, menos baldeações, menos caminhada, menor
  /// extensão, menos trechos incertos.
  static int compare(TripOption a, TripOption b) {
    for (final c in [
      a.reliability.index.compareTo(b.reliability.index),
      a.transfers.compareTo(b.transfers),
      a.walkM.compareTo(b.walkM),
      a.distanceM.compareTo(b.distanceM),
      a._uncertain.compareTo(b._uncertain),
    ]) {
      if (c != 0) return c;
    }
    return a.key.compareTo(b.key);
  }
}

@immutable
class TripPlan {
  const TripPlan(
    this.status, [
    this.options = const [],
    this.truncated = false,
  ]);

  final TripPlanStatus status;
  final List<TripOption> options;

  /// A busca atingiu [plannerMaxExpansions] e parou.
  final bool truncated;
}

class TripPlanner {
  TripPlanner(this.catalog) {
    for (final seq in catalog.sequences) {
      final shape = catalog.shape(seq.shapeId);
      if (shape == null || shape.direction == null || !seq.ordered) {
        continue;
      }
      final s = _routes.length;
      _routes.add((shape, seq));
      for (var i = 0; i < seq.entries.length; i++) {
        _occurrences.putIfAbsent(seq.entries[i].stopId, () => []).add((s, i));
      }
    }
  }

  final TransitCatalog catalog;
  final _routes = <(CatalogShape, StopSequence)>[];
  final _occurrences = <String, List<(int, int)>>{};
  final _walkCache = <String, List<(String, int)>>{};
  Map<(int, int), List<String>>? _grid;

  /// Trajetos utilizáveis (sequência `estimated`).
  int get routeCount => _routes.length;

  /// Pontos que participam do grafo.
  int get stopCount => _occurrences.length;

  /// Arestas do grafo (pares consecutivos de paradas nos trajetos).
  int get edgeCount =>
      _routes.fold(0, (n, r) => n + math.max(0, r.$2.entries.length - 1));

  /// Linhas com pelo menos um trajeto utilizável.
  int get lineCount => {for (final r in _routes) r.$1.lineId}.length;

  bool covers(String stopId) => _occurrences.containsKey(stopId.trim());

  /// Pontos do grafo onde dá para trocar de linha sem andar (2+ linhas).
  int get sameStopTransferPoints => _occurrences.values
      .where(
        (occ) => {for (final (s, _) in occ) _routes[s].$1.lineId}.length > 1,
      )
      .length;

  /// Pares de pontos do grafo a até [plannerMaxWalkM] (baldeação a pé
  /// possível, sempre sinalizada). Calcula todos os vizinhos: uso em métricas.
  int get walkTransferPairs =>
      _occurrences.keys.fold(0, (n, id) => n + _walkable(id).length) ~/ 2;

  /// Trajetos utilizáveis (para escolher exemplos em métricas e testes).
  List<(CatalogShape, StopSequence)> get routes => List.unmodifiable(_routes);

  TripPlan plan(String origin, String destination) {
    final o = origin.trim();
    final d = destination.trim();
    if (catalog.stop(o) == null || catalog.stop(d) == null) {
      return const TripPlan(TripPlanStatus.unknownStop);
    }
    if (o == d) return const TripPlan(TripPlanStatus.sameStop);
    final fromO = _occurrences[o];
    final toD = _occurrences[d];
    if (fromO == null) return const TripPlan(TripPlanStatus.noCoverageOrigin);
    if (toD == null) {
      return const TripPlan(TripPlanStatus.noCoverageDestination);
    }
    // Para cada trajeto, os índices do destino (passagens repetidas).
    final destIn = <int, List<int>>{};
    for (final (s, i) in toD) {
      destIn.putIfAbsent(s, () => []).add(i);
    }
    int? firstAfter(int s, int i) {
      int? best;
      for (final j in destIn[s] ?? const <int>[]) {
        if (j > i && (best == null || j < best)) best = j;
      }
      return best;
    }

    final best = <String, TripOption>{};
    void offer(TripOption option) {
      final current = best[option.key];
      if (current == null || TripOption.compare(option, current) < 0) {
        best[option.key] = option;
      }
    }

    TripLeg leg(int s, int i, int j) {
      final entries = _routes[s].$2.entries;
      return TripLeg(
        _routes[s].$1,
        _routes[s].$2,
        i,
        j,
        hub: _isHub(entries[i].stopId) || _isHub(entries[j].stopId),
      );
    }

    // Diretas: destino depois do embarque, no mesmo trajeto.
    for (final (s, i) in fromO) {
      final j = firstAfter(s, i);
      if (j != null) offer(TripOption([leg(s, i, j)]));
    }
    final directLines = {
      for (final o in best.values) o.legs.first.shape.lineId,
    };

    // Uma baldeação.
    var expansions = 0;
    var truncated = false;
    search:
    for (final (s1, i) in fromO) {
      final route1 = _routes[s1];
      final line1 = route1.$1.lineId;
      if (directLines.contains(line1)) continue; // já resolve sem baldeação
      final entries = route1.$2.entries;
      for (var k = i + 1; k < entries.length; k++) {
        final t1 = entries[k].stopId;
        if (t1 == d) break; // o próprio trajeto chegou: é direta
        for (final (t2, walk) in [(t1, 0), ..._walkable(t1)]) {
          for (final (s2, m) in _occurrences[t2] ?? const <(int, int)>[]) {
            if (++expansions > plannerMaxExpansions) {
              truncated = true;
              break search;
            }
            final line2 = _routes[s2].$1.lineId;
            if (line2 == line1 || directLines.contains(line2)) continue;
            final j = firstAfter(s2, m);
            if (j == null) continue;
            offer(
              TripOption(
                [leg(s1, i, k), leg(s2, m, j)],
                walkM: walk,
                sameStation: walk > 0 && _sameStation(t1, t2),
              ),
            );
          }
        }
      }
    }
    if (best.isEmpty && !truncated) {
      truncated = _twoTransfers(fromO, toD, d, leg, offer);
    }
    final options = best.values.toList()..sort(TripOption.compare);
    if (options.isEmpty) {
      return TripPlan(TripPlanStatus.noRoute, const [], truncated);
    }
    return TripPlan(
      TripPlanStatus.ok,
      List.unmodifiable(options.take(plannerMaxOptions)),
      truncated,
    );
  }

  /// Duas baldeações no mesmo ponto. Devolve `true` se parou no limite.
  bool _twoTransfers(
    List<(int, int)> fromO,
    List<(int, int)> toD,
    String d,
    TripLeg Function(int, int, int) leg,
    void Function(TripOption) offer,
  ) {
    // Para cada ponto, os embarques que levam ao destino: (trajeto, i, j).
    final toDest = <String, List<(int, int, int)>>{};
    for (final (s3, j) in toD) {
      final entries = _routes[s3].$2.entries;
      for (var m = 0; m < j; m++) {
        toDest.putIfAbsent(entries[m].stopId, () => []).add((s3, m, j));
      }
    }
    var expansions = 0;
    for (final (s1, i) in fromO) {
      final line1 = _routes[s1].$1.lineId;
      final e1 = _routes[s1].$2.entries;
      for (var k = i + 1; k < e1.length; k++) {
        final t1 = e1[k].stopId;
        if (t1 == d) break;
        for (final (s2, m2) in _occurrences[t1] ?? const <(int, int)>[]) {
          final line2 = _routes[s2].$1.lineId;
          if (line2 == line1) continue;
          final e2 = _routes[s2].$2.entries;
          for (var k2 = m2 + 1; k2 < e2.length; k2++) {
            final t2 = e2[k2].stopId;
            if (t2 == d) break;
            for (final (s3, m3, j3)
                in toDest[t2] ?? const <(int, int, int)>[]) {
              if (++expansions > plannerMaxExpansions) return true;
              final line3 = _routes[s3].$1.lineId;
              if (line3 == line1 || line3 == line2) continue;
              offer(
                TripOption([leg(s1, i, k), leg(s2, m2, k2), leg(s3, m3, j3)]),
              );
            }
          }
        }
      }
    }
    return false;
  }

  bool _isHub(String stopId) {
    final kind = catalog.stop(stopId)?.kind;
    return kind == CatalogStopKind.station || kind == CatalogStopKind.terminal;
  }

  bool _sameStation(String a, String b) {
    final ga = catalog.stop(a)?.group;
    return ga != null && ga == catalog.stop(b)?.group;
  }

  /// Pontos do grafo a até [plannerMaxWalkM] (linha reta), sem o próprio.
  List<(String, int)> _walkable(String stopId) =>
      _walkCache.putIfAbsent(stopId, () {
        final stop = catalog.stop(stopId);
        final lat = stop?.latitude;
        final lon = stop?.longitude;
        if (lat == null || lon == null) return const [];
        final here = GeoPosition(latitude: lat, longitude: lon);
        final grid = _grid ??= _buildGrid();
        final (cy, cx) = _cell(lat, lon);
        final out = <(String, int)>[];
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            for (final id in grid[(cy + dy, cx + dx)] ?? const <String>[]) {
              if (id == stopId) continue;
              final other = catalog.stop(id)!;
              final m = geoDistanceMeters(
                here,
                GeoPosition(
                  latitude: other.latitude!,
                  longitude: other.longitude!,
                ),
              );
              if (m <= plannerMaxWalkM) out.add((id, m.round()));
            }
          }
        }
        return out;
      });

  // Células de ~0,0015° (~165 m): vizinhos a até 150 m caem nas 9 células.
  static const _cellDeg = 0.0015;
  (int, int) _cell(double lat, double lon) =>
      ((lat / _cellDeg).floor(), (lon / _cellDeg).floor());

  Map<(int, int), List<String>> _buildGrid() {
    final grid = <(int, int), List<String>>{};
    for (final id in _occurrences.keys) {
      final s = catalog.stop(id);
      if (s?.latitude == null || s?.longitude == null) continue;
      grid.putIfAbsent(_cell(s!.latitude!, s.longitude!), () => []).add(id);
    }
    return grid;
  }
}
