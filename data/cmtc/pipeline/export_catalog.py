"""Exporta o catálogo oficial (linhas, variantes, pontos) para o app, SÓ para
desenvolvimento local.

Gera, em `app/dev_catalog/` (ignorado pelo Git):
- `cmtc_catalog_payload.g.dart`: o catálogo como string JSON (`busaogyn.catalog` v1);
- `main.dart`: entrypoint de desenvolvimento que liga o catálogo.

O `lib/main.dart` de produção nunca importa nada daqui; por isso nenhum build
de produção contém os dados (ver docs/BUSAOGYN_2_0_FASE_2_IMPLEMENTACAO.md).

Dados oficiais (cadastros, KMZ, planilhas OSO) e, separada e rotulada, a
sequência ESTIMADA de paradas (ADR-0005: só em desenvolvimento). As notas das
planilhas não entram (trazem nome de pessoa); operadoras também não.

    cd data/cmtc && python3 -I pipeline/export_catalog.py
"""

from __future__ import annotations

import collections
import datetime as dt
import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

from cmtc.geo import encode_polyline, length_m, simplify  # noqa: E402
from cmtc.schedules import parse_sheet  # noqa: E402
from cmtc.sequence import Params  # noqa: E402
from cmtc.sources import read_lines, read_shapes, read_stop_points, read_stops  # noqa: E402
from cmtc.stop_sequences import (MAX_AMBIGUOUS_SHARE, METHOD, MIN_ENTRIES, MIN_HIGH_SHARE,  # noqa: E402
                                 MIN_STREET_RHO, sequence_shapes)
from cmtc.timetables import build_timetables, delivered_date  # noqa: E402
from cmtc.xlsx import read_workbook  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
RAW = os.path.join(ROOT, 'raw')
APP_DEV = os.path.abspath(os.path.join(ROOT, '..', '..', 'app', 'dev_catalog'))
LINES_XLSX = 'Cadastro Geral das Linhas da RMTC _Setembro-2026 01.09.2026.xlsx'
STOPS_XLSX = 'Cadastro Geral dos Pontos de Ônibus da RMTC- Outubro - 2026.xlsx'
POINTS_KMZ = 'PED_S MUNICIPIO.kmz'
SHAPES_KMZ = 'LINHAS RMTC.kmz'
SCHEDULES_DIR = 'Planilhas Horárias por Terminal da RMTC _ 28-10-2026'

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

    shapes = read_shapes(os.path.join(RAW, SHAPES_KMZ))
    shape_rows = []
    for sh in shapes:
        if sh.code is None or len(sh.coords) < 2:
            continue
        simple = simplify(sh.coords, SHAPE_TOLERANCE_M)
        shape_rows.append([
            sh.shape_id, sh.code.base, sh.code.variant_key, sh.direction, sh.description,
            encode_polyline(simple), round(length_m(sh.coords)), len(sh.coords),
        ])

    # Horários programados (planilhas OSO): partidas agrupadas por aba, dia,
    # código da planilha e tipo de viagem; minutos desde o início do dia de
    # operação (>= 1440 = depois da meia-noite). Duplicidades ficam (repetidas).
    folder = os.path.join(RAW, SCHEDULES_DIR)
    sheets = []
    for name in sorted(os.listdir(folder)):
        if name.endswith('.xlsx') and not name.startswith('~$'):
            sheets += [parse_sheet(s, name) for s in read_workbook(os.path.join(folder, name))]
    delivered = delivered_date(SCHEDULES_DIR)
    timetables = build_timetables(sheets, {l.code.variant_key for l in lines}, delivered)
    timetable_rows, trip_rows = [], []
    for tt in timetables:
        if not tt.line:
            continue
        timetable_rows.append([tt.id, tt.line, tt.source, tt.line_name, tt.sheet_date, tt.oso, tt.validity,
                               len(tt.issues)])
        groups = collections.defaultdict(list)
        for t in tt.trips:
            groups[(t.day_type, t.variant_raw, t.variant_key, t.kind)].append(t.minutes)
        for (day, raw, key, kind), minutes in groups.items():
            trip_rows.append([tt.id, day, raw, key, kind, minutes])

    # Sequência ESTIMADA (não oficial) por trajeto.
    members = collections.defaultdict(list)
    for s in stops:
        if s.lat is not None:
            for b in s.lines:
                members[b].append((s.stop_id, s.lon, s.lat))
    params = Params()
    sequences = sequence_shapes(
        shapes, members, {l.code.variant_key: (l.streets_outbound, l.streets_inbound) for l in lines},
        {s.stop_id: s.street for s in stops}, params)
    level_code = {'high': 'h', 'medium': 'm'}
    sequence_rows = [
        [r.shape_id, r.status, r.circular,
         ';'.join(f'{e.stop_id},{round(e.along_m)},{level_code[e.level]}' for e in r.entries),
         sorted({sid for sid, _ in r.ambiguous}, key=int)]
        for r in sequences
    ]

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
            'timetablesDelivered': delivered,
            'sequenceMethod': {
                'id': METHOD, 'official': False, 'toleranceM': params.tolerance_m,
                'minConfidence': params.min_confidence, 'minEntries': MIN_ENTRIES,
                'minHighShare': MIN_HIGH_SHARE, 'maxAmbiguousShare': MAX_AMBIGUOUS_SHARE,
                'minStreetRho': MIN_STREET_RHO,
            },
            'files': {
                SHAPES_KMZ: _sha(os.path.join(RAW, SHAPES_KMZ)),
                SCHEDULES_DIR: hashlib.sha256(''.join(
                    _sha(os.path.join(folder, n)) for n in sorted(os.listdir(folder))
                    if n.endswith('.xlsx') and not n.startswith('~$')).encode()).hexdigest(),
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
        # Quadros de horário (uma aba OSO cada). validity: confirmed | recent |
        # old | insufficient (ver cmtc/timetables.py). Sem sentido nem local de
        # partida: a planilha não os informa.
        'timetables': {
            'fields': ['id', 'line', 'source', 'lineName', 'sheetDate', 'oso', 'validity', 'issues'],
            'rows': timetable_rows,
        },
        'trips': {
            'fields': ['timetable', 'day', 'code', 'variant', 'kind', 'minutes'],
            'rows': trip_rows,
        },
        # ESTIMATIVA por geometria (não oficial). entries: 'ponto,metros,nível;…'
        # na ordem do trajeto (nível h = alto, m = intermediário).
        'sequences': {
            'fields': ['shape', 'status', 'circular', 'entries', 'ambiguous'],
            'rows': sequence_rows,
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
        'quadros': len(catalog['timetables']['rows']),
        'partidas': sum(len(r[-1]) for r in catalog['trips']['rows']),
        'sequencias': collections.Counter(r[1] for r in catalog['sequences']['rows']),
        'bytes_por_tabela': {k: len(json.dumps(v, ensure_ascii=False, separators=(',', ':')).encode())
                             for k, v in catalog.items() if isinstance(v, dict) and 'rows' in v},
    }, ensure_ascii=False))


if __name__ == '__main__':
    main()
