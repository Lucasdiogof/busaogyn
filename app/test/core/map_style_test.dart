import 'dart:convert';
import 'dart:io';

import 'package:busaogyn/src/core/config/map_config.dart';
import 'package:busaogyn/src/core/map/night_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _asset() =>
    jsonDecode(File(MapConfig.nightStyleAsset).readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('MapStyles.resolve', () {
    test(
      'padrão: Liberty de dia, noturno empacotado e fallback no Liberty',
      () {
        final styles = MapStyles.resolve(styleUrl: MapConfig.defaultStyleUrl);
        expect(styles.light, MapConfig.defaultStyleUrl);
        expect(styles.dark, MapConfig.nightStyleAsset);
        expect(styles.fallback, MapConfig.defaultStyleUrl);
        expect(
          styles.forBrightness(Brightness.dark),
          MapConfig.nightStyleAsset,
        );
        expect(
          styles.forBrightness(Brightness.light),
          MapConfig.defaultStyleUrl,
        );
      },
    );

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
      expect(styles.dark, 'https://example.com/night.json');
      expect(styles.fallback, 'https://example.com/day.json');
    });

    test('MAP_STYLE_URL vazio cai no Liberty', () {
      final styles = MapStyles.resolve(styleUrl: '  ');
      expect(styles.light, MapConfig.defaultStyleUrl);
      expect(styles.dark, MapConfig.nightStyleAsset);
    });
  });

  group('Liberty noturno empacotado', () {
    final night = _asset();
    final layers = (night['layers'] as List).cast<Map<String, dynamic>>();

    test('preserva sources, fontes e sprites do Liberty', () {
      expect(night['version'], 8);
      expect(
        night['glyphs'],
        'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf',
      );
      expect(
        night['sprite'],
        startsWith('https://tiles.openfreemap.org/sprites/'),
      );
      final sources = night['sources'] as Map<String, dynamic>;
      // A atribuição OpenFreeMap/OpenMapTiles/OSM vem do TileJSON desta
      // source; ela não pode ser trocada nem removida.
      expect(sources['openmaptiles'], {
        'type': 'vector',
        'url': 'https://tiles.openfreemap.org/planet',
      });
      expect(
        (night['metadata'] as Map)['busaogyn:derivedFrom'],
        MapConfig.defaultStyleUrl,
      );
    });

    test('fundo e áreas escuros, textos claros, sem POIs', () {
      final background = layers.firstWhere((l) => l['type'] == 'background');
      final bg = (background['paint'] as Map)['background-color'] as String;
      expect(cssLightness(bg), lessThan(0.12));

      expect(
        layers.where((l) => (l['id'] as String).startsWith('poi')),
        isEmpty,
      );

      for (final layer in layers.where((l) => l['type'] == 'symbol')) {
        final color = (layer['paint'] as Map?)?['text-color'];
        if (color is String) {
          expect(cssLightness(color), greaterThan(0.4), reason: layer['id']);
        }
      }
      for (final layer in layers.where((l) => l['type'] == 'fill')) {
        final color = (layer['paint'] as Map?)?['fill-color'];
        if (color is String) {
          expect(cssLightness(color), lessThan(0.3), reason: layer['id']);
        }
      }
    });

    test('toda cor gerada é válida', () {
      void visit(Object? value, String id) {
        if (value is String && value.startsWith('hsla(')) {
          expect(parseCssColor(value), isNotNull, reason: '$id: $value');
        } else if (value is List) {
          for (final v in value) {
            visit(v, id);
          }
        } else if (value is Map) {
          for (final v in value.values) {
            visit(v, id);
          }
        }
      }

      for (final layer in layers) {
        visit(layer['paint'], layer['id'] as String);
      }
    });

    test('está registrado como asset no pubspec', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- ${MapConfig.nightStyleAsset}'));
    });
  });

  group('deriveNightStyle', () {
    const style = {
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
          'id': 'road',
          'type': 'line',
          'filter': ['==', 'class', 'minor'],
          'paint': {
            'line-color': [
              'interpolate',
              ['linear'],
              ['zoom'],
              5,
              'hsl(0, 0%, 100%)',
              10,
              'rgba(255,255,255,0.5)',
            ],
            'line-width': 2,
          },
        },
        {
          'id': 'label',
          'type': 'symbol',
          'layout': {
            'text-font': ['Noto Sans Regular'],
          },
          'paint': {'text-color': '#333', 'text-halo-color': '#fff'},
        },
        {'id': 'poi_r1', 'type': 'symbol'},
      ],
    };

    test('recolore só cores e mantém o resto intacto', () {
      final night = deriveNightStyle(style, sourceUrl: 'https://x/style');
      expect(night['sources'], style['sources']);
      expect(night['glyphs'], style['glyphs']);
      expect(night['sprite'], style['sprite']);

      final layers = (night['layers'] as List).cast<Map<String, dynamic>>();
      expect(layers.map((l) => l['id']), ['background', 'road', 'label']);

      final road = layers[1];
      expect(road['filter'], ['==', 'class', 'minor']);
      final line = (road['paint'] as Map)['line-color'] as List;
      expect(line.take(3), [
        'interpolate',
        ['linear'],
        ['zoom'],
      ]);
      expect(line[4], startsWith('hsla('));
      expect(line[6], endsWith(',0.500)'));
      expect((road['paint'] as Map)['line-width'], 2);

      final label = layers[2];
      expect((label['layout'] as Map)['text-font'], ['Noto Sans Regular']);
      final paint = label['paint'] as Map;
      expect(cssLightness(paint['text-color'] as String), greaterThan(0.6));
      expect(cssLightness(paint['text-halo-color'] as String), lessThan(0.1));
    });

    test('é determinístico', () {
      expect(
        jsonEncode(deriveNightStyle(style, sourceUrl: 'u')),
        jsonEncode(deriveNightStyle(style, sourceUrl: 'u')),
      );
    });
  });

  test('parseCssColor', () {
    expect(parseCssColor('#fff')!.l, closeTo(1, 1e-9));
    expect(parseCssColor('#000000')!.l, 0);
    expect(parseCssColor('rgba(255, 0, 0, 0.5)')!.a, 0.5);
    expect(parseCssColor('hsl(120deg, 50%, 25%)')!.h, 120);
    expect(parseCssColor('Noto Sans Regular'), isNull);
    expect(parseCssColor('interpolate'), isNull);
  });
}
