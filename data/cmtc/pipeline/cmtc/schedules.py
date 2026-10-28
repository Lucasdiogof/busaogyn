"""Planilhas horárias por terminal (CMTC, Anexo II das OSO).

As 303 abas recebidas em 28/10/2026 seguem um único gabarito, mas o parser
não depende de linhas/colunas fixas: localiza os rótulos ("Nº de Ordem",
"Horários", "DIA ÚTIL"/"SÁBADO"/"DOMINGO", " Linha:", "Data:", "OSO") e
lê a partir deles. Aba que não tem os rótulos vira `layout='desconhecido'`
e não produz horários (nunca adivinha).
"""

from __future__ import annotations

import datetime as dt
import re
from dataclasses import dataclass, field

from .xlsx import Sheet, excel_time

DAY_TYPES = {
    'DIA ÚTIL': 'weekday',
    'SÁBADO': 'saturday',
    'DOMINGO': 'sunday_holiday',
}
_EXCEL_EPOCH = dt.date(1899, 12, 30)


def excel_date(value) -> str | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    if not 30000 < value < 80000:  # 1982..2119: fora disso não é data plausível
        return None
    return (_EXCEL_EPOCH + dt.timedelta(days=int(value))).isoformat()


def norm(text) -> str:
    return re.sub(r'\s+', ' ', str(text)).strip().upper() if text is not None else ''


@dataclass
class Departure:
    day_type: str
    order: int | None
    variant_code: str | None  # como está na planilha, ex.: '032-1'
    time: str  # 'HH:MM' (pode passar de 24:00)
    operator: str | None
    trip_kind: str | None  # 'VG', 'MVG' etc., cru
    row: int  # linha da planilha (1-based) para rastreio


@dataclass
class ScheduleSheet:
    file: str
    sheet: str
    hidden: bool
    layout: str
    line_number: str | None = None  # como texto; zeros à esquerda reconstruídos? não
    line_number_raw: object = None
    line_name: str | None = None
    oso: str | None = None
    sheet_number: str | None = None
    sheet_date: str | None = None
    group: object = None
    operators: list[str] = field(default_factory=list)
    vehicle_type: str | None = None
    operational: dict = field(default_factory=dict)
    notes: list[str] = field(default_factory=list)
    departures: list[Departure] = field(default_factory=list)
    issues: list[str] = field(default_factory=list)


def _find(sheet: Sheet, predicate):
    return [(r, c, v) for (r, c), v in sorted(sheet.cells.items()) if predicate(norm(v))]


def _right_value(sheet: Sheet, r: int, c: int, max_gap: int = 4):
    for cc in range(c + 1, c + 1 + max_gap):
        v = sheet.cells.get((r, cc))
        if v is not None:
            return v, cc
    return None, None


def parse_sheet(sheet: Sheet, file: str) -> ScheduleSheet:
    out = ScheduleSheet(file=file, sheet=sheet.name.strip(), hidden=sheet.hidden, layout='desconhecido')
    order_cells = _find(sheet, lambda t: t == 'Nº DE ORDEM')
    if not order_cells:
        out.issues.append('sem cabeçalho "Nº de Ordem"')
        return out
    header_row = order_cells[0][0]
    out.layout = 'oso-anexo-ii'

    # Identificação.
    for r, c, v in _find(sheet, lambda t: t == 'LINHA:'):
        num, cc = _right_value(sheet, r, c)
        out.line_number_raw = num
        out.line_number = None if num is None else str(num).strip()
        name, _ = _right_value(sheet, r, cc if cc is not None else c)
        out.line_name = str(name).strip() if name is not None else None
        g = _find(sheet, lambda t: t == 'GRUPO')
        if g:
            out.group, _ = _right_value(sheet, g[0][0], g[0][1])
    for r, c, v in _find(sheet, lambda t: t.startswith('OSO')):
        val, _ = _right_value(sheet, r, c)
        out.oso = None if val is None else str(val).strip()
    for r, c, v in _find(sheet, lambda t: t == 'NÚMERO DA PLANILHA:'):
        val, _ = _right_value(sheet, r, c)
        out.sheet_number = None if val is None else str(val).strip()
    for r, c, v in _find(sheet, lambda t: t == 'DATA:'):
        val, _ = _right_value(sheet, r, c)
        out.sheet_date = excel_date(val)
        if out.sheet_date is None:
            out.issues.append(f'data da planilha ilegível: {val!r}')
    for r, c, v in _find(sheet, lambda t: t == 'CONCESSIONÁRIAS:'):
        stop = sheet.max_col
        for cc in range(c + 1, sheet.max_col):
            if norm(sheet.cells.get((r, cc))) == 'TIPO DE VEÍCULO:':
                stop = cc
                val, _ = _right_value(sheet, r, cc)
                out.vehicle_type = None if val is None else str(val).strip()
                break
        out.operators = [
            str(sheet.cells[(r, cc)]).strip() for cc in range(c + 1, stop) if (r, cc) in sheet.cells
        ]

    # Dados operacionais (intervalos, frota, tempo de viagem, horário de operação).
    labels = {'SEGUNDA A SEXTA-FEIRA': 'weekday', 'SÁBADOS': 'saturday', 'DOMINGOS E FERIADOS': 'sunday_holiday'}
    for r, c, v in _find(sheet, lambda t: t in labels):
        # Dez valores na ordem do cabeçalho; '-' na planilha = sem valor.
        vals = [sheet.cells[(r, cc)] for cc in range(c + 1, sheet.max_col) if (r, cc) in sheet.cells][:10]
        if len(vals) < 10:
            out.issues.append(f'dados operacionais com {len(vals)} de 10 campos em {norm(v)}')
            continue
        nums = [x if isinstance(x, (int, float)) and not isinstance(x, bool) else None for x in vals]
        out.operational[labels[norm(v)]] = {
            'headway_peak_min': nums[0],
            'headway_offpeak_min': nums[1],
            'fleet': nums[2],
            'trip_time_peak_min': nums[3],
            'trip_time_offpeak_min': nums[4],
            'trips_day': nums[5],
            'avg_speed_kmh': None if nums[6] is None else round(nums[6], 3),
            'length_km_round_trip': nums[7],
            'service_start': excel_time(nums[8]),
            'service_end': excel_time(nums[9]),
        }

    # Blocos de horários: cada "Nº de Ordem" do cabeçalho abre um bloco; o
    # tipo de dia é o rótulo DIA ÚTIL/SÁBADO/DOMINGO acima dele.
    day_row = header_row - 1
    blocks = []
    for _, c, _ in order_cells:
        day = norm(sheet.cells.get((day_row, c)))
        day_type = DAY_TYPES.get(day)
        if day_type is None:
            out.issues.append(f'bloco na coluna {c} sem tipo de dia ({day!r})')
            continue
        cols = {}
        for cc in range(c, min(c + 6, sheet.max_col)):
            t = norm(sheet.cells.get((header_row, cc)))
            if t == 'Nº DA LINHA':
                cols['line'] = cc
            elif t == 'HORÁRIOS':
                cols['time'] = cc
            elif t == 'OPERADORA':
                cols['operator'] = cc
        if 'time' not in cols:
            out.issues.append(f'bloco {day_type} sem coluna Horários')
            continue
        # A coluna seguinte à operadora (sem rótulo) traz VG/Mvg.
        cols['kind'] = cols.get('operator', cols['time']) + 1
        blocks.append((day_type, c, cols))

    notes_row = next((r for r, c, v in _find(sheet, lambda t: t.startswith('OBS'))), sheet.max_row)
    for day_type, c, cols in blocks:
        for r in range(header_row + 1, notes_row):
            raw_time = sheet.cells.get((r, cols['time']))
            if raw_time is None:
                continue
            time = excel_time(raw_time)
            if time is None:
                out.issues.append(f'horário ilegível {raw_time!r} (linha {r + 1}, {day_type})')
                continue
            order = sheet.cells.get((r, c))
            variant = sheet.cells.get((r, cols['line'])) if 'line' in cols else None
            operator = sheet.cells.get((r, cols['operator'])) if 'operator' in cols else None
            kind = sheet.cells.get((r, cols['kind']))
            out.departures.append(Departure(
                day_type=day_type,
                order=order if isinstance(order, int) else None,
                variant_code=None if variant is None else str(variant).strip(),
                time=time,
                operator=None if operator is None else str(operator).strip(),
                trip_kind=None if kind is None else norm(kind),
                row=r + 1,
            ))

    for r in range(notes_row + 1, sheet.max_row):
        texts = [str(v).strip() for (rr, _), v in sorted(sheet.cells.items()) if rr == r and isinstance(v, str)]
        if texts:
            out.notes.append(' '.join(texts))
    return out
