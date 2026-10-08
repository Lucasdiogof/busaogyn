import 'dart:math' as math;

/// Deriva a versão noturna de um estilo MapLibre (pensado para o Liberty do
/// OpenFreeMap) recolorindo apenas propriedades `*-color` do `paint`.
///
/// Sources, `glyphs`, `sprite`, filtros, zooms e expressões ficam intactos: as
/// fontes, os ícones e as atribuições (que vêm do TileJSON das sources) são os
/// do estilo original. Roda uma vez, em `tool/build_night_style.dart`; o
/// resultado é empacotado como asset e o app não processa nada em runtime.
Map<String, dynamic> deriveNightStyle(
  Map<String, dynamic> style, {
  required String sourceUrl,
}) {
  final layers = <Map<String, dynamic>>[];
  for (final raw in style['layers'] as List) {
    final layer = Map<String, dynamic>.from(raw as Map);
    // Ícones de POI são desenhados para fundo claro e disputam atenção com o
    // ônibus acompanhado; à noite ficam de fora (como na prévia aprovada).
    if ((layer['id'] as String).startsWith('poi')) continue;

    final paint = layer['paint'];
    if (paint is Map) {
      final type = layer['type'] as String;
      final next = <String, dynamic>{};
      for (final entry in paint.entries) {
        final key = entry.key as String;
        next[key] = key.contains('color')
            ? _mapColors(entry.value, _transformFor(type, key))
            : entry.value;
      }
      if (type == 'raster') next['raster-brightness-max'] = 0.35;
      layer['paint'] = next;
    }
    layers.add(layer);
  }

  return {
    ...style,
    'name': 'BusãoGyn Night (derived from OpenFreeMap Liberty)',
    'metadata': {
      ...?(style['metadata'] as Map<String, dynamic>?),
      'busaogyn:derivedFrom': sourceUrl,
      'busaogyn:generator': 'tool/build_night_style.dart',
    },
    'layers': layers,
  };
}

typedef _ColorTransform = String Function(HslaColor color);

_ColorTransform _transformFor(String layerType, String property) {
  if (layerType == 'symbol') {
    return property.contains('halo') ? _nightHalo : _nightText;
  }
  if (layerType == 'line') return _nightLine;
  return _nightFill;
}

/// Puxa o matiz para um âmbar quente (36°), coerente com o acento do app.
double _hue(double h) => h * 0.25 + 36 * 0.75;

/// Terreno escuro: quanto mais claro o original, mais escuro fica.
String _nightFill(HslaColor c) =>
    _format(_hue(c.h), math.min(c.s, 1) * 0.18, 0.055 + (1 - c.l) * 0.22, c.a);

/// Vias um pouco mais claras que o terreno para manter a malha legível.
String _nightLine(HslaColor c) =>
    _format(_hue(c.h), math.min(c.s, 1) * 0.14, 0.115 + c.l * 0.22, c.a);

String _nightText(HslaColor c) =>
    _format(_hue(c.h), 0.08, 0.90 - c.l * 0.55, c.a);

String _nightHalo(HslaColor c) => _format(_hue(c.h), 0.10, 0.06, c.a);

String _format(double h, double s, double l, double a) {
  String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
  final alpha = a >= 1 ? '1' : a.toStringAsFixed(3);
  return 'hsla(${h.round()},${pct(s)},${pct(l)},$alpha)';
}

/// Percorre valores e expressões trocando só strings que são cores.
Object? _mapColors(Object? value, _ColorTransform transform) {
  if (value is String) {
    final color = parseCssColor(value);
    return color == null ? value : transform(color);
  }
  if (value is List) return [for (final v in value) _mapColors(v, transform)];
  if (value is Map) {
    return {
      for (final e in value.entries) e.key: _mapColors(e.value, transform),
    };
  }
  return value;
}

/// Cor em HSL (componentes 0–1, matiz em graus).
class HslaColor {
  const HslaColor(this.h, this.s, this.l, this.a);

  final double h;
  final double s;
  final double l;
  final double a;
}

/// Cor CSS (`#rgb`, `#rrggbb(aa)`, `rgb[a]()`, `hsl[a]()`) em HSL; `null` para
/// qualquer outra string (nomes de campos, operadores, fontes).
HslaColor? parseCssColor(String input) {
  final s = input.trim();
  final hex = RegExp(r'^#([0-9a-fA-F]{3,8})$').firstMatch(s);
  if (hex != null) {
    var h = hex.group(1)!;
    if (h.length == 3 || h.length == 4) {
      h = h.split('').map((c) => '$c$c').join();
    }
    if (h.length != 6 && h.length != 8) return null;
    int part(int i) => int.parse(h.substring(i, i + 2), radix: 16);
    return _rgbToHsl(
      part(0) / 255,
      part(2) / 255,
      part(4) / 255,
      h.length == 8 ? part(6) / 255 : 1,
    );
  }

  final fn = RegExp(r'^(rgba?|hsla?)\(([^)]*)\)$').firstMatch(s);
  if (fn == null) return null;
  final parts = fn
      .group(2)!
      .split(RegExp(r'[,\s/]+'))
      .where((p) => p.isNotEmpty)
      .map((p) => double.tryParse(p.replaceAll(RegExp(r'(deg|%)$'), '')))
      .toList();
  if (parts.length < 3 || parts.contains(null)) return null;
  final a = parts.length > 3 ? parts[3]! : 1.0;
  if (fn.group(1)!.startsWith('rgb')) {
    return _rgbToHsl(parts[0]! / 255, parts[1]! / 255, parts[2]! / 255, a);
  }
  return HslaColor(parts[0]! % 360, parts[1]! / 100, parts[2]! / 100, a);
}

HslaColor _rgbToHsl(double r, double g, double b, double a) {
  final mx = math.max(r, math.max(g, b));
  final mn = math.min(r, math.min(g, b));
  final l = (mx + mn) / 2;
  if (mx == mn) return HslaColor(0, 0, l, a);
  final d = mx - mn;
  final s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
  double h;
  if (mx == r) {
    h = (g - b) / d + (g < b ? 6 : 0);
  } else if (mx == g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  return HslaColor(h * 60, s, l, a);
}

/// Luminosidade (0–1) de uma cor CSS; usado nos testes do asset.
double? cssLightness(String color) => parseCssColor(color)?.l;
