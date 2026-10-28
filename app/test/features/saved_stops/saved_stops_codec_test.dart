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
    expect(json.keys.toSet(), {
      'schema',
      'favorites',
      'recents',
      'lines',
      'trips',
    });
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
      '{"schema": 4, "favorites": [], "recents": []}', // formato novo
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

  group('linhas favoritas (par ponto + linha)', () {
    test('o formato antigo (versão 1) continua legível, sem linhas', () {
      final load = decodeSavedStops(
        jsonEncode({
          'schema': 1,
          'favorites': [_item('30402')],
          'recents': <Object?>[],
        }),
      );
      expect(load.unreadable, isFalse);
      expect(codes(load.data.favorites), ['30402']);
      expect(load.data.lines, isEmpty);
    });

    test('grava e lê de volta só ponto, linha e hora', () {
      final at = DateTime.utc(2026, 10, 17, 12);
      final raw = encodeSavedStops(
        SavedStopsData(
          lines: [SavedLine(stopCode: '30402', routeId: '003', at: at)],
        ),
      );
      final json = jsonDecode(raw) as Map;
      expect((json['lines'] as List).single.keys.toSet(), {
        'stop',
        'route',
        'at',
      });
      final back = decodeSavedStops(raw).data.lines.single;
      expect(back.stopCode, '30402');
      expect(back.routeId, '003');
      expect(back.at, at);
    });

    test('a linha é texto opaco: zeros e letras preservados', () {
      final lines = decodeSavedStops(
        jsonEncode({
          'schema': 2,
          'favorites': <Object?>[],
          'recents': <Object?>[],
          'lines': [
            {'stop': '30402', 'route': '003', 'at': '2026-10-17T12:00:00Z'},
            {'stop': '30402', 'route': 'MGP1', 'at': '2026-10-17T12:00:00Z'},
          ],
        }),
      ).data.lines;
      expect([for (final l in lines) l.routeId], ['003', 'MGP1']);
    });

    test('descarta inválidas e repetidas sem lançar', () {
      final lines = decodeSavedStops(
        jsonEncode({
          'schema': 2,
          'favorites': <Object?>[],
          'recents': <Object?>[],
          'lines': [
            {'stop': '30402', 'route': '003'},
            {'stop': '30402', 'route': '003'},
            {'stop': 'abc', 'route': '003'},
            {'stop': '30402', 'route': ''},
            {'stop': '30402', 'route': 'a b'},
            {'stop': '30402', 'route': 'ABCDEFGHI'},
            {'stop': 30402, 'route': '003'},
            'lixo',
            null,
          ],
        }),
      ).data.lines;
      expect(lines, hasLength(1));
    });

    test('respeita o limite', () {
      final lines = decodeSavedStops(
        jsonEncode({
          'schema': 2,
          'favorites': <Object?>[],
          'recents': <Object?>[],
          'lines': [
            for (var i = 0; i < 5; i++) {'stop': '$i', 'route': '003'},
          ],
        }),
        lineLimit: 3,
      ).data.lines;
      expect(lines, hasLength(3));
    });
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

  group('viagens salvas (schema 3)', () {
    final at = DateTime.utc(2026, 10, 28, 9);

    test('ida e volta: só códigos, nome e hora; sem itinerário', () {
      final data = SavedStopsData(
        trips: [
          SavedTrip(from: '1201', to: 'T-PADRE-PELAGIO', at: at, name: 'Casa'),
          SavedTrip(from: '30402', to: '1201', at: at),
        ],
      );
      final raw = encodeSavedStops(data);
      final json = jsonDecode(raw) as Map;
      expect(json['schema'], 3);
      expect((json['trips'] as List).first.keys.toSet(), {
        'from',
        'to',
        'name',
        'at',
      });
      expect((json['trips'] as List).last.keys.toSet(), {'from', 'to', 'at'});
      expect(decodeSavedStops(raw).data.trips, data.trips);
    });

    test('migração: schema 1 e 2 continuam legíveis, sem viagens', () {
      for (final schema in [1, 2]) {
        final load = decodeSavedStops(
          jsonEncode({
            'schema': schema,
            'favorites': [
              {'code': '1201', 'at': at.toIso8601String()},
            ],
            'recents': [],
            if (schema == 2) 'lines': [],
          }),
        );
        expect(load.unreadable, isFalse, reason: 'schema $schema');
        expect(load.data.favorites.single.code, '1201');
        expect(load.data.trips, isEmpty);
      }
    });

    test('descarta inválidas, repetidas e origem = destino; corta o nome', () {
      final load = decodeSavedStops(
        jsonEncode({
          'schema': 3,
          'favorites': [],
          'recents': [],
          'trips': [
            {'from': '1', 'to': '2', 'name': '  ${'N' * 90}  '},
            {'from': '1', 'to': '2'},
            {'from': '3', 'to': '3'},
            {'from': 'a b', 'to': '2'},
            {'from': 4, 'to': '2'},
            'lixo',
            {'from': '2', 'to': '1', 'name': '   ', 'at': 'ontem'},
          ],
        }),
      );
      expect(load.unreadable, isFalse);
      expect(
        [for (final t in load.data.trips) '${t.from}>${t.to}'],
        ['1>2', '2>1'],
      );
      expect(load.data.trips.first.name!.length, maxTripNameLength);
      expect(load.data.trips.last.name, isNull);
      expect(load.data.trips.last.at.millisecondsSinceEpoch, 0);
    });
  });
}
