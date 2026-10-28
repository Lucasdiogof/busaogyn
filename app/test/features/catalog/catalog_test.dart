import 'dart:convert';

import 'package:busaogyn/src/bootstrap.dart';
import 'package:busaogyn/src/features/catalog/data/catalog_codec.dart';
import 'package:busaogyn/src/features/catalog/domain/text_search.dart';
import 'package:busaogyn/src/features/catalog/domain/transit_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_fixture.dart';

void main() {
  group('normalização', () {
    test('minúsculas, sem acento e sem pontuação', () {
      expect(normalizeSearch('Praça Cívica, Nº 3'), 'praca civica no 3');
      expect(normalizeSearch('  ÁGUA-CLARA  '), 'agua clara');
      expect(normalizeSearch(null), '');
    });

    test('abreviações de endereço viram a forma longa', () {
      expect(searchTokens('Pça cívica'), ['praca', 'civica']);
      expect(searchTokens('Jd simulado'), ['jardim', 'simulado']);
    });

    test('código de linha como a API: 1 a 3 dígitos com zeros', () {
      expect(normalizeLineId('3'), '003');
      expect(normalizeLineId('003'), '003');
      expect(normalizeLineId('ns9'), 'NS9');
      expect(normalizeLineId('MGP-07'), 'MGP-07');
    });

    test('caixa de leitura preserva siglas e romanos', () {
      expect(displayCase('RUA DAS FLORES II'), 'Rua das Flores II');
      expect(displayCase('AVENIDA C-08'), 'Avenida C-08');
      expect(displayCase('ESQ. C- RUA U 61'), 'Esq. C- Rua U 61');
    });
  });

  group('decodificação', () {
    test('lê linhas, variantes e pontos; descarta linhas malformadas', () {
      final c = fixtureCatalog();
      expect(c.lines.map((l) => l.id), ['001', '042', 'NS9']);
      expect(c.variants, hasLength(4));
      expect(c.stops.map((s) => s.id), [
        '00294',
        '1201',
        '1202',
        '1203',
        '40999',
      ]);
      expect(c.version.restricted, isTrue);
      expect(c.version.licenseStatus, 'pendente');
      expect(c.version.stopsReference, '2026-10');
    });

    test('códigos ficam como texto e zeros à esquerda são preservados', () {
      final c = fixtureCatalog();
      expect(c.stop('00294'), isNotNull);
      expect(c.stop('294'), isNull);
      // Linha que veio como inteiro (1) vira a base da API ('001').
      expect(c.stop('00294')!.lineIds, ['001', '042']);
    });

    test('formato desconhecido ou JSON inválido lança', () {
      expect(() => decodeCatalog('{'), throwsA(isA<CatalogFormatException>()));
      expect(
        () =>
            decodeCatalog(jsonEncode({'format': 'outro', 'formatVersion': 1})),
        throwsA(isA<CatalogFormatException>()),
      );
      expect(
        () => decodeCatalog(
          jsonEncode({...fixtureCatalogMap(), 'formatVersion': 2}),
        ),
        throwsA(isA<CatalogFormatException>()),
      );
    });

    test('sem a marca restricted, o catálogo é tratado como restrito', () {
      final map = fixtureCatalogMap();
      (map['version']! as Map).remove('restricted');
      expect(decodeCatalog(jsonEncode(map)).version.restricted, isTrue);
    });

    test('colunas reordenadas não quebram a leitura', () {
      final map = fixtureCatalogMap();
      final stops = map['stops']! as Map<String, Object?>;
      final fields = [...(stops['fields']! as List)];
      final rows = [
        for (final r in stops['rows']! as List) [...(r as List)],
      ];
      // Troca 'street' e 'district' de lugar.
      final a = fields.indexOf('street');
      final b = fields.indexOf('district');
      fields[a] = 'district';
      fields[b] = 'street';
      for (final r in rows) {
        final tmp = r[a];
        r[a] = r[b];
        r[b] = tmp;
      }
      map['stops'] = {'fields': fields, 'rows': rows};
      final stop = decodeCatalog(jsonEncode(map)).stop('1201')!;
      expect(stop.street, 'EXEMPLO');
      expect(stop.district, 'JARDIM SIMULADO');
    });
  });

  group('busca de pontos', () {
    final c = fixtureCatalog();
    List<String> ids(String q) => [for (final s in c.searchStops(q)) s.id];

    test('código exato vem primeiro; prefixo também casa', () {
      expect(ids('1201').first, '1201');
      expect(ids('120'), ['1201', '1202', '1203']);
      expect(ids('00294'), ['00294']);
    });

    test('por logradouro, sem acento e sem diferença de caixa', () {
      expect(ids('ficticia'), contains('00294'));
      expect(ids('RUA FICTÍCIA'), ['00294']);
      expect(ids('av exemplo'), ['1201', '1202']);
    });

    test('por bairro e por município', () {
      expect(ids('agua clara'), ['00294']);
      expect(ids('jardim simulado'), ['1201']);
      expect(ids('trindade'), ['1202']);
      expect(ids('aparecida'), ['1201']);
    });

    test('todas as palavras precisam casar; sem duplicidade', () {
      expect(ids('exemplo trindade'), ['1202']);
      expect(ids('exemplo inexistente'), isEmpty);
      final all = ids('a');
      expect(all.toSet(), hasLength(all.length));
    });

    test('logradouro pesa mais que bairro', () {
      final map = fixtureCatalogMap(
        extraStops: [
          [
            '2001',
            'ped',
            'RUA',
            'OUTRA',
            null,
            'EXEMPLO',
            'GOIÂNIA',
            null,
            null,
            [],
            null,
          ],
        ],
      );
      final cat = decodeCatalog(jsonEncode(map));
      final found = [for (final s in cat.searchStops('exemplo')) s.id];
      expect(found.last, '2001');
    });

    test('estação só do KMZ é encontrada pelo nome e pelo código', () {
      expect(ids('estacao teste'), ['40999']);
      expect(ids('40999'), ['40999']);
      expect(c.stop('40999')!.kind, CatalogStopKind.station);
    });

    test('busca vazia não devolve nada', () {
      expect(ids('   '), isEmpty);
    });

    test('rápida com o volume real (~7,5 mil pontos)', () {
      final extra = [
        for (var i = 0; i < 7500; i++)
          [
            '${10000 + i}',
            'ped',
            'RUA',
            'SINTÉTICA $i',
            'QUADRA ${i % 90}',
            'BAIRRO ${i % 400}',
            i.isEven ? 'GOIÂNIA' : 'TRINDADE',
            null,
            null,
            ['${i % 300}'],
            null,
          ],
      ];
      final big = decodeCatalog(
        jsonEncode(fixtureCatalogMap(extraStops: extra)),
      );
      final watch = Stopwatch()..start();
      for (final q in [
        'sintetica 12',
        'bairro 3',
        'trindade',
        '1234',
        'quadra 5 goiania',
      ]) {
        for (var i = 0; i < 10; i++) {
          big.searchStops(q);
        }
      }
      watch.stop();
      // 50 buscas; folga larga para máquinas de CI lentas.
      expect(watch.elapsedMilliseconds, lessThan(3000));
    });
  });

  group('linhas', () {
    final c = fixtureCatalog();
    List<String> ids(String q) => [for (final l in c.searchLines(q)) l.id];

    test('por número, com ou sem zeros', () {
      expect(ids('1').first, '001');
      expect(ids('001').first, '001');
      expect(ids('42').first, '042');
      expect(ids('ns9'), ['NS9']);
    });

    test('por nome, terminal e cidade', () {
      expect(ids('imaginario'), ['001']);
      expect(ids('hospital'), ['001']);
      expect(ids('ficticio sul'), ['042']);
      expect(ids('praca simulada'), ['NS9']);
    });

    test('sem busca: todas, em ordem de código', () {
      expect(ids(''), ['001', '042', 'NS9']);
    });

    test('variantes e pontos associados (relação ponto-linha oficial)', () {
      expect(c.variantsOf('1').map((v) => v.id), ['001-1', '001-2']);
      expect(c.stopsOf('042').map((s) => s.id), ['00294', '1201']);
      expect(c.stopsOf('NS9').map((s) => s.id), ['1201']);
      expect(c.stopCitiesOf('042'), ['Aparecida de Goiânia', 'Goiânia']);
      expect(c.line('999'), isNull);
    });
  });

  group('endereço para exibição', () {
    final c = fixtureCatalog();

    test('logradouro, referência, bairro e município', () {
      final stop = c.stop('00294')!;
      expect(stop.address, 'Rua Fictícia — Em Frente ao Mercado Teste');
      expect(stop.place, 'Setor Água Clara, Goiânia');
    });

    test('traço ou zero no cadastro é ausência, não texto', () {
      final map = fixtureCatalogMap(
        extraStops: [
          [
            '3001',
            'ped',
            'AVENIDA',
            'ANHANGUERA',
            '-',
            '0',
            'GOIÂNIA',
            null,
            null,
            [],
            null,
          ],
        ],
      );
      final stop = decodeCatalog(jsonEncode(map)).stop('3001')!;
      expect(stop.address, 'Avenida Anhanguera');
      expect(stop.place, 'Goiânia');
    });

    test('sem referência ou sem endereço', () {
      expect(c.stop('1203')!.address, 'Praça Cívica Fictícia');
      expect(c.stop('40999')!.address, 'Estação Teste (Plataforma A)');
      expect(c.stop('40999')!.place, isNull);
    });
  });

  group('inicialização (bootstrap)', () {
    test('sem payload: catálogo desligado', () {
      expect(loadDevCatalog(null, releaseMode: false), isNull);
    });

    test('build release nunca liga o catálogo, mesmo com payload', () {
      expect(loadDevCatalog(fixtureCatalogJson(), releaseMode: true), isNull);
    });

    test('desenvolvimento com payload válido liga', () {
      expect(
        loadDevCatalog(fixtureCatalogJson(), releaseMode: false),
        isNotNull,
      );
    });

    test('payload inválido desliga sem derrubar o app', () {
      expect(loadDevCatalog('{"format":"x"}', releaseMode: false), isNull);
    });
  });
}
