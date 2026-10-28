"""Confere as viagens da amostra (route_samples.json, gerado pelo teste local
`app/test/dev_catalog/route_samples_test.dart`) contra evidências oficiais
INDEPENDENTES da geometria:

1. relação ponto-linha do Cadastro de Pontos: o ponto de embarque e o de
   desembarque listam a linha? (estações e terminais: não há relação oficial);
2. ordem dos logradouros do Cadastro de Linhas no sentido do trecho: para os
   pontos percorridos cujo logradouro aparece uma única vez na lista, a
   proporção de pares na mesma ordem (>= 0,75 concorda; <= 0,25 contradiz;
   entre, inconclusiva; menos de 3 logradouros distintos, não verificável).

Retornar uma rota não prova que ela está certa; isto mede quanto da amostra
tem apoio oficial. Saída local em reports/ (fora do Git).

    cd data/cmtc && python3 -I pipeline/route_validation.py
"""

from __future__ import annotations

import collections
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

from cmtc.sequence import street_key  # noqa: E402
from cmtc.sources import read_lines, read_stops  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))


def street_index(street, streets):
    k = street_key(street)
    if len(k) < 3:
        return None
    idx = [i for i, s in enumerate(streets) if k in street_key(s)]
    return idx[0] if len(idx) == 1 else None


def check_leg(leg, stops, lines_by_variant):
    out = {}
    board, alight = stops.get(leg['board']), stops.get(leg['alight'])
    rel = []
    for s in (board, alight):
        if s is None:
            rel.append('inferida (estação/terminal)')
        else:
            rel.append('oficial' if leg['line'] in s.lines else 'ausente')
    out['relacao_ponto_linha'] = rel
    line = lines_by_variant.get(leg['variant'])
    if line is None or board is None or alight is None:
        out['ordem_logradouros'] = 'não verificável'
        return out
    streets = line.streets_outbound if leg['direction'] == 'i' else line.streets_inbound
    # Ordem de TODOS os pontos do trecho (embarque..desembarque) contra a lista
    # oficial de logradouros do sentido: pares concordantes x discordantes.
    idx = [street_index(stops[sid].street, streets) for sid in leg.get('path', []) if sid in stops]
    idx = [i for i in idx if i is not None]
    pairs = [(a, b) for k, a in enumerate(idx) for b in idx[k + 1:] if a != b]
    if len({*idx}) < 3:
        out['ordem_logradouros'] = 'não verificável'
    else:
        agree = sum(a < b for a, b in pairs) / len(pairs)
        out['concordancia'] = round(agree, 2)
        out['ordem_logradouros'] = 'concorda' if agree >= 0.75 else 'contradiz' if agree <= 0.25 else 'inconclusiva'
    return out


def main():
    data = json.load(open(os.path.join(ROOT, 'reports', 'route_samples.json'), encoding='utf-8'))
    lines, _ = read_lines(os.path.join(ROOT, 'raw/Cadastro Geral das Linhas da RMTC _Setembro-2026 01.09.2026.xlsx'))
    stops, _ = read_stops(os.path.join(ROOT, 'raw/Cadastro Geral dos Pontos de Ônibus da RMTC- Outubro - 2026.xlsx'))
    by_variant = {l.code.variant_key: l for l in lines}
    by_stop = {s.stop_id: s for s in stops}
    rows = []
    totals = collections.Counter()
    for sample in data['samples']:
        legs = [check_leg(l, by_stop, by_variant) for l in sample['legs']]
        for l in legs:
            totals['trechos'] += 1
            totals['ordem: ' + l['ordem_logradouros']] += 1
            for r in l['relacao_ponto_linha']:
                totals['relação ponto-linha: ' + r] += 1
        rows.append({**sample, 'checks': legs})
    md = ['# Validação por evidência das viagens da amostra', '',
          f"Amostra: {len(rows)} viagens (semente 2026). Resumo por categoria: {data['summary']}", '',
          '| Categoria | Origem → destino | Confiança | Baldeações | Linhas | Relação oficial ponto-linha | Ordem pelos logradouros |',
          '|---|---|---|---|---|---|---|']
    for r in rows:
        md.append(f"| {r['category']} | {r['origin']} → {r['destination']} | {r['reliability']} | {r['transfers']} | "
                  f"{' > '.join(l['variant'] + l['direction'] for l in r['legs'])} | "
                  f"{'; '.join('/'.join(c['relacao_ponto_linha']) for c in r['checks'])} | "
                  f"{'; '.join(c['ordem_logradouros'] for c in r['checks'])} |")
    md += ['', 'Totais: ' + json.dumps(dict(totals), ensure_ascii=False)]
    with open(os.path.join(ROOT, 'reports', 'route_validation.md'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(md) + '\n')
    with open(os.path.join(ROOT, 'reports', 'route_validation.json'), 'w', encoding='utf-8') as f:
        json.dump({'totals': totals, 'rows': rows}, f, ensure_ascii=False, indent=1)
    print(json.dumps(dict(totals), ensure_ascii=False, indent=1))


if __name__ == '__main__':
    main()
