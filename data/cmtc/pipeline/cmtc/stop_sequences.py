"""Sequência ESTIMADA de paradas por trajeto, com nível por ponto.

Não é sequência oficial: a CMTC não entregou a relação ordenada
linha -> sentido -> pontos. Reaproveita `sequence.build_sequence` (projeção
sobre o trajeto do KMZ) e `sequence.assign_direction` (ida x volta) e
acrescenta:

- uma entrada por PASSAGEM: trajeto que passa duas vezes perto do ponto
  (retorno, laço, circular) gera duas entradas, ambas de nível médio;
- nível por ponto: high | medium | ambiguous | unassociated
  ('official' só existiria com relação explícita da fonte; hoje nunca);
- ponto atribuído ao sentido oposto da mesma variante sai da sequência e
  fica registrado em `other_direction`;
- status do trajeto: 'estimated' (ordem utilizável, sempre rotulada como
  estimativa), 'partial' (só pertencimento, sem ordem) ou 'none';
- proveniência: método, parâmetros e evidência de cada entrada.
"""

from __future__ import annotations

import collections
from dataclasses import dataclass, field

from .geo import Polyline, haversine_m
from .sequence import Params, assign_direction, score, street_hint, street_key

METHOD = 'projecao-kmz-v2'

# Limiares do status 'estimated' (calibrados em out/2026; ver doc da fase 4 §4).
MIN_ENTRIES = 5
MIN_HIGH_SHARE = 0.7
MAX_AMBIGUOUS_SHARE = 0.15
MIN_STREET_RHO = 0.5
CIRCULAR_GAP_M = 300.0


@dataclass
class Entry:
    stop_id: str
    along_m: float
    distance_m: float
    level: str  # 'high' | 'medium'
    evidence: list[str] = field(default_factory=list)
    passes: int = 1


@dataclass
class ShapeStops:
    shape_id: str
    line: str
    variant_key: str
    direction: str | None
    circular: bool
    length_m: float
    entries: list[Entry]
    ambiguous: list[tuple[str, str]]  # (stop_id, motivo)
    unassociated: list[str]
    other_direction: list[str]
    status: str = 'none'
    status_reason: str = ''
    street_rho: float | None = None


def _spearman(a, b):
    n = len(a)
    ra = {k: i for i, k in enumerate(sorted(range(n), key=lambda k: a[k]))}
    rb = {k: i for i, k in enumerate(sorted(range(n), key=lambda k: b[k]))}
    return 1 - 6 * sum((ra[i] - rb[i]) ** 2 for i in range(n)) / (n * (n * n - 1))


def street_rho(entries: list[Entry], streets: list[str], street_of: dict[str, str]) -> float | None:
    """Spearman entre a posição estimada e o índice do logradouro na lista
    OFICIAL do sentido (só pontos cujo logradouro aparece uma única vez)."""
    keys = [street_key(s) for s in streets]
    a, b = [], []
    for e in entries:
        k = street_key(street_of.get(e.stop_id))
        if len(k) < 3:
            continue
        idx = [i for i, x in enumerate(keys) if k in x]
        if len(idx) == 1:
            a.append(e.along_m)
            b.append(idx[0])
    return round(_spearman(a, b), 3) if len(a) >= 6 else None


def classify_status(s: ShapeStops) -> tuple[str, str]:
    if not s.entries:
        return 'none', 'nenhum ponto do cadastro perto do trajeto'
    n = len(s.entries)
    high = sum(e.level == 'high' for e in s.entries) / n
    amb = len(s.ambiguous) / (n + len(s.ambiguous))
    if n < MIN_ENTRIES:
        return 'partial', f'só {n} ponto(s) associados'
    if high < MIN_HIGH_SHARE:
        return 'partial', f'{high:.0%} dos pontos com confiança alta (mínimo {MIN_HIGH_SHARE:.0%})'
    if amb > MAX_AMBIGUOUS_SHARE:
        return 'partial', f'{amb:.0%} dos pontos ambíguos (máximo {MAX_AMBIGUOUS_SHARE:.0%})'
    if s.street_rho is not None and s.street_rho < MIN_STREET_RHO:
        return 'partial', f'ordem não acompanha os logradouros oficiais (rho {s.street_rho})'
    return 'estimated', f'{n} pontos, {high:.0%} alta, {amb:.0%} ambíguos, rho {s.street_rho}'


def sequence_shapes(shapes, members: dict[str, list[tuple[str, float, float]]], streets_of: dict[str, tuple[list, list]],
                    street_of: dict[str, str], params: Params = Params()) -> list[ShapeStops]:
    """`shapes`: objetos com shape_id, code (base, variant_key), direction, coords.
    `members`: base da linha -> (stop_id, lon, lat) do cadastro de pontos.
    `streets_of`: variant_key -> (logradouros de ida, de volta) do cadastro de linhas.
    `street_of`: stop_id -> logradouro do ponto."""
    by_variant = collections.defaultdict(dict)
    polys = {}
    for sh in shapes:
        if sh.code and sh.direction and len(sh.coords) >= 2:
            by_variant[sh.code.variant_key].setdefault(sh.direction, sh)
            polys[sh.shape_id] = Polyline(sh.coords)

    def best(shape_id, lon, lat):
        passes = polys[shape_id].project_all(lon, lat, params.tolerance_m)
        return passes, (min(passes, key=lambda p: p.distance_m) if passes else None)

    out = []
    for sh in shapes:
        if sh.shape_id not in polys:
            continue
        vk, d = sh.code.variant_key, sh.direction
        other = by_variant[vk].get('v' if d == 'i' else 'i')
        if other is sh:
            other = None
        outbound, inbound = streets_of.get(vk, ([], []))
        res = ShapeStops(sh.shape_id, sh.code.base, vk, d, haversine_m(sh.coords[0], sh.coords[-1]) < CIRCULAR_GAP_M,
                         round(polys[sh.shape_id].length, 1), [], [], [], [])
        for stop_id, lon, lat in members.get(sh.code.base, []):
            passes, here = best(sh.shape_id, lon, lat)
            if here is None:
                res.unassociated.append(stop_id)
                continue
            conf, reasons = score(here.distance_m, 'sobre', len(passes), params)
            if conf < params.min_confidence:
                res.ambiguous.append((stop_id, '; '.join(reasons) or 'confiança baixa'))
                continue
            dir_level = 'alta'
            if other is not None:
                _, there = best(other.shape_id, lon, lat)
                hint = street_hint(street_of.get(stop_id), outbound, inbound)
                # assign_direction espera objetos com distance_m (Projection serve).
                mine, theirs = (here, there) if d == 'i' else (there, here)
                got, why, dir_level = assign_direction(mine, theirs, hint, params)
                if got is None:
                    res.ambiguous.append((stop_id, why))
                    continue
                if got != d:
                    res.other_direction.append(stop_id)
                    continue
                if dir_level != 'alta':
                    reasons.append(f'sentido: {why}')
            level = 'high' if conf >= 0.9 and len(passes) == 1 and dir_level == 'alta' else 'medium'
            for p in passes:
                ev = list(reasons) + (['passagem repetida pelo mesmo trecho'] if len(passes) > 1 else [])
                res.entries.append(Entry(stop_id, round(p.along_m, 1), round(p.distance_m, 1), level, ev, len(passes)))
        res.entries.sort(key=lambda e: e.along_m)
        streets = outbound if d == 'i' else inbound
        res.street_rho = street_rho(res.entries, streets, street_of) if streets else None
        res.status, res.status_reason = classify_status(res)
        out.append(res)
    return out
