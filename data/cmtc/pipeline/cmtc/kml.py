"""Leitura de KMZ/KML (Google Earth) só com a biblioteca padrão.

Cada Placemark vira um `Feature` com o caminho de pastas/documentos onde
está, o nome cru e a geometria (lista de (lon, lat)). Nada é renomeado aqui.
"""

from __future__ import annotations

import zipfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass

KML = '{http://www.opengis.net/kml/2.2}'
_CONTAINERS = {KML + 'Folder', KML + 'Document'}


@dataclass
class Feature:
    path: tuple[str, ...]  # nomes das pastas, de fora para dentro
    name: str | None
    kind: str  # 'LineString' | 'Point' | outro
    coords: list[tuple[float, float]]
    parts: int  # quantas geometrias o Placemark tinha
    invalid_coords: int  # tuplas que não puderam ser lidas


def parse_coordinates(text: str | None) -> tuple[list[tuple[float, float]], int]:
    coords: list[tuple[float, float]] = []
    invalid = 0
    for token in (text or '').split():
        parts = token.split(',')
        try:
            coords.append((float(parts[0]), float(parts[1])))
        except (IndexError, ValueError):
            invalid += 1
    return coords, invalid


def read_kml_bytes(data: bytes) -> list[Feature]:
    root = ET.fromstring(data)
    out: list[Feature] = []

    def walk(node, path):
        for child in node:
            if child.tag in _CONTAINERS:
                name = child.findtext(KML + 'name')
                walk(child, path + ((name or '').strip(),))
            elif child.tag == KML + 'Placemark':
                geoms = [
                    g for g in child.iter()
                    if g.tag in (KML + 'LineString', KML + 'Point', KML + 'Polygon')
                ]
                coords: list[tuple[float, float]] = []
                invalid = 0
                for g in geoms:
                    c, bad = parse_coordinates(g.findtext('.//' + KML + 'coordinates'))
                    coords.extend(c)
                    invalid += bad
                name = child.findtext(KML + 'name')
                out.append(Feature(
                    path=path,
                    name=name.strip() if name else None,
                    kind=geoms[0].tag.replace(KML, '') if geoms else 'none',
                    coords=coords,
                    parts=len(geoms),
                    invalid_coords=invalid,
                ))

    walk(root, ())
    return out


def read_kmz(path: str) -> list[Feature]:
    with zipfile.ZipFile(path) as zf:
        kmls = [n for n in zf.namelist() if n.lower().endswith('.kml')]
        features: list[Feature] = []
        for name in kmls:
            features.extend(read_kml_bytes(zf.read(name)))
        return features
