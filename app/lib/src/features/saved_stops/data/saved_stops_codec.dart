import 'dart:convert';

import '../domain/saved_stop.dart';

/// Versão do documento. Documento de outra versão é tratado como ilegível, em
/// vez de ser interpretado por adivinhação.
const savedStopsSchema = 3;

/// A versão 1 não tinha linhas favoritas e a 2 não tinha viagens; o que falta
/// é lido como lista vazia e a próxima gravação já sai na versão atual.
const _legacySchemas = {1, 2};

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
    'trips': [
      for (final trip in data.trips)
        {
          'from': trip.from,
          'to': trip.to,
          'name': ?trip.name,
          'at': trip.at.toUtc().toIso8601String(),
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
  int tripLimit = defaultSavedTripsLimit,
}) {
  if (raw == null) return const SavedStopsLoad(SavedStopsData.empty);
  try {
    final decoded = jsonDecode(raw);
    final schema = decoded is Map ? decoded['schema'] : null;
    if (decoded is! Map ||
        (schema != savedStopsSchema && !_legacySchemas.contains(schema))) {
      return const SavedStopsLoad(SavedStopsData.empty, unreadable: true);
    }
    return SavedStopsLoad(
      SavedStopsData(
        favorites: _readList(decoded['favorites'], favoriteLimit),
        recents: _readList(decoded['recents'], recentLimit),
        lines: _readLines(decoded['lines'], lineLimit),
        trips: _readTrips(decoded['trips'], tripLimit),
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

List<SavedTrip> _readTrips(Object? value, int limit) {
  if (value is! List) return const [];
  final seen = <String>{};
  final trips = <SavedTrip>[];
  for (final entry in value) {
    if (entry is! Map) continue;
    final from = canonicalCatalogStopId(
      entry['from'] is String ? entry['from'] as String : null,
    );
    final to = canonicalCatalogStopId(
      entry['to'] is String ? entry['to'] as String : null,
    );
    if (from == null || to == null || from == to) continue;
    if (!seen.add('$from>$to')) continue;
    final at = entry['at'] is String
        ? DateTime.tryParse(entry['at'] as String)
        : null;
    trips.add(
      SavedTrip(
        from: from,
        to: to,
        name: tripName(
          entry['name'] is String ? entry['name'] as String : null,
        ),
        at: at ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
    );
    if (trips.length >= limit) break;
  }
  return trips;
}

/// Nome de viagem limpo: sem espaços nas pontas, até [maxTripNameLength];
/// vazio vira `null` (a tela mostra "origem → destino").
String? tripName(String? raw) {
  final name = raw?.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name == null || name.isEmpty) return null;
  return name.length <= maxTripNameLength
      ? name
      : name.substring(0, maxTripNameLength);
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
