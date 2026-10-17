import 'saved_stop.dart';

/// Onde favoritos e recentes ficam entre aberturas do app.
///
/// Favoritos e recentes são gravados juntos, num único documento: uma escrita
/// nunca deixa uma lista de um jeito e a outra de outro.
abstract interface class SavedStopsStore {
  /// `false` quando o que se salva só vale até fechar o app (armazenamento do
  /// aparelho indisponível).
  bool get persistent;

  /// Lê o que foi guardado. Armazenamento vazio, corrompido ou desconhecido
  /// vira dados vazios (com `unreadable` quando havia algo ilegível); só
  /// lança se o próprio acesso falhar.
  Future<SavedStopsLoad> load();

  /// Substitui o conteúdo guardado.
  Future<void> save(SavedStopsData data);
}
