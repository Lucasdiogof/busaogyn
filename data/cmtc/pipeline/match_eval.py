"""Avaliação CONTROLADA da associação ônibus -> trajeto com veículos reais.

Usa a API do BusãoGyn (Worker com cache), nunca a RMTC diretamente, e aplica
exatamente as regras do app (`cmtc/tracking.py` = `route_match.dart` +
`stop_sequence.dart`).

Limites fixos (não configuráveis acima disso):
- até 3 pontos consultados uma vez cada (chegadas);
- até 4 veículos, até 6 amostras de posição cada, intervalo >= 20 s;
- execução única, sem laço em segundo plano (~2-3 min, <= 27 requisições).

Privacidade: número do veículo vira pseudônimo (v1, v2…) já na coleta; nada
sai da máquina; resultados em `reports/` (ignorado pelo Git) e arquivos com
mais de 7 dias são apagados a cada execução. O resumo `.md` não tem posições
nem identificadores.

    cd data/cmtc && python3 -I pipeline/match_eval.py            # coleta + relatório
    cd data/cmtc && python3 -I pipeline/match_eval.py --reanalyze reports/match_eval_X.json
"""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import glob
import json
import os
import sys
import time
import urllib.request

sys.path.insert(0, os.path.dirname(__file__))

from cmtc.geo import Polyline, haversine_m  # noqa: E402
from cmtc.sequence import Params  # noqa: E402
from cmtc.sources import read_lines, read_shapes, read_stops  # noqa: E402
from cmtc.stop_sequences import sequence_shapes  # noqa: E402
from cmtc.tracking import Shape, match_tracked_route, next_stops  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
REPORTS = os.path.join(ROOT, 'reports')
API = 'https://busaogyn-api.lively-cloud-f009.workers.dev'
LINES_XLSX = 'raw/Cadastro Geral das Linhas da RMTC _Setembro-2026 01.09.2026.xlsx'
STOPS_XLSX = 'raw/Cadastro Geral dos Pontos de Ônibus da RMTC- Outubro - 2026.xlsx'
SHAPES_KMZ = 'raw/LINHAS RMTC.kmz'

MAX_STOPS, MAX_VEHICLES, MAX_SAMPLES, MIN_INTERVAL_S = 3, 4, 6, 20.0
RETENTION_DAYS = 7
# Igual ao app (ObservedMovement): posição nova só com 2 m de deslocamento;
# salto > 1 km reinicia o rastro; no máximo 20 posições.
TRAIL_MIN_M, TRAIL_JUMP_M, TRAIL_MAX = 2.0, 1000.0, 20


def get(path):
    req = urllib.request.Request(API + path, headers={'Accept': 'application/json',
                                                     'User-Agent': 'busaogyn-match-eval'})
    with urllib.request.urlopen(req, timeout=25) as r:
        return json.load(r)


def purge_old():
    limit = time.time() - RETENTION_DAYS * 86400
    for path in glob.glob(os.path.join(REPORTS, 'match_eval_*')):
        if os.path.getmtime(path) < limit:
            os.remove(path)


def busiest_stops(stops, n):
    """Pontos do cadastro com mais linhas: mais chance de ônibus ao vivo."""
    ranked = sorted((s for s in stops if s.lat is not None), key=lambda s: (-len(s.lines), int(s.stop_id)))
    return [s.stop_id for s in ranked[:n]]


def collect(stop_ids, samples, interval):
    vehicles = {}  # pseudônimo -> dados
    real_to_alias = {}
    log = {'stopsQueried': [], 'requests': 0, 'startedAt': dt.datetime.now(dt.timezone.utc).isoformat()}
    for stop in stop_ids[:MAX_STOPS]:
        try:
            arrivals = get(f'/v1/stops/{stop}/arrivals')
            log['requests'] += 1
        except Exception as e:  # rede: registra e segue
            log['stopsQueried'].append({'stop': stop, 'error': type(e).__name__})
            continue
        live = [g for g in arrivals.get('data') or [] if g['next'].get('realtime') and g['next'].get('vehicleNumber')]
        log['stopsQueried'].append({'stop': stop, 'groups': len(arrivals.get('data') or []), 'live': len(live)})
        # Um veículo por linha, para variar a amostra.
        for g in sorted(live, key=lambda g: g['next'].get('minutes') or 999):
            if len(real_to_alias) >= MAX_VEHICLES:
                break
            number = g['next']['vehicleNumber']
            if number in real_to_alias or any(v['routeId'] == g['routeId'] for v in vehicles.values()):
                continue
            alias = f'v{len(real_to_alias) + 1}'
            real_to_alias[number] = alias
            vehicles[alias] = {'routeId': g['routeId'], 'stop': stop, '_number': number, 'samples': []}
    for i in range(samples if vehicles else 0):
        if i:
            time.sleep(interval)
        for alias, v in vehicles.items():
            try:
                r = get(f"/v1/vehicles/{v['_number']}/position?stopId={v['stop']}")
                log['requests'] += 1
            except Exception as e:
                v['samples'].append({'error': type(e).__name__})
                continue
            d, meta = r.get('data') or {}, r.get('meta') or {}
            pos = d.get('position')
            v['samples'].append({
                'routeId': d.get('routeId'), 'routeName': d.get('routeName'), 'destination': d.get('destination'),
                'lon': None if not pos else round(pos['longitude'], 5),
                'lat': None if not pos else round(pos['latitude'], 5),
                'stale': bool(meta.get('stale')), 'ageSeconds': meta.get('ageSeconds'),
            })
    for v in vehicles.values():
        del v['_number']  # nunca gravado
    log['finishedAt'] = dt.datetime.now(dt.timezone.utc).isoformat()
    return {'log': log, 'vehicles': vehicles}


def from_probe(probe):
    """Converte a gravação da fase 1 (posições distintas de um ônibus) para o
    formato desta avaliação, sem o número do veículo."""
    metas = probe.get('positions_meta') or []
    return {
        'log': {'startedAt': metas[0]['fetchedAt'] if metas else '?',
                'finishedAt': metas[-1]['fetchedAt'] if metas else '?',
                'requests': 0, 'stopsQueried': [{'stop': probe['stop'], 'source': 'vehicle_probe (fase 1)'}]},
        'vehicles': {'v1': {'routeId': probe['routeId'], 'stop': probe['stop'], 'samples': [
            {'routeId': probe['routeId'], 'routeName': probe.get('routeName_position'),
             'destination': probe.get('destination_position'), 'lon': round(lon, 5), 'lat': round(lat, 5),
             'stale': False, 'ageSeconds': None}
            for lon, lat in probe['samples_distinct']]}},
    }


def evaluate(data):
    lines, _ = read_lines(os.path.join(ROOT, LINES_XLSX))
    bases = {v['routeId'] for v in data['vehicles'].values()}
    raw_shapes = [s for s in read_shapes(os.path.join(ROOT, SHAPES_KMZ)) if s.code and s.code.base in bases]
    stops, _ = read_stops(os.path.join(ROOT, STOPS_XLSX))
    members = collections.defaultdict(list)
    for s in stops:
        if s.lat is not None:
            for b in s.lines:
                if b in bases:
                    members[b].append((s.stop_id, s.lon, s.lat))
    seqs = {r.shape_id: r for r in sequence_shapes(
        raw_shapes, members, {l.code.variant_key: (l.streets_outbound, l.streets_inbound) for l in lines},
        {s.stop_id: s.street for s in stops}, Params())}

    results = {}
    for alias, v in data['vehicles'].items():
        base = v['routeId']
        names = {l.code.variant_key: l.name for l in lines if l.code.base == base}
        shapes = [Shape(s.shape_id, s.code.variant_key, s.direction, Polyline(s.coords))
                  for s in raw_shapes if s.code.base == base and len(s.coords) >= 2]
        trail, steps, previous = [], [], None
        for smp in v['samples']:
            if 'error' in smp:
                steps.append({'error': smp['error']})
                continue
            pos = None if smp['lon'] is None or smp['stale'] else (smp['lon'], smp['lat'])
            changed = previous is not None and (smp['routeName'], smp['destination']) != previous
            previous = (smp['routeName'], smp['destination'])
            if changed:
                trail = []  # troca de itinerário: o app recomeça o rastro
            if pos is not None:
                if trail and haversine_m(trail[-1], pos) > TRAIL_JUMP_M:
                    trail = []
                if not trail or haversine_m(trail[-1], pos) >= TRAIL_MIN_M:
                    trail = (trail + [pos])[-TRAIL_MAX:]
            m = match_tracked_route(variants=names, shapes=shapes, route_name=smp['routeName'],
                                    destination=smp['destination'], position=pos, trail=trail[:-1] if pos else [])
            seq = seqs.get(m.shape.id) if m.shape else None
            entries = [(e.stop_id, e.along_m, e.level) for e in seq.entries] if seq else []
            n = next_stops(m, seq.status if seq else None, entries)
            steps.append({'level': m.level, 'reason': m.reason, 'shape': m.shape.id if m.shape else None,
                          'alongM': None if m.along_m is None else round(m.along_m),
                          'routeChanged': changed, 'stale': smp['stale'],
                          'nextStops': n.reason, 'remaining': len(n.remaining), 'nextConfident': n.next_confident,
                          'sequenceStatus': seq.status if seq else None})
        results[alias] = {'routeId': base, 'variantsOfLine': len(names), 'shapesOfLine': len(shapes), 'steps': steps}
    return results


def summary(data, results):
    final = collections.Counter()
    reasons = collections.Counter()
    first_confirmed = []
    for r in results.values():
        ok = [s for s in r['steps'] if 'level' in s]
        if not ok:
            final['sem amostras'] += 1
            continue
        final[ok[-1]['level']] += 1
        for s in ok:
            reasons[s['reason']] += 1
        idx = next((i for i, s in enumerate(ok) if s['level'] == 'confirmed'), None)
        if idx is not None:
            first_confirmed.append(idx + 1)
    lines = [
        '# Avaliação da associação com veículos reais',
        '',
        f"- Coleta: {data['log']['startedAt']} → {data['log']['finishedAt']} (UTC)",
        f"- Requisições à API BusãoGyn: {data['log']['requests']}",
        f"- Pontos consultados: {len(data['log']['stopsQueried'])}; veículos ao vivo amostrados: {len(results)}",
        '',
        '| Veículo | Linha | Amostras | Níveis por amostra | Motivo final | Próximos pontos (final) |',
        '|---|---|---|---|---|---|',
    ]
    for alias, r in results.items():
        ok = [s for s in r['steps'] if 'level' in s]
        levels = ' → '.join(s['level'] for s in ok) or '—'
        last = ok[-1] if ok else {}
        lines.append(f"| {alias} | {r['routeId']} | {len(r['steps'])} | {levels} | {last.get('reason', '—')} | "
                     f"{last.get('nextStops', '—')} ({last.get('remaining', 0)}) |")
    lines += ['', f'Nível final: {dict(final)}', f'Motivos (todas as amostras): {dict(reasons)}',
              f'Amostra em que confirmou (quando confirmou): {first_confirmed}', '',
              'Amostra pequena: não serve para declarar precisão geral.']
    return '\n'.join(lines) + '\n'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--stops', help='códigos separados por vírgula (padrão: os 3 pontos com mais linhas)')
    ap.add_argument('--samples', type=int, default=5)
    ap.add_argument('--interval', type=float, default=25)
    ap.add_argument('--reanalyze', help='JSON salvo: refaz a avaliação sem consultar a API')
    ap.add_argument('--from-probe', help='JSON do vehicle_probe.py (fase 1): avalia sem consultar a API')
    a = ap.parse_args()
    if not a.reanalyze and (a.samples > MAX_SAMPLES or a.interval < MIN_INTERVAL_S):
        raise SystemExit(f'limites: até {MAX_SAMPLES} amostras, intervalo >= {MIN_INTERVAL_S:.0f} s')
    os.makedirs(REPORTS, exist_ok=True)
    purge_old()
    if a.from_probe:
        data = from_probe(json.load(open(a.from_probe, encoding='utf-8')))
        path = os.path.join(REPORTS, 'match_eval_probe_' + os.path.basename(a.from_probe))
    elif a.reanalyze:
        data = json.load(open(a.reanalyze, encoding='utf-8'))
        path = a.reanalyze
    else:
        stops, _ = read_stops(os.path.join(ROOT, STOPS_XLSX))
        chosen = a.stops.split(',') if a.stops else busiest_stops(stops, MAX_STOPS)
        data = collect(chosen, a.samples, a.interval)
        path = os.path.join(REPORTS, f"match_eval_{dt.datetime.now(dt.timezone.utc):%Y%m%dT%H%M%SZ}.json")
    data['results'] = evaluate(data)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    md = summary(data, data['results'])
    with open(path.replace('.json', '.md'), 'w', encoding='utf-8') as f:
        f.write(md)
    print(md)
    print('arquivos (locais, fora do Git):', path)


if __name__ == '__main__':
    main()
