"""Extração das quatro bases cadastrais da CMTC em registros simples.

Cada registro guarda `source` (arquivo, aba, linha da planilha ou nome do
Placemark) para que todo valor derivado possa ser rastreado ao original.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from .geo import length_m
from .ids import LineCode, base_key, in_rmtc, parse_coordinate, parse_line_code, stop_code
from .kml import read_kmz
from .schedules import excel_date
from .xlsx import read_workbook

# --------------------------------------------------------------------------
# Cadastro Geral das Linhas


def _clean(v):
    if isinstance(v, str):
        v = re.sub(r'[ \t]+', ' ', v).strip()
        return v or None
    return v


def _lines_list(v) -> list[str]:
    return [s.strip() for s in str(v).split('\n') if s.strip()] if v else []


@dataclass
class LineRecord:
    code: LineCode | None
    raw_code: str
    name: str | None
    status: str | None
    characteristic: str | None  # Principal / Sublinha / Especial
    city: str | None
    area: str | None
    origin: str | None
    destination: str | None
    lot: object
    company_1: str | None
    company_2: str | None
    subsystem: str | None
    type: str | None
    form: str | None
    km_outbound: float | None
    km_inbound: float | None
    km_total: float | None
    vehicle_type: str | None
    integration_raw: object
    streets_outbound: list[str]
    districts_outbound: list[str]
    streets_inbound: list[str]
    districts_inbound: list[str]
    valid_from: str | None
    valid_from_raw: object
    source_row: int


def _num(v):
    if isinstance(v, (int, float)) and not isinstance(v, bool):
        return float(v)
    try:
        return float(str(v).replace(',', '.'))
    except (TypeError, ValueError):
        return None


def read_lines(path: str) -> tuple[list[LineRecord], dict]:
    sheets = {s.name.strip(): s for s in read_workbook(path)}
    sheet = sheets['Cadastro GERAL']
    header_row = next(r for r in range(sheet.max_row) if str(sheet.cells.get((r, 0), '')).strip() == 'NÚMERO')
    headers = [re.sub(r'\s+', ' ', str(h)).strip() if h is not None else None for h in sheet.row(header_row)]
    col = {h: i for i, h in enumerate(headers) if h}
    out = []
    for r in range(header_row + 1, sheet.max_row):
        row = sheet.row(r)
        raw = row[col['NÚMERO']]
        if raw is None:
            continue
        g = lambda name: _clean(row[col[name]]) if name in col else None  # noqa: E731
        vig = row[col['Data de Vigência']] if 'Data de Vigência' in col else None
        out.append(LineRecord(
            code=parse_line_code(raw),
            raw_code=str(raw).strip(),
            name=g('DENOMINAÇÃO'),
            status=g('STATUS DA LINHA'),
            characteristic=g('CARACTERÍSTICA'),
            city=g('CIDADE DE ATENDIMENTO'),
            area=g('ÁREA OPERACIONAL'),
            origin=g('ORIGEM LOCAL - 1'),
            destination=g('DESTINO LOCAL - 2'),
            lot=row[col['LOTE-1']],
            company_1=g('Empresa 1'),
            company_2=g('Empresa 2'),
            subsystem=g('SUBSISTEMA'),
            type=g('TIPO'),
            form=g('FORMA'),
            km_outbound=_num(row[col['KM IDA']]),
            km_inbound=_num(row[col['KM VOLTA']]),
            km_total=_num(row[col['EXTENSÃO TOTAL']]),
            vehicle_type=g('TIPO VEÍCULO'),
            integration_raw=row[col['INTEGRAÇÃO']],
            streets_outbound=_lines_list(row[col['LOGRADOURO - IDA']]),
            districts_outbound=_lines_list(row[col['BAIRRO - IDA']]),
            streets_inbound=_lines_list(row[col['LOGRADOURO - VOLTA']]),
            districts_inbound=_lines_list(row[col['BAIRRO - VOLTA']]),
            valid_from=excel_date(vig),
            valid_from_raw=vig,
            source_row=r + 1,
        ))
    meta = {
        'sheets': [(s.name, s.hidden, s.max_row, s.max_col) for s in sheets.values()],
        'header_row': header_row + 1,
        'headers': headers,
    }
    return out, meta


# --------------------------------------------------------------------------
# Cadastro Geral dos Pontos


@dataclass
class StopRecord:
    stop_id: str
    kind: str | None  # TIPO do logradouro
    street: str | None
    reference: str | None
    number: object
    block: object
    lot: object
    locality: str | None
    district: str | None
    city: str | None
    direction_label: str | None  # coluna SENTIDO (texto livre)
    arc: str | None
    lat: float | None
    lon: float | None
    coord_status: str
    lat_raw: object
    lon_raw: object
    status: str | None
    model: str | None
    module: str | None
    structure: str | None
    lines_raw: list[object]
    lines: list[str]  # base da linha normalizada ('027', 'NS1')
    total_lines_declared: object
    registered_raw: object
    year: object
    source_row: int
    issues: list[str] = field(default_factory=list)


def read_stops(path: str) -> tuple[list[StopRecord], dict]:
    sheets = {s.name.strip(): s for s in read_workbook(path)}
    sheet = sheets['Cadastro']
    header_row = next(r for r in range(sheet.max_row) if str(sheet.cells.get((r, 0), '')).strip() == 'ID')
    headers = [re.sub(r'\s+', ' ', str(h)).strip() if h is not None else None for h in sheet.row(header_row)]
    col = {h: i for i, h in enumerate(headers) if h}
    line_cols = [i for i, h in enumerate(headers) if h and h.startswith('LINHA')]
    out = []
    for r in range(header_row + 1, sheet.max_row):
        row = sheet.row(r)
        sid = stop_code(row[col['ID']])
        if sid is None:
            continue
        g = lambda name: _clean(row[col[name]]) if name in col else None  # noqa: E731
        issues = []
        lat, s_lat = parse_coordinate(row[col['LATITUDE']], 'lat')
        lon, s_lon = parse_coordinate(row[col['LONGITUDE']], 'lon')
        if lat is not None and lon is not None and not in_rmtc(lat, lon):
            issues.append('coordenada fora da RMTC')
        if s_lat != s_lon:
            issues.append(f'formatos diferentes lat={s_lat} lon={s_lon}')
        coord_status = 'ok' if lat is not None and lon is not None and not issues else (
            'ausente' if lat is None and lon is None else 'inválida')
        raw_lines = [row[i] for i in line_cols if row[i] is not None]
        lines = []
        for v in raw_lines:
            code = parse_line_code(v)
            key = code.base if code else None
            if key is None:
                issues.append(f'código de linha ilegível: {v!r}')
            elif key not in lines:
                lines.append(key)
        declared = row[col['TOTAL DE LINHAS']] if 'TOTAL DE LINHAS' in col else None
        if isinstance(declared, int) and declared != len(raw_lines):
            issues.append(f'TOTAL DE LINHAS={declared} mas {len(raw_lines)} colunas preenchidas')
        out.append(StopRecord(
            stop_id=sid, kind=g('TIPO'), street=g('LOGRADOURO'), reference=g('REFEREN/CIA'),
            number=row[col['Nº']], block=row[col['QD.']], lot=row[col['LT.']],
            locality=g('LOCAL'), district=g('BAIRRO'), city=g('MUNICIPIO'),
            direction_label=g('SENTIDO'), arc=g('ARCO'),
            lat=lat if coord_status == 'ok' else None, lon=lon if coord_status == 'ok' else None,
            coord_status=coord_status, lat_raw=row[col['LATITUDE']], lon_raw=row[col['LONGITUDE']],
            status=g('SITUAÇÃO'), model=g('MODELO DO PED'), module=g('MÓDULO'), structure=g('ESTRUTURA'),
            lines_raw=raw_lines, lines=lines, total_lines_declared=declared,
            registered_raw=row[col['DATA DO CADASTRO']], year=row[col['ANO']],
            source_row=r + 1, issues=issues,
        ))
    meta = {
        'sheets': [(s.name, s.hidden, s.max_row, s.max_col) for s in sheets.values()],
        'header_row': header_row + 1,
        'headers': headers,
    }
    return out, meta


# --------------------------------------------------------------------------
# KMZ de trajetos

# '003-1i - DESCRIÇÃO - IDA'; o código vai até o primeiro espaço. A segunda
# forma cobre nomes sem espaço antes do hífen ('113-2v- ...').
_NAME = re.compile(
    r'^\s*(?P<code>\S+)\s+-\s*(?P<desc>.*)$'
    r'|^\s*(?P<code2>[0-9A-Za-z]+(?:-\d+[iv]?)?)\s*-\s*(?P<desc2>.*)$'
)


@dataclass
class ShapeRecord:
    shape_id: str  # nome original completo (+ #n se repetido)
    raw_name: str
    folder: tuple[str, ...]
    code: LineCode | None
    description: str
    direction: str | None  # 'i'/'v' (sufixo) ou derivado do texto
    direction_source: str  # 'sufixo' | 'texto' | 'ausente'
    direction_conflict: bool
    coords: list[tuple[float, float]]
    length_m: float
    points: int
    out_of_area_points: int
    duplicate_consecutive: int
    closed: bool  # início ~ fim (< 100 m)
    issues: list[str] = field(default_factory=list)


def _text_direction(desc: str) -> str | None:
    u = desc.upper()
    if re.search(r'\bIDA\b', u):
        return 'i'
    if re.search(r'\bVOLTA\b', u):
        return 'v'
    return None


def read_shapes(path: str) -> list[ShapeRecord]:
    seen: dict[str, int] = {}
    out = []
    for f in read_kmz(path):
        if f.kind != 'LineString':
            continue
        raw = f.name or ''
        m = _NAME.match(raw)
        code_text = (m.group('code') or m.group('code2')) if m else None
        code = parse_line_code(code_text) if code_text else None
        desc = (m.group('desc') if m.group('code') else m.group('desc2')).strip() if m else raw
        text_dir = _text_direction(desc)
        suffix_dir = code.direction if code else None
        direction = suffix_dir or text_dir
        issues = []
        if code is None:
            issues.append('código de linha ilegível no nome')
        conflict = bool(suffix_dir and text_dir and suffix_dir != text_dir)
        if conflict:
            issues.append('sufixo i/v diverge de IDA/VOLTA no texto')
        n = seen.get(raw, 0)
        seen[raw] = n + 1
        coords = f.coords
        dup = sum(1 for a, b in zip(coords, coords[1:]) if a == b)
        oob = sum(1 for lon, lat in coords if not in_rmtc(lat, lon))
        if len(coords) < 2:
            issues.append('geometria com menos de 2 pontos')
        if oob:
            issues.append(f'{oob} vértices fora da RMTC')
        if f.invalid_coords:
            issues.append(f'{f.invalid_coords} coordenadas ilegíveis')
        closed = len(coords) > 1 and _close(coords[0], coords[-1])
        out.append(ShapeRecord(
            shape_id=raw if n == 0 else f'{raw}#{n + 1}',
            raw_name=raw,
            folder=f.path,
            code=code,
            description=desc,
            direction=direction,
            direction_source='sufixo' if suffix_dir else ('texto' if text_dir else 'ausente'),
            direction_conflict=conflict,
            coords=coords,
            length_m=length_m(coords),
            points=len(coords),
            out_of_area_points=oob,
            duplicate_consecutive=dup,
            closed=closed,
            issues=issues,
        ))
    return out


def _close(a, b) -> bool:
    from .geo import haversine_m
    return haversine_m(a, b) < 100


# --------------------------------------------------------------------------
# KMZ de pontos


@dataclass
class StopPoint:
    stop_id: str | None
    raw_name: str
    label: str | None
    folder: tuple[str, ...]
    lon: float | None
    lat: float | None
    issues: list[str] = field(default_factory=list)


def read_stop_points(path: str) -> list[StopPoint]:
    out = []
    for f in read_kmz(path):
        if f.kind != 'Point':
            continue
        raw = f.name or ''
        m = re.match(r'^\s*(\d+)\s*(?:-\s*(.*))?$', raw)
        issues = []
        lon, lat = (f.coords[0] if f.coords else (None, None))
        if lat is None or not in_rmtc(lat, lon):
            issues.append('coordenada ausente ou fora da RMTC')
        if m is None:
            issues.append('nome sem código numérico')
        out.append(StopPoint(
            stop_id=m.group(1) if m else None,
            raw_name=raw,
            label=(m.group(2) or '').strip() or None if m else None,
            folder=f.path,
            lon=lon,
            lat=lat,
            issues=issues,
        ))
    return out


__all__ = [
    'LineRecord', 'StopRecord', 'ShapeRecord', 'StopPoint',
    'read_lines', 'read_stops', 'read_shapes', 'read_stop_points', 'base_key',
]
