"""Protótipo: reconstruir a sequência de pontos de cada trajeto por geometria.

RESULTADO INFERIDO, NÃO OFICIAL. A CMTC não entregou a relação ordenada
linha -> sentido -> pontos (item "d" do pedido). Isto projeta os pontos
sobre o trajeto do KMZ e ordena pela posição ao longo da linha.

Entradas oficiais usadas:
- trajeto (KMZ de linhas), com sentido pelo sufixo i/v; a ordem dos
  vértices segue o sentido de circulação (validado contra a ordem dos
  logradouros do Cadastro de Linhas em 508 de 511 trajetos testáveis);
- coordenadas e relação ponto -> linha (base) do Cadastro de Pontos;
- listas de logradouros de ida e de volta do Cadastro de Linhas (desempate).

Medido nos dados de out/2026: o lado da via (direita/esquerda do sentido)
concorda com os logradouros só ~50% das vezes, por isso é registrado como
informação e NÃO entra na confiança (`side_penalty=0` por padrão).
"""

from __future__ import annotations

import math
import re
import unicodedata
from dataclasses import dataclass, field

from .geo import Polyline, to_xy


@dataclass
class Params:
    tolerance_m: float = 25.0  # distância máxima ponto-trajeto (25 m: ver reports/tolerance_sensitivity.json)
    strong_m: float = 15.0  # até aqui a distância não penaliza
    min_confidence: float = 0.5
    side_penalty: float = 0.0  # ver docstring do módulo
    multi_pass_penalty: float = 0.2
    direction_gap_m: float = 10.0  # diferença mínima de distância para desempatar ida/volta


@dataclass
class Match:
    stop_id: str
    along_m: float
    distance_m: float
    side: str  # 'direita' | 'esquerda' | 'sobre' (informativo)
    passes: int  # quantas vezes o trajeto passa perto do ponto
    confidence: float
    reasons: list[str] = field(default_factory=list)


@dataclass
class ShapeSequence:
    shape_id: str
    variant_key: str
    direction: str | None
    length_m: float
    candidates: int
    sequence: list[Match]
    ambiguous: list[Match]  # perto do trajeto, mas confiança baixa
    unmatched: list[str]  # membros oficiais da linha longe do trajeto


def _side(poly: Polyline, segment: int, lon: float, lat: float) -> str:
    (x1, y1), (x2, y2) = poly.xy[segment], poly.xy[segment + 1]
    px, py = to_xy(lon, lat)
    seg = math.hypot(x2 - x1, y2 - y1) or 1.0
    offset = ((x2 - x1) * (py - y1) - (y2 - y1) * (px - x1)) / seg  # >0 = esquerda
    if abs(offset) < 2.0:
        return 'sobre'
    return 'esquerda' if offset > 0 else 'direita'


def score(distance_m: float, side: str, passes: int, p: Params) -> tuple[float, list[str]]:
    reasons = []
    conf = 1.0
    if distance_m > p.strong_m:
        conf -= (distance_m - p.strong_m) / (p.tolerance_m - p.strong_m) * 0.4
        reasons.append(f'distância {distance_m:.0f} m')
    if side == 'esquerda' and p.side_penalty:
        conf -= p.side_penalty
        reasons.append('ponto à esquerda do sentido')
    if passes > 1:
        conf -= p.multi_pass_penalty
        reasons.append(f'trajeto passa {passes}x perto do ponto')
    return max(0.0, round(conf, 3)), reasons


def build_sequence(shape_id: str, variant_key: str, direction: str | None,
                   coords: list[tuple[float, float]], members: list[tuple[str, float, float]],
                   params: Params = Params()) -> ShapeSequence:
    """`members`: (stop_id, lon, lat) dos pontos oficialmente ligados à linha."""
    poly = Polyline(coords)
    seq, amb, unmatched = [], [], []
    for stop_id, lon, lat in members:
        passes = poly.project_all(lon, lat, params.tolerance_m)
        if not passes:
            unmatched.append(stop_id)
            continue
        best = min(passes, key=lambda pr: pr.distance_m)
        side = _side(poly, best.segment, lon, lat)
        conf, reasons = score(best.distance_m, side, len(passes), params)
        m = Match(stop_id, round(best.along_m, 1), round(best.distance_m, 1), side, len(passes), conf, reasons)
        (seq if conf >= params.min_confidence else amb).append(m)
    seq.sort(key=lambda m: m.along_m)
    return ShapeSequence(shape_id, variant_key, direction, round(poly.length, 1), len(members), seq, amb, unmatched)


def street_key(text) -> str:
    """Logradouro comparável: maiúsculas, sem acento nem pontuação."""
    ascii_text = unicodedata.normalize('NFKD', str(text or '').upper()).encode('ascii', 'ignore').decode()
    return re.sub(r'\s+', ' ', re.sub(r'[^A-Z0-9 ]', ' ', ascii_text)).strip()


def street_hint(stop_street, outbound: list[str], inbound: list[str]) -> str | None:
    """'i'/'v' quando o logradouro do ponto aparece só na lista oficial de um
    sentido; None quando aparece nas duas, em nenhuma, ou é curto demais."""
    key = street_key(stop_street)
    if len(key) < 3:
        return None
    in_i = any(key in street_key(s) for s in outbound)
    in_v = any(key in street_key(s) for s in inbound)
    if in_i == in_v:
        return None
    return 'i' if in_i else 'v'


def assign_direction(i_match: Match | None, v_match: Match | None, hint: str | None = None,
                     params: Params = Params()) -> tuple[str | None, str, str]:
    """Qual sentido de uma variante o ponto atende.

    Devolve (sentido | None, evidência, nível) com nível 'alta' | 'média' |
    'baixa' | 'ambíguo'. Ordem das regras = ordem de confiabilidade medida.
    """
    if i_match is None and v_match is None:
        return None, 'longe dos dois sentidos', 'ambíguo'
    if v_match is None:
        return 'i', 'só perto da ida', 'alta'
    if i_match is None:
        return 'v', 'só perto da volta', 'alta'
    if hint is not None:
        return hint, 'perto dos dois; logradouro só na lista oficial de ' + ('ida' if hint == 'i' else 'volta'), 'média'
    gap = abs(i_match.distance_m - v_match.distance_m)
    if gap >= params.direction_gap_m:
        closer = 'i' if i_match.distance_m < v_match.distance_m else 'v'
        return closer, f'perto dos dois; {gap:.0f} m mais perto da {"ida" if closer == "i" else "volta"}', 'baixa'
    return None, 'perto dos dois sentidos, sem desempate', 'ambíguo'
