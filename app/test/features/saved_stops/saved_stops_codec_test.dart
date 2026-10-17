import 'dart:convert';

import 'package:busaogyn/src/features/saved_stops/data/saved_stops_codec.dart';
import 'package:busaogyn/src/features/saved_stops/domain/saved_stop.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

String _doc({Object? favorites, Object? recents, Object? schema = 1}) =>
    jsonEncode({'schema': schema, 'favorites': favorites, 'recents': recents});

Map<String, Object?> _item(Object? code, {Object? name, Object? at}) => {
  'code': code,
  'name': name,
  'at': at ?? '2026-10-17T12:00:00.000Z',
};

void main() {
  test('ida e volta preservam códigos, nomes, horas e a ordem', () {
    final data = SavedStopsData(
      favorites: [
        stop('30402', name: 'Ponto A', second: 5),
        stop('00294'),
      ],
      recents: [stop('30100', second: 9), stop('30402')],
    );
    final load = decodeSavedStops(encodeSavedStops(data));

    expect(load.unreadable, isFalse);
    expect(load.data.favorites, data.favorites);
    expect(load.data.recents, data.recents);
  });

  test('nada guardado ainda é vazio, não erro', () {
    final load = decodeSavedStops(null);
    expect(load.unreadable, isFalse);
    expect(load.data.favorites, isEmpty);
    expect(load.data.recents, isEmpty);
  });

  test('só guarda código, nome, hora e versão (nenhuma previsão)', () {
    final json =
        jsonDecode(encodeSavedStops(SavedStopsData(favorites: [stop('1')])))
            as Map;
    expect(json.keys.toSet(), {'schema', 'favorites', 'recents'});
    expect((json['favorites'] as List).single.keys.toSet(), {
      'code',
      'name',
      'at',
    });
  });

  group('armazenamento ilegível vira vazio e avisa', () {
    for (final raw in [
      '',
      '{',
      'não é json',
      '[]',
      '"texto"',
      '123',
      'null',
      '{"favorites": []}', // sem schema
      '{"schema": 2, "favorites": [], "recents": []}', // formato novo
      '{"schema": "1"}',
    ]) {
      test(raw.isEmpty ? 'texto vazio' : raw, () {
        final load = decodeSavedStops(raw);
        expect(load.unreadable, isTrue);
        expect(load.data.favorites, isEmpty);
        expect(load.data.recents, isEmpty);
      });
    }
  });

  test('listas ausentes ou de tipo errado viram vazias, sem lançar', () {
    final load = decodeSavedStops(_doc(favorites: 'x', recents: {'a': 1}));
    expect(load.unreadable, isFalse);
    expect(load.data.favorites, isEmpty);
    expect(load.data.recents, isEmpty);
  });

  test('itens inválidos são descartados e os válidos ficam', () {
    final load = decodeSavedStops(
      _doc(
        favorites: [
          _item('30402'),
          _item('abc'),
          _item(''),
          _item(null),
          _item(123),
          'texto solto',
          null,
          _item('1' * 50),
          _item('00294'),
        ],
      ),
    );
    expect(codes(load.data.favorites), ['30402', '00294']);
  });

  test('códigos repetidos são descartados, mantendo o primeiro', () {
    final load = decodeSavedStops(
      _doc(
        favorites: [
          _item('30402', name: 'primeiro'),
          _item('30402', name: 'repetido'),
          _item(' 30402 '),
          _item('30100'),
        ],
      ),
    );
    expect(codes(load.data.favorites), ['30402', '30100']);
    expect(load.data.favorites.first.name, 'primeiro');
  });

  test('as listas respeitam os limites ao ler', () {
    final many = [for (var i = 1; i <= 80; i++) _item('$i')];
    final load = decodeSavedStops(
      _doc(favorites: many, recents: many),
      favoriteLimit: 50,
      recentLimit: 10,
    );
    expect(load.data.favorites, hasLength(50));
    expect(load.data.recents, hasLength(10));
    expect(codes(load.data.recents).first, '1');
  });

  test('nome vazio some, nome longo é cortado, hora ruim não derruba', () {
    final load = decodeSavedStops(
      _doc(
        favorites: [
          _item('1', name: '   '),
          _item('2', name: 'N' * 500),
          _item('3', name: 42),
          _item('4', at: 'ontem'),
          _item('5', at: 7),
        ],
      ),
    );
    final byCode = {for (final s in load.data.favorites) s.code: s};
    expect(byCode['1']!.name, isNull);
    expect(byCode['2']!.name!.length, 80);
    expect(byCode['3']!.name, isNull);
    expect(byCode['4']!.at.millisecondsSinceEpoch, 0);
    expect(byCode['5']!.at.millisecondsSinceEpoch, 0);
  });
}
