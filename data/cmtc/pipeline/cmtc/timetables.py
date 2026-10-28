"""Quadros de horários normalizados a partir das abas OSO (schedules.py).

Regras (ver docs/BUSAOGYN_2_0_FASE_4_HORARIOS_E_PARADAS.md §3):
- cada partida mantém arquivo, aba e linha da planilha de origem;
- a variante só é associada quando o código da planilha é IDÊNTICO a uma
  variante do cadastro; caso contrário fica `variant_key=None` e o código cru;
- o horário vira minutos desde o início do dia de operação ('24:10' = 1450,
  dia seguinte), preservando a ordem da grade;
- nada é descartado: duplicidades e partidas fora de ordem são marcadas;
- a planilha NÃO informa o sentido nem o local de partida; nenhum dos dois é
  atribuído aqui;
- a vigência nunca é presumida: a CMTC não a confirmou (ver `classify_validity`).
"""

from __future__ import annotations

import collections
import datetime as dt
import os
import re
from dataclasses import dataclass, field

from .ids import parse_line_code
from .schedules import ScheduleSheet

# Classes de validade, da mais forte para a mais fraca.
CONFIRMED = 'confirmed'  # vigência confirmada pela fonte (registrada à mão em CONFIRMED_SHEETS)
RECENT = 'recent'  # referência no ano da entrega; vigência NÃO confirmada
OLD = 'old'  # referência anterior ao ano da entrega
INSUFFICIENT = 'insufficient'  # sem data, data futura, sem partidas ou em conflito

# Abas cuja vigência a CMTC confirmou por escrito: 'arquivo:aba' -> referência
# do documento. Vazio enquanto não houver confirmação (Ofício 728/2026 não a dá).
CONFIRMED_SHEETS: dict[str, str] = {}

TRIP_KINDS = {'VG', 'MVGI', 'MVGV'}


def to_minutes(hhmm: str | None) -> int | None:
    """'05:10' -> 310; '24:10' -> 1450 (após a meia-noite, mesmo dia de operação)."""
    m = re.fullmatch(r'(\d{1,2}):(\d{2})', hhmm or '')
    if not m or int(m.group(2)) > 59 or int(m.group(1)) > 47:
        return None
    return int(m.group(1)) * 60 + int(m.group(2))


def source_label(file: str) -> str:
    """'Araguaia_ .xlsx' -> 'Araguaia'. É o nome do arquivo (grupo/terminal que
    publica a planilha), não o local de partida."""
    return re.sub(r'[_\s]+$', '', os.path.splitext(file)[0]).strip()


def classify_validity(sheet_date: str | None, delivered: str, *, has_departures: bool,
                      conflict: bool, confirmed_by: str | None = None) -> tuple[str, str]:
    """(classe, motivo). Data de 2026 sozinha NÃO confirma vigência."""
    if conflict:
        return INSUFFICIENT, 'mesma linha em abas diferentes com horários diferentes'
    if not has_departures:
        return INSUFFICIENT, 'aba sem partidas legíveis'
    if sheet_date is None:
        return INSUFFICIENT, 'aba sem data legível'
    if sheet_date > delivered:
        return INSUFFICIENT, f'data da aba ({sheet_date}) posterior à entrega ({delivered})'
    if confirmed_by:
        return CONFIRMED, f'vigência confirmada: {confirmed_by}'
    if sheet_date[:4] == delivered[:4]:
        return RECENT, f'referência {sheet_date}; vigência não confirmada pela CMTC'
    return OLD, f'referência {sheet_date}, anterior a {delivered[:4]}'


@dataclass
class Trip:
    day_type: str
    minutes: int
    variant_raw: str | None
    variant_key: str | None  # só com código idêntico ao do cadastro
    kind: str | None
    row: int
    duplicate: bool = False  # mesma (dia, variante, hora, tipo) já vista na aba
    out_of_order: bool = False  # anterior à partida da linha de cima no mesmo bloco


@dataclass
class Timetable:
    id: str  # 'arquivo:aba' (proveniência)
    file: str
    sheet: str
    source: str
    line: str | None
    line_name: str | None
    sheet_date: str | None
    oso: str | None
    validity: str
    validity_reason: str
    trips: list[Trip] = field(default_factory=list)
    issues: list[str] = field(default_factory=list)


def build_timetables(sheets: list[ScheduleSheet], variant_keys: set[str], delivered: str,
                     confirmed: dict[str, str] | None = None) -> list[Timetable]:
    """Uma entrada por aba visível com layout reconhecido. Abas ocultas ou
    desconhecidas também entram, com classe `insufficient` e o motivo."""
    confirmed = CONFIRMED_SHEETS if confirmed is None else confirmed
    out: list[Timetable] = []
    for sh in sheets:
        pc = parse_line_code(sh.line_number)
        line = pc.base if pc else None
        tt = Timetable(
            id=f'{sh.file}:{sh.sheet}', file=sh.file, sheet=sh.sheet, source=source_label(sh.file),
            line=line, line_name=sh.line_name, sheet_date=sh.sheet_date, oso=sh.oso,
            validity=INSUFFICIENT, validity_reason='', issues=list(sh.issues),
        )
        if sh.hidden:
            tt.issues.append('aba oculta (rascunho?)')
        seen = set()
        last = {}
        for d in sh.departures:
            minutes = to_minutes(d.time)
            if minutes is None:
                tt.issues.append(f'horário fora do padrão {d.time!r} (linha {d.row})')
                continue
            vc = parse_line_code(d.variant_code)
            key = vc.variant_key if vc and vc.variant_key in variant_keys else None
            if d.variant_code and key is None:
                tt.issues.append(f'variante {d.variant_code} sem registro idêntico no cadastro')
            if vc and line and vc.base != line:
                tt.issues.append(f'partida da linha {vc.base} na aba da linha {line} (linha {d.row})')
            kind = d.trip_kind if d.trip_kind in TRIP_KINDS else None
            if d.trip_kind and kind is None:
                tt.issues.append(f'tipo de viagem desconhecido {d.trip_kind!r} (linha {d.row})')
            trip = Trip(d.day_type, minutes, d.variant_code, key, kind, d.row)
            sig = (d.day_type, d.variant_code, minutes, kind)
            trip.duplicate = sig in seen
            seen.add(sig)
            prev = last.get(d.day_type)
            trip.out_of_order = prev is not None and minutes < prev
            last[d.day_type] = minutes
            tt.trips.append(trip)
        dups = sum(t.duplicate for t in tt.trips)
        if dups:
            tt.issues.append(f'{dups} partida(s) duplicada(s) mantida(s) e marcada(s)')
        disorder = sum(t.out_of_order for t in tt.trips)
        if disorder:
            tt.issues.append(f'{disorder} partida(s) fora de ordem na planilha')
        out.append(tt)

    # Conflito: mesma linha em mais de uma aba utilizável.
    by_line = collections.defaultdict(list)
    for tt in out:
        if tt.line and tt.trips and 'aba oculta (rascunho?)' not in tt.issues:
            by_line[tt.line].append(tt)
    conflicting = set()
    for line, tts in by_line.items():
        if len(tts) > 1:
            sigs = {tuple(sorted((t.day_type, t.variant_raw, t.minutes, t.kind) for t in x.trips)) for x in tts}
            if len(sigs) > 1:
                conflicting.update(x.id for x in tts)
            for x in tts:
                x.issues.append(f'linha {line} também em ' + ', '.join(y.id for y in tts if y is not x))

    for tt in out:
        hidden = 'aba oculta (rascunho?)' in tt.issues
        tt.validity, tt.validity_reason = classify_validity(
            tt.sheet_date, delivered, has_departures=bool(tt.trips) and not hidden,
            conflict=tt.id in conflicting, confirmed_by=confirmed.get(tt.id))
        if hidden:
            tt.validity_reason = 'aba oculta (rascunho?)'
    return out


def delivered_date(folder_name: str) -> str:
    """'Planilhas ... _ 28-10-2026' -> '2026-10-28' (data de entrega no nome da pasta)."""
    m = re.search(r'(\d{2})-(\d{2})-(\d{4})', folder_name)
    if not m:
        raise ValueError(f'pasta sem data de entrega: {folder_name!r}')
    return dt.date(int(m.group(3)), int(m.group(2)), int(m.group(1))).isoformat()
