import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/saved_stop.dart';
import '../../domain/saved_stops_store.dart';

enum SavedStopsStatus { loading, ready }

/// O que aconteceu ao pedir para favoritar ou desfavoritar.
enum FavoriteResult { added, removed, limitReached, invalidCode }

@immutable
class SavedStopsState {
  const SavedStopsState({
    this.status = SavedStopsStatus.loading,
    this.favorites = const [],
    this.recents = const [],
    this.persistent = true,
    this.readFailed = false,
    this.writeFailed = false,
  });

  final SavedStopsStatus status;

  /// Do mais novo ao mais antigo, sem códigos repetidos.
  final List<SavedStop> favorites;
  final List<SavedStop> recents;

  /// `false`: o aparelho não guarda; o que foi salvo vale até fechar o app.
  final bool persistent;

  /// O que estava guardado não pôde ser lido (corrompido ou formato novo).
  final bool readFailed;

  /// A última gravação falhou; a lista na tela vale, mas pode não sobreviver.
  final bool writeFailed;

  bool get loading => status == SavedStopsStatus.loading;

  bool isFavorite(String? code) =>
      code != null && favorites.any((stop) => stop.code == code);

  SavedStopsState copyWith({
    SavedStopsStatus? status,
    List<SavedStop>? favorites,
    List<SavedStop>? recents,
    bool? persistent,
    bool? readFailed,
    bool? writeFailed,
  }) => SavedStopsState(
    status: status ?? this.status,
    favorites: favorites ?? this.favorites,
    recents: recents ?? this.recents,
    persistent: persistent ?? this.persistent,
    readFailed: readFailed ?? this.readFailed,
    writeFailed: writeFailed ?? this.writeFailed,
  );
}

/// Favoritos e recentes de pontos, guardados no aparelho.
///
/// - O estado em memória é a fonte da verdade: cada operação muda a lista na
///   hora e a gravação vem depois, uma de cada vez, sempre com o estado mais
///   novo. Favoritar e desfavoritar em sequência rápida nunca deixa lista e
///   disco em estados diferentes, e uma gravação lenta não trava a tela.
/// - Falha de gravação não desfaz a lista: vira aviso (`writeFailed`) e a
///   próxima operação tenta de novo. Nunca há repetição automática em laço.
/// - Operações feitas antes da leitura terminar esperam por ela, na ordem.
/// - Nenhuma previsão de chegada é guardada, só código, nome confiável (se
///   houver) e hora.
class SavedStopsCubit extends Cubit<SavedStopsState> {
  SavedStopsCubit(
    this._store, {
    this.favoriteLimit = defaultFavoriteStopsLimit,
    this.recentLimit = defaultRecentStopsLimit,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(SavedStopsState(persistent: _store.persistent)) {
    unawaited(_load());
  }

  final SavedStopsStore _store;
  final int favoriteLimit;
  final int recentLimit;
  final DateTime Function() _clock;

  final _loaded = Completer<void>();
  bool _writing = false;
  bool _dirty = false;
  Future<void>? _flushing;

  Future<void> _load() async {
    var data = SavedStopsData.empty;
    var unreadable = false;
    try {
      final result = await _store.load();
      data = result.data;
      unreadable = result.unreadable;
    } catch (_) {
      unreadable = true;
    }
    if (!isClosed) {
      emit(
        state.copyWith(
          status: SavedStopsStatus.ready,
          favorites: _capped(data.favorites, favoriteLimit),
          recents: _capped(data.recents, recentLimit),
          readFailed: unreadable,
        ),
      );
    }
    _loaded.complete();
  }

  List<SavedStop> _capped(List<SavedStop> stops, int limit) =>
      stops.length <= limit ? stops : stops.sublist(0, limit);

  /// Favorita o ponto, ou desfavorita se já era favorito. Código inválido nunca
  /// é salvo; passou do limite, nada é removido sozinho.
  Future<FavoriteResult> toggleFavorite(String? rawCode, {String? name}) async {
    final code = canonicalStopCode(rawCode);
    if (code == null) return FavoriteResult.invalidCode;
    await _loaded.future;
    if (isClosed) return FavoriteResult.invalidCode;

    final favorites = state.favorites;
    if (state.isFavorite(code)) {
      _apply(
        favorites: [
          for (final stop in favorites)
            if (stop.code != code) stop,
        ],
      );
      return FavoriteResult.removed;
    }
    if (favorites.length >= favoriteLimit) return FavoriteResult.limitReached;
    _apply(
      favorites: [
        SavedStop(code: code, name: name, at: _clock()),
        ...favorites,
      ],
    );
    return FavoriteResult.added;
  }

  Future<void> removeFavorite(String? rawCode) async {
    final code = canonicalStopCode(rawCode);
    if (code == null) return;
    await _loaded.future;
    if (isClosed || !state.isFavorite(code)) return;
    _apply(
      favorites: [
        for (final stop in state.favorites)
          if (stop.code != code) stop,
      ],
    );
  }

  /// Registra uma consulta **bem-sucedida**: o ponto vai para o início dos
  /// recentes (sem repetir) e a lista respeita o limite. Quem chama só deve
  /// usar depois de a consulta dar certo; código inválido é ignorado.
  Future<void> recordQuery(String? rawCode, {String? name}) async {
    final code = canonicalStopCode(rawCode);
    if (code == null) return;
    await _loaded.future;
    if (isClosed) return;
    final others = [
      for (final stop in state.recents)
        if (stop.code != code) stop,
    ];
    _apply(
      recents: _capped([
        SavedStop(code: code, name: name, at: _clock()),
        ...others,
      ], recentLimit),
    );
  }

  Future<void> removeRecent(String? rawCode) async {
    final code = canonicalStopCode(rawCode);
    if (code == null) return;
    await _loaded.future;
    if (isClosed || !state.recents.any((stop) => stop.code == code)) return;
    _apply(
      recents: [
        for (final stop in state.recents)
          if (stop.code != code) stop,
      ],
    );
  }

  Future<void> clearRecents() async {
    await _loaded.future;
    if (isClosed || state.recents.isEmpty) return;
    _apply(recents: const []);
  }

  /// Aplica a mudança na hora e agenda a gravação.
  void _apply({List<SavedStop>? favorites, List<SavedStop>? recents}) {
    emit(state.copyWith(favorites: favorites, recents: recents));
    _dirty = true;
    if (!_writing) _flushing = _flush();
  }

  /// Uma gravação por vez, sempre do estado mais novo; várias mudanças
  /// seguidas viram poucas gravações. Falhar não repete sozinho.
  Future<void> _flush() async {
    _writing = true;
    try {
      while (_dirty) {
        _dirty = false;
        final snapshot = SavedStopsData(
          favorites: state.favorites,
          recents: state.recents,
        );
        try {
          await _store.save(snapshot);
          if (!isClosed && (state.writeFailed || state.readFailed)) {
            emit(state.copyWith(writeFailed: false, readFailed: false));
          }
        } catch (_) {
          if (!isClosed && !state.writeFailed) {
            emit(state.copyWith(writeFailed: true));
          }
        }
      }
    } finally {
      _writing = false;
      _flushing = null;
    }
  }

  /// Completa quando não há gravação pendente.
  Future<void> whenSaved() async {
    while (_flushing != null) {
      await _flushing;
    }
  }

  @override
  Future<void> close() async {
    await whenSaved();
    return super.close();
  }
}
