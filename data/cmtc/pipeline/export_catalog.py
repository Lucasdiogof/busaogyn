"""Exporta o catálogo oficial (linhas, variantes, pontos) para o app, SÓ para
desenvolvimento local.

Gera, em `app/dev_catalog/` (ignorado pelo Git):
- `cmtc_catalog_payload.g.dart`: o catálogo como string JSON (`busaogyn.catalog` v1);
- `main.dart`: entrypoint de desenvolvimento que liga o catálogo.

O `lib/main.dart` de produção nunca importa nada daqui; por isso nenhum build
de produção contém os dados (ver docs/BUSAOGYN_2_0_FASE_2_IMPLEMENTACAO.md).

Só dados OFICIAIS entram (cadastros e KMZ de pontos). Nada inferido.

    cd data/cmtc && python3 -I pipeline/export_catalog.py
"""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

from cmtc.geo import encode_polyline, length_m, simplify  # noqa: E402
from cmtc.sources import read_lines, read_shapes, read_stop_points, read_stops  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
RAW = os.path.join(ROOT, 'raw')
APP_DEV = os.path.abspath(os.path.join(ROOT, '..', '..', 'app', 'dev_catalog'))
LINES_XLSX = 'Cadastro Geral das Linhas da RMTC _Setembro-2026 01.09.2026.xlsx'
STOPS_XLSX = 'Cadastro Geral dos Pontos de Ônibus da RMTC- Outubro - 2026.xlsx'
POINTS_KMZ = 'PED_S MUNICIPIO.kmz'
SHAPES_KMZ = 'LINHAS RMTC.kmz'

# Tolerância de simplificação dos trajetos distribuídos ao app (Douglas-Peucker,
# em metros). O original fica intacto em raw/ e processed/.
SHAPE_TOLERANCE_M = 3.0


def _sha(path):
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()


def _txt(v):
    if v is None:
        return None
    s = str(v).strip()
    return s or None


def build_catalog():
    lines, _ = read_lines(os.path.join(RAW, LINES_XLSX))
    stops, _ = read_stops(os.path.join(RAW, STOPS_XLSX))
    points = read_stop_points(os.path.join(RAW, POINTS_KMZ))

    by_base = {}
    for l in lines:
        by_base.setdefault(l.code.base, []).append(l)
    line_rows = []
    for base in sorted(by_base, key=lambda b: (not b.isdigit(), b)):
        vs = by_base[base]
        principal = next((v for v in vs if v.characteristic == 'Principal'), vs[0])
        cities = sorted({v.city for v in vs if v.city})
        areas = sorted({v.area for v in vs if v.area})
        line_rows.append([base, principal.name, principal.type, principal.form, areas, cities])

    variant_rows = [
        [l.code.variant_key, l.code.base, l.raw_code, l.name, l.characteristic, l.status,
         l.origin, l.destination, l.city, l.valid_from, l.company_1, l.company_2]
        for l in lines
    ]

    stop_rows = []
    seen = set()
    for s in stops:
        seen.add(s.stop_id)
        stop_rows.append([
            s.stop_id, 'ped', _txt(s.kind), _txt(s.street), _txt(s.reference), _txt(s.district), _txt(s.city),
            None if s.lat is None else round(s.lat, 6), None if s.lon is None else round(s.lon, 6),
            s.lines, None,
        ])
    # Estações (40000+) e PEDs que só existem no KMZ: sem endereço e sem
    # linhas no cadastro; entram para a busca por código e o nome do KMZ.
    for p in points:
        if not p.stop_id or p.stop_id in seen or p.lat is None or p.issues:
            continue
        seen.add(p.stop_id)
        stop_rows.append([
            p.stop_id, 'estacao' if int(p.stop_id) >= 40000 else 'ped_kmz', None, None, None, None, None,
            round(p.lat, 6), round(p.lon, 6), [], p.label,
        ])

    shape_rows = []
    for sh in read_shapes(os.path.join(RAW, SHAPES_KMZ)):
        if sh.code is None or len(sh.coords) < 2:
            continue
        simple = simplify(sh.coords, SHAPE_TOLERANCE_M)
        shape_rows.append([
            sh.shape_id, sh.code.base, sh.code.variant_key, sh.direction, sh.description,
            encode_polyline(simple), round(length_m(sh.coords)), len(sh.coords),
        ])

    return {
        'format': 'busaogyn.catalog',
        'formatVersion': 1,
        'version': {
            'id': 'cmtc-2026-10',
            # Marca para scripts/check-no-official-catalog.sh achar o payload em artefatos.
            'marker': 'busaogyn-cmtc-payload',
            'generatedAt': dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
            'source': 'CMTC — Ofício nº 728/2026 e Parecer nº 226/2026 (resposta LAI)',
            'referenceDates': {'lines': '2026-09-01', 'stops': '2026-10'},
            'licenseStatus': 'pendente',
            'restricted': True,
            'shapeToleranceM': SHAPE_TOLERANCE_M,
            'files': {
                SHAPES_KMZ: _sha(os.path.join(RAW, SHAPES_KMZ)),
                LINES_XLSX: _sha(os.path.join(RAW, LINES_XLSX)),
                STOPS_XLSX: _sha(os.path.join(RAW, STOPS_XLSX)),
                POINTS_KMZ: _sha(os.path.join(RAW, POINTS_KMZ)),
            },
        },
        'lines': {'fields': ['id', 'name', 'type', 'form', 'areas', 'cities'], 'rows': line_rows},
        'variants': {
            'fields': ['id', 'line', 'code', 'name', 'characteristic', 'status', 'origin', 'destination',
                       'city', 'validFrom', 'company1', 'company2'],
            'rows': variant_rows,
        },
        # Trajetos oficiais (KMZ), um por variante + sentido ('i'/'v' do nome).
        'shapes': {
            'fields': ['id', 'line', 'variant', 'direction', 'description', 'polyline', 'lengthM',
                       'sourceVertices'],
            'rows': shape_rows,
        },
        'stops': {
            'fields': ['id', 'kind', 'streetType', 'street', 'reference', 'district', 'city', 'lat', 'lon',
                       'lines', 'label'],
            'rows': stop_rows,
        },
    }


def main():
    catalog = build_catalog()
    payload = json.dumps(catalog, ensure_ascii=False, separators=(',', ':'))
    if "'''" in payload:
        raise SystemExit("payload contém ''' e não cabe numa string raw do Dart")
    os.makedirs(APP_DEV, exist_ok=True)
    with open(os.path.join(APP_DEV, 'cmtc_catalog_payload.g.dart'), 'w', encoding='utf-8') as f:
        f.write('// GERADO por data/cmtc/pipeline/export_catalog.py — NÃO VERSIONAR.\n'
                '// Dados oficiais da CMTC com licença de redistribuição pendente.\n'
                '// ignore_for_file: type=lint\n'
                f"const String cmtcCatalogJson = r'''{payload}''';\n")
    with open(os.path.join(APP_DEV, 'main.dart'), 'w', encoding='utf-8') as f:
        f.write('// GERADO por data/cmtc/pipeline/export_catalog.py — NÃO VERSIONAR.\n'
                '// Entrypoint de DESENVOLVIMENTO com o catálogo oficial da CMTC:\n'
                '//   flutter run -t dev_catalog/main.dart\n'
                "import 'package:busaogyn/src/bootstrap.dart';\n\n"
                "import 'cmtc_catalog_payload.g.dart';\n\n"
                'Future<void> main() => runBusaoGyn(devCatalogJson: cmtcCatalogJson);\n')
    print(json.dumps({
        'saida': APP_DEV,
        'bytes_json': len(payload.encode()),
        'linhas': len(catalog['lines']['rows']),
        'variantes': len(catalog['variants']['rows']),
        'pontos': len(catalog['stops']['rows']),
        'trajetos': len(catalog['shapes']['rows']),
    }, ensure_ascii=False))


if __name__ == '__main__':
    main()
