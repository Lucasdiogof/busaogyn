"""Geometria plana local (equiretangular) — suficiente para a escala da RMTC
(~100 km): erro bem abaixo de 1 m nas distâncias de dezenas de metros que
interessam aqui."""

from __future__ import annotations

import math
from dataclasses import dataclass

EARTH_M = 6371008.8
REF_LAT = -16.68  # Goiânia


def to_xy(lon: float, lat: float) -> tuple[float, float]:
    k = math.pi / 180 * EARTH_M
    return lon * k * math.cos(math.radians(REF_LAT)), lat * k


def haversine_m(a: tuple[float, float], b: tuple[float, float]) -> float:
    """a, b = (lon, lat)."""
    lon1, lat1, lon2, lat2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((lat2 - lat1) / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2
    return 2 * EARTH_M * math.asin(min(1.0, math.sqrt(h)))


def length_m(coords: list[tuple[float, float]]) -> float:
    return sum(haversine_m(a, b) for a, b in zip(coords, coords[1:]))


@dataclass
class Projection:
    distance_m: float  # distância perpendicular do ponto à linha
    along_m: float  # posição ao longo da linha, desde o início
    segment: int


class Polyline:
    """Linha pré-processada para projeções repetidas."""

    def __init__(self, coords: list[tuple[float, float]]):
        self.coords = coords
        self.xy = [to_xy(lon, lat) for lon, lat in coords]
        self.cum = [0.0]
        for (x1, y1), (x2, y2) in zip(self.xy, self.xy[1:]):
            self.cum.append(self.cum[-1] + math.hypot(x2 - x1, y2 - y1))

    @property
    def length(self) -> float:
        return self.cum[-1]

    def project_all(self, lon: float, lat: float, max_distance_m: float) -> list[Projection]:
        """Todas as passagens da linha a até `max_distance_m` do ponto.

        Uma linha pode passar duas vezes pelo mesmo lugar (ida e volta pela
        mesma via, laços): cada passagem vira um mínimo local separado.
        Segmentos consecutivos dentro da tolerância formam uma passagem, a
        menos que a posição ao longo da linha salte mais que 2x a tolerância
        (retorno em U: os segmentos são vizinhos, mas são duas passagens).
        """
        px, py = to_xy(lon, lat)
        passes: list[Projection] = []
        current: Projection | None = None
        last_along = 0.0
        for i, ((x1, y1), (x2, y2)) in enumerate(zip(self.xy, self.xy[1:])):
            dx, dy = x2 - x1, y2 - y1
            seg2 = dx * dx + dy * dy
            t = 0.0 if seg2 == 0 else max(0.0, min(1.0, ((px - x1) * dx + (py - y1) * dy) / seg2))
            cx, cy = x1 + t * dx, y1 + t * dy
            d = math.hypot(px - cx, py - cy)
            if d <= max_distance_m:
                proj = Projection(d, self.cum[i] + t * math.sqrt(seg2), i)
                if current is not None and proj.along_m - last_along > 2 * max_distance_m:
                    passes.append(current)
                    current = None
                if current is None or proj.distance_m < current.distance_m:
                    current = proj
                last_along = proj.along_m
            elif current is not None:
                passes.append(current)
                current = None
        if current is not None:
            passes.append(current)
        return passes


def simplify(coords: list[tuple[float, float]], tolerance_m: float) -> list[tuple[float, float]]:
    """Douglas-Peucker em metros (iterativo). Mantém primeiro e último."""
    if len(coords) < 3:
        return list(coords)
    xy = [to_xy(lon, lat) for lon, lat in coords]
    keep = [False] * len(coords)
    keep[0] = keep[-1] = True
    stack = [(0, len(coords) - 1)]
    while stack:
        a, b = stack.pop()
        (x1, y1), (x2, y2) = xy[a], xy[b]
        dx, dy = x2 - x1, y2 - y1
        seg = math.hypot(dx, dy)
        best, idx = -1.0, -1
        for i in range(a + 1, b):
            px, py = xy[i]
            d = math.hypot(px - x1, py - y1) if seg == 0 else abs(dy * (px - x1) - dx * (py - y1)) / seg
            if d > best:
                best, idx = d, i
        if best > tolerance_m:
            keep[idx] = True
            stack.extend(((a, idx), (idx, b)))
    return [c for c, k in zip(coords, keep) if k]


def bearing_deg(a: tuple[float, float], b: tuple[float, float]) -> float:
    """Azimute de a para b (lon, lat), 0 = norte."""
    (x1, y1), (x2, y2) = to_xy(*a), to_xy(*b)
    return (math.degrees(math.atan2(x2 - x1, y2 - y1)) + 360) % 360
