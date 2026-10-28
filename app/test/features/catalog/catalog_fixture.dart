import 'dart:convert';

import 'package:busaogyn/src/features/catalog/data/catalog_codec.dart';
import 'package:busaogyn/src/features/catalog/domain/transit_catalog.dart';

/// Catálogo SINTÉTICO (ADR-0002, item 7): nomes e códigos fictícios, no
/// mesmo formato que `export_catalog.py` gera a partir da base da CMTC.
/// Polyline do Google (precisão 1e-5) a partir de (lat, lon), para montar
/// trajetos sintéticos no mesmo formato do exportador.
String encodePolyline(List<(double, double)> points) {
  final out = StringBuffer();
  var pLat = 0;
  var pLon = 0;
  void put(int v) {
    var x = v < 0 ? ~(v << 1) : v << 1;
    while (x >= 0x20) {
      out.writeCharCode((0x20 | (x & 0x1f)) + 63);
      x >>= 5;
    }
    out.writeCharCode(x + 63);
  }

  for (final (lat, lon) in points) {
    final iLat = (lat * 1e5).round();
    final iLon = (lon * 1e5).round();
    put(iLat - pLat);
    put(iLon - pLon);
    pLat = iLat;
    pLon = iLon;
  }
  return out.toString();
}

/// Linha 001: ida para leste ao longo de -16.68 (passa pelo ponto 00294),
/// volta pelo mesmo corredor em sentido contrário; 001-2 só ida, ao norte.
List<(double, double)> fixtureOutbound() => [
  for (var i = 0; i <= 10; i++) (-16.68, -49.30 + i * 0.005),
];

List<List<Object?>> fixtureShapes() => [
  [
    '001-1i - T. FICTICIO NORTE / CENTRO IMAGINARIO - IDA',
    '001',
    '001-1',
    'i',
    'IDA',
    encodePolyline(fixtureOutbound()),
    5330,
    11,
  ],
  [
    '001-1v - T. FICTICIO NORTE / CENTRO IMAGINARIO - VOLTA',
    '001',
    '001-1',
    'v',
    'VOLTA',
    encodePolyline(fixtureOutbound().reversed.toList()),
    5330,
    11,
  ],
  [
    '001-2i - T. FICTICIO NORTE / HOSPITAL TESTE - IDA',
    '001',
    '001-2',
    'i',
    'IDA',
    encodePolyline([(-16.66, -49.30), (-16.66, -49.26)]),
    4270,
    2,
  ],
  [
    '042-1i - BAIRRO EXEMPLO / T. FICTICIO SUL - IDA',
    '042',
    '042-1',
    'i',
    'IDA',
    encodePolyline([(-16.68, -49.26), (-16.8, -49.24)]),
    13500,
    2,
  ],
  [
    '999-21v - SO NO KMZ - VOLTA',
    '042',
    '042-21',
    'v',
    'VOLTA',
    encodePolyline([(-16.7, -49.25), (-16.75, -49.25)]),
    5500,
    2,
  ],
];

Map<String, Object?> fixtureCatalogMap({List<List<Object?>>? extraStops}) => {
  'format': 'busaogyn.catalog',
  'formatVersion': 1,
  'version': {
    'id': 'sintetico-1',
    'generatedAt': '2026-10-27T12:00:00+00:00',
    'source': 'fixture de teste',
    'referenceDates': {'lines': '2026-09-01', 'stops': '2026-10'},
    'licenseStatus': 'pendente',
    'restricted': true,
    'shapeToleranceM': 3.0,
  },
  'lines': {
    'fields': ['id', 'name', 'type', 'form', 'areas', 'cities'],
    'rows': [
      [
        '001',
        'T. Fictício Norte / Centro Imaginário',
        'Eixo',
        'Radial',
        ['Sul'],
        ['Goiânia'],
      ],
      [
        '042',
        'Bairro Exemplo / T. Fictício Sul',
        'Alimentadora',
        'Circular',
        ['Sul'],
        ['Aparecida de Goiânia'],
      ],
      ['NS9', 'BRT Teste / Praça Simulada', 'Eixo', null, [], []],
    ],
  },
  'variants': {
    'fields': [
      'id',
      'line',
      'code',
      'name',
      'characteristic',
      'status',
      'origin',
      'destination',
      'city',
      'validFrom',
    ],
    'rows': [
      [
        '001-1',
        '001',
        '001-1',
        'T. Fictício Norte / Centro Imaginário',
        'Principal',
        'OPERAÇÃO',
        'T. Fictício Norte',
        'Centro Imaginário',
        'Goiânia',
        '2024-03-01',
      ],
      [
        '001-2',
        '001',
        '001-2',
        'T. Fictício Norte / Hospital Teste',
        'Sublinha',
        'OPERAÇÃO',
        'T. Fictício Norte',
        'Hospital Teste',
        'Goiânia',
        null,
      ],
      [
        '042-1',
        '042',
        '042-1',
        'Bairro Exemplo / T. Fictício Sul',
        'Principal',
        'OPERAÇÃO',
        'Bairro Exemplo',
        'T. Fictício Sul',
        'Aparecida de Goiânia',
        '2025-01-10',
      ],
      [
        'NS9-1',
        'NS9',
        'NS9-1',
        'BRT Teste / Praça Simulada',
        'Principal',
        'OPERAÇÃO',
        'BRT Teste',
        'Praça Simulada',
        null,
        null,
      ],
      [null, '001', 'x', 'linha malformada'],
    ],
  },
  'shapes': {
    'fields': [
      'id',
      'line',
      'variant',
      'direction',
      'description',
      'polyline',
      'lengthM',
      'sourceVertices',
    ],
    'rows': fixtureShapes(),
  },
  'stops': {
    'fields': [
      'id',
      'kind',
      'streetType',
      'street',
      'reference',
      'district',
      'city',
      'lat',
      'lon',
      'lines',
      'label',
    ],
    'rows': [
      [
        '00294',
        'ped',
        'RUA',
        'FICTÍCIA',
        'EM FRENTE AO MERCADO TESTE',
        'SETOR ÁGUA CLARA',
        'GOIÂNIA',
        -16.68,
        -49.26,
        [1, '042'],
        null,
      ],
      [
        '1201',
        'ped',
        'AVENIDA',
        'EXEMPLO',
        'ESQ. C- RUA SIMULADA',
        'JARDIM SIMULADO',
        'APARECIDA DE GOIÂNIA',
        -16.8,
        -49.24,
        ['042', 'NS9'],
        null,
      ],
      [
        '1202',
        'ped',
        'AVENIDA',
        'EXEMPLO',
        null,
        'VILA TESTE',
        'TRINDADE',
        -16.65,
        -49.49,
        ['001'],
        null,
      ],
      [
        '1203',
        'ped',
        'PRAÇA',
        'CÍVICA FICTÍCIA',
        null,
        'CENTRO',
        'GOIÂNIA',
        null,
        null,
        [],
        null,
      ],
      [
        '40999',
        'estacao',
        null,
        null,
        null,
        null,
        null,
        -16.66,
        -49.21,
        [],
        'ESTAÇÃO TESTE (PLATAFORMA A)',
      ],
      [
        'abc',
        'ped',
        'RUA',
        'CÓDIGO INVÁLIDO',
        null,
        null,
        null,
        null,
        null,
        [],
        null,
      ],
      ...?extraStops,
    ],
  },
};

String fixtureCatalogJson() => jsonEncode(fixtureCatalogMap());

TransitCatalog fixtureCatalog() => decodeCatalog(fixtureCatalogJson());
