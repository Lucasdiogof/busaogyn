import 'package:flutter/foundation.dart';

/// Quantos pontos recentes o app guarda. Mudar aqui muda o app todo.
const defaultRecentStopsLimit = 10;

/// Máximo de pontos favoritos (decisão D-9 do plano v2). Não há remoção
/// automática: passou do limite, o usuário remove um para adicionar outro.
const defaultFavoriteStopsLimit = 50;

/// Máximo de linhas favoritas (par ponto + linha). Mesmo critério dos pontos:
/// sem remoção automática.
const defaultFavoriteLinesLimit = 50;

/// Tamanho máximo de um código de ponto aceito no armazenamento.
const maxStopCodeLength = 12;

/// Código canônico de um ponto: os dígitos exatos, sem espaços nas pontas.
///
/// Zeros à esquerda **não** são descartados: a equivalência entre `00294` e
/// `294` ainda não foi validada na API (ADR-0002, decisão 2). Devolve `null`
/// para qualquer coisa que não seja um código numérico válido, para que
/// entrada inválida nunca chegue a favoritos ou recentes.
String? canonicalStopCode(String? raw) {
  final code = raw?.trim();
  if (code == null || code.isEmpty || code.length > maxStopCodeLength) {
    return null;
  }
  return RegExp(r'^\d+$').hasMatch(code) ? code : null;
}

/// Código de linha aceito no armazenamento. A linha é um texto opaco (`003`,
/// `MGP1`): nunca vira número, não é reordenada nem derivada do itinerário
/// (ADR-0002). Devolve `null` para vazio, longo demais ou com símbolos.
String? canonicalRouteCode(String? raw) {
  final code = raw?.trim();
  if (code == null || code.isEmpty || code.length > 8) return null;
  return RegExp(r'^[A-Za-z0-9]+$').hasMatch(code) ? code : null;
}

/// Uma linha favorita **num ponto específico** (par ponto + linha). Guarda só
/// a intenção do usuário: nenhuma previsão, destino ou sentido.
@immutable
class SavedLine {
  const SavedLine({
    required this.stopCode,
    required this.routeId,
    required this.at,
  });

  final String stopCode;
  final String routeId;
  final DateTime at;

  bool matches(String stop, String route) =>
      stopCode == stop && routeId == route;

  @override
  bool operator ==(Object other) =>
      other is SavedLine &&
      other.stopCode == stopCode &&
      other.routeId == routeId &&
      other.at == at;

  @override
  int get hashCode => Object.hash(stopCode, routeId, at);

  @override
  String toString() => 'SavedLine($stopCode, $routeId, $at)';
}

/// Um ponto guardado no aparelho (favorito ou recente).
///
/// Só metadados mínimos: o código, um [name] **apenas quando a fonte der um
/// nome confiável** (hoje nenhuma dá, então fica `null` e a tela mostra o
/// código) e [at], a hora em que foi favoritado ou consultado pela última vez.
/// Nenhuma previsão de chegada é guardada.
/// Viagens salvas: até 20, sem remoção automática.
const defaultSavedTripsLimit = 20;

const maxTripNameLength = 40;

/// Código de ponto do catálogo (pontos, estações e terminais: `1201`,
/// `T-PADRE-PELAGIO`). `null` quando não parece um código.
String? canonicalCatalogStopId(String? raw) {
  final id = raw?.trim();
  if (id == null || id.isEmpty || id.length > 40) return null;
  return RegExp(r'^[A-Za-z0-9-]+$').hasMatch(id) ? id : null;
}

/// Par origem → destino salvo pelo passageiro. Só os códigos dos pontos e um
/// nome opcional: o itinerário é recalculado sempre que a viagem é aberta,
/// nunca guardado como se valesse para sempre.
@immutable
class SavedTrip {
  const SavedTrip({
    required this.from,
    required this.to,
    required this.at,
    this.name,
  });

  final String from;
  final String to;
  final String? name;
  final DateTime at;

  bool matches(String origin, String destination) =>
      from == origin && to == destination;

  SavedTrip copyWith({String? Function()? name}) => SavedTrip(
    from: from,
    to: to,
    at: at,
    name: name == null ? this.name : name(),
  );

  @override
  bool operator ==(Object other) =>
      other is SavedTrip &&
      other.from == from &&
      other.to == to &&
      other.name == name &&
      other.at == at;

  @override
  int get hashCode => Object.hash(from, to, name, at);

  @override
  String toString() => 'SavedTrip($from → $to, $name, $at)';
}

@immutable
class SavedStop {
  const SavedStop({required this.code, required this.at, this.name});

  final String code;
  final String? name;
  final DateTime at;

  /// Nome para mostrar: o nome confiável, ou o código.
  String get label => name ?? code;

  SavedStop copyWith({String? Function()? name, DateTime? at}) => SavedStop(
    code: code,
    at: at ?? this.at,
    name: name != null ? name() : this.name,
  );

  @override
  bool operator ==(Object other) =>
      other is SavedStop &&
      other.code == code &&
      other.name == name &&
      other.at == at;

  @override
  int get hashCode => Object.hash(code, name, at);

  @override
  String toString() => 'SavedStop($code, $name, $at)';
}

/// Tudo o que o aparelho guarda: favoritos e recentes, do mais novo ao mais
/// antigo, sem códigos repetidos dentro de cada lista.
@immutable
class SavedStopsData {
  const SavedStopsData({
    this.favorites = const [],
    this.recents = const [],
    this.lines = const [],
    this.trips = const [],
  });

  static const empty = SavedStopsData();

  final List<SavedStop> favorites;
  final List<SavedStop> recents;

  /// Linhas favoritas por ponto, da mais nova à mais antiga.
  final List<SavedLine> lines;

  final List<SavedTrip> trips;
}

/// Resultado da leitura: [unreadable] indica armazenamento corrompido ou de um
/// formato desconhecido (o app começa vazio e avisa).
@immutable
class SavedStopsLoad {
  const SavedStopsLoad(this.data, {this.unreadable = false});

  final SavedStopsData data;
  final bool unreadable;
}
