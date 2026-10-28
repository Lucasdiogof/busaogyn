import 'dart:convert';

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
      stopsReference: refs is Map ? _str(refs['stops']) : null,
    ),
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
