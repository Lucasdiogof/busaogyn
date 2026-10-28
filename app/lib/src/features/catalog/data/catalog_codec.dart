import 'dart:convert';

import '../domain/stop_sequence.dart';
import '../domain/timetable.dart';
import '../domain/transit_catalog.dart';

/// Formato `busaogyn.catalog` v1, gerado por
/// `data/cmtc/pipeline/export_catalog.py`. Cada tabela traz `fields` e
/// `rows`; o decodificador lê pelo nome do campo, então colunas novas ou
/// reordenadas não quebram o app.
const catalogFormat = 'busaogyn.catalog';
const catalogFormatVersion = 1;

class CatalogFormatException implements Exception {
  const CatalogFormatException(this.message);

  final String message;

  @override
  String toString() => 'CatalogFormatException: $message';
}

/// Lê o catálogo. Formato ou versão desconhecidos lançam
/// [CatalogFormatException]; linha malformada é descartada sem derrubar o
/// resto. Códigos sempre como texto (zeros à esquerda preservados).
TransitCatalog decodeCatalog(String json) {
  final Object? root;
  try {
    root = jsonDecode(json);
  } on FormatException catch (error) {
    throw CatalogFormatException('JSON inválido: ${error.message}');
  }
  if (root is! Map<String, dynamic> ||
      root['format'] != catalogFormat ||
      root['formatVersion'] != catalogFormatVersion) {
    throw const CatalogFormatException('formato ou versão desconhecidos');
  }
  final version = root['version'];
  if (version is! Map<String, dynamic>) {
    throw const CatalogFormatException('sem bloco version');
  }
  final refs = version['referenceDates'];
  return TransitCatalog(
    version: CatalogVersion(
      id: _str(version['id']) ?? 'desconhecida',
      source: _str(version['source']) ?? '',
      licenseStatus: _str(version['licenseStatus']) ?? 'pendente',
      // Na dúvida, restrito.
      restricted: version['restricted'] != false,
      generatedAt: DateTime.tryParse(_str(version['generatedAt']) ?? ''),
      linesReference: refs is Map ? _str(refs['lines']) : null,
      shapeToleranceM: version['shapeToleranceM'] is num
          ? (version['shapeToleranceM'] as num).toDouble()
          : null,
      stopsReference: refs is Map ? _str(refs['stops']) : null,
      timetablesDelivered: _str(version['timetablesDelivered']),
    ),
    // Validade desconhecida vira `insufficient` (não exibida): nunca o
    // contrário.
    timetables: _table(root['timetables'], (r) {
      final id = _str(r('id'));
      final line = _code(r('line'));
      if (id == null || line == null) return null;
      return CatalogTimetable(
        id: id,
        lineId: normalizeLineId(line),
        source: _str(r('source')),
        lineName: _str(r('lineName')),
        sheetDate: _str(r('sheetDate')),
        oso: _str(r('oso')),
        validity: switch (r('validity')) {
          'confirmed' => TimetableValidity.confirmed,
          'recent' => TimetableValidity.recent,
          'old' => TimetableValidity.old,
          _ => TimetableValidity.insufficient,
        },
        issues: r('issues') is int ? r('issues')! as int : 0,
      );
    }),
    trips: _table(root['trips'], (r) {
      final timetable = _str(r('timetable'));
      final day = switch (r('day')) {
        'weekday' => ServiceDay.weekday,
        'saturday' => ServiceDay.saturday,
        'sunday_holiday' => ServiceDay.sundayHoliday,
        _ => null,
      };
      if (timetable == null || day == null) return null;
      final minutes = [
        for (final m in _list(r('minutes')))
          if (m is int && m >= 0 && m < 48 * 60) m,
      ];
      if (minutes.isEmpty) return null;
      return CatalogTrips(
        timetableId: timetable,
        day: day,
        code: _code(r('code')),
        variantId: _code(r('variant')),
        kind: switch (r('kind')) {
          'VG' => TripKind.full,
          'MVGI' => TripKind.halfStartsAtTurn,
          'MVGV' => TripKind.halfEndsAtTurn,
          _ => null,
        },
        minutes: List.unmodifiable(minutes),
      );
    }),
    sequences: _table(root['sequences'], (r) {
      final shape = _str(r('shape'));
      final status = switch (r('status')) {
        'estimated' => SequenceStatus.estimated,
        'partial' => SequenceStatus.partial,
        'none' => SequenceStatus.none,
        _ => null,
      };
      if (shape == null || status == null) return null;
      return StopSequence(
        shapeId: shape,
        status: status,
        circular: r('circular') == true,
        encoded: r('entries') is String ? r('entries')! as String : '',
        ambiguous: [for (final v in _list(r('ambiguous'))) ?_code(v)],
      );
    }),
    lines: _table(root['lines'], (r) {
      final id = _code(r('id'));
      if (id == null) return null;
      return CatalogLine(
        id: id,
        name: _str(r('name')),
        type: _str(r('type')),
        form: _str(r('form')),
        areas: _strList(r('areas')),
        cities: _strList(r('cities')),
      );
    }),
    variants: _table(root['variants'], (r) {
      final id = _code(r('id'));
      final line = _code(r('line'));
      if (id == null || line == null) return null;
      return CatalogVariant(
        id: id,
        lineId: line,
        code: _code(r('code')) ?? id,
        name: _str(r('name')),
        characteristic: _str(r('characteristic')),
        status: _str(r('status')),
        origin: _str(r('origin')),
        destination: _str(r('destination')),
        city: _str(r('city')),
        validFrom: _str(r('validFrom')),
      );
    }),
    shapes: _table(root['shapes'], (r) {
      final id = _str(r('id'));
      final line = _code(r('line'));
      final variant = _code(r('variant'));
      final encoded = r('polyline');
      if (id == null || line == null || variant == null || encoded is! String) {
        return null;
      }
      final direction = _str(r('direction'));
      final length = r('lengthM');
      final vertices = r('sourceVertices');
      return CatalogShape(
        id: id,
        lineId: normalizeLineId(line),
        variantId: variant,
        direction: direction == 'i' || direction == 'v' ? direction : null,
        description: _str(r('description')),
        encoded: encoded,
        lengthM: length is int ? length : null,
        sourceVertices: vertices is int ? vertices : null,
      );
    }),
    stops: _table(root['stops'], (r) {
      final id = _code(r('id'));
      if (id == null || !RegExp(r'^\d+$').hasMatch(id)) return null;
      final lat = r('lat');
      final lon = r('lon');
      return CatalogStop(
        id: id,
        kind: switch (r('kind')) {
          'estacao' => CatalogStopKind.station,
          'ped_kmz' => CatalogStopKind.kmzOnly,
          _ => CatalogStopKind.ped,
        },
        streetType: _str(r('streetType')),
        street: _str(r('street')),
        reference: _str(r('reference')),
        district: _str(r('district')),
        city: _str(r('city')),
        latitude: lat is num && lat.abs() <= 90 ? lat.toDouble() : null,
        longitude: lon is num && lon.abs() <= 180 ? lon.toDouble() : null,
        lineIds: [
          for (final v in _list(r('lines')))
            if (_code(v) case final code?) normalizeLineId(code),
        ],
        label: _str(r('label')),
      );
    }),
  );
}

List<T> _table<T>(Object? table, T? Function(Object? Function(String)) read) {
  if (table is! Map) return const [];
  final fields = table['fields'];
  final rows = table['rows'];
  if (fields is! List || rows is! List) return const [];
  final index = {
    for (var i = 0; i < fields.length; i++) fields[i].toString(): i,
  };
  final out = <T>[];
  for (final row in rows) {
    if (row is! List) continue;
    Object? field(String name) {
      final i = index[name];
      return i == null || i >= row.length ? null : row[i];
    }

    final item = read(field);
    if (item != null) out.add(item);
  }
  return out;
}

/// Texto do cadastro; vazio ou só traço/ponto ('-', '0', '.') é ausência.
String? _str(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty || RegExp(r'^[-–—.0\s]+$').hasMatch(text) ? null : text;
}

/// Código como texto; número inteiro vindo do JSON também vale.
String? _code(Object? value) {
  if (value is int) return '$value';
  return _str(value);
}

List<Object?> _list(Object? value) => value is List ? value : const [];

List<String> _strList(Object? value) => [
  for (final v in _list(value)) ?_str(v),
];
