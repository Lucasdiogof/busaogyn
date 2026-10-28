"""Estações de corredor (Eixo Anhanguera, BRT Norte-Sul) e terminais.

Nada aqui é relação oficial ponto-linha (a CMTC não a entregou para
estações nem terminais). Cada associação é INFERIDA e carrega a evidência:

- Estação → corredor: pasta oficial do KMZ de pontos ("EIXO ANHANGUERA",
  "ESTAÇÕES BRT NORTE SUL"). Oficial.
- Linha → corredor: arquivo de planilha horária do corredor ("Eixo
  Anhanguera_.xlsx", "BRT Norte-Sul_.xlsx") ou denominação "Eixo Anhanguera /
  …" no cadastro. Oficial.
- Linha que NÃO para nas estações: tipo "Direta" no cadastro, "Direto" ou
  "Semiexpresso" na denominação → fica fora (passar perto não é parar).
- Estação → trajeto: a até STATION_MAX_M do trajeto oficial da linha do mesmo
  corredor (geometria). Sozinha a geometria NÃO basta; junto com as duas
  relações oficiais acima, vira associação inferida utilizável.
- Terminal: nome "T. X" no 1º/último trecho da denominação oficial da
  variante + extremo do trajeto oficial. Posição = mediana dos extremos que
  concordam (até TERMINAL_MAX_M); exige TERMINAL_MIN_SUPPORT extremos.
"""

from __future__ import annotations

import os
import re
import statistics
import unicodedata
from dataclasses import dataclass, field

from .geo import haversine_m
from .schedules import parse_sheet
from .xlsx import read_workbook

STATION_MAX_M = 30.0
TERMINAL_MAX_M = 300.0
TERMINAL_MIN_SUPPORT = 3

CORRIDOR_FOLDERS = {'EIXO ANHANGUERA': 'eixo', 'ESTAÇÕES BRT NORTE SUL.kmz': 'brt'}
CORRIDOR_SCHEDULES = {'Eixo Anhanguera_.xlsx': 'eixo', 'BRT Norte-Sul_.xlsx': 'brt'}
_NON_STOPPING = re.compile(r'\b(DIRETO|DIRETA|SEMIEXPRESSO|SEMI EXPRESSO|EXPRESSO)\b')


def _ascii(text) -> str:
    return unicodedata.normalize('NFKD', str(text or '').upper()).encode('ascii', 'ignore').decode()


@dataclass
class Station:
    stop_id: str
    corridor: str  # 'eixo' | 'brt'
    name: str  # rótulo do KMZ
    group: str  # mesma estação (plataformas com o mesmo nome no corredor)
    lon: float
    lat: float


def station_group(label: str | None) -> str:
    """'AV. ANHANGUERA (PLATAFORMA PALMITO)' -> 'PLATAFORMA PALMITO'."""
    m = re.search(r'\(([^)]+)\)', label or '')
    return re.sub(r'\s+', ' ', _ascii(m.group(1) if m else label)).strip()


def read_stations(points) -> list[Station]:
    out = []
    for p in points:
        folder = next((CORRIDOR_FOLDERS[f] for f in (p.folder or ()) if f in CORRIDOR_FOLDERS), None)
        if folder is None or not p.stop_id or p.lat is None or p.issues:
            continue
        out.append(Station(p.stop_id, folder, p.label or p.stop_id, f'{folder}:{station_group(p.label)}', p.lon, p.lat))
    return out


@dataclass
class CorridorLine:
    corridor: str
    stops_at_stations: bool
    evidence: list[str] = field(default_factory=list)


def corridor_lines(lines, schedules_dir: str | None = None) -> dict[str, CorridorLine]:
    """base da linha -> corredor, com a evidência oficial e se para nas
    estações (linhas diretas/expressas/semiexpressas não param)."""
    out: dict[str, CorridorLine] = {}
    names = {}
    if schedules_dir and os.path.isdir(schedules_dir):
        for file, corridor in CORRIDOR_SCHEDULES.items():
            path = os.path.join(schedules_dir, file)
            if not os.path.exists(path):
                continue
            for sh in read_workbook(path):
                p = parse_sheet(sh, file)
                if p.hidden or not p.line_number:
                    continue
                base = str(p.line_number).strip().upper()
                base = base.zfill(3) if base.isdigit() else base
                out.setdefault(base, CorridorLine(corridor, True)).evidence.append(f'planilha {file}')
                names.setdefault(base, []).append(p.line_name)
    for l in lines:
        if _ascii(l.name).startswith('EIXO ANHANGUERA'):
            out.setdefault(l.code.base, CorridorLine('eixo', True)).evidence.append('denominação do cadastro')
        if l.code.base in out:
            names.setdefault(l.code.base, []).append(l.name)
            if _ascii(l.type) == 'DIRETA':
                names[l.code.base].append('DIRETA')
    for base, c in out.items():
        if any(_NON_STOPPING.search(_ascii(n)) for n in names.get(base, [])):
            c.stops_at_stations = False
        c.evidence = sorted(set(c.evidence))
    return out


@dataclass
class Terminal:
    id: str  # 'T-BIBLIA'
    name: str  # como na denominação oficial mais frequente: 'T. Bíblia'
    lon: float
    lat: float
    support: int  # extremos de trajeto que concordam


_ALIAS = {'PE': 'PADRE', 'PQ': 'PARQUE', 'SEN': 'SENADOR', 'REC': 'RECANTO', 'PCA': 'PRACA', 'STA': 'SANTA', 'VL': 'VILA'}
_STOP_WORDS = {'DO', 'DA', 'DE', 'DOS', 'DAS'}


def terminal_key(segment: str | None) -> str | None:
    """'T. Pe. Pelágio' -> 'PADRE PELAGIO'; 'T. Bíblia - Via Alpes' -> 'BIBLIA'.
    None se o trecho não nomeia um terminal."""
    t = _ascii(segment).strip()
    m = re.match(r'^(?:T\.|T |TERMINAL )\s*(.+)$', t)
    if not m:
        return None
    body = re.split(r'\s+-\s+|\bVIA\b', m.group(1))[0]
    words = [_ALIAS.get(w, w) for w in re.sub(r'[^A-Z0-9 ]', ' ', body).split()]
    key = ' '.join(w for w in words if w not in _STOP_WORDS)
    return key or None


def shape_terminals(variant_name: str | None, direction: str | None) -> tuple[str | None, str | None]:
    """(terminal no início, terminal no fim) do trajeto pela denominação."""
    segs = [s for s in (variant_name or '').split('/') if s.strip()]
    if len(segs) < 2 or direction not in ('i', 'v'):
        return None, None
    first, last = terminal_key(segs[0]), terminal_key(segs[-1])
    return (first, last) if direction == 'i' else (last, first)


def find_terminals(shapes, variant_names: dict[str, str]) -> dict[str, Terminal]:
    ends: dict[str, list[tuple[float, float]]] = {}
    raw_names: dict[str, list[str]] = {}
    for sh in shapes:
        if not sh.code or len(sh.coords) < 2:
            continue
        name = variant_names.get(sh.code.variant_key)
        start, end = shape_terminals(name, sh.direction)
        for key, point in ((start, sh.coords[0]), (end, sh.coords[-1])):
            if key:
                ends.setdefault(key, []).append(point)
        for seg in (name or '').split('/'):
            key = terminal_key(seg)
            if key:
                raw_names.setdefault(key, []).append(re.split(r'\s+-\s+', seg.strip())[0])
    out = {}
    for key, pts in ends.items():
        lon = statistics.median(p[0] for p in pts)
        lat = statistics.median(p[1] for p in pts)
        agree = [p for p in pts if haversine_m((lon, lat), p) <= TERMINAL_MAX_M]
        if len(agree) < TERMINAL_MIN_SUPPORT:
            continue
        lon = statistics.median(p[0] for p in agree)
        lat = statistics.median(p[1] for p in agree)
        names = raw_names.get(key) or [key]
        out[key] = Terminal('T-' + key.replace(' ', '-'), max(set(names), key=names.count), lon, lat, len(agree))
    return out
