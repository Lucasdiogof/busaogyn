import 'package:flutter/foundation.dart';

/// Quantos pontos recentes o app guarda. Mudar aqui muda o app todo.
const defaultRecentStopsLimit = 10;

/// Máximo de pontos favoritos (decisão D-9 do plano v2). Não há remoção
/// automática: passou do limite, o usuário remove um para adicionar outro.
const defaultFavoriteStopsLimit = 50;

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

/// Um ponto guardado no aparelho (favorito ou recente).
///
/// Só metadados mínimos: o código, um [name] **apenas quando a fonte der um
/// nome confiável** (hoje nenhuma dá, então fica `null` e a tela mostra o
/// código) e [at], a hora em que foi favoritado ou consultado pela última vez.
/// Nenhuma previsão de chegada é guardada.
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
  const SavedStopsData({this.favorites = const [], this.recents = const []});

  static const empty = SavedStopsData();

  final List<SavedStop> favorites;
  final List<SavedStop> recents;
}

/// Resultado da leitura: [unreadable] indica armazenamento corrompido ou de um
/// formato desconhecido (o app começa vazio e avisa).
@immutable
class SavedStopsLoad {
  const SavedStopsLoad(this.data, {this.unreadable = false});

  final SavedStopsData data;
  final bool unreadable;
}
