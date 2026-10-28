import 'package:flutter/foundation.dart';

import '../../transit/domain/entities/tracked_vehicle.dart';
import 'route_geometry.dart';
import 'stop_sequence.dart';
import 'text_search.dart';
import 'timetable.dart';

/// Versão e proveniência do catálogo estático.
@immutable
class CatalogVersion {
  const CatalogVersion({
    required this.id,
    required this.source,
    required this.licenseStatus,
    required this.restricted,
    this.generatedAt,
    this.linesReference,
    this.stopsReference,
    this.shapeToleranceM,
    this.timetablesDelivered,
  });

  /// Tolerância (m) da simplificação dos trajetos distribuídos.
  final double? shapeToleranceM;

  /// Data em que a CMTC entregou as planilhas horárias ('2026-10-28').
  final String? timetablesDelivered;

  final String id;
  final String source;

  /// 'pendente' enquanto a CMTC não definir condições de redistribuição.
  final String licenseStatus;

  /// Só para desenvolvimento: não pode ir para build publicado.
  final bool restricted;
  final DateTime? generatedAt;

  /// Data de referência declarada pela fonte ('2026-09-01', '2026-10').
  final String? linesReference;
  final String? stopsReference;
}

/// Linha comercial (base): '003', 'NS1', 'MGP-07'. Mesmo código que a API em
/// tempo real usa como `routeId`.
@immutable
class CatalogLine {
  const CatalogLine({
    required this.id,
    required this.name,
    this.type,
    this.form,
    this.areas = const [],
    this.cities = const [],
  });

  final String id;
  final String? name;
  final String? type;
  final String? form;
  final List<String> areas;
  final List<String> cities;
}

/// Registro do Cadastro Geral das Linhas ('003-1').
@immutable
class CatalogVariant {
  const CatalogVariant({
    required this.id,
    required this.lineId,
    required this.code,
    this.name,
    this.characteristic,
    this.status,
    this.origin,
    this.destination,
    this.city,
    this.validFrom,
  });

  final String id;
  final String lineId;

  /// Código como veio da planilha.
  final String code;
  final String? name;

  /// Principal, Sublinha ou Especial.
  final String? characteristic;

  /// Situação operacional do cadastro ('OPERAÇÃO').
  final String? status;
  final String? origin;
  final String? destination;
  final String? city;

  /// Início de vigência declarado ('2022-10-10'); não é data de validade.
  final String? validFrom;
}

enum CatalogStopKind {
  /// Ponto do Cadastro Geral de Pontos.
  ped,

  /// Estação do Eixo/BRT que só existe no KMZ de pontos (sem endereço).
  station,

  /// Ponto que só existe no KMZ de pontos.
  kmzOnly,
}

/// Ponto de parada (PED). [id] é o mesmo código da consulta de chegadas.
@immutable
class CatalogStop {
  const CatalogStop({
    required this.id,
    required this.kind,
    this.streetType,
    this.street,
    this.reference,
    this.district,
    this.city,
    this.latitude,
    this.longitude,
    this.lineIds = const [],
    this.label,
  });

  final String id;
  final CatalogStopKind kind;
  final String? streetType;
  final String? street;
  final String? reference;
  final String? district;
  final String? city;
  final double? latitude;
  final double? longitude;

  /// Linhas oficialmente associadas ao ponto (sem ordem e sem sentido).
  final List<String> lineIds;

  /// Nome vindo do KMZ (estações).
  final String? label;

  /// 'Rua Araguaia' (tipo + logradouro), ou o nome do KMZ.
  String? get streetLine {
    final parts = [?streetType, ?street];
    if (parts.isNotEmpty) return displayCase(parts.join(' '));
    return label == null ? null : displayCase(label);
  }

  /// Endereço em uma linha: logradouro e referência.
  String? get address {
    final street = streetLine;
    final ref = reference == null ? null : displayCase(reference);
    if (street == null) return ref;
    return ref == null ? street : '$street — $ref';
  }

  /// 'Setor Bueno, Goiânia'.
  String? get place {
    final parts = [
      if (district != null) displayCase(district),
      if (city != null) displayCase(city),
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }
}

/// Trajeto oficial (KMZ da CMTC) de uma variante num sentido. A geometria
/// vem simplificada para exibição (ver `version.shapeToleranceM`); o
/// original fica no pipeline. Decodificada só quando usada.
class CatalogShape {
  CatalogShape({
    required this.id,
    required this.lineId,
    required this.variantId,
    required this.direction,
    required this.encoded,
    this.description,
    this.lengthM,
    this.sourceVertices,
  });

  /// Nome original do Placemark ('003-1i - T. MARANATA / … - IDA').
  final String id;
  final String lineId;
  final String variantId;

  /// 'i' (ida) ou 'v' (volta), do nome oficial; `null` quando ausente.
  final String? direction;
  final String? description;
  final String encoded;

  /// Comprimento do trajeto original (antes de simplificar).
  final int? lengthM;
  final int? sourceVertices;

  late final List<GeoPosition> points = decodePolyline(encoded);
  late final RouteLine line = RouteLine(points);
}

/// Resultado de busca com pontuação (maior = mais relevante).
@immutable
class Ranked<T> {
  const Ranked(this.item, this.score);

  final T item;
  final int score;
}

/// Catálogo estático em memória, com índices de busca. Imutável: uma versão
/// nova é outro objeto.
class TransitCatalog {
  TransitCatalog({
    required this.version,
    required List<CatalogLine> lines,
    required List<CatalogVariant> variants,
    required List<CatalogStop> stops,
    List<CatalogShape> shapes = const [],
    List<CatalogTimetable> timetables = const [],
    List<CatalogTrips> trips = const [],
    List<StopSequence> sequences = const [],
  }) : lines = List.unmodifiable(lines),
       variants = List.unmodifiable(variants),
       stops = List.unmodifiable(stops),
       shapes = List.unmodifiable(shapes),
       timetables = List.unmodifiable(timetables),
       sequences = List.unmodifiable(sequences) {
    for (final shape in this.shapes) {
      _shapesByLine.putIfAbsent(shape.lineId, () => []).add(shape);
      _shapeById[shape.id] = shape;
    }
    for (final t in this.timetables) {
      _timetablesByLine.putIfAbsent(t.lineId, () => []).add(t);
    }
    for (final t in trips) {
      _tripsByTimetable.putIfAbsent(t.timetableId, () => []).add(t);
    }
    for (final s in this.sequences) {
      _sequenceByShape[s.shapeId] = s;
    }
    for (final line in this.lines) {
      _lineById[line.id] = line;
    }
    for (final variant in this.variants) {
      _variantsByLine.putIfAbsent(variant.lineId, () => []).add(variant);
    }
    for (final stop in this.stops) {
      _stopById[stop.id] = stop;
      for (final lineId in stop.lineIds) {
        _stopsByLine.putIfAbsent(lineId, () => []).add(stop);
      }
      _stopIndex.add(_StopEntry.of(stop));
    }
    for (final line in this.lines) {
      _lineIndex.add(_LineEntry.of(line, _variantsByLine[line.id] ?? const []));
    }
  }

  final CatalogVersion version;
  final List<CatalogLine> lines;
  final List<CatalogVariant> variants;
  final List<CatalogStop> stops;
  final List<CatalogShape> shapes;
  final List<CatalogTimetable> timetables;
  final List<StopSequence> sequences;
  final _shapesByLine = <String, List<CatalogShape>>{};
  final _shapeById = <String, CatalogShape>{};
  final _timetablesByLine = <String, List<CatalogTimetable>>{};
  final _tripsByTimetable = <String, List<CatalogTrips>>{};
  final _sequenceByShape = <String, StopSequence>{};

  CatalogShape? shape(String? id) => id == null ? null : _shapeById[id];

  /// Quadros de horário da linha (abas OSO), de qualquer validade.
  List<CatalogTimetable> timetablesOf(String lineId) =>
      List.unmodifiable(_timetablesByLine[normalizeLineId(lineId)] ?? const []);

  List<CatalogTrips> tripsOf(String timetableId) =>
      List.unmodifiable(_tripsByTimetable[timetableId] ?? const []);

  /// Sequência ESTIMADA de paradas do trajeto, se calculada.
  StopSequence? sequenceOf(String? shapeId) =>
      shapeId == null ? null : _sequenceByShape[shapeId];

  /// Onde o ponto aparece nas sequências estimadas confiáveis: (trajeto,
  /// posição 1-based na sequência). Índice montado no primeiro uso.
  List<(CatalogShape, int)> itineraryOf(String stopId) {
    final index = _itinerary ??= () {
      final out = <String, List<(CatalogShape, int)>>{};
      for (final seq in sequences) {
        final shape = _shapeById[seq.shapeId];
        if (shape == null || seq.status != SequenceStatus.estimated) continue;
        for (var i = 0; i < seq.entries.length; i++) {
          out.putIfAbsent(seq.entries[i].stopId, () => []).add((shape, i + 1));
        }
      }
      return out;
    }();
    return List.unmodifiable(index[stopId.trim()] ?? const []);
  }

  Map<String, List<(CatalogShape, int)>>? _itinerary;

  /// Trajetos oficiais da linha (todas as variantes e sentidos).
  List<CatalogShape> shapesOf(String lineId) =>
      List.unmodifiable(_shapesByLine[normalizeLineId(lineId)] ?? const []);

  final _lineById = <String, CatalogLine>{};
  final _stopById = <String, CatalogStop>{};
  final _variantsByLine = <String, List<CatalogVariant>>{};
  final _stopsByLine = <String, List<CatalogStop>>{};
  final _stopIndex = <_StopEntry>[];
  final _lineIndex = <_LineEntry>[];

  /// Ponto pelo código exato (o texto, com zeros, como foi digitado).
  CatalogStop? stop(String? id) => id == null ? null : _stopById[id.trim()];

  /// Linha pela base; aceita '3' e '003' (mesma normalização da API).
  CatalogLine? line(String? id) {
    if (id == null) return null;
    return _lineById[normalizeLineId(id)];
  }

  List<CatalogVariant> variantsOf(String lineId) =>
      List.unmodifiable(_variantsByLine[normalizeLineId(lineId)] ?? const []);

  /// Pontos oficialmente associados à linha, por código.
  List<CatalogStop> stopsOf(String lineId) {
    final stops = [...?_stopsByLine[normalizeLineId(lineId)]];
    stops.sort((a, b) => _compareIds(a.id, b.id));
    return stops;
  }

  /// Municípios dos pontos associados à linha.
  List<String> stopCitiesOf(String lineId) {
    final cities = <String>{
      for (final stop in _stopsByLine[normalizeLineId(lineId)] ?? const [])
        if (stop.city != null) displayCase(stop.city),
    }.toList()..sort();
    return cities;
  }

  /// Busca de pontos por código, logradouro, referência, bairro ou município.
  /// Todas as palavras precisam aparecer (no início de alguma palavra do
  /// ponto); só dígitos também casam com o começo do código.
  List<CatalogStop> searchStops(String query, {int limit = 50}) =>
      rankStops(query, limit: limit).map((r) => r.item).toList();

  List<Ranked<CatalogStop>> rankStops(String query, {int limit = 50}) {
    final tokens = searchTokens(query);
    if (tokens.isEmpty) return const [];
    final digits = normalizeSearch(query).replaceAll(' ', '');
    final codeQuery = RegExp(r'^\d+$').hasMatch(query.trim()) ? digits : null;
    final results = <Ranked<CatalogStop>>[];
    for (final entry in _stopIndex) {
      final score = entry.score(tokens, codeQuery);
      if (score > 0) results.add(Ranked(entry.stop, score));
    }
    results.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : _compareIds(a.item.id, b.item.id);
    });
    return results.length <= limit ? results : results.sublist(0, limit);
  }

  /// Quantos pontos casam com a busca (sem limite).
  int countStops(String query) => rankStops(query, limit: 1 << 30).length;

  /// Busca de linhas por número ('3', '003', 'NS1') ou nome/terminais.
  List<CatalogLine> searchLines(String query, {int limit = 400}) {
    final tokens = searchTokens(query);
    if (tokens.isEmpty) return lines.take(limit).toList();
    final results = <Ranked<CatalogLine>>[];
    for (final entry in _lineIndex) {
      final score = entry.score(tokens, query.trim());
      if (score > 0) results.add(Ranked(entry.line, score));
    }
    results.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : _compareIds(a.item.id, b.item.id);
    });
    return [for (final r in results.take(limit)) r.item];
  }
}

/// Base da linha como a API normaliza: 1 a 3 dígitos viram 3 ('3' -> '003').
String normalizeLineId(String raw) {
  final id = raw.trim().toUpperCase();
  return RegExp(r'^\d{1,3}$').hasMatch(id) ? id.padLeft(3, '0') : id;
}

int _compareIds(String a, String b) {
  final ia = int.tryParse(a);
  final ib = int.tryParse(b);
  if (ia != null && ib != null) return ia.compareTo(ib);
  if (ia != null) return -1;
  if (ib != null) return 1;
  return a.compareTo(b);
}

/// Pesos por campo: logradouro pesa mais que bairro, que pesa mais que cidade.
class _StopEntry {
  _StopEntry(this.stop, this.fields);

  factory _StopEntry.of(CatalogStop stop) => _StopEntry(stop, [
    (
      searchTokens(
        '${stop.streetType ?? ''} ${stop.street ?? ''} ${stop.label ?? ''}',
      ),
      4,
    ),
    (searchTokens(stop.reference), 3),
    (searchTokens(stop.district), 3),
    (searchTokens(stop.city), 1),
  ]);

  final CatalogStop stop;
  final List<(List<String>, int)> fields;

  int score(List<String> tokens, String? codeQuery) {
    var total = 0;
    if (codeQuery != null) {
      if (stop.id == codeQuery) return 10000;
      if (stop.id.startsWith(codeQuery)) {
        total = 5000 - (stop.id.length - codeQuery.length);
      }
    }
    var matchedAll = true;
    var text = 0;
    for (final token in tokens) {
      var best = 0;
      for (final (words, weight) in fields) {
        for (final word in words) {
          if (word == token) {
            best = best > weight * 2 ? best : weight * 2;
          } else if (word.startsWith(token)) {
            best = best > weight ? best : weight;
          }
        }
      }
      if (best == 0) {
        matchedAll = false;
        break;
      }
      text += best;
    }
    return matchedAll ? total + text : total;
  }
}

class _LineEntry {
  _LineEntry(this.line, this.name, this.terminals);

  factory _LineEntry.of(CatalogLine line, List<CatalogVariant> variants) =>
      _LineEntry(
        line,
        searchTokens([line.name, for (final v in variants) v.name].join(' ')),
        searchTokens(
          [
            for (final v in variants) ...[v.origin, v.destination, v.city],
            ...line.cities,
          ].whereType<String>().join(' '),
        ),
      );

  final CatalogLine line;
  final List<String> name;
  final List<String> terminals;

  int score(List<String> tokens, String raw) {
    final code = raw.toUpperCase();
    if (code.isNotEmpty) {
      final normalized = normalizeLineId(code);
      if (line.id == normalized || line.id == code) return 10000;
      final bare = line.id.replaceFirst(RegExp(r'^0+'), '');
      if (line.id.startsWith(code) || bare.startsWith(code)) {
        return 5000 - line.id.length;
      }
    }
    var total = 0;
    for (final token in tokens) {
      var best = 0;
      for (final word in name) {
        if (word == token) best = best > 4 ? best : 4;
        if (word.startsWith(token)) best = best > 2 ? best : 2;
      }
      for (final word in terminals) {
        if (word.startsWith(token)) best = best > 1 ? best : 1;
      }
      if (best == 0) return 0;
      total += best;
    }
    return total;
  }
}
