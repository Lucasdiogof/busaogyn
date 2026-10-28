"""Diagnóstico de cobertura do planejador: por que cada trajeto, linha e ponto
fica fora. Lê os dados locais (raw/), não consulta rede; grava em reports/
(fora do Git) e imprime o resumo.

    cd data/cmtc && python3 -I pipeline/coverage_report.py
"""

from __future__ import annotations

import collections
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

from cmtc.sequence import Params  # noqa: E402
from cmtc.sources import read_lines, read_shapes, read_stop_points, read_stops  # noqa: E402
from cmtc.stop_sequences import sequence_shapes  # noqa: E402
from cmtc.stations import corridor_lines, find_terminals, read_stations  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
RAW = os.path.join(ROOT, 'raw')


def cause(shape, seq, variant_keys, members, corridor):
    """Causa principal de um trajeto ficar fora (ou 'ok')."""
    if shape.code is None:
        return 'variante não identificada (nome do Placemark)'
    if shape.direction is None:
        return 'sentido ausente no trajeto'
    if seq is None:
        return 'geometria inconsistente'
    if seq.status in ('estimated', 'ordered'):
        return 'ok'
    if not members.get(shape.code.base):
        if shape.code.base in corridor:
            return 'linha de corredor: paradas são estações sem cadastro'
        return 'falta de ligação ponto-linha no cadastro'
    if seq.status == 'none':
        return 'nenhum ponto da linha perto deste trajeto'
    reason = seq.status_reason
    if 'só ' in reason:
        return 'poucos pontos associados'
    if 'confiança alta' in reason:
        return 'sentido ambíguo (ida e volta próximas)'
    if 'ambíguos' in reason:
        return 'muitos pontos ambíguos'
    if 'logradouros' in reason:
        return 'ordem contradiz logradouros oficiais'
    return 'qualidade insuficiente'


def main(phase6: bool = True):
    lines, _ = read_lines(os.path.join(RAW, 'Cadastro Geral das Linhas da RMTC _Setembro-2026 01.09.2026.xlsx'))
    stops, _ = read_stops(os.path.join(RAW, 'Cadastro Geral dos Pontos de Ônibus da RMTC- Outubro - 2026.xlsx'))
    shapes = read_shapes(os.path.join(RAW, 'LINHAS RMTC.kmz'))
    stations = read_stations(read_stop_points(os.path.join(RAW, 'PED_S MUNICIPIO.kmz')))
    corridor = corridor_lines(lines, os.path.join(RAW, 'Planilhas Horárias por Terminal da RMTC _ 28-10-2026'))
    names = {l.code.variant_key: l.name for l in lines}
    terminals = find_terminals(shapes, names)
    members = collections.defaultdict(list)
    for s in stops:
        if s.lat is not None:
            for b in s.lines:
                members[b].append((s.stop_id, s.lon, s.lat))
    seqs = {r.shape_id: r for r in sequence_shapes(
        shapes, members, {l.code.variant_key: (l.streets_outbound, l.streets_inbound) for l in lines},
        {s.stop_id: s.street for s in stops}, Params(),
        stations=stations if phase6 else None, corridor=corridor,
        terminals=terminals if phase6 else None, variant_names=names, recover_by_streets=phase6)}
    variant_keys = {l.code.variant_key for l in lines}
    rows = []
    for sh in shapes:
        seq = seqs.get(sh.shape_id)
        rows.append({'shape': sh.shape_id, 'line': sh.code.base if sh.code else None,
                     'status': seq.status if seq else None, 'evidence': seq.evidence if seq else None,
                     'cause': cause(sh, seq, variant_keys, members, corridor),
                     'reason': seq.status_reason if seq else None})
    by_cause = collections.Counter(r['cause'] for r in rows)
    usable_lines = {r['line'] for r in rows if r['cause'] == 'ok'}
    all_lines = {l.code.base for l in lines}
    line_cause = {}
    for base in sorted(all_lines - usable_lines):
        cs = collections.Counter(r['cause'] for r in rows if r['line'] == base)
        line_cause[base] = cs.most_common(1)[0][0] if cs else 'ausência de trajeto no KMZ'
    usable = ('estimated', 'ordered')
    in_graph = {e.stop_id for r in seqs.values() if r.status in usable for e in r.entries}
    stop_cause = collections.Counter()
    for s in stops:
        if s.stop_id in in_graph:
            stop_cause['no planejador'] += 1
        elif s.lat is None:
            stop_cause['sem coordenada'] += 1
        elif not s.lines:
            stop_cause['sem linha associada no cadastro'] += 1
        elif not any(r.status in usable and r.line == b for b in s.lines for r in seqs.values()):
            stop_cause['nenhuma linha do ponto tem trajeto utilizável'] += 1
        else:
            stop_cause['fora da ordem (ambíguo, sentido oposto ou longe do trajeto)'] += 1
    out = {
        'trajetos': len(shapes),
        'trajetos_por_causa': dict(by_cause),
        'trajetos_por_evidencia': dict(collections.Counter(r['evidence'] for r in rows if r['cause'] == 'ok')),
        'linhas': len(all_lines), 'linhas_utilizaveis': len(usable_lines),
        'linhas_fora_por_causa': dict(collections.Counter(line_cause.values())),
        'pontos_cadastro': len(stops), 'pontos_por_situacao': dict(stop_cause),
        'estacoes_no_grafo': len({sid for sid in in_graph if sid.isdigit() and int(sid) >= 40000}),
        'terminais_no_grafo': len({sid for sid in in_graph if sid.startswith('T-')}),
        'terminais_identificados': len(terminals),
        'trajetos_por_status': dict(collections.Counter(r.status for r in seqs.values())),
        'linhas_de_corredor': {b: (c.corridor, c.stops_at_stations, c.evidence) for b, c in sorted(corridor.items())},
    }
    os.makedirs(os.path.join(ROOT, 'reports'), exist_ok=True)
    name = 'coverage_diagnosis.json' if phase6 else 'coverage_diagnosis_baseline.json'
    with open(os.path.join(ROOT, 'reports', name), 'w', encoding='utf-8') as f:
        json.dump({**out, 'por_trajeto': rows, 'linhas_fora': line_cause}, f, ensure_ascii=False, indent=1)
    print(json.dumps(out, ensure_ascii=False, indent=1))


if __name__ == '__main__':
    main(phase6='--baseline' not in sys.argv)
