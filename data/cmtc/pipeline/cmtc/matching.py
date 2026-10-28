"""Protótipo de map matching de um veículo aos trajetos oficiais.

A fonte em tempo real não informa variante, sentido nem viagem: só a base
da linha (`routeId`), o destino em texto e a posição. Aqui se ranqueiam os
trajetos (variante + sentido) da linha com a sequência de posições:

- distância: mediana da distância das amostras ao trajeto (corte: `max_m`);
- progresso: com duas ou mais amostras, a posição ao longo do trajeto deve
  crescer (o KMZ segue o sentido de circulação); recuo derruba o candidato;
- destino: palavras do destino textual da RMTC que aparecem na descrição
  do trajeto (ex.: 'T BIBLIA' x 'T. BIBLIA') somam um bônus pequeno.

O resultado é uma lista ordenada com pontuação e motivo; o chamador decide
se a diferença entre o 1º e o 2º é grande o bastante para afirmar algo.
"""

from __future__ import annotations

import re
import statistics
import unicodedata
from dataclasses import dataclass

from .geo import Polyline


@dataclass
class Candidate:
    shape_id: str
    score: float
    median_distance_m: float | None
    progress_m: float | None  # avanço ao longo do trajeto entre 1ª e última amostra
    monotonic: bool | None
    destination_hits: int
    reason: str


def _words(text: str) -> set[str]:
    t = unicodedata.normalize('NFKD', text.upper()).encode('ascii', 'ignore').decode()
    return {w for w in re.split(r'[^A-Z0-9]+', t) if len(w) >= 3}


def rank_patterns(samples: list[tuple[float, float]], patterns: dict[str, tuple[list[tuple[float, float]], str]],
                  destination: str | None = None, max_m: float = 60.0) -> list[Candidate]:
    """`samples`: posições (lon, lat) em ordem de tempo.
    `patterns`: shape_id -> (coords, descrição)."""
    dest = _words(destination or '') - {'TERMINAL'}
    out = []
    for sid, (coords, desc) in patterns.items():
        poly = Polyline(coords)
        projs = []
        for lon, lat in samples:
            p = poly.project_all(lon, lat, max_m)
            projs.append(min(p, key=lambda x: x.distance_m) if p else None)
        hits = len(dest & _words(desc))
        if any(p is None for p in projs):
            out.append(Candidate(sid, 0.0, None, None, None, hits, f'amostra a mais de {max_m:.0f} m do trajeto'))
            continue
        med = statistics.median(p.distance_m for p in projs)
        score = max(0.0, 1 - med / max_m)
        progress = monotonic = None
        reason = f'mediana {med:.0f} m'
        if len(projs) >= 2:
            along = [p.along_m for p in projs]
            progress = along[-1] - along[0]
            monotonic = all(b >= a - 15 for a, b in zip(along, along[1:]))  # 15 m de ruído de GPS
            if not monotonic or progress < -15:
                score *= 0.2
                reason += '; posições andam para trás neste trajeto'
            elif progress > 15:
                score += 0.2
                reason += f'; avança {progress:.0f} m no sentido do trajeto'
            else:
                reason += '; sem deslocamento suficiente para ver o sentido'
        if hits:
            score += 0.05 * hits
            reason += f'; destino casa {hits} palavra(s)'
        out.append(Candidate(sid, round(score, 3), round(med, 1), progress and round(progress, 1), monotonic, hits, reason))
    out.sort(key=lambda c: c.score, reverse=True)
    return out


def _norm_name(text: str | None) -> str:
    return ' '.join(sorted(_words(text or '')))


def variants_by_route_name(route_name: str | None, variants: dict[str, str]) -> list[str]:
    """Variantes do cadastro cuja DENOMINAÇÃO é igual ao `routeName` da RMTC
    (palavras normalizadas, sem ordem). `variants`: variant_key -> nome."""
    key = _norm_name(route_name)
    return sorted(vk for vk, name in variants.items() if key and _norm_name(name) == key)


def direction_by_destination(destination: str | None, variant_name: str | None) -> str | None:
    """'i' se o destino casa com o último trecho da denominação ('A / B / C'),
    'v' se casa com o primeiro; None se não casa ou casa com os dois."""
    if not destination or not variant_name:
        return None
    parts = [p for p in re.split(r'\s*/\s*', variant_name) if p.strip()]
    if len(parts) < 2:
        return None
    dest = _words(destination) - {'TERMINAL'}
    first, last = _words(parts[0]) & dest, _words(parts[-1]) & dest
    if bool(first) == bool(last):
        return None
    return 'i' if last else 'v'
