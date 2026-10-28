"""Pipeline CMTC 2026 — reexecutável, sem dependências fora da biblioteca padrão.

Uso (a partir de data/cmtc):
    python3 -I pipeline/build.py            # tolerância padrão de 25 m
    python3 -I pipeline/build.py --tolerance 40

Lê apenas raw/ (nunca escreve lá). Escreve processed/ (fora do Git) e
reports/ (pequenos, versionáveis). Nada aqui é publicado nem enviado.
"""

from __future__ import annotations

import argparse
import collections
import csv
import gzip
import hashlib
import json
import os
import sqlite3
import statistics
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))

from cmtc.geo import simplify  # noqa: E402
from cmtc.schedules import parse_sheet  # noqa: E402
from cmtc.sequence import Params, assign_direction, build_sequence, street_hint  # noqa: E402
from cmtc.sources import read_lines, read_shapes, read_stop_points, read_stops  # noqa: E402
from cmtc.xlsx import read_workbook  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
RAW = os.path.join(ROOT, 'raw')
OUT = os.path.join(ROOT, 'processed')
REP = os.path.join(ROOT, 'reports')

LINES_XLSX = 'Cadastro Geral das Linhas da RMTC _Setembro-2026 01.09.2026.xlsx'
STOPS_XLSX = 'Cadastro Geral dos Pontos de Ônibus da RMTC- Outubro - 2026.xlsx'
SHAPES_KMZ = 'LINHAS RMTC.kmz'
POINTS_KMZ = 'PED_S MUNICIPIO.kmz'
SCHED_DIR = 'Planilhas Horárias por Terminal da RMTC _ 28-10-2026'


def indicator(name, num, den, method):
    return {
        'indicador': name,
        'numerador': num,
        'denominador': den,
        'percentual': None if not den else round(100 * num / den, 2),
        'metodo': method,
    }


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def write_csv(path, header, rows):
    with open(path, 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--tolerance', type=float, default=Params.tolerance_m)
    args = ap.parse_args()
    params = Params(tolerance_m=args.tolerance)
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(REP, exist_ok=True)
    t0 = time.time()
    issues = []  # (base, identificador, problema)

    # ------------------------------------------------------------ leitura
    lines, lines_meta = read_lines(os.path.join(RAW, LINES_XLSX))
    stops, stops_meta = read_stops(os.path.join(RAW, STOPS_XLSX))
    shapes = read_shapes(os.path.join(RAW, SHAPES_KMZ))
    points = read_stop_points(os.path.join(RAW, POINTS_KMZ))
    sched_files = sorted(
        f for f in os.listdir(os.path.join(RAW, SCHED_DIR))
        if f.endswith('.xlsx') and not f.startswith('~$')
    )
    temp_files = sorted(f for f in os.listdir(os.path.join(RAW, SCHED_DIR)) if f.startswith('~$'))
    sheets = []
    for f in sched_files:
        for s in read_workbook(os.path.join(RAW, SCHED_DIR, f)):
            sheets.append(parse_sheet(s, f))

    by_variant = {l.code.variant_key: l for l in lines}
    line_bases = sorted({l.code.base for l in lines})
    stop_by_id = {s.stop_id: s for s in stops}
    point_by_id = collections.defaultdict(list)
    for p in points:
        if p.stop_id:
            point_by_id[p.stop_id].append(p)

    # ------------------------------------------------------------ linhas
    for l in lines:
        if l.valid_from is None:
            issues.append(('linhas', l.raw_code, 'sem Data de Vigência legível'))
        if l.km_total is not None and l.km_outbound is not None and l.km_inbound is not None \
                and abs(l.km_outbound + l.km_inbound - l.km_total) > 0.01:
            issues.append(('linhas', l.raw_code, 'KM IDA + KM VOLTA != EXTENSÃO TOTAL'))
        if not l.streets_outbound:
            issues.append(('linhas', l.raw_code, 'sem logradouros de ida'))
        if not l.streets_inbound:
            issues.append(('linhas', l.raw_code, 'sem logradouros de volta'))

    # ------------------------------------------------------------ pontos
    for s in stops:
        for i in s.issues:
            issues.append(('pontos', s.stop_id, i))
    cad_ids = set(stop_by_id)
    kmz_ids = set(point_by_id)
    dist_cad_kmz = []
    from cmtc.geo import haversine_m
    for sid in sorted(cad_ids & kmz_ids, key=int):
        s = stop_by_id[sid]
        if s.lat is None:
            continue
        p = point_by_id[sid][0]
        if p.lat is not None:
            dist_cad_kmz.append((sid, haversine_m((s.lon, s.lat), (p.lon, p.lat))))
    far = [(sid, d) for sid, d in dist_cad_kmz if d > 50]
    for sid, d in far:
        issues.append(('pontos', sid, f'cadastro e KMZ divergem {d:.0f} m'))
    for sid, pts in point_by_id.items():
        if len(pts) > 1:
            issues.append(('pontos-kmz', sid, f'{len(pts)} Placemarks com o mesmo código'))

    # coordenadas repetidas entre pontos distintos
    coord_groups = collections.defaultdict(list)
    for s in stops:
        if s.lat is not None:
            coord_groups[(round(s.lat, 6), round(s.lon, 6))].append(s.stop_id)
    same_coord = [ids for ids in coord_groups.values() if len(ids) > 1]
    for ids in same_coord:
        issues.append(('pontos', ','.join(ids), 'mesma coordenada em pontos distintos'))

    # ------------------------------------------------------------ trajetos
    shape_variants = collections.defaultdict(list)
    for sh in shapes:
        for i in sh.issues:
            issues.append(('trajetos', sh.shape_id, i))
        if sh.code:
            shape_variants[sh.code.variant_key].append(sh)
    geom_hash = collections.defaultdict(list)
    for sh in shapes:
        geom_hash[hashlib.md5(json.dumps(sh.coords).encode()).hexdigest()].append(sh.shape_id)
    dup_geom = [ids for ids in geom_hash.values() if len(ids) > 1]
    for ids in dup_geom:
        issues.append(('trajetos', ' | '.join(ids), 'geometria idêntica repetida'))
    name_dups = [n for n, c in collections.Counter(sh.raw_name for sh in shapes).items() if c > 1]

    # variante do KMZ sem variante no cadastro: tenta só a base com '-1'.
    crosswalk = []  # tabela de correspondência de identificadores
    for vk, shs in sorted(shape_variants.items()):
        code = shs[0].code
        if vk in by_variant:
            crosswalk.append(('kmz_trajeto', vk, 'cadastro_linhas', vk, 'alta', 'código idêntico (variante)'))
        elif code.variant is None and f'{code.base}-1' in by_variant:
            crosswalk.append(('kmz_trajeto', vk, 'cadastro_linhas', f'{code.base}-1', 'média', 'KMZ sem variante; cadastro só tem -1'))
        elif code.base in line_bases:
            crosswalk.append(('kmz_trajeto', vk, 'cadastro_linhas', code.base, 'baixa', 'só a base da linha existe no cadastro'))
        else:
            crosswalk.append(('kmz_trajeto', vk, 'cadastro_linhas', None, 'nenhuma', 'base ausente no cadastro'))

    # ------------------------------------------------------------ horários
    visible = [s for s in sheets if not s.hidden]
    departures = []
    for sh in visible:
        for d in sh.departures:
            departures.append((sh, d))
    sheet_bases = collections.Counter()
    for sh in visible:
        code = sh.line_number
        from cmtc.ids import parse_line_code
        pc = parse_line_code(code)
        sheet_bases[pc.base if pc else code] += 1
    for sh in sheets:
        for i in sh.issues:
            issues.append(('horarios', f'{sh.file}:{sh.sheet}', i))
        if sh.hidden:
            issues.append(('horarios', f'{sh.file}:{sh.sheet}', 'aba oculta (rascunho?) excluída do catálogo'))
    dep_variants = collections.Counter(d.variant_code for _, d in departures)
    for raw in dep_variants:
        pc = parse_line_code(raw)
        key = pc.variant_key if pc else None
        if key in by_variant:
            crosswalk.append(('planilha_horaria', raw, 'cadastro_linhas', key, 'alta', 'código idêntico (variante)'))
        elif pc and pc.variant is None and f'{pc.base}-1' in by_variant:
            crosswalk.append(('planilha_horaria', raw, 'cadastro_linhas', f'{pc.base}-1', 'média', 'planilha sem variante; cadastro só tem -1'))
        elif pc and pc.base in line_bases:
            crosswalk.append(('planilha_horaria', raw, 'cadastro_linhas', pc.base, 'baixa', 'só a base existe no cadastro'))
        else:
            crosswalk.append(('planilha_horaria', raw, 'cadastro_linhas', None, 'nenhuma', 'sem correspondência'))
    dup_departures = 0
    for sh in visible:
        c = collections.Counter((d.day_type, d.variant_code, d.time, d.trip_kind) for d in sh.departures)
        dup_departures += sum(v - 1 for v in c.values() if v > 1)
        for k, v in c.items():
            if v > 1:
                issues.append(('horarios', f'{sh.file}:{sh.sheet}', f'{v}x {k[0]} {k[1]} {k[2]} {k[3]}'))
    out_of_order = 0
    for sh in visible:
        for dt in ('weekday', 'saturday', 'sunday_holiday'):
            ds = [d for d in sh.departures if d.day_type == dt]
            out_of_order += sum(1 for a, b in zip(ds, ds[1:]) if b.time < a.time)
    for l in lines:
        crosswalk.append(('cadastro_linhas', l.raw_code, 'api_realtime_routeId', l.code.base, 'alta' if l.code.kind == 'numbered' else 'baixa',
                          'base normalizada como a API (1-3 dígitos -> 3); confirmar códigos especiais'))
    crosswalk.append(('cadastro_pontos', 'ID (PED)', 'api_realtime_stopId', 'ID (PED)', 'alta',
                      'amostra de 7 pontos em 27/10/2026: chegadas reais com linhas contidas na relação do cadastro (reports/api_stop_sample.json)'))

    # ------------------------------------------------------------ sequências (INFERIDAS)
    members = collections.defaultdict(list)
    for s in stops:
        if s.lat is not None:
            for b in s.lines:
                members[b].append((s.stop_id, s.lon, s.lat))
    seqs = {}
    for sh in shapes:
        if sh.code and sh.direction:
            seqs[sh.shape_id] = build_sequence(sh.shape_id, sh.code.variant_key, sh.direction, sh.coords,
                                               members.get(sh.code.base, []), params)
    # sentido por ponto em cada variante com ida e volta
    direction_rows = []
    level_count = collections.Counter()
    for vk, shs in shape_variants.items():
        by_dir = {}
        for sh in shs:
            if sh.direction and sh.direction not in by_dir and sh.shape_id in seqs:
                by_dir[sh.direction] = seqs[sh.shape_id]
        if set(by_dir) != {'i', 'v'}:
            continue
        line = by_variant.get(vk)
        imap = {m.stop_id: m for m in by_dir['i'].sequence}
        vmap = {m.stop_id: m for m in by_dir['v'].sequence}
        for sid in sorted(set(imap) | set(vmap), key=int):
            hint = street_hint(stop_by_id[sid].street, line.streets_outbound, line.streets_inbound) if line else None
            d, why, level = assign_direction(imap.get(sid), vmap.get(sid), hint, params)
            level_count[level] += 1
            direction_rows.append((vk, sid, d or '', level, why))
    dir_of = {(vk, sid): d or None for vk, sid, d, _, _ in direction_rows}

    # Sequência final do trajeto: sai o ponto atribuído ao outro sentido da
    # mesma variante; ponto de sentido ambíguo fica, marcado.
    final = {}
    seq_rows = []
    for sid, r in seqs.items():
        kept = []
        for m in r.sequence:
            d = dir_of.get((r.variant_key, m.stop_id))
            if d is not None and d != r.direction:
                seq_rows.append((r.shape_id, r.variant_key, r.direction, '', m.stop_id, m.along_m, m.distance_m,
                                 m.side, m.passes, m.confidence, '; '.join(m.reasons), 'OUTRO_SENTIDO'))
                continue
            kept.append((m, (r.variant_key, m.stop_id) in dir_of and d is None))
        final[sid] = [m for m, _ in kept]
        for n, (m, dir_ambiguous) in enumerate(kept, 1):
            seq_rows.append((r.shape_id, r.variant_key, r.direction, n, m.stop_id, m.along_m, m.distance_m,
                             m.side, m.passes, m.confidence, '; '.join(m.reasons),
                             'INFERIDO_SENTIDO_AMBIGUO' if dir_ambiguous else 'INFERIDO'))
        for m in r.ambiguous:
            seq_rows.append((r.shape_id, r.variant_key, r.direction, '', m.stop_id, m.along_m, m.distance_m,
                             m.side, m.passes, m.confidence, '; '.join(m.reasons), 'AMBIGUO'))
        for sid2 in r.unmatched:
            seq_rows.append((r.shape_id, r.variant_key, r.direction, '', sid2, '', '', '', 0, 0, 'longe do trajeto', 'SEM_CORRESPONDENCIA'))

    # validação: ordem ao longo do trajeto x ordem dos logradouros oficiais
    def spearman(a, b):
        n = len(a)
        ra = {k: i for i, k in enumerate(sorted(range(n), key=lambda k: a[k]))}
        rb = {k: i for i, k in enumerate(sorted(range(n), key=lambda k: b[k]))}
        return 1 - 6 * sum((ra[i] - rb[i]) ** 2 for i in range(n)) / (n * (n * n - 1))

    from cmtc.sequence import street_key
    rhos = {}
    for sh in shapes:
        r = seqs.get(sh.shape_id)
        line = by_variant.get(sh.code.variant_key) if sh.code else None
        if not r or not line:
            continue
        streets = [street_key(x) for x in (line.streets_outbound if sh.direction == 'i' else line.streets_inbound)]
        a, b = [], []
        for m in final[sh.shape_id]:
            k = street_key(stop_by_id[m.stop_id].street)
            if len(k) < 3:
                continue
            idx = [i for i, x in enumerate(streets) if k in x]
            if len(idx) == 1:
                a.append(m.along_m)
                b.append(idx[0])
        if len(a) >= 6:
            rhos[sh.shape_id] = round(spearman(a, b), 3)

    # ------------------------------------------------------------ indicadores
    principal = [l for l in lines if l.characteristic == 'Principal']
    sched_base_set = set(sheet_bases)
    member_pairs = [(s.stop_id, b) for s in stops if s.lat is not None for b in s.lines]
    in_seq = collections.defaultdict(set)
    for r in seqs.values():
        base = r.variant_key.split('-')[0] if not r.variant_key.startswith('MGP') else r.variant_key
        for m in final[r.shape_id]:
            in_seq[base].add(m.stop_id)
    all_matches = [m for r in seqs.values() for m in r.sequence + r.ambiguous]
    vig_dates = sorted(s.sheet_date for s in visible if s.sheet_date)
    quality = [
        indicator('variantes do cadastro com trajeto no KMZ', sum(1 for l in lines if l.code.variant_key in shape_variants), len(lines),
                  'variant_key (base-variante) do cadastro presente entre as variantes dos nomes de Placemark do KMZ'),
        indicator('linhas (base) do cadastro com trajeto', len({l.code.base for l in lines} & {sh.code.base for sh in shapes if sh.code}), len(line_bases),
                  'base da linha (ex.: 003) presente em algum trajeto'),
        indicator('trajetos com sentido identificável', sum(1 for sh in shapes if sh.direction), len(shapes),
                  'sufixo i/v do código ou IDA/VOLTA no nome do Placemark'),
        indicator('trajetos com sentido pelo sufixo i/v', sum(1 for sh in shapes if sh.direction_source == 'sufixo'), len(shapes), 'sufixo i/v'),
        indicator('variantes do KMZ com ida e volta', sum(1 for shs in shape_variants.values() if {s.direction for s in shs} >= {'i', 'v'}), len(shape_variants),
                  'variante com pelo menos um trajeto i e um v'),
        indicator('variantes do KMZ presentes no cadastro', sum(1 for vk in shape_variants if vk in by_variant), len(shape_variants), 'código idêntico'),
        indicator('pontos do cadastro com coordenada válida', sum(1 for s in stops if s.lat is not None), len(stops),
                  'lat/lon legíveis (DMS ou decimal), hemisférios corretos e dentro do envelope da RMTC'),
        indicator('pontos do cadastro presentes no KMZ de pontos', len(cad_ids & kmz_ids), len(cad_ids), 'ID do cadastro = código numérico do nome do Placemark'),
        indicator('pontos do KMZ presentes no cadastro', len(cad_ids & kmz_ids), len(kmz_ids), 'idem, no sentido inverso'),
        indicator('pontos em ambas as fontes com coordenadas a até 10 m', sum(1 for _, d in dist_cad_kmz if d <= 10), len(dist_cad_kmz),
                  'haversine entre a coordenada do cadastro e a do KMZ'),
        indicator('pontos com ao menos uma linha associada', sum(1 for s in stops if s.lines), len(stops), 'colunas LINHA 01..27 do cadastro de pontos'),
        indicator('linhas principais com planilha horária', sum(1 for l in principal if l.code.base in sched_base_set), len(principal),
                  'base da linha principal do cadastro = número da linha da aba (abas visíveis)'),
        indicator('variantes do cadastro com partidas programadas', sum(1 for l in lines if any(c[3] == l.code.variant_key for c in crosswalk if c[0] == 'planilha_horaria')), len(lines),
                  'variante citada em "Nº da Linha" de alguma partida'),
        indicator('códigos de variante das planilhas presentes no cadastro', sum(1 for c in crosswalk if c[0] == 'planilha_horaria' and c[4] == 'alta'), sum(1 for c in crosswalk if c[0] == 'planilha_horaria'),
                  'código idêntico'),
        indicator('pares oficiais ponto-linha cobertos por sequência inferida', sum(1 for sid, b in member_pairs if sid in in_seq[b]), len(member_pairs),
                  f'ponto a até {params.tolerance_m:.0f} m de algum trajeto da linha com confiança >= {params.min_confidence}'),
        indicator('associações ponto-trajeto com confiança alta (>= 0,9)', sum(1 for m in all_matches if m.confidence >= 0.9), len(all_matches),
                  'score de sequence.py; associações dentro da tolerância'),
        indicator('trajetos cuja ordem inferida acompanha os logradouros oficiais (rho > 0,5)', sum(1 for v in rhos.values() if v > 0.5), len(rhos),
                  'Spearman entre posição ao longo do trajeto e índice do logradouro do ponto na lista oficial do sentido (>= 6 pontos com logradouro único)'),
        indicator('sentido do ponto por variante com nível alta', level_count['alta'], sum(level_count.values()),
                  'ponto perto de só um dos sentidos da variante'),
        indicator('pontos removidos da sequência por pertencerem ao outro sentido', sum(1 for r in seq_rows if r[-1] == 'OUTRO_SENTIDO'), sum(len(r.sequence) for r in seqs.values()),
                  'associação dentro da tolerância cujo ponto foi atribuído ao sentido oposto da mesma variante'),
        indicator('sentido do ponto por variante ambíguo', level_count['ambíguo'], sum(level_count.values()),
                  'ponto perto de ida e volta sem desempate por logradouro nem distância'),
        indicator('abas de horário com data de planilha anterior a 2026', sum(1 for s in visible if s.sheet_date and s.sheet_date < '2026'), len(visible),
                  'campo "Data:" da aba; a CMTC não informou vigência, só a data da planilha'),
        indicator('linhas do cadastro com Data de Vigência anterior a 2026', sum(1 for l in lines if l.valid_from and l.valid_from < '2026'), len(lines),
                  'coluna Data de Vigência (serial Excel)'),
    ]

    # ------------------------------------------------------------ escrita: processed/
    write_csv(os.path.join(OUT, 'lines.csv'),
              ['code_raw', 'base', 'variant', 'name', 'status', 'characteristic', 'city', 'area', 'origin', 'destination',
               'company_1', 'company_2', 'subsystem', 'type', 'form', 'km_outbound', 'km_inbound', 'km_total', 'vehicle_type',
               'valid_from', 'n_streets_outbound', 'n_streets_inbound', 'has_shape', 'has_schedule_sheet', 'source_row'],
              [(l.raw_code, l.code.base, l.code.variant, l.name, l.status, l.characteristic, l.city, l.area, l.origin, l.destination,
                l.company_1, l.company_2, l.subsystem, l.type, l.form, l.km_outbound, l.km_inbound, l.km_total, l.vehicle_type,
                l.valid_from, len(l.streets_outbound), len(l.streets_inbound), l.code.variant_key in shape_variants,
                l.code.base in sched_base_set, l.source_row) for l in lines])
    write_csv(os.path.join(OUT, 'stops.csv'),
              ['stop_id', 'street_type', 'street', 'reference', 'district', 'city', 'direction_label', 'arc', 'lat', 'lon',
               'coord_status', 'status', 'model', 'lines', 'in_kmz', 'source_row'],
              [(s.stop_id, s.kind, s.street, s.reference, s.district, s.city, s.direction_label, s.arc,
                None if s.lat is None else round(s.lat, 7), None if s.lon is None else round(s.lon, 7),
                s.coord_status, s.status, s.model, ' '.join(s.lines), s.stop_id in kmz_ids, s.source_row) for s in stops])
    write_csv(os.path.join(OUT, 'shapes_index.csv'),
              ['shape_id', 'variant_key', 'base', 'direction', 'direction_source', 'folder', 'description', 'points',
               'length_m', 'in_cadastro', 'spearman_vs_streets'],
              [(sh.shape_id, sh.code.variant_key if sh.code else None, sh.code.base if sh.code else None, sh.direction,
                sh.direction_source, ' / '.join(sh.folder[1:]), sh.description, sh.points, round(sh.length_m),
                bool(sh.code and sh.code.variant_key in by_variant), rhos.get(sh.shape_id)) for sh in shapes])
    write_csv(os.path.join(OUT, 'departures.csv'),
              ['file', 'sheet', 'line_number', 'variant_code', 'day_type', 'order', 'time', 'operator', 'trip_kind',
               'sheet_date', 'oso', 'row', 'quality'],
              [(sh.file, sh.sheet, sh.line_number, d.variant_code, d.day_type, d.order, d.time, d.operator, d.trip_kind,
                sh.sheet_date, sh.oso, d.row, 'PROGRAMADO_OFICIAL') for sh, d in departures])
    write_csv(os.path.join(OUT, 'inferred_stop_sequences.csv'),
              ['shape_id', 'variant_key', 'direction', 'seq', 'stop_id', 'along_m', 'distance_m', 'side', 'passes',
               'confidence', 'reasons', 'status'], seq_rows)
    write_csv(os.path.join(OUT, 'inferred_stop_direction.csv'),
              ['variant_key', 'stop_id', 'direction', 'level', 'evidence'], direction_rows)

    # GeoJSON simplificado e catálogo protótipo para medir tamanho
    sizes = {}
    for tol in (0, 3, 8):
        feats = []
        for sh in shapes:
            coords = sh.coords if tol == 0 else simplify(sh.coords, tol)
            feats.append({'type': 'Feature', 'properties': {'id': sh.shape_id, 'v': sh.code.variant_key if sh.code else None, 'd': sh.direction},
                          'geometry': {'type': 'LineString', 'coordinates': [[round(x, 5), round(y, 5)] for x, y in coords]}})
        data = json.dumps({'type': 'FeatureCollection', 'features': feats}, separators=(',', ':')).encode()
        path = os.path.join(OUT, f'shapes_tol{tol}m.geojson')
        with open(path, 'wb') as f:
            f.write(data)
        sizes[f'shapes_geojson_tol{tol}m'] = {'bytes': len(data), 'gzip_bytes': len(gzip.compress(data, 9)),
                                              'vertices': sum(len(f['geometry']['coordinates']) for f in feats)}
    db_path = os.path.join(OUT, 'catalog_prototype.sqlite')
    if os.path.exists(db_path):
        os.remove(db_path)
    db = sqlite3.connect(db_path)
    db.executescript('''
        CREATE TABLE line (base TEXT PRIMARY KEY, name TEXT);
        CREATE TABLE variant (variant_key TEXT PRIMARY KEY, base TEXT, code_raw TEXT, name TEXT, origin TEXT, destination TEXT, characteristic TEXT, valid_from TEXT);
        CREATE TABLE stop (stop_id TEXT PRIMARY KEY, street TEXT, reference TEXT, district TEXT, city TEXT, lat REAL, lon REAL);
        CREATE TABLE stop_line (stop_id TEXT, base TEXT, PRIMARY KEY (stop_id, base)) WITHOUT ROWID;
        CREATE TABLE pattern (pattern_id TEXT PRIMARY KEY, variant_key TEXT, direction TEXT, polyline TEXT);
        CREATE TABLE pattern_stop (pattern_id TEXT, seq INTEGER, stop_id TEXT, along_m REAL, confidence REAL, PRIMARY KEY (pattern_id, seq)) WITHOUT ROWID;
        CREATE TABLE departure (variant_key TEXT, day_type TEXT, time TEXT, trip_kind TEXT);
        CREATE INDEX stop_line_base ON stop_line(base);
        CREATE INDEX departure_variant ON departure(variant_key, day_type);
    ''')
    principal_name = {}
    for l in lines:
        principal_name.setdefault(l.code.base, l.name)
        if l.characteristic == 'Principal':
            principal_name[l.code.base] = l.name
    db.executemany('INSERT INTO line VALUES (?,?)', principal_name.items())
    db.executemany('INSERT INTO variant VALUES (?,?,?,?,?,?,?,?)', [(l.code.variant_key, l.code.base, l.raw_code, l.name, l.origin, l.destination, l.characteristic, l.valid_from) for l in lines])
    db.executemany('INSERT INTO stop VALUES (?,?,?,?,?,?,?)', [(s.stop_id, s.street, s.reference, s.district, s.city, s.lat, s.lon) for s in stops])
    db.executemany('INSERT OR IGNORE INTO stop_line VALUES (?,?)', [(s.stop_id, b) for s in stops for b in s.lines])

    def encode_polyline(coords):  # algoritmo do Google, precisão 1e-5
        out, plat, plon = [], 0, 0
        for lon, lat in coords:
            ilat, ilon = round(lat * 1e5), round(lon * 1e5)
            for v in (ilat - plat, ilon - plon):
                v = ~(v << 1) if v < 0 else v << 1
                while v >= 0x20:
                    out.append(chr((0x20 | (v & 0x1f)) + 63))
                    v >>= 5
                out.append(chr(v + 63))
            plat, plon = ilat, ilon
        return ''.join(out)

    db.executemany('INSERT INTO pattern VALUES (?,?,?,?)', [(sh.shape_id, sh.code.variant_key if sh.code else None, sh.direction, encode_polyline(simplify(sh.coords, 3))) for sh in shapes])
    db.executemany('INSERT INTO pattern_stop VALUES (?,?,?,?,?)', [(r.shape_id, n, m.stop_id, m.along_m, m.confidence) for r in seqs.values() for n, m in enumerate(final[r.shape_id], 1)])
    db.executemany('INSERT INTO departure VALUES (?,?,?,?)', [(parse_line_code(d.variant_code).variant_key if parse_line_code(d.variant_code) else d.variant_code, d.day_type, d.time, d.trip_kind) for _, d in departures])
    db.commit()
    db.execute('VACUUM')
    db.close()
    raw_db = open(db_path, 'rb').read()
    sizes['catalog_sqlite'] = {'bytes': len(raw_db), 'gzip_bytes': len(gzip.compress(raw_db, 9))}
    catalog_json = json.dumps({
        'lines': principal_name,
        'variants': [(l.code.variant_key, l.name, l.origin, l.destination) for l in lines],
        'stops': [(s.stop_id, s.street, s.reference, s.district, s.city, s.lat and round(s.lat, 6), s.lon and round(s.lon, 6), s.lines) for s in stops],
        'patterns': [(sh.shape_id, sh.code.variant_key if sh.code else None, sh.direction, encode_polyline(simplify(sh.coords, 3))) for sh in shapes],
        'pattern_stops': {r.shape_id: [m.stop_id for m in final[r.shape_id]] for r in seqs.values()},
        'departures': [(d.variant_code, d.day_type, d.time) for _, d in departures],
    }, ensure_ascii=False, separators=(',', ':')).encode()
    sizes['catalog_json'] = {'bytes': len(catalog_json), 'gzip_bytes': len(gzip.compress(catalog_json, 9))}
    stops_only = json.dumps([(s.stop_id, s.street, s.district, s.lat and round(s.lat, 6), s.lon and round(s.lon, 6), s.lines) for s in stops],
                            ensure_ascii=False, separators=(',', ':')).encode()
    sizes['stops_json'] = {'bytes': len(stops_only), 'gzip_bytes': len(gzip.compress(stops_only, 9))}

    # ------------------------------------------------------------ escrita: reports/
    inventory = {
        'gerado_em': time.strftime('%Y-%m-%dT%H:%M:%S%z'),
        'arquivos': [
            {'arquivo': LINES_XLSX, 'sha256': sha256(os.path.join(RAW, LINES_XLSX)), 'abas': lines_meta['sheets'],
             'cabecalho_linha': lines_meta['header_row'], 'colunas': lines_meta['headers'], 'registros': len(lines),
             'registros_unicos': len({l.raw_code for l in lines}),
             'por_caracteristica': collections.Counter(l.characteristic for l in lines),
             'bases_distintas': len(line_bases),
             'status': collections.Counter(l.status for l in lines),
             'cidades': collections.Counter(l.city for l in lines),
             'tipos': collections.Counter(l.type for l in lines),
             'formas': collections.Counter(l.form for l in lines),
             'empresa_1': collections.Counter(l.company_1 for l in lines),
             'empresa_2': collections.Counter(l.company_2 for l in lines),
             'vigencia_por_ano': collections.Counter((l.valid_from or 'ausente')[:4] for l in lines),
             'vigencia_min_max': [min(l.valid_from for l in lines if l.valid_from), max(l.valid_from for l in lines if l.valid_from)]},
            {'arquivo': STOPS_XLSX, 'sha256': sha256(os.path.join(RAW, STOPS_XLSX)), 'abas': stops_meta['sheets'],
             'cabecalho_linha': stops_meta['header_row'], 'colunas': stops_meta['headers'], 'registros': len(stops),
             'registros_unicos': len(cad_ids),
             'situacao': collections.Counter(s.status for s in stops),
             'municipios': collections.Counter(s.city for s in stops),
             'coord_status': collections.Counter(s.coord_status for s in stops),
             'sentido_rotulos_distintos': len({s.direction_label for s in stops}),
             'sentido_top': collections.Counter(s.direction_label for s in stops).most_common(12),
             'linhas_por_ponto_mediana': statistics.median(len(s.lines) for s in stops),
             'linhas_por_ponto_max': max(len(s.lines) for s in stops),
             'bases_de_linha_citadas': len({b for s in stops for b in s.lines}),
             'bbox': [min(s.lat for s in stops if s.lat), max(s.lat for s in stops if s.lat), min(s.lon for s in stops if s.lon), max(s.lon for s in stops if s.lon)]},
            {'arquivo': SHAPES_KMZ, 'sha256': sha256(os.path.join(RAW, SHAPES_KMZ)), 'placemarks': len(shapes),
             'pastas': collections.Counter(' / '.join(sh.folder[2:]) for sh in shapes),
             'variantes_distintas': len(shape_variants), 'bases_distintas': len({sh.code.base for sh in shapes if sh.code}),
             'nomes_repetidos': name_dups, 'geometrias_identicas': dup_geom,
             'sentido_fonte': collections.Counter(sh.direction_source for sh in shapes),
             'sentidos_por_variante': collections.Counter(''.join(sorted((s.direction or '-') for s in shs)) for shs in shape_variants.values()),
             'vertices_total': sum(sh.points for sh in shapes),
             'comprimento_km_min_mediana_max': [round(min(sh.length_m for sh in shapes) / 1000, 2), round(statistics.median(sh.length_m for sh in shapes) / 1000, 2), round(max(sh.length_m for sh in shapes) / 1000, 2)],
             'comprimento_km_total': round(sum(sh.length_m for sh in shapes) / 1000, 1),
             'variantes_kmz_fora_do_cadastro': sorted(vk for vk in shape_variants if vk not in by_variant),
             'variantes_cadastro_sem_kmz': sorted(l.code.variant_key for l in lines if l.code.variant_key not in shape_variants)},
            {'arquivo': POINTS_KMZ, 'sha256': sha256(os.path.join(RAW, POINTS_KMZ)), 'placemarks': len(points),
             'pastas': collections.Counter(' / '.join(p.folder[1:]) for p in points),
             'codigos_distintos': len(kmz_ids), 'codigos_repetidos': sorted(k for k, v in point_by_id.items() if len(v) > 1),
             'so_no_kmz': len(kmz_ids - cad_ids), 'so_no_cadastro': len(cad_ids - kmz_ids),
             'so_no_kmz_faixa_40000': sum(1 for k in kmz_ids - cad_ids if int(k) >= 40000),
             'distancia_cadastro_kmz_m': {'n': len(dist_cad_kmz), 'mediana': round(statistics.median(d for _, d in dist_cad_kmz), 2),
                                          'p95': round(sorted(d for _, d in dist_cad_kmz)[int(len(dist_cad_kmz) * .95)], 1),
                                          'acima_50m': len(far)}},
            {'pasta': SCHED_DIR, 'arquivos_xlsx': len(sched_files), 'temporarios_ignorados': temp_files,
             'abas': len(sheets), 'abas_ocultas': [(s.file, s.sheet) for s in sheets if s.hidden],
             'layouts': collections.Counter(s.layout for s in sheets),
             'abas_por_arquivo': collections.Counter(s.file for s in sheets),
             'linhas_distintas': len(sheet_bases), 'partidas': len(departures),
             'partidas_por_dia': collections.Counter(d.day_type for _, d in departures),
             'tipo_viagem': collections.Counter(d.trip_kind for _, d in departures),
             'operadoras': collections.Counter(d.operator for _, d in departures),
             'variantes_citadas': len(dep_variants),
             'partidas_apos_meia_noite': sum(1 for _, d in departures if d.time >= '24:00'),
             'duplicidades_exatas': dup_departures, 'fora_de_ordem': out_of_order,
             'data_planilha_por_ano': collections.Counter((s.sheet_date or 'ausente')[:4] for s in visible),
             'data_planilha_min_max': [vig_dates[0], vig_dates[-1]],
             'oso': collections.Counter(s.oso for s in visible),
             'observacoes_distintas': sorted({n for s in visible for n in s.notes if not n.startswith(('Flávia', 'Gerente'))})},
        ],
        'parametros': {'tolerance_m': params.tolerance_m, 'min_confidence': params.min_confidence},
        'tamanhos': sizes,
        'tempo_s': round(time.time() - t0, 1),
    }
    with open(os.path.join(REP, 'inventory.json'), 'w', encoding='utf-8') as f:
        json.dump(inventory, f, ensure_ascii=False, indent=1, default=str)
    with open(os.path.join(REP, 'quality_indicators.json'), 'w', encoding='utf-8') as f:
        json.dump(quality, f, ensure_ascii=False, indent=1)
    write_csv(os.path.join(REP, 'issues.csv'), ['base', 'identificador', 'problema'], issues)
    write_csv(os.path.join(REP, 'id_crosswalk.csv'),
              ['origem', 'id_origem', 'destino', 'id_destino', 'confianca', 'evidencia'], crosswalk)
    write_csv(os.path.join(REP, 'direction_levels.csv'), ['nivel', 'quantidade'], sorted(level_count.items()))
    print(json.dumps({q['indicador']: f"{q['numerador']}/{q['denominador']} ({q['percentual']}%)" for q in quality}, ensure_ascii=False, indent=1))
    print('tamanhos', json.dumps(sizes))
    print('tempo', round(time.time() - t0, 1), 's')


from cmtc.ids import parse_line_code  # noqa: E402

if __name__ == '__main__':
    main()
