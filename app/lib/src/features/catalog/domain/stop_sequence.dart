import 'package:flutter/foundation.dart';

import 'route_match.dart';

/// Situação da sequência de paradas de um trajeto. Sempre ESTIMADA pela
/// geometria (ADR-0005): a CMTC não forneceu a sequência oficial.
enum SequenceStatus {
  /// Ordem utilizável, exibida como estimativa.
  estimated,

  /// Só pertencimento (pontos perto do trajeto), sem ordem confirmada.
  partial,

  /// Nenhum ponto do cadastro associado ao trajeto.
  none,
}

/// Confiança de um ponto na sequência estimada.
enum StopLevel { high, medium }

@immutable
class SequenceEntry {
  const SequenceEntry(this.stopId, this.alongM, this.level);

  final String stopId;

  /// Posição ao longo do trajeto (m). Um ponto pode aparecer duas vezes
  /// (trajeto que passa de novo pelo mesmo trecho).
  final int alongM;
  final StopLevel level;
}

class StopSequence {
  StopSequence({
    required this.shapeId,
    required this.status,
    required String encoded,
    this.circular = false,
    this.ambiguous = const [],
  }) : _encoded = encoded;

  final String shapeId;
  final SequenceStatus status;
  final bool circular;

  /// Pontos perto do trajeto que ficaram fora por ambiguidade.
  final List<String> ambiguous;
  final String _encoded;

  /// 'ponto,metros,h|m;…' decodificado só quando usado.
  late final List<SequenceEntry> entries = List.unmodifiable([
    for (final part in _encoded.split(';')) ?_entry(part),
  ]);

  /// Pontos distintos associados ao trajeto (sem ordem: por código).
  late final List<String> stopIds = {for (final e in entries) e.stopId}.toList()
    ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));

  static SequenceEntry? _entry(String part) {
    final f = part.split(',');
    if (f.length != 3) return null;
    final along = int.tryParse(f[1]);
    if (f[0].isEmpty || along == null) return null;
    return switch (f[2]) {
      'h' => SequenceEntry(f[0], along, StopLevel.high),
      'm' => SequenceEntry(f[0], along, StopLevel.medium),
      _ => null,
    };
  }
}

/// Ponto só conta como passado com o ônibus 40 m além dele (GPS impreciso;
/// passar perto não basta).
const passedMarginM = 40.0;

enum NextStopsReason { ok, notConfirmed, sequenceUnreliable, endOfRoute }

@immutable
class NextStops {
  const NextStops(
    this.reason, {
    this.remaining = const [],
    this.nextConfident = false,
  });

  final NextStopsReason reason;

  /// Pontos ainda à frente, na ordem estimada.
  final List<SequenceEntry> remaining;

  /// Destacar o primeiro como "próximo ponto" (só com confiança alta).
  final bool nextConfident;

  bool get available => reason == NextStopsReason.ok;
}

/// Próximos pontos do ônibus acompanhado. Só com associação confirmada
/// (variante, sentido, posição atual e projeção coerentes) E sequência
/// estimada confiável; senão o tracking segue como sempre. Nunca há
/// previsão de chegada por ponto. Mesma regra de `tracking.py`.
NextStops nextStopsFor(RouteMatch match, StopSequence? sequence) {
  final along = match.alongM;
  if (!match.confirmed || along == null) {
    return const NextStops(NextStopsReason.notConfirmed);
  }
  if (sequence == null || sequence.status != SequenceStatus.estimated) {
    return const NextStops(NextStopsReason.sequenceUnreliable);
  }
  final remaining = [
    for (final e in sequence.entries)
      if (e.alongM + passedMarginM > along) e,
  ];
  if (remaining.isEmpty) return const NextStops(NextStopsReason.endOfRoute);
  return NextStops(
    NextStopsReason.ok,
    remaining: remaining,
    nextConfident: remaining.first.level == StopLevel.high,
  );
}
