import 'dart:convert';

/// Tema do mapa do BusãoGyn.
enum BusaoMapTheme { light, dark }

/// Gera o estilo cartográfico do BusãoGyn a partir do Liberty do OpenFreeMap.
///
/// Diferente de uma recoloração genérica, cada camada recebe cor, largura,
/// `minzoom` e peso de texto decididos por grupo, para dar hierarquia ao mapa:
///
/// 1. o ônibus acompanhado (desenhado pelo app, fora do estilo);
/// 2. rodovias e avenidas;
/// 3. ruas principais, depois ruas locais, finas e sem halo;
/// 4. nomes relevantes;
/// 5. todo o resto recuado (terreno, prédios, parques, água, limites).
///
/// Vias usam só tons neutros: o âmbar é reservado ao ônibus acompanhado, ao
/// rastro e aos controles. POIs, setas de mão única, escudos de rodovia e
/// prédios em 3D ficam de fora.
///
/// Sources, `glyphs`, `sprite`, filtros e `source-layer` do Liberty são
/// preservados: a atribuição OpenFreeMap/OpenMapTiles/OSM vem do TileJSON da
/// source `openmaptiles` e continua sendo exibida pelo controle nativo.
///
/// A saída é determinística. Roda uma vez, em `tool/build_map_styles.dart`; o
/// resultado é empacotado como asset e o app não processa estilo em runtime.
Map<String, dynamic> buildBusaoStyle(
  Map<String, dynamic> liberty,
  BusaoMapTheme theme, {
  required String sourceUrl,
  void Function(String id)? onUnhandled,
}) {
  final palette = theme == BusaoMapTheme.dark ? _Palette.dark : _Palette.light;
  final layers = <Map<String, dynamic>>[];
  for (final raw in liberty['layers'] as List) {
    final source = Map<String, dynamic>.from(raw as Map);
    final id = source['id'] as String;
    if (_isDropped(id)) continue;
    final layer = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
    final styled = _Restyler(palette).restyle(id, layer);
    if (styled == null) {
      onUnhandled?.call(id);
      layers.add(layer);
    } else if (styled != _dropMarker) {
      layers.add(styled);
    }
  }

  return {
    ...liberty,
    'name': theme == BusaoMapTheme.dark ? 'BusãoGyn Dark' : 'BusãoGyn Light',
    'metadata': {
      ...?(liberty['metadata'] as Map<String, dynamic>?),
      'busaogyn:derivedFrom': sourceUrl,
      'busaogyn:generator': 'tool/build_map_styles.dart',
      'busaogyn:theme': theme.name,
    },
    'layers': layers,
  };
}

/// Camadas que só adicionam ruído ao mapa do BusãoGyn.
bool _isDropped(String id) =>
    id.startsWith('poi') ||
    id.startsWith('building-3d') ||
    id.startsWith('road_one_way_arrow') ||
    id.startsWith('highway-shield') ||
    id.startsWith('road_shield') ||
    id.startsWith('highway-name-path') ||
    id == 'airport' ||
    id == 'road_area_pattern' ||
    id == 'park_outline' ||
    id == 'boundary_disputed' ||
    id.contains('hatching') ||
    id.contains('transit_rail');

const _dropMarker = <String, dynamic>{'drop': true};

/// Cores por tema. Tons neutros; grafite (não preto) no escuro, off-white
/// suave (não branco estourado) no claro.
class _Palette {
  const _Palette({
    required this.background,
    required this.land,
    required this.landSoft,
    required this.park,
    required this.green,
    required this.water,
    required this.building,
    required this.buildingEdge,
    required this.roadLocal,
    required this.roadService,
    required this.roadAvenue,
    required this.roadTrunk,
    required this.roadMotorway,
    required this.casingAvenue,
    required this.casingTrunk,
    required this.casingMotorway,
    required this.rail,
    required this.boundary,
    required this.labelRoad,
    required this.labelRoadMinor,
    required this.labelPlaceMinor,
    required this.labelPlace,
    required this.labelCity,
    required this.labelRegion,
    required this.labelWater,
    required this.halo,
    required this.isDark,
  });

  final String background;
  final String land;
  final String landSoft;
  final String park;
  final String green;
  final String water;
  final String building;
  final String buildingEdge;
  final String roadLocal;
  final String roadService;
  final String roadAvenue;
  final String roadTrunk;
  final String roadMotorway;
  final String casingAvenue;
  final String casingTrunk;
  final String casingMotorway;
  final String rail;
  final String boundary;
  final String labelRoad;
  final String labelRoadMinor;
  final String labelPlaceMinor;
  final String labelPlace;
  final String labelCity;
  final String labelRegion;
  final String labelWater;
  final String halo;
  final bool isDark;

  static const dark = _Palette(
    background: '#141613',
    land: '#161815',
    landSoft: '#181a17',
    park: '#1a1f18',
    green: '#1b2119',
    water: '#0f191c',
    building: '#1c1e1b',
    buildingEdge: '#232622',
    roadLocal: '#30332e',
    roadService: '#262925',
    roadAvenue: '#50554c',
    roadTrunk: '#62675c',
    roadMotorway: '#70756a',
    casingAvenue: '#0f100e',
    casingTrunk: '#0f100e',
    casingMotorway: '#0f100e',
    rail: '#2b2e29',
    boundary: '#454942',
    labelRoad: '#9aa093',
    labelRoadMinor: '#747a6f',
    labelPlaceMinor: '#7c8176',
    labelPlace: '#9ca197',
    labelCity: '#babeb4',
    labelRegion: '#80857a',
    labelWater: '#4f6c76',
    halo: '#141613',
    isDark: true,
  );

  static const light = _Palette(
    background: '#e9e8e2',
    land: '#e7e6e0',
    landSoft: '#e2e1da',
    park: '#cbdabf',
    green: '#c5d5b8',
    water: '#b3ccda',
    building: '#dcdad3',
    buildingEdge: '#cfcdc5',
    roadLocal: '#fafaf7',
    roadService: '#f4f3ef',
    roadAvenue: '#ffffff',
    roadTrunk: '#ffffff',
    roadMotorway: '#fbfbf8',
    casingAvenue: '#b8b5ab',
    casingTrunk: '#a7a499',
    casingMotorway: '#97948a',
    rail: '#bdbbb3',
    boundary: '#b0aea6',
    labelRoad: '#43463f',
    labelRoadMinor: '#6c6f66',
    labelPlaceMinor: '#72756c',
    labelPlace: '#3e413a',
    labelCity: '#34372f',
    labelRegion: '#666961',
    labelWater: '#4c7185',
    halo: '#e9e8e2',
    isDark: false,
  );
}

/// Largura de linha por zoom; `[zoom, px]`.
typedef _Stops = List<List<num>>;

class _Road {
  const _Road({
    required this.color,
    required this.widths,
    this.casing,
    this.minzoom,
  });

  final String color;
  final _Stops widths;

  /// `null`: sem contorno (ruas locais ficam finas e sem halo).
  final String? casing;
  final double? minzoom;
}

class _Restyler {
  _Restyler(this.p);

  final _Palette p;

  _Road? _road(String group) {
    switch (group) {
      case 'motorway':
      case 'motorway_link':
        return _Road(
          color: p.roadMotorway,
          casing: p.casingMotorway,
          widths: group == 'motorway'
              ? const [
                  [5, 0],
                  [7, 0.8],
                  [10, 1.6],
                  [14, 3.4],
                  [18, 10],
                  [20, 17],
                ]
              : const [
                  [12, 0],
                  [14, 1.6],
                  [18, 6],
                  [20, 10],
                ],
        );
      case 'trunk_primary':
        return _Road(
          color: p.roadTrunk,
          casing: p.casingTrunk,
          widths: const [
            [5, 0],
            [7, 0.7],
            [10, 1.4],
            [14, 3.0],
            [18, 9],
            [20, 15],
          ],
        );
      case 'secondary_tertiary':
        return _Road(
          color: p.roadAvenue,
          casing: p.casingAvenue,
          widths: const [
            [7, 0],
            [9, 0.5],
            [12, 1.0],
            [14, 2.2],
            [18, 7],
            [20, 12],
          ],
        );
      case 'link':
        return _Road(
          color: p.roadTrunk,
          casing: p.casingTrunk,
          widths: const [
            [13, 0],
            [14, 1.2],
            [18, 5],
            [20, 9],
          ],
        );
      case 'minor':
      case 'street':
        return _Road(
          color: p.roadLocal,
          minzoom: 14,
          widths: const [
            [14, 0.6],
            [16, 1.6],
            [18, 4.2],
            [20, 9],
          ],
        );
      case 'service_track':
        return _Road(
          color: p.roadService,
          minzoom: 15.5,
          widths: const [
            [15.5, 0.5],
            [18, 2.0],
            [20, 4.5],
          ],
        );
      case 'path_pedestrian':
        return _Road(
          color: p.roadService,
          minzoom: 16,
          widths: const [
            [16, 0.5],
            [18, 1.4],
            [20, 2.6],
          ],
        );
    }
    return null;
  }

  /// Devolve a camada reestilizada, [_dropMarker] para removê-la ou `null`
  /// quando o id não é conhecido (a camada original é mantida).
  Map<String, dynamic>? restyle(String id, Map<String, dynamic> layer) {
    final roadMatch = RegExp(r'^(tunnel|road|bridge)_(.+)$').firstMatch(id);
    if (roadMatch != null && layer['type'] == 'line') {
      return _restyleRoad(roadMatch.group(1)!, roadMatch.group(2)!, layer);
    }
    if (id.startsWith('boundary_')) {
      layer['paint'] = {
        'line-color': p.boundary,
        'line-opacity': 0.55,
        'line-width': layer['paint']['line-width'],
        if (layer['paint']['line-dasharray'] != null)
          'line-dasharray': layer['paint']['line-dasharray'],
      };
      return layer;
    }
    switch (id) {
      case 'background':
        layer['paint'] = {'background-color': p.background};
      case 'natural_earth':
        layer['paint'] = {
          'raster-opacity': p.isDark ? 0.12 : 0.22,
          'raster-saturation': -1,
          'raster-brightness-max': p.isDark ? 0.3 : 1,
        };
      case 'park':
        layer['paint'] = {'fill-color': p.park, 'fill-opacity': 0.9};
      case 'landuse_residential':
        layer['paint'] = {'fill-color': p.land};
      case 'landcover_wood':
      case 'landcover_grass':
        layer['paint'] = {
          'fill-antialias': false,
          'fill-color': p.green,
          'fill-opacity': 0.55,
        };
      case 'landcover_ice':
      case 'landcover_sand':
      case 'landcover_wetland':
      case 'landuse_pitch':
      case 'landuse_track':
      case 'landuse_cemetery':
      case 'landuse_hospital':
      case 'landuse_school':
      case 'aeroway_fill':
        layer['paint'] = {'fill-color': p.landSoft};
      case 'aeroway_runway':
      case 'aeroway_taxiway':
        layer['paint'] = {
          'line-color': p.roadLocal,
          'line-width': layer['paint']['line-width'],
        };
      case 'waterway_tunnel':
      case 'waterway_river':
      case 'waterway_other':
        layer['paint'] = {
          'line-color': p.water,
          'line-width': layer['paint']['line-width'],
        };
      case 'water':
        layer['paint'] = {'fill-color': p.water};
      case 'building':
        // Sem a versão 3D, o prédio plano passa a valer em todos os zooms
        // altos, mas só aparece de perto e tom sobre tom.
        layer
          ..remove('maxzoom')
          ..['minzoom'] = 15;
        layer['paint'] = {
          'fill-color': p.building,
          'fill-outline-color': p.buildingEdge,
          'fill-opacity': const [
            'interpolate',
            ['linear'],
            ['zoom'],
            15,
            0,
            16,
            1,
          ],
        };
      case 'waterway_line_label':
        layer['minzoom'] = 12;
        _label(layer, color: p.labelWater, size: 11, halo: 1.2, opacity: 0.9);
      case 'water_name_point_label':
      case 'water_name_line_label':
        _label(
          layer,
          color: p.labelWater,
          scale: 0.85,
          halo: 1.2,
          opacity: 0.9,
        );
      case 'highway-name-major':
        layer['minzoom'] = 13;
        _label(
          layer,
          color: p.labelRoad,
          size: const [
            'interpolate',
            ['linear'],
            ['zoom'],
            13,
            9.5,
            16,
            11.5,
          ],
          halo: 1,
          opacity: 0.92,
        );
      case 'highway-name-minor':
        layer['minzoom'] = 16;
        _label(
          layer,
          color: p.labelRoadMinor,
          size: const [
            'interpolate',
            ['linear'],
            ['zoom'],
            16,
            9.5,
            18,
            11,
          ],
          halo: 0.9,
          opacity: 0.85,
        );
      case 'label_other':
        layer['minzoom'] = 12.5;
        _label(
          layer,
          color: p.labelPlaceMinor,
          size: const [
            'interpolate',
            ['linear'],
            ['zoom'],
            12.5,
            8.5,
            15,
            10,
          ],
          halo: 1,
          opacity: 0.85,
        );
      case 'label_village':
      case 'label_town':
        _noIcon(layer);
        _label(layer, color: p.labelPlace, scale: 0.88, halo: 1.1);
      case 'label_city':
      case 'label_city_capital':
        _noIcon(layer);
        _label(layer, color: p.labelCity, scale: 0.9, halo: 1.2);
      case 'label_state':
      case 'label_country_3':
      case 'label_country_2':
      case 'label_country_1':
        _label(
          layer,
          color: p.labelRegion,
          scale: 0.88,
          halo: 1.2,
          opacity: 0.85,
        );
      default:
        return null;
    }
    return layer;
  }

  Map<String, dynamic> _restyleRoad(
    String kind,
    String name,
    Map<String, dynamic> layer,
  ) {
    final isCasing = name.endsWith('_casing');
    final group = isCasing ? name.substring(0, name.length - 7) : name;
    final road = _road(group);
    if (road == null) {
      if (group == 'major_rail') {
        layer['minzoom'] = 12;
        layer['paint'] = {
          'line-color': p.rail,
          'line-opacity': 0.8,
          'line-width': layer['paint']['line-width'],
        };
        return layer;
      }
      return _dropMarker;
    }
    if (isCasing && road.casing == null) return _dropMarker;

    final color = isCasing ? road.casing! : road.color;
    // Contorno fino e discreto: separa cruzamentos sem virar halo.
    final widths = isCasing
        ? [
            for (final s in road.widths)
              [s[0], s[1] == 0 ? 0 : s[1] + (p.isDark ? 0.8 : 1.4)],
          ]
        : road.widths;
    final old = layer['paint'] as Map;
    final hasDash = old['line-dasharray'] != null;
    if (road.minzoom != null) {
      layer['minzoom'] = road.minzoom;
    }
    layer['paint'] = {
      'line-color': color,
      'line-width': _width(widths),
      if (kind == 'tunnel')
        'line-opacity': 0.55
      else if (group == 'minor' || group == 'street')
        'line-opacity': const [
          'interpolate',
          ['linear'],
          ['zoom'],
          14,
          0.6,
          15.5,
          1,
        ],
      if (hasDash) 'line-dasharray': old['line-dasharray'],
    };
    return layer;
  }

  static List<Object> _width(_Stops stops) => [
    'interpolate',
    ['exponential', 1.2],
    ['zoom'],
    for (final s in stops) ...[s[0], s[1]],
  ];

  void _noIcon(Map<String, dynamic> layer) {
    final layout = layer['layout'] as Map<String, dynamic>;
    for (final key in const [
      'icon-image',
      'icon-size',
      'icon-allow-overlap',
      'icon-optional',
    ]) {
      layout.remove(key);
    }
    layout['text-anchor'] = 'center';
    layout.remove('text-offset');
  }

  /// [size] fixa o tamanho (número ou expressão); [scale] reduz o original.
  void _label(
    Map<String, dynamic> layer, {
    required String color,
    Object? size,
    double? scale,
    required double halo,
    double? opacity,
  }) {
    final layout = layer['layout'] as Map<String, dynamic>;
    if (size != null) {
      layout['text-size'] = size;
    } else if (scale != null && layout['text-size'] != null) {
      layout['text-size'] = _scaleSize(layout['text-size'], scale);
    }
    layer['paint'] = {
      'text-color': color,
      'text-opacity': ?opacity,
      'text-halo-color': p.halo,
      'text-halo-width': halo,
      'text-halo-blur': 0.5,
    };
  }
}

/// Multiplica os tamanhos de uma expressão `text-size` (`interpolate`/`step`).
Object? _scaleSize(Object? value, double factor) {
  if (value is num) return double.parse((value * factor).toStringAsFixed(2));
  if (value is! List || value.isEmpty) return value;
  final op = value.first;
  if (op == 'interpolate') {
    return [
      for (var i = 0; i < value.length; i++)
        if (i >= 4 && i.isEven) _scaleSize(value[i], factor) else value[i],
    ];
  }
  if (op == 'step') {
    return [
      for (var i = 0; i < value.length; i++)
        if (i == 2 || (i > 2 && i.isOdd))
          _scaleSize(value[i], factor)
        else
          value[i],
    ];
  }
  return value;
}
