import 'package:busaogyn/src/features/saved_stops/data/shared_preferences_saved_stops_store.dart';
import 'package:busaogyn/src/features/saved_stops/domain/saved_stop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

Future<SharedPreferences> _prefs([Map<String, Object> initial = const {}]) {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

void main() {
  test('o que foi gravado volta numa nova leitura (entre sessões)', () async {
    final prefs = await _prefs();
    final store = SharedPreferencesSavedStopsStore(prefs);
    await store.save(
      SavedStopsData(
        favorites: [stop('30402', second: 3)],
        recents: [stop('30100', second: 8), stop('30402', second: 3)],
      ),
    );

    // "Reabrir o app": o texto guardado vira o estado inicial de outra sessão.
    final raw = prefs.getString(SharedPreferencesSavedStopsStore.key)!;
    final reopened = SharedPreferencesSavedStopsStore(
      await _prefs({SharedPreferencesSavedStopsStore.key: raw}),
    );
    final load = await reopened.load();

    expect(load.unreadable, isFalse);
    expect(codes(load.data.favorites), ['30402']);
    expect(codes(load.data.recents), ['30100', '30402']);
    expect(load.data.recents.first.at, stop('30100', second: 8).at);
  });

  test('nada guardado é vazio', () async {
    final store = SharedPreferencesSavedStopsStore(await _prefs());
    final load = await store.load();
    expect(load.unreadable, isFalse);
    expect(load.data.favorites, isEmpty);
  });

  test('JSON corrompido é ilegível e a próxima gravação o substitui', () async {
    final prefs = await _prefs({
      SharedPreferencesSavedStopsStore.key: '{ quebrado',
    });
    final store = SharedPreferencesSavedStopsStore(prefs);

    expect((await store.load()).unreadable, isTrue);
    await store.save(SavedStopsData(favorites: [stop('30402')]));
    final load = await store.load();
    expect(load.unreadable, isFalse);
    expect(codes(load.data.favorites), ['30402']);
  });

  test('chave com outro tipo de valor é ilegível, não lança', () async {
    final store = SharedPreferencesSavedStopsStore(
      await _prefs({SharedPreferencesSavedStopsStore.key: 42}),
    );
    final load = await store.load();
    expect(load.unreadable, isTrue);
    expect(load.data.favorites, isEmpty);
  });

  test('os limites configurados valem na leitura', () async {
    final store = SharedPreferencesSavedStopsStore(
      await _prefs(),
      favoriteLimit: 2,
      recentLimit: 1,
    );
    await store.save(
      SavedStopsData(
        favorites: [stop('1'), stop('2'), stop('3')],
        recents: [stop('1'), stop('2')],
      ),
    );
    final load = await store.load();
    expect(codes(load.data.favorites), ['1', '2']);
    expect(codes(load.data.recents), ['1']);
  });

  test('é persistente e usa uma chave própria e versionada', () async {
    final store = SharedPreferencesSavedStopsStore(await _prefs());
    expect(store.persistent, isTrue);
    expect(SharedPreferencesSavedStopsStore.key, 'busaogyn.saved_stops.v1');
  });
}
