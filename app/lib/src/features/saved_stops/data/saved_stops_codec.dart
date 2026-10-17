import 'dart:convert';

import '../domain/saved_stop.dart';

/// Versão do documento. Documento de outra versão é tratado como ilegível, em
/// vez de ser interpretado por adivinhação.
const savedStopsSchema = 2;

/// A versão 1 não tinha linhas favoritas; lê-se como lista vazia.
const _legacySchema = 1;

const _maxNameLength = 80;

String encodeSavedStops(SavedStopsData data) {
  Map<String, Object?> item(SavedStop stop) => {
    'code': stop.code,
    'name': stop.name,
    'at': stop.at.toUtc().toIso8601String(),
  };
  return jsonEncode({
    'schema': savedStopsSchema,
    'favorites': [for (final stop in data.favorites) item(stop)],
    'recents': [for (final stop in data.recents) item(stop)],
    'lines': [
      for (final line in data.lines)
        {
          'stop': line.stopCode,
          'route': line.routeId,
          'at': line.at.toUtc().toIso8601String(),
        },
    ],
  });
}

/// Lê o documento com tolerância: itens inválidos e códigos repetidos são
/// descartados, listas passam pelo limite e nada disso lança. `null` (nada
/// guardado ainda) é "vazio", não erro.
SavedStopsLoad decodeSavedStops(
  String? raw, {
  int favoriteLimit = defaultFavoriteStopsLimit,
  int recentLimit = defaultRecentStopsLimit,
  int lineLimit = defaultFavoriteLinesLimit,
}) {
  if (raw == null) return const SavedStopsLoad(SavedStopsData.empty);
  try {
    final decoded = jsonDecode(raw);
    final schema = decoded is Map ? decoded['schema'] : null;
    if (decoded is! Map ||
        (schema != savedStopsSchema && schema != _legacySchema)) {
      return const SavedStopsLoad(SavedStopsData.empty, unreadable: true);
    }
    return SavedStopsLoad(
      SavedStopsData(
        favorites: _readList(decoded['favorites'], favoriteLimit),
        recents: _readList(decoded['recents'], recentLimit),
        lines: _readLines(decoded['lines'], lineLimit),
      ),
    );
  } catch (_) {
    return const SavedStopsLoad(SavedStopsData.empty, unreadable: true);
  }
}

List<SavedLine> _readLines(Object? value, int limit) {
  if (value is! List) return const [];
  final seen = <String>{};
  final lines = <SavedLine>[];
  for (final entry in value) {
    if (entry is! Map) continue;
    final stop = canonicalStopCode(
      entry['stop'] is String ? entry['stop'] as String : null,
    );
    final route = canonicalRouteCode(
      entry['route'] is String ? entry['route'] as String : null,
    );
    if (stop == null || route == null || !seen.add('$stop|$route')) continue;
    final at = entry['at'] is String
        ? DateTime.tryParse(entry['at'] as String)
        : null;
    lines.add(
      SavedLine(
        stopCode: stop,
        routeId: route,
        at: at ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
    );
    if (lines.length >= limit) break;
  }
  return lines;
}

List<SavedStop> _readList(Object? value, int limit) {
  if (value is! List) return const [];
  final seen = <String>{};
  final stops = <SavedStop>[];
  for (final entry in value) {
    if (entry is! Map) continue;
    final code = canonicalStopCode(
      entry['code'] is String ? entry['code'] as String : null,
    );
    if (code == null || !seen.add(code)) continue;
    final name = entry['name'];
    final at = entry['at'] is String
        ? DateTime.tryParse(entry['at'] as String)
        : null;
    stops.add(
      SavedStop(
        code: code,
        name: name is String && name.trim().isNotEmpty
            ? name.trim().substring(
                0,
                name.trim().length.clamp(0, _maxNameLength),
              )
            : null,
        at: at ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
    );
    if (stops.length >= limit) break;
  }
  return stops;
}
