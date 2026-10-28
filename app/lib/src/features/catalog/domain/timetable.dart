import 'package:flutter/foundation.dart';

/// Validade de um quadro de horários. A CMTC não confirmou a vigência das
/// planilhas: uma data de 2026 sozinha não basta para [confirmed].
enum TimetableValidity {
  /// Vigência confirmada pela fonte (registrada no pipeline).
  confirmed,

  /// Referência do ano da entrega; vigência não confirmada.
  recent,

  /// Referência anterior ao ano da entrega.
  old,

  /// Sem data, data futura, sem partidas ou em conflito: não exibido.
  insufficient,
}

/// Tipos de dia das planilhas OSO ("DOMINGO" vale para domingos e feriados,
/// conforme os dados operacionais da própria planilha).
enum ServiceDay { weekday, saturday, sundayHoliday }

/// Tipo de dia de uma data. Feriados não são conhecidos (a planilha não traz
/// calendário): o passageiro escolhe o quadro de domingo nesses dias.
ServiceDay serviceDayOf(DateTime date) => switch (date.weekday) {
  DateTime.saturday => ServiceDay.saturday,
  DateTime.sunday => ServiceDay.sundayHoliday,
  _ => ServiceDay.weekday,
};

/// Uma aba OSO (planilha horária) de uma linha.
@immutable
class CatalogTimetable {
  const CatalogTimetable({
    required this.id,
    required this.lineId,
    required this.validity,
    this.source,
    this.lineName,
    this.sheetDate,
    this.oso,
    this.issues = 0,
  });

  /// 'arquivo:aba' de origem.
  final String id;
  final String lineId;

  /// Nome do arquivo (grupo/terminal que publica a planilha). Não é o local
  /// de partida: a planilha não informa isso.
  final String? source;
  final String? lineName;

  /// Campo "Data:" da aba ('2025-12-03'): referência, não vigência.
  final String? sheetDate;
  final String? oso;
  final TimetableValidity validity;

  /// Quantos problemas o pipeline registrou na aba (duplicidades etc.).
  final int issues;
}

/// Tipo de viagem da planilha.
enum TripKind {
  /// Viagem completa (VG).
  full,

  /// Meia viagem, início no retorno (MVGI).
  halfStartsAtTurn,

  /// Meia viagem, fim no retorno (MVGV).
  halfEndsAtTurn,
}

/// Partidas programadas de uma aba, num tipo de dia, com o mesmo código de
/// linha e tipo de viagem. [minutes] fica na ordem da planilha; >= 1440 é
/// depois da meia-noite (madrugada do dia seguinte).
@immutable
class CatalogTrips {
  const CatalogTrips({
    required this.timetableId,
    required this.day,
    required this.minutes,
    this.code,
    this.variantId,
    this.kind,
  });

  final String timetableId;
  final ServiceDay day;

  /// Código como está na planilha ('003-1').
  final String? code;

  /// Variante do cadastro, só quando o código é idêntico; senão `null`.
  final String? variantId;
  final TripKind? kind;
  final List<int> minutes;
}

/// Uma partida para exibir: hora, código, tipo e quantas vezes aparece
/// repetida na planilha (duplicidade mantida, não escondida).
@immutable
class Departure {
  const Departure(this.minutes, this.code, this.kind, {this.repeated = 1});

  final int minutes;
  final String? code;
  final TripKind? kind;
  final int repeated;

  bool get nextDay => minutes >= 24 * 60;

  /// 'HH:MM' do relógio (24:15 vira 00:15; ver [nextDay]).
  String get clock {
    final m = minutes % (24 * 60);
    return '${(m ~/ 60).toString().padLeft(2, '0')}:'
        '${(m % 60).toString().padLeft(2, '0')}';
  }
}

/// Partidas de um dia, em ordem cronológica, juntando duplicidades exatas
/// (mesma hora, código e tipo). [codes] filtra por código da planilha.
List<Departure> departuresOf(
  Iterable<CatalogTrips> trips,
  ServiceDay day, {
  Set<String>? codes,
}) {
  final counts = <(int, String?, TripKind?), int>{};
  for (final group in trips) {
    if (group.day != day) continue;
    if (codes != null && !codes.contains(group.code)) continue;
    for (final m in group.minutes) {
      final key = (m, group.code, group.kind);
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  final out = [
    for (final MapEntry(key: (m, code, kind), value: n) in counts.entries)
      Departure(m, code, kind, repeated: n),
  ];
  out.sort((a, b) {
    final byTime = a.minutes.compareTo(b.minutes);
    return byTime != 0 ? byTime : (a.code ?? '').compareTo(b.code ?? '');
  });
  return out;
}
