"""Normalização de identificadores. O valor original é sempre preservado
por quem chama; aqui só se derivam chaves de junção, como texto."""

from __future__ import annotations

import re
from dataclasses import dataclass

# 003-1, 112-21, NS1-1, com sufixo opcional i/v do KMZ.
_VARIANT = re.compile(r'^(?P<base>\d{1,3}|[A-Z]{2}\d)-(?P<variant>\d{1,2})(?P<dir>[iv])?$', re.I)
# Códigos especiais sem variante (MGP-07) ou só a base (551, NS2).
_SPECIAL = re.compile(r'^[A-Z]{3}-\d{2}$')
_BASE_ONLY = re.compile(r'^(\d{1,3}|[A-Z]{2}\d)$', re.I)


@dataclass(frozen=True)
class LineCode:
    raw: str
    base: str  # chave de junção com a API: '003', 'NS1', 'MGP-07'
    variant: str | None  # '1', '21'; None quando o código não tem variante
    direction: str | None  # 'i' (ida) / 'v' (volta) quando o KMZ informa
    kind: str  # 'numbered' | 'special' | 'base_only'

    @property
    def variant_key(self) -> str:
        return self.base if self.variant is None else f'{self.base}-{self.variant}'


def base_key(raw: str) -> str:
    """Base da linha como a API normaliza: 1-3 dígitos -> 3 dígitos."""
    raw = raw.strip().upper()
    return raw.zfill(3) if raw.isdigit() and len(raw) <= 3 else raw


def parse_line_code(raw) -> LineCode | None:
    if raw is None:
        return None
    text = str(raw).strip()
    m = _VARIANT.match(text)
    if m:
        return LineCode(
            raw=text,
            base=base_key(m.group('base')),
            variant=str(int(m.group('variant'))) if m.group('variant').isdigit() else m.group('variant'),
            direction=(m.group('dir') or '').lower() or None,
            kind='numbered',
        )
    if _SPECIAL.match(text.upper()):
        return LineCode(raw=text, base=text.upper(), variant=None, direction=None, kind='special')
    if _BASE_ONLY.match(text):
        return LineCode(raw=text, base=base_key(text), variant=None, direction=None, kind='base_only')
    return None


def stop_code(raw) -> str | None:
    """Código do ponto como texto, só dígitos, sem mexer em zeros à esquerda."""
    if raw is None or isinstance(raw, bool):
        return None
    if isinstance(raw, float):
        if not raw.is_integer():
            return None
        raw = int(raw)
    text = str(raw).strip()
    return text if text.isdigit() else None


_DMS = re.compile(
    r"""^\s*(?P<deg>\d{1,3})\s*°\s*(?P<min>\d{1,2})\s*'\s*(?P<sec>\d{1,2}(?:[.,]\d+)?)\s*"?\s*(?P<hem>[NSLEOW])\s*$""",
    re.I,
)


def parse_coordinate(raw, axis: str) -> tuple[float | None, str]:
    """Graus/minutos/segundos ('16°42'26.63"S', '49° 7'11.93"O') ou decimal.

    Devolve (valor, status). `axis` é 'lat' ou 'lon'; o hemisfério precisa
    combinar com o eixo (S/N para latitude, O/W/L/E para longitude).
    """
    if raw is None:
        return None, 'ausente'
    if isinstance(raw, (int, float)) and not isinstance(raw, bool):
        value = float(raw)
        return value, 'decimal'
    text = str(raw).strip()
    try:
        return float(text.replace(',', '.')), 'decimal'
    except ValueError:
        pass
    m = _DMS.match(text)
    if not m:
        return None, f'ilegível:{text[:20]}'
    hem = m.group('hem').upper()
    if axis == 'lat' and hem not in 'NS':
        return None, f'hemisfério trocado:{hem}'
    if axis == 'lon' and hem not in 'OWLE':
        return None, f'hemisfério trocado:{hem}'
    value = int(m.group('deg')) + int(m.group('min')) / 60 + float(m.group('sec').replace(',', '.')) / 3600
    if hem in 'SOW':
        value = -value
    return value, 'dms'


# Envelope generoso da RMTC (Grande Goiânia e municípios atendidos).
RMTC_BBOX = (-17.2, -16.2, -49.8, -48.7)  # lat_min, lat_max, lon_min, lon_max


def in_rmtc(lat: float | None, lon: float | None) -> bool:
    if lat is None or lon is None:
        return False
    return RMTC_BBOX[0] <= lat <= RMTC_BBOX[1] and RMTC_BBOX[2] <= lon <= RMTC_BBOX[3]
