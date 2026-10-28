"""Amostra real e PEQUENA para testar o map matching (não roda no build).

Faz 1 consulta de chegadas e até N consultas de posição de UM ônibus em
tempo real, sequenciais e espaçadas, pela API BusãoGyn (que tem cache).
Guarda as respostas em reports/vehicle_probe_<ponto>.json e o ranking dos
trajetos da linha. Uso:

    python3 -I pipeline/vehicle_probe.py 30402 --samples 4 --interval 20
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.request

sys.path.insert(0, os.path.dirname(__file__))

from cmtc.matching import direction_by_destination, rank_patterns, variants_by_route_name  # noqa: E402
from cmtc.sources import read_lines  # noqa: E402
from cmtc.sources import read_shapes  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
API = 'https://busaogyn-api.lively-cloud-f009.workers.dev'


def get(path):
    req = urllib.request.Request(API + path, headers={'Accept': 'application/json', 'User-Agent': 'busaogyn-cmtc-study'})
    with urllib.request.urlopen(req, timeout=25) as r:
        return json.load(r)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('stop')
    ap.add_argument('--samples', type=int, default=4)
    ap.add_argument('--interval', type=float, default=20)
    ap.add_argument('--reanalyze', action='store_true', help='não consulta a API; refaz a análise do JSON salvo')
    a = ap.parse_args()
    path = os.path.join(ROOT, f'reports/vehicle_probe_{a.stop}.json')
    if a.reanalyze:
        analyze(json.load(open(path, encoding='utf-8')), path)
        return
    assert a.samples <= 6 and a.interval >= 15, 'amostra pequena e espaçada'

    arrivals = get(f'/v1/stops/{a.stop}/arrivals')
    live = [g for g in arrivals['data'] if g['next']['realtime'] and g['next']['vehicleNumber']]
    if not live:
        print('nenhuma chegada em tempo real agora')
        return
    group = sorted(live, key=lambda g: g['next']['minutes'] or 999)[0]
    vehicle = group['next']['vehicleNumber']
    positions = []
    for i in range(a.samples):
        if i:
            time.sleep(a.interval)
        r = get(f'/v1/vehicles/{vehicle}/position?stopId={a.stop}')
        positions.append(r)
    samples = [(p['data']['position']['longitude'], p['data']['position']['latitude'])
               for p in positions if p['data'] and p['data']['position']]
    # posições repetidas (mesmo snapshot em cache) não contam como deslocamento
    samples = [s for i, s in enumerate(samples) if i == 0 or s != samples[i - 1]]
    last = positions[-1]['data'] or {}
    analyze({
        'stop': a.stop, 'routeId': group['routeId'], 'destination_arrivals': group['destination'],
        'vehicle': vehicle, 'samples_distinct': samples,
        'positions_meta': [p['meta'] for p in positions],
        'destination_position': last.get('destination'),
        'routeName_position': last.get('routeName'),
    }, path)


def analyze(out, path):
    route = out['routeId']
    lines, _ = read_lines(os.path.join(ROOT, 'raw/Cadastro Geral das Linhas da RMTC _Setembro-2026 01.09.2026.xlsx'))
    names = {l.code.variant_key: l.name for l in lines if l.code.base == route}
    variants = variants_by_route_name(out['routeName_position'], names)
    out['variants_by_routeName'] = variants
    out['direction_by_destination'] = {vk: direction_by_destination(out['destination_position'], names[vk]) for vk in variants}
    shapes = [s for s in read_shapes(os.path.join(ROOT, 'raw/LINHAS RMTC.kmz')) if s.code and s.code.base == route]
    ranking = rank_patterns([tuple(s) for s in out['samples_distinct']], {s.shape_id: (s.coords, s.description) for s in shapes},
                            destination=out['destination_position'] or out['destination_arrivals'])
    out['ranking'] = [c.__dict__ for c in ranking]
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print(json.dumps({k: out[k] for k in ('routeId', 'vehicle', 'destination_position', 'routeName_position',
                                          'variants_by_routeName', 'direction_by_destination')}, ensure_ascii=False))
    for c in ranking[:6]:
        print(c.score, c.shape_id[:60], '|', c.reason)


if __name__ == '__main__':
    main()
