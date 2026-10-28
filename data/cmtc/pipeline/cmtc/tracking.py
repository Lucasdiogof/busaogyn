"""Regras de associação ônibus -> trajeto e de próximos pontos, IDÊNTICAS às
do app (`app/lib/src/features/catalog/domain/route_match.dart` e
`next_stops.dart`). Existem aqui para a avaliação com veículos reais
(`match_eval.py`) medir exatamente o que o app faria.

Qualquer mudança de regra precisa ser feita nos dois lados; os testes dos
dois usam os mesmos cenários.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field

from .geo import Polyline, haversine_m

MAX_DISTANCE_M = 50.0
MIN_PROGRESS_M = 20.0
BACK_TOLERANCE_M = 15.0
# Avanço ao longo do trajeto entre duas amostras: no máximo 1,5x o
# deslocamento em linha reta + 300 m (curvas e retornos). Mais que isso é
# salto para outra passagem do trajeto, não movimento.
DETOUR_FACTOR = 1.5
DETOUR_SLACK_M = 300.0
# Cadeias coerentes que terminam a até 50 m uma da outra apontam o mesmo
# lugar (geometria sinuosa perto da amostra): não é ambiguidade.
CONVERGE_M = 50.0
PASSED_MARGIN_M = 40.0  # ponto só conta como passado com o ônibus 40 m além dele

_SYNONYMS = {'pca': 'praca', 'pc': 'praca', 'rod': 'rodovia', 'est': 'estrada', 'jd': 'jardim',
             'res': 'residencial', 'st': 'setor', 'vl': 'vila', 'pq': 'parque', 'term': 'terminal'}


def tokens(text: str | None) -> list[str]:
    """Mesmo que `searchTokens` do app."""
    t = unicodedata.normalize('NFKD', (text or '').lower()).encode('ascii', 'ignore').decode()
    t = t.replace('º', 'o').replace('ª', 'a')
    return [_SYNONYMS.get(w, w) for w in re.split(r'[^a-z0-9]+', t) if w]


def _words(text):
    return {w for w in tokens(text) if len(w) >= 3 and w != 'terminal'}


def _key(text):
    return ' '.join(sorted(_words(text)))


def direction_by_destination(destination: str | None, variant_name: str | None) -> str | None:
    if not destination or not variant_name:
        return None
    parts = [p for p in variant_name.split('/') if p.strip()]
    if len(parts) < 2:
        return None
    dest = _words(destination)
    first, last = bool(_words(parts[0]) & dest), bool(_words(parts[-1]) & dest)
    if first == last:
        return None
    return 'i' if last else 'v'


def destination_on_itinerary(destination: str | None, variant_name: str | None) -> bool:
    """O destino casa com algum trecho da denominação, inclusive um do meio."""
    if not destination or not variant_name:
        return False
    dest = _words(destination)
    return any(_words(p) & dest for p in variant_name.split('/'))


@dataclass
class Shape:
    id: str
    variant: str
    direction: str | None
    line: Polyline


@dataclass
class RouteMatch:
    level: str  # confirmed | pending | ambiguous | unavailable
    reason: str
    shape: Shape | None = None
    along_m: float | None = None


def match_tracked_route(*, variants: dict[str, str], shapes: list[Shape], route_name: str | None,
                        destination: str | None, position: tuple[float, float] | None,
                        trail: list[tuple[float, float]] = ()) -> RouteMatch:
    """`variants`: variant_key -> denominação; posições (lon, lat)."""
    if not shapes:
        return RouteMatch('unavailable', 'noShapes')
    if position is None:
        return RouteMatch('unavailable', 'noPosition')
    if not route_name or not route_name.strip():
        return RouteMatch('ambiguous', 'routeNameMissing')
    key = _key(route_name)
    found = [vk for vk, name in variants.items() if _key(name) == key]
    if not found:
        return RouteMatch('ambiguous', 'routeNameNoMatch')
    if len(found) > 1:
        return RouteMatch('ambiguous', 'routeNameSeveral')
    vk = found[0]
    points = list(trail)
    if not points or points[-1] != position:
        points.append(position)
    direction = direction_by_destination(destination, variants[vk])
    if direction is None:
        if not destination_on_itinerary(destination, variants[vk]):
            return RouteMatch('ambiguous', 'directionUnknown')
        return _by_movement([s for s in shapes if s.variant == vk], points)
    cands = [s for s in shapes if s.variant == vk and s.direction == direction]
    if len(cands) != 1:
        return RouteMatch('ambiguous', 'shapeMissing')
    shape = cands[0]
    along, reason = _chain(shape.line, points)
    if along is None:
        return RouteMatch('ambiguous', reason, shape)
    if along[-1] - along[0] < MIN_PROGRESS_M:
        return RouteMatch('pending', 'waitingMovement', shape, along[-1])
    return RouteMatch('confirmed', 'confirmed', shape, along[-1])


def _by_movement(shapes: list[Shape], points) -> RouteMatch:
    """Destino num trecho do meio (ou nos dois extremos): confirma o sentido
    só se, entre ida e volta, exatamente um é coerente com o deslocamento."""
    ida = [s for s in shapes if s.direction == 'i']
    volta = [s for s in shapes if s.direction == 'v']
    if len(ida) != 1 or len(volta) != 1:
        return RouteMatch('ambiguous', 'directionUnknown')
    coherent = [(s, a) for s in (ida[0], volta[0]) for a in [_chain(s.line, points)[0]] if a is not None]
    if len(coherent) != 1:
        moved = any(a[-1] - a[0] >= MIN_PROGRESS_M for _, a in coherent)
        if not coherent or moved:
            return RouteMatch('ambiguous', 'directionUnknown')
        return RouteMatch('pending', 'waitingMovement', ida[0])
    shape, along = coherent[0]
    if along[-1] - along[0] < MIN_PROGRESS_M:
        return RouteMatch('pending', 'waitingMovement', shape, along[-1])
    return RouteMatch('confirmed', 'confirmed', shape, along[-1])


def _chain(line: Polyline, points) -> tuple[list[float] | None, str | None]:
    """Posições ao longo do trajeto, com continuidade: cada amostra fica na
    passagem mais próxima À FRENTE da anterior (trajeto que passa duas vezes
    pelo mesmo trecho). Cada passagem da 1ª amostra inicia uma cadeia; vale
    se as coerentes terminam no mesmo lugar (até CONVERGE_M)."""
    candidates = [line.project_all(lon, lat, MAX_DISTANCE_M) for lon, lat in points]
    if any(not c for c in candidates):
        return None, 'offRoute'
    chains, failure = [], None
    for start in candidates[0]:
        along = [start.along_m]
        for i, passes in enumerate(candidates[1:], 1):
            ahead = [p.along_m for p in passes if p.along_m >= along[-1] - BACK_TOLERANCE_M]
            if not ahead:
                failure = 'movingBackwards'
                break
            step = min(ahead)
            limit = haversine_m(points[i - 1], points[i]) * DETOUR_FACTOR + DETOUR_SLACK_M
            if step - along[-1] > limit:
                failure = 'gpsJump'
                break
            along.append(step)
        else:
            chains.append(along)
    if not chains:
        return None, failure
    ends = [c[-1] for c in chains]
    if max(ends) - min(ends) > CONVERGE_M:
        return None, 'repeatedSection'
    # Convergem: vale a de menor avanço (a mais conservadora para confirmar).
    return min(chains, key=lambda c: c[-1] - c[0]), None


@dataclass
class NextStops:
    available: bool
    reason: str
    remaining: list = field(default_factory=list)  # entradas ainda à frente
    next_confident: bool = False  # destacar o primeiro como próximo ponto


def next_stops(match: RouteMatch, status: str | None, entries: list) -> NextStops:
    """`entries`: (stop_id, along_m, level) da sequência ESTIMADA do trajeto."""
    if match.level != 'confirmed' or match.along_m is None:
        return NextStops(False, 'notConfirmed')
    if status != 'estimated':
        return NextStops(False, 'sequenceUnreliable')
    remaining = [e for e in entries if e[1] + PASSED_MARGIN_M > match.along_m]
    if not remaining:
        return NextStops(False, 'endOfRoute')
    return NextStops(True, 'ok', remaining, remaining[0][2] == 'high')
