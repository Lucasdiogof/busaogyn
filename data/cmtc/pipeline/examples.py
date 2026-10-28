"""Exemplos para inspeção humana das sequências INFERIDAS.

Uso (a partir de data/cmtc, depois de build.py):
    python3 -I pipeline/examples.py [shape_id_prefixo ...]

Escreve reports/sequence_examples.md e processed/examples/*.geojson (trajeto
+ pontos casados, com confiança nas propriedades) para abrir em qualquer
visualizador GeoJSON. Nada é publicado.
"""

from __future__ import annotations

import csv
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

from cmtc.sources import read_shapes  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DEFAULT = ['003-1i', '003-1v', '032-1i', '113-1i', '113-1v', '113-2i', '113-2v', '582-1v', 'NS1-1i', '115-1i']


def main(prefixes):
    stops = {r['stop_id']: r for r in csv.DictReader(open(os.path.join(ROOT, 'processed/stops.csv'), encoding='utf-8'))}
    rows = list(csv.DictReader(open(os.path.join(ROOT, 'processed/inferred_stop_sequences.csv'), encoding='utf-8')))
    index = {r['shape_id']: r for r in csv.DictReader(open(os.path.join(ROOT, 'processed/shapes_index.csv'), encoding='utf-8'))}
    directions = {(r['variant_key'], r['stop_id']): r for r in csv.DictReader(open(os.path.join(ROOT, 'processed/inferred_stop_direction.csv'), encoding='utf-8'))}
    shapes = {s.shape_id: s for s in read_shapes(os.path.join(ROOT, 'raw/LINHAS RMTC.kmz'))}
    os.makedirs(os.path.join(ROOT, 'processed/examples'), exist_ok=True)

    md = ['# Exemplos de sequência INFERIDA (não oficial)', '',
          'Gerado por `pipeline/examples.py` a partir de `processed/inferred_stop_sequences.csv`.',
          'Cada tabela lista os pontos na ordem ao longo do trajeto do KMZ. "Sentido do ponto" é a',
          'atribuição ida/volta da variante (nível alta/média/baixa/ambíguo). Endereços vêm do cadastro.', '']
    for prefix in prefixes:
        shape_ids = [k for k in index if k.startswith(prefix + ' ') or k.startswith(prefix + '-') or k == prefix]
        for sid in shape_ids:
            meta = index[sid]
            seq = [r for r in rows if r['shape_id'] == sid]
            inferred = [r for r in seq if r['status'].startswith('INFERIDO')]
            amb = [r for r in seq if r['status'] == 'AMBIGUO']
            other = [r for r in seq if r['status'] == 'OUTRO_SENTIDO']
            far = [r for r in seq if r['status'] == 'SEM_CORRESPONDENCIA']
            md += [f'## {sid}', '',
                   f'- Variante `{meta["variant_key"]}`, sentido `{meta["direction"]}` ({meta["direction_source"]}), '
                   f'{int(meta["length_m"]) / 1000:.1f} km, {meta["points"]} vértices, pasta `{meta["folder"]}`.',
                   f'- Membros oficiais da linha avaliados: {len(seq)} → na sequência {len(inferred)} '
                   f'({sum(r["status"] == "INFERIDO_SENTIDO_AMBIGUO" for r in inferred)} com sentido ambíguo), '
                   f'do outro sentido {len(other)}, confiança baixa {len(amb)}, longe do trajeto {len(far)}. Spearman com logradouros oficiais: {meta["spearman_vs_streets"] or "n/d"}.', '']
            if inferred:
                md += ['| # | PED | logradouro | bairro | km | dist. m | passagens | conf. | sentido do ponto |', '|---|---|---|---|---|---|---|---|---|']
                show = inferred if len(inferred) <= 30 else inferred[:15] + [None] + inferred[-10:]
                for r in show:
                    if r is None:
                        md.append('| … | | | | | | | | |')
                        continue
                    s = stops.get(r['stop_id'], {})
                    d = directions.get((meta['variant_key'], r['stop_id']))
                    dtxt = f'{d["direction"] or "?"} ({d["level"]})' if d else 'n/d'
                    md.append(f'| {r["seq"]} | {r["stop_id"]} | {s.get("street_type", "")} {s.get("street", "")} | {s.get("district", "")} | '
                              f'{float(r["along_m"]) / 1000:.2f} | {r["distance_m"]} | {r["passes"]} | {r["confidence"]} | {dtxt} |')
                md.append('')
            else:
                md += ['_Nenhum ponto casado: os pontos desta linha não estão na relação LINHA do cadastro de pontos '
                       '(ex.: estações 40000+ só existem no KMZ de pontos)._', '']
            sh = shapes[sid]
            feats = [{'type': 'Feature', 'properties': {'kind': 'trajeto', 'id': sid},
                      'geometry': {'type': 'LineString', 'coordinates': sh.coords}}]
            for r in seq:
                s = stops.get(r['stop_id'])
                if s and s['lat']:
                    feats.append({'type': 'Feature', 'properties': {
                        'kind': r['status'], 'stop_id': r['stop_id'], 'seq': r['seq'], 'confidence': r['confidence'],
                        'street': s['street']}, 'geometry': {'type': 'Point', 'coordinates': [float(s['lon']), float(s['lat'])]}})
            name = ''.join(ch if ch.isalnum() or ch in '-_' else '_' for ch in sid)[:60]
            with open(os.path.join(ROOT, 'processed/examples', f'{name}.geojson'), 'w', encoding='utf-8') as f:
                json.dump({'type': 'FeatureCollection', 'features': feats}, f, ensure_ascii=False)
    with open(os.path.join(ROOT, 'reports/sequence_examples.md'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(md) + '\n')
    print('ok', len(md), 'linhas')


if __name__ == '__main__':
    main(sys.argv[1:] or DEFAULT)
