import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:busaogyn/src/core/config/map_config.dart';
import 'package:busaogyn/src/core/map/busao_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _glyphs = 'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf';

Map<String, dynamic> _asset(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Saturação e luminosidade HSL (0–1) de uma cor `#rrggbb`.
({double s, double l}) _hsl(String hex) {
  final m = RegExp(r'^#([0-9a-f]{6})$').firstMatch(hex.toLowerCase());
  expect(m, isNotNull, reason: 'cor inesperada: $hex');
  final v = int.parse(m!.group(1)!, radix: 16);
  final r = ((v >> 16) & 0xFF) / 255;
  final g = ((v >> 8) & 0xFF) / 255;
  final b = (v & 0xFF) / 255;
  final mx = math.max(r, math.max(g, b));
  final mn = math.min(r, math.min(g, b));
  final l = (mx + mn) / 2;
  if (mx == mn) return (s: 0, l: l);
  final d = mx - mn;
  return (s: l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn), l: l);
}

/// Croma (max − min dos canais, 0–1) de uma cor `#rrggbb`: 0 é cinza puro.
double _chroma(String hex) {
  final v = int.parse(hex.substring(1), radix: 16);
  final c = [(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
  return (c.reduce(math.max) - c.reduce(math.min)) / 255;
}

/// Último valor de uma expressão `interpolate` (maior zoom) ou o próprio
/// número.
double _lastStop(Object? value) {
  if (value is num) return value.toDouble();
  final list = value as List;
  return (list.last as num).toDouble();
}

void main() {
  group('MapStyles.resolve', () {
    test('padrão: estilos BusãoGyn empacotados e fallback no Liberty', () {
      final styles = MapStyles.resolve(styleUrl: MapConfig.defaultStyleUrl);
      expect(styles.light, MapConfig.lightStyleAsset);
      expect(styles.dark, MapConfig.nightStyleAsset);
      expect(styles.fallback, MapConfig.defaultStyleUrl);
      expect(styles.forBrightness(Brightness.dark), MapConfig.nightStyleAsset);
      expect(styles.forBrightness(Brightness.light), MapConfig.lightStyleAsset);
    });

    test('MAP_STYLE_URL próprio vale para os dois temas', () {
      final styles = MapStyles.resolve(styleUrl: 'https://example.com/s.json');
      expect(styles.light, 'https://example.com/s.json');
      expect(styles.dark, 'https://example.com/s.json');
      expect(styles.fallback, 'https://example.com/s.json');
    });

    test('MAP_STYLE_DARK_URL define o noturno com fallback no diurno', () {
      final styles = MapStyles.resolve(
        styleUrl: 'https://example.com/day.json',
        darkStyleUrl: 'https://example.com/night.json',
      );
      expect(styles.light, 'https://example.com/day.json');
      expect(styles.dark, 'https://example.com/night.json');
      expect(styles.fallback, 'https://example.com/day.json');
    });

    test('MAP_STYLE_URL vazio cai nos estilos empacotados', () {
      final styles = MapStyles.resolve(styleUrl: '  ');
      expect(styles.light, MapConfig.lightStyleAsset);
      expect(styles.dark, MapConfig.nightStyleAsset);
      expect(styles.fallback, MapConfig.defaultStyleUrl);
    });
  });

  for (final theme in BusaoMapTheme.values) {
    final dark = theme == BusaoMapTheme.dark;
    final path = dark ? MapConfig.nightStyleAsset : MapConfig.lightStyleAsset;

    group('estilo empacotado (${theme.name})', () {
      final style = _asset(path);
      final layers = (style['layers'] as List).cast<Map<String, dynamic>>();
      final byId = {for (final l in layers) l['id'] as String: l};

      test('preserva sources, glyphs e sprite do Liberty', () {
        expect(style['version'], 8);
        expect(style['glyphs'], _glyphs);
        expect(
          style['sprite'],
          startsWith('https://tiles.openfreemap.org/sprites/'),
        );
        final sources = style['sources'] as Map<String, dynamic>;
        // A atribuição OpenFreeMap/OpenMapTiles/OSM vem do TileJSON desta
        // source; ela não pode ser trocada nem removida.
        expect(sources['openmaptiles'], {
          'type': 'vector',
          'url': 'https://tiles.openfreemap.org/planet',
        });
        expect(sources, contains('ne2_shaded'));
        final meta = style['metadata'] as Map;
        expect(meta['busaogyn:derivedFrom'], MapConfig.defaultStyleUrl);
        expect(meta['busaogyn:theme'], theme.name);
      });

      test('ids únicos e sources existentes', () {
        expect(byId.length, layers.length);
        final sources = (style['sources'] as Map).keys.toSet();
        for (final layer in layers) {
          final source = layer['source'];
          if (source != null) {
            expect(sources, contains(source), reason: layer['id'] as String);
          }
        }
      });

      test('sem ruído: POIs, prédios 3D, setas e escudos fora', () {
        for (final id in byId.keys) {
          expect(id, isNot(startsWith('poi')));
          expect(id, isNot(startsWith('building-3d')));
          expect(id, isNot(startsWith('road_one_way')));
          expect(id, isNot(contains('shield')));
        }
        expect(byId, contains('building'));
      });

      test('textos acima de todo o resto', () {
        final firstSymbol = layers.indexWhere((l) => l['type'] == 'symbol');
        final lastOther = layers.lastIndexWhere((l) => l['type'] != 'symbol');
        expect(firstSymbol, greaterThan(lastOther));
        expect(layers.first['type'], 'background');
      });

      test('fundo em grafite/off-white, nunca preto ou branco puro', () {
        final bg = (layers.first['paint'] as Map)['background-color'] as String;
        final l = _hsl(bg).l;
        if (dark) {
          expect(l, inInclusiveRange(0.05, 0.12));
        } else {
          expect(l, inInclusiveRange(0.85, 0.95));
        }
      });

      test('vias só em tons neutros: sem amarelo/âmbar', () {
        final roads = layers.where(
          (l) =>
              l['type'] == 'line' &&
              RegExp(r'^(road|tunnel|bridge)_').hasMatch(l['id'] as String),
        );
        expect(roads, isNotEmpty);
        for (final road in roads) {
          final color = (road['paint'] as Map)['line-color'] as String;
          expect(_chroma(color), lessThan(0.06), reason: road['id'] as String);
        }
      });

      test('ruas locais finas e sem contorno; principais com contorno', () {
        for (final id in byId.keys) {
          expect(id, isNot(matches(r'_(minor|street|service_track)_casing$')));
        }
        expect(byId, contains('road_secondary_tertiary_casing'));
        expect(byId, contains('road_trunk_primary_casing'));
        expect(byId, contains('road_motorway_casing'));
        expect(byId['road_minor']!['minzoom'], greaterThanOrEqualTo(14));
        expect(
          byId['road_service_track']!['minzoom'],
          greaterThanOrEqualTo(15.5),
        );
      });

      test('hierarquia de largura: local < avenida < tronco < rodovia', () {
        double width(String id) =>
            _lastStop((byId[id]!['paint'] as Map)['line-width']);
        expect(width('road_service_track'), lessThan(width('road_minor')));
        expect(width('road_minor'), lessThan(width('road_secondary_tertiary')));
        expect(
          width('road_secondary_tertiary'),
          lessThan(width('road_trunk_primary')),
        );
        expect(
          width('road_trunk_primary'),
          lessThanOrEqualTo(width('road_motorway')),
        );
      });

      if (dark) {
        test('à noite, quanto mais importante a via, mais clara', () {
          double light(String id) =>
              _hsl((byId[id]!['paint'] as Map)['line-color'] as String).l;
          expect(light('road_service_track'), lessThan(light('road_minor')));
          expect(
            light('road_minor'),
            lessThan(light('road_secondary_tertiary')),
          );
          expect(
            light('road_secondary_tertiary'),
            lessThan(light('road_trunk_primary')),
          );
          expect(light('road_trunk_primary'), lessThan(light('road_motorway')));
        });
      }

      test('nomes de ruas locais só em zoom alto', () {
        expect(
          byId['highway-name-minor']!['minzoom'],
          greaterThanOrEqualTo(16),
        );
        expect(
          byId['highway-name-major']!['minzoom'],
          greaterThanOrEqualTo(13),
        );
        expect(byId['label_other']!['minzoom'], greaterThanOrEqualTo(12.5));
      });

      test('textos legíveis sobre o fundo', () {
        final bg = _hsl((layers.first['paint'] as Map)['background-color']).l;
        for (final layer in layers.where((l) => l['type'] == 'symbol')) {
          final color = (layer['paint'] as Map)['text-color'] as String;
          final l = _hsl(color).l;
          expect(
            (l - bg).abs(),
            greaterThan(0.2),
            reason: layer['id'] as String,
          );
        }
      });

      test('prédios só de perto e tom sobre tom', () {
        final building = byId['building']!;
        expect(building['minzoom'], greaterThanOrEqualTo(15));
        expect(building.containsKey('maxzoom'), isFalse);
      });

      test('está registrado como asset no pubspec', () {
        final pubspec = File('pubspec.yaml').readAsStringSync();
        expect(pubspec, contains('- $path'));
      });
    });
  }

  group('buildBusaoStyle', () {
    const liberty = {
      'version': 8,
      'sources': {
        'openmaptiles': {'type': 'vector', 'url': 'https://x/planet'},
      },
      'glyphs': 'https://x/{fontstack}/{range}.pbf',
      'sprite': 'https://x/sprite',
      'layers': [
        {
          'id': 'background',
          'type': 'background',
          'paint': {'background-color': '#f8f4f0'},
        },
        {
          'id': 'road_minor_casing',
          'type': 'line',
          'filter': ['==', 'class', 'minor'],
          'paint': {'line-color': '#cfcdca', 'line-width': 4},
        },
        {
          'id': 'road_minor',
          'type': 'line',
          'filter': ['==', 'class', 'minor'],
          'layout': {'line-cap': 'round'},
          'paint': {'line-color': '#fff', 'line-width': 2},
        },
        {
          'id': 'road_trunk_primary',
          'type': 'line',
          'paint': {'line-color': '#fea', 'line-width': 3},
        },
        {'id': 'poi_r1', 'type': 'symbol'},
        {'id': 'building-3d', 'type': 'fill-extrusion'},
        {'id': 'road_one_way_arrow', 'type': 'symbol'},
        {
          'id': 'highway-name-minor',
          'type': 'symbol',
          'minzoom': 15,
          'layout': {
            'text-font': ['Noto Sans Regular'],
            'text-size': 12,
          },
          'paint': {'text-color': '#666'},
        },
        {'id': 'camada_nova', 'type': 'fill', 'source': 'openmaptiles'},
      ],
    };

    Map<String, dynamic> build(BusaoMapTheme theme, [Set<String>? unhandled]) =>
        buildBusaoStyle(
          liberty,
          theme,
          sourceUrl: 'https://x/style',
          onUnhandled: unhandled?.add,
        );

    test('preserva sources, glyphs, sprite e filtros', () {
      final style = build(BusaoMapTheme.dark);
      expect(style['sources'], liberty['sources']);
      expect(style['glyphs'], liberty['glyphs']);
      expect(style['sprite'], liberty['sprite']);
      final layers = (style['layers'] as List).cast<Map<String, dynamic>>();
      final minor = layers.firstWhere((l) => l['id'] == 'road_minor');
      expect(minor['filter'], ['==', 'class', 'minor']);
      expect((minor['layout'] as Map)['line-cap'], 'round');
    });

    test(
      'remove ruído e contorno de rua local; mantém camada desconhecida',
      () {
        final unhandled = <String>{};
        final style = build(BusaoMapTheme.light, unhandled);
        final ids = [for (final l in style['layers'] as List) (l as Map)['id']];
        expect(ids, [
          'background',
          'road_minor',
          'road_trunk_primary',
          'highway-name-minor',
          'camada_nova',
        ]);
        expect(unhandled, {'camada_nova'});
      },
    );

    test('aplica paleta por tema', () {
      Map<String, dynamic> layer(BusaoMapTheme theme, String id) =>
          ((build(theme)['layers'] as List).cast<Map<String, dynamic>>())
              .firstWhere((l) => l['id'] == id);
      final nightBg =
          (layer(BusaoMapTheme.dark, 'background')['paint']
                  as Map)['background-color']
              as String;
      final dayBg =
          (layer(BusaoMapTheme.light, 'background')['paint']
                  as Map)['background-color']
              as String;
      expect(_hsl(nightBg).l, lessThan(0.12));
      expect(_hsl(dayBg).l, greaterThan(0.85));
      final trunk =
          (layer(BusaoMapTheme.dark, 'road_trunk_primary')['paint']
                  as Map)['line-color']
              as String;
      expect(_chroma(trunk), lessThan(0.06));
      expect(layer(BusaoMapTheme.dark, 'highway-name-minor')['minzoom'], 16);
    });

    test('é determinístico e não altera a entrada', () {
      final before = jsonEncode(liberty);
      expect(
        jsonEncode(build(BusaoMapTheme.dark)),
        jsonEncode(build(BusaoMapTheme.dark)),
      );
      expect(jsonEncode(liberty), before);
    });
  });
}
