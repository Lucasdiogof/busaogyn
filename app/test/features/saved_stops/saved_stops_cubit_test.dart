import 'dart:async';

import 'package:busaogyn/src/features/saved_stops/domain/saved_stop.dart';
import 'package:busaogyn/src/features/saved_stops/presentation/cubit/saved_stops_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

SavedStopsCubit _cubit(
  FakeStore store, {
  int favoriteLimit = defaultFavoriteStopsLimit,
  int recentLimit = defaultRecentStopsLimit,
}) => SavedStopsCubit(
  store,
  favoriteLimit: favoriteLimit,
  recentLimit: recentLimit,
  clock: TickClock().call,
);

/// Cria o cubit e espera a leitura inicial.
Future<SavedStopsCubit> _ready(
  FakeStore store, {
  int favoriteLimit = defaultFavoriteStopsLimit,
  int recentLimit = defaultRecentStopsLimit,
}) async {
  final cubit = _cubit(
    store,
    favoriteLimit: favoriteLimit,
    recentLimit: recentLimit,
  );
  await cubit.stream.firstWhere((s) => !s.loading);
  return cubit;
}

Future<SavedStopsCubit> _readyWithLineLimit(FakeStore store, int limit) async {
  final cubit = SavedStopsCubit(
    store,
    lineLimit: limit,
    clock: TickClock().call,
  );
  await cubit.stream.firstWhere((s) => !s.loading);
  return cubit;
}

void main() {
  group('viagens salvas', () {
    test(
      'salva sem repetir, renomeia, remove e grava; preserva o resto',
      () async {
        final store = FakeStore(
          initial: SavedStopsData(
            favorites: [SavedStop(code: '1201', at: DateTime.utc(2026))],
          ),
        );
        final cubit = await _ready(store);

        expect(await cubit.saveTrip('1201', 'T-ALFA'), TripSaveResult.saved);
        expect(
          await cubit.saveTrip('1201', 'T-ALFA'),
          TripSaveResult.alreadySaved,
        );
        expect(await cubit.saveTrip('1201', '1201'), TripSaveResult.invalid);
        expect(await cubit.saveTrip(null, '1201'), TripSaveResult.invalid);
        expect(cubit.state.isSavedTrip('1201', 'T-ALFA'), isTrue);
        // Sentido importa: a volta é outra viagem.
        expect(cubit.state.isSavedTrip('T-ALFA', '1201'), isFalse);

        await cubit.renameTrip('1201', 'T-ALFA', '  Trabalho  ');
        expect(cubit.state.trips.single.name, 'Trabalho');
        await cubit.renameTrip('1201', 'T-ALFA', '   ');
        expect(cubit.state.trips.single.name, isNull);

        await cubit.whenSaved();
        expect(store.data.trips.single.from, '1201');
        expect(store.data.favorites.single.code, '1201');

        await cubit.removeTrip('1201', 'T-ALFA');
        await cubit.whenSaved();
        expect(cubit.state.trips, isEmpty);
        expect(store.data.trips, isEmpty);
        expect(store.data.favorites, hasLength(1));
        await cubit.close();
      },
    );

    test('limite: não remove nada sozinho', () async {
      final store = FakeStore();
      final cubit = SavedStopsCubit(
        store,
        tripLimit: 2,
        clock: TickClock().call,
      );
      await cubit.stream.firstWhere((s) => !s.loading);
      expect(await cubit.saveTrip('1', '2'), TripSaveResult.saved);
      expect(await cubit.saveTrip('1', '3'), TripSaveResult.saved);
      expect(await cubit.saveTrip('1', '4'), TripSaveResult.limitReached);
      expect(cubit.state.trips, hasLength(2));
      await cubit.close();
    });
  });

  group('linhas favoritas', () {
    test('favorita, desfavorita e grava só o par', () async {
      final store = FakeStore();
      final cubit = await _ready(store);

      expect(
        await cubit.toggleFavoriteLine('30402', '003'),
        FavoriteResult.added,
      );
      expect(cubit.state.isFavoriteLine('30402', '003'), isTrue);
      // A mesma linha em outro ponto é outro favorito.
      expect(cubit.state.isFavoriteLine('30100', '003'), isFalse);
      await cubit.whenSaved();
      expect(store.data.lines.single.routeId, '003');

      expect(
        await cubit.toggleFavoriteLine('30402', '003'),
        FavoriteResult.removed,
      );
      expect(cubit.state.lines, isEmpty);
      await cubit.whenSaved();
      expect(store.data.lines, isEmpty);
      await cubit.close();
    });

    test('ponto ou linha inválidos nunca são salvos', () async {
      final store = FakeStore();
      final cubit = await _ready(store);
      for (final (stop, route) in [
        ('abc', '003'),
        ('30402', ''),
        ('30402', 'a b'),
        (null, '003'),
        ('30402', null),
      ]) {
        expect(
          await cubit.toggleFavoriteLine(stop, route),
          FavoriteResult.invalidCode,
        );
      }
      expect(cubit.state.lines, isEmpty);
      expect(store.saves, isEmpty);
      await cubit.close();
    });

    test('passou do limite: avisa e não remove nada', () async {
      final cubit = await _readyWithLineLimit(FakeStore(), 2);
      await cubit.toggleFavoriteLine('1', '003');
      await cubit.toggleFavoriteLine('2', '003');
      expect(
        await cubit.toggleFavoriteLine('3', '003'),
        FavoriteResult.limitReached,
      );
      expect(cubit.state.lines.map((l) => l.stopCode), ['2', '1']);
      await cubit.close();
    });

    test('remover não mexe nos pontos favoritos', () async {
      final cubit = await _ready(FakeStore());
      await cubit.toggleFavorite('30402');
      await cubit.toggleFavoriteLine('30402', '003');
      await cubit.removeFavoriteLine('30402', '003');
      expect(cubit.state.lines, isEmpty);
      expect(codes(cubit.state.favorites), ['30402']);
      await cubit.close();
    });
  });

  group('leitura inicial', () {
    test('começa carregando e termina com o que estava guardado', () async {
      final gate = Completer<void>();
      final store = FakeStore(
        initial: SavedStopsData(
          favorites: [stop('30402')],
          recents: [stop('30100')],
        ),
      )..loadGate = gate;
      final cubit = _cubit(store);

      expect(cubit.state.loading, isTrue);
      expect(cubit.state.favorites, isEmpty);

      gate.complete();
      final ready = await cubit.stream.firstWhere((s) => !s.loading);
      expect(codes(ready.favorites), ['30402']);
      expect(codes(ready.recents), ['30100']);
      expect(ready.readFailed, isFalse);
      await cubit.close();
    });

    test(
      'operações feitas antes da leitura esperam por ela, na ordem',
      () async {
        final gate = Completer<void>();
        final store = FakeStore(initial: SavedStopsData(recents: [stop('1')]))
          ..loadGate = gate;
        final cubit = _cubit(store);

        final fav = cubit.toggleFavorite('30402');
        final recent = cubit.recordQuery('30100');
        expect(cubit.state.loading, isTrue);

        gate.complete();
        expect(await fav, FavoriteResult.added);
        await recent;
        expect(codes(cubit.state.favorites), ['30402']);
        expect(codes(cubit.state.recents), ['30100', '1']);
        await cubit.close();
        expect(codes(store.data.recents), ['30100', '1']);
      },
    );

    test('leitura que lança começa vazia e avisa', () async {
      final store = FakeStore()..loadError = StateError('sem acesso');
      final cubit = await _ready(store);
      expect(cubit.state.readFailed, isTrue);
      expect(cubit.state.favorites, isEmpty);
      await cubit.close();
    });

    test('armazenamento ilegível começa vazio e avisa', () async {
      final cubit = await _ready(FakeStore(unreadable: true));
      expect(cubit.state.readFailed, isTrue);
      await cubit.close();
    });

    test('a próxima gravação válida limpa o aviso de leitura', () async {
      final cubit = await _ready(FakeStore(unreadable: true));
      await cubit.toggleFavorite('30402');
      await cubit.whenSaved();
      expect(cubit.state.readFailed, isFalse);
      await cubit.close();
    });

    test('sem armazenamento persistente o estado diz isso', () async {
      final cubit = await _ready(FakeStore(isPersistent: false));
      expect(cubit.state.persistent, isFalse);
      await cubit.close();
    });

    test('listas lidas acima do limite são cortadas', () async {
      final store = FakeStore(
        initial: SavedStopsData(
          favorites: [for (var i = 1; i <= 5; i++) stop('$i')],
          recents: [for (var i = 1; i <= 5; i++) stop('$i')],
        ),
      );
      final cubit = await _ready(store, favoriteLimit: 3, recentLimit: 2);
      expect(cubit.state.favorites, hasLength(3));
      expect(cubit.state.recents, hasLength(2));
      await cubit.close();
    });
  });

  group('favoritos', () {
    test('favorita e desfavorita o mesmo ponto', () async {
      final store = FakeStore();
      final cubit = await _ready(store);

      expect(await cubit.toggleFavorite('30402'), FavoriteResult.added);
      expect(cubit.state.isFavorite('30402'), isTrue);
      await cubit.whenSaved();
      expect(codes(store.data.favorites), ['30402']);

      expect(await cubit.toggleFavorite('30402'), FavoriteResult.removed);
      expect(cubit.state.isFavorite('30402'), isFalse);
      await cubit.whenSaved();
      expect(store.data.favorites, isEmpty);
      await cubit.close();
    });

    test('não duplica: o mesmo código com espaços é o mesmo ponto', () async {
      final cubit = await _ready(FakeStore());
      await cubit.toggleFavorite('30402');
      await cubit.toggleFavorite(' 30402 '); // desfavorita, não duplica
      expect(cubit.state.favorites, isEmpty);
      await cubit.toggleFavorite('30402');
      await cubit.toggleFavorite('30402');
      await cubit.toggleFavorite('30402');
      expect(codes(cubit.state.favorites), ['30402']);
      await cubit.close();
    });

    test('zeros à esquerda fazem pontos diferentes', () async {
      final cubit = await _ready(FakeStore());
      await cubit.toggleFavorite('294');
      await cubit.toggleFavorite('00294');
      expect(codes(cubit.state.favorites), ['00294', '294']);
      await cubit.close();
    });

    test('código inválido nunca é salvo', () async {
      final store = FakeStore();
      final cubit = await _ready(store);
      for (final bad in [null, '', 'abc', '12 34', '1' * 40]) {
        expect(await cubit.toggleFavorite(bad), FavoriteResult.invalidCode);
      }
      expect(cubit.state.favorites, isEmpty);
      await cubit.whenSaved();
      expect(store.saves, isEmpty);
      await cubit.close();
    });

    test(
      'o mais novo vem primeiro e há um limite sem remoção sozinha',
      () async {
        final cubit = await _ready(FakeStore(), favoriteLimit: 2);
        await cubit.toggleFavorite('1');
        await cubit.toggleFavorite('2');
        expect(codes(cubit.state.favorites), ['2', '1']);

        expect(await cubit.toggleFavorite('3'), FavoriteResult.limitReached);
        expect(codes(cubit.state.favorites), ['2', '1']);

        // Desfavoritar com a lista cheia continua funcionando.
        expect(await cubit.toggleFavorite('1'), FavoriteResult.removed);
        expect(await cubit.toggleFavorite('3'), FavoriteResult.added);
        expect(codes(cubit.state.favorites), ['3', '2']);
        await cubit.close();
      },
    );

    test('removeFavorite tira o ponto e ignora o que não é favorito', () async {
      final cubit = await _ready(FakeStore());
      await cubit.toggleFavorite('1');
      await cubit.removeFavorite('999');
      await cubit.removeFavorite('abc');
      expect(codes(cubit.state.favorites), ['1']);
      await cubit.removeFavorite('1');
      expect(cubit.state.favorites, isEmpty);
      await cubit.close();
    });

    test('guarda o nome só quando ele é informado', () async {
      final cubit = await _ready(FakeStore());
      await cubit.toggleFavorite('1');
      await cubit.toggleFavorite('2', name: 'Terminal');
      expect(cubit.state.favorites.last.name, isNull);
      expect(cubit.state.favorites.first.name, 'Terminal');
      await cubit.close();
    });
  });

  group('recentes', () {
    test('ordem do mais recente para o mais antigo, sem repetir', () async {
      final cubit = await _ready(FakeStore());
      for (final code in ['1', '2', '3']) {
        await cubit.recordQuery(code);
      }
      expect(codes(cubit.state.recents), ['3', '2', '1']);
      await cubit.close();
    });

    test('reconsultar move o ponto para o início, sem duplicar', () async {
      final cubit = await _ready(FakeStore());
      for (final code in ['1', '2', '3']) {
        await cubit.recordQuery(code);
      }
      final before = cubit.state.recents.last.at;
      await cubit.recordQuery('1');
      expect(codes(cubit.state.recents), ['1', '3', '2']);
      expect(cubit.state.recents.first.at.isAfter(before), isTrue);
      await cubit.close();
    });

    test('o limite padrão é 10 e o mais antigo sai', () async {
      final cubit = await _ready(FakeStore());
      for (var i = 1; i <= 12; i++) {
        await cubit.recordQuery('$i');
      }
      expect(cubit.state.recents, hasLength(defaultRecentStopsLimit));
      expect(cubit.state.recents.first.code, '12');
      expect(cubit.state.recents.last.code, '3');
      expect(cubit.state.recents.any((s) => s.code == '1'), isFalse);
      await cubit.close();
    });

    test('o limite é configurável', () async {
      final cubit = await _ready(FakeStore(), recentLimit: 3);
      for (var i = 1; i <= 5; i++) {
        await cubit.recordQuery('$i');
      }
      expect(codes(cubit.state.recents), ['5', '4', '3']);
      await cubit.close();
    });

    test('código inválido nunca é registrado', () async {
      final store = FakeStore();
      final cubit = await _ready(store);
      for (final bad in [null, '', 'abc', '12 34', '1' * 40]) {
        await cubit.recordQuery(bad);
      }
      expect(cubit.state.recents, isEmpty);
      await cubit.whenSaved();
      expect(store.saves, isEmpty);
      await cubit.close();
    });

    test('remove um item e limpa tudo sem mexer nos favoritos', () async {
      final store = FakeStore();
      final cubit = await _ready(store);
      await cubit.toggleFavorite('9');
      for (final code in ['1', '2', '3']) {
        await cubit.recordQuery(code);
      }

      await cubit.removeRecent('2');
      expect(codes(cubit.state.recents), ['3', '1']);
      await cubit.removeRecent('999'); // não existe: nada muda

      await cubit.clearRecents();
      expect(cubit.state.recents, isEmpty);
      expect(codes(cubit.state.favorites), ['9']);
      await cubit.whenSaved();
      expect(store.data.recents, isEmpty);
      expect(codes(store.data.favorites), ['9']);
      await cubit.close();
    });

    test('limpar uma lista vazia não grava nada', () async {
      final store = FakeStore();
      final cubit = await _ready(store);
      await cubit.clearRecents();
      await cubit.whenSaved();
      expect(store.saves, isEmpty);
      await cubit.close();
    });
  });

  group('persistência entre sessões', () {
    test('uma nova sessão enxerga favoritos e recentes da anterior', () async {
      final store = FakeStore();
      final first = await _ready(store);
      await first.toggleFavorite('30402');
      await first.recordQuery('30100');
      await first.recordQuery('30402');
      await first.close(); // espera a gravação

      final second = await _ready(store);
      expect(codes(second.state.favorites), ['30402']);
      expect(codes(second.state.recents), ['30402', '30100']);
      await second.close();
    });
  });

  group('operações rápidas e falhas de gravação', () {
    test(
      'favoritar e desfavoritar em sequência rápida fica consistente',
      () async {
        final store = FakeStore();
        final cubit = await _ready(store);

        // Sem esperar nenhuma gravação entre as chamadas.
        final results = await Future.wait([
          for (var i = 0; i < 5; i++) cubit.toggleFavorite('30402'),
        ]);
        expect(results, [
          FavoriteResult.added,
          FavoriteResult.removed,
          FavoriteResult.added,
          FavoriteResult.removed,
          FavoriteResult.added,
        ]);
        expect(codes(cubit.state.favorites), ['30402']);

        await cubit.whenSaved();
        // O disco termina igual à memória, com menos gravações que operações.
        expect(codes(store.data.favorites), ['30402']);
        expect(store.saves.length, lessThanOrEqualTo(5));
        await cubit.close();
      },
    );

    test('operações misturadas em rajada terminam iguais em disco', () async {
      final store = FakeStore();
      final cubit = await _ready(store);

      unawaited(cubit.toggleFavorite('1'));
      unawaited(cubit.recordQuery('1'));
      unawaited(cubit.toggleFavorite('2'));
      unawaited(cubit.recordQuery('2'));
      unawaited(cubit.removeRecent('1'));
      unawaited(cubit.toggleFavorite('1'));
      await cubit.close();

      expect(codes(store.data.favorites), codes(cubit.state.favorites));
      expect(codes(store.data.recents), codes(cubit.state.recents));
      expect(codes(store.data.recents), ['2']);
      expect(codes(store.data.favorites), ['2']);
    });

    test('a lista na tela vale mesmo com a gravação lenta', () async {
      final gate = Completer<void>();
      final store = FakeStore()..saveGate = gate;
      final cubit = await _ready(store);

      await cubit.toggleFavorite('30402');
      expect(cubit.state.isFavorite('30402'), isTrue); // sem esperar o disco
      expect(store.saves, isEmpty);

      gate.complete();
      await cubit.whenSaved();
      expect(codes(store.data.favorites), ['30402']);
      await cubit.close();
    });

    test(
      'falha de gravação mantém a lista, avisa e não repete sozinha',
      () async {
        final store = FakeStore()..saveError = StateError('disco cheio');
        final cubit = await _ready(store);

        await cubit.toggleFavorite('30402');
        await cubit.whenSaved();
        expect(cubit.state.isFavorite('30402'), isTrue);
        expect(cubit.state.writeFailed, isTrue);

        // Sem laço: esperar não gera nova tentativa.
        var attempts = 0;
        store.saveError = null;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(store.saves.length, attempts);

        // A próxima operação tenta de novo e, dando certo, limpa o aviso.
        await cubit.recordQuery('30100');
        await cubit.whenSaved();
        attempts = store.saves.length;
        expect(cubit.state.writeFailed, isFalse);
        expect(codes(store.data.favorites), ['30402']);
        expect(codes(store.data.recents), ['30100']);
        await cubit.close();
      },
    );

    test('falhas seguidas contam uma tentativa por operação', () async {
      var calls = 0;
      final store = _CountingFailStore(onSave: () => calls++);
      final cubit = SavedStopsCubit(store, clock: TickClock().call);
      await cubit.stream.firstWhere((s) => !s.loading);

      await cubit.toggleFavorite('1');
      await cubit.whenSaved();
      expect(calls, 1);
      await cubit.toggleFavorite('2');
      await cubit.whenSaved();
      expect(calls, 2);
      await cubit.close();
    });

    test('close espera a gravação pendente', () async {
      final gate = Completer<void>();
      final store = FakeStore()..saveGate = gate;
      final cubit = await _ready(store);
      await cubit.toggleFavorite('30402');

      var closed = false;
      final closing = cubit.close().then((_) => closed = true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(closed, isFalse);

      gate.complete();
      await closing;
      expect(codes(store.data.favorites), ['30402']);
    });
  });
}

class _CountingFailStore extends FakeStore {
  _CountingFailStore({required this.onSave});

  final void Function() onSave;

  @override
  Future<void> save(SavedStopsData next) async {
    onSave();
    throw StateError('sempre falha');
  }
}
