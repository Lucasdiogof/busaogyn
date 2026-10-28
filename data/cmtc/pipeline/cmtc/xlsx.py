"""Leitor mínimo de XLSX só com a biblioteca padrão (zip + XML).

Devolve os valores crus de cada célula: texto como `str`, números como
`float`/`int`, sem aplicar formato. Datas e horas chegam como número serial
do Excel; quem lê decide se é hora (ver `excel_time`). Células mescladas são
informadas em `merged`, nunca propagadas automaticamente.
"""

from __future__ import annotations

import re
import zipfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field

_NS = {
    'm': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main',
    'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
    'rel': 'http://schemas.openxmlformats.org/package/2006/relationships',
}
_CELL_REF = re.compile(r'^([A-Z]+)(\d+)$')


def col_index(letters: str) -> int:
    """'A' -> 0, 'Z' -> 25, 'AA' -> 26."""
    n = 0
    for ch in letters:
        n = n * 26 + (ord(ch) - 64)
    return n - 1


def col_letters(index: int) -> str:
    index += 1
    out = ''
    while index:
        index, rem = divmod(index - 1, 26)
        out = chr(65 + rem) + out
    return out


@dataclass
class Sheet:
    name: str
    hidden: bool
    # (linha, coluna) zero-based -> valor
    cells: dict[tuple[int, int], object] = field(default_factory=dict)
    merged: list[str] = field(default_factory=list)

    @property
    def max_row(self) -> int:
        return max((r for r, _ in self.cells), default=-1) + 1

    @property
    def max_col(self) -> int:
        return max((c for _, c in self.cells), default=-1) + 1

    def row(self, r: int) -> list[object]:
        return [self.cells.get((r, c)) for c in range(self.max_col)]

    def rows(self):
        for r in range(self.max_row):
            yield self.row(r)


def _text(node) -> str:
    # Rich text: junta todos os <t>, inclusive dentro de <r>.
    return ''.join(t.text or '' for t in node.iter(f'{{{_NS["m"]}}}t'))


def _number(raw: str):
    try:
        return int(raw)
    except ValueError:
        return float(raw)


def read_workbook(path: str) -> list[Sheet]:
    with zipfile.ZipFile(path) as zf:
        names = set(zf.namelist())
        shared: list[str] = []
        if 'xl/sharedStrings.xml' in names:
            root = ET.fromstring(zf.read('xl/sharedStrings.xml'))
            shared = [_text(si) for si in root.findall('m:si', _NS)]

        rels = ET.fromstring(zf.read('xl/_rels/workbook.xml.rels'))
        targets = {
            rel.get('Id'): rel.get('Target')
            for rel in rels.findall('rel:Relationship', _NS)
        }
        workbook = ET.fromstring(zf.read('xl/workbook.xml'))
        sheets: list[Sheet] = []
        for node in workbook.find('m:sheets', _NS):
            rid = node.get(f'{{{_NS["r"]}}}id')
            target = targets[rid].lstrip('/')
            if not target.startswith('xl/'):
                target = 'xl/' + target
            sheet = Sheet(
                name=node.get('name'),
                hidden=node.get('state') in ('hidden', 'veryHidden'),
            )
            root = ET.fromstring(zf.read(target))
            for c in root.iter(f'{{{_NS["m"]}}}c'):
                match = _CELL_REF.match(c.get('r', ''))
                if not match:
                    continue
                r = int(match.group(2)) - 1
                col = col_index(match.group(1))
                kind = c.get('t')
                v = c.find('m:v', _NS)
                if kind == 'inlineStr':
                    value = _text(c)
                elif v is None or v.text is None:
                    continue
                elif kind == 's':
                    value = shared[int(v.text)]
                elif kind in ('str', 'e'):
                    value = v.text
                elif kind == 'b':
                    value = v.text == '1'
                else:
                    value = _number(v.text)
                if isinstance(value, str) and value.strip() == '':
                    continue
                sheet.cells[(r, col)] = value
            merges = root.find('m:mergeCells', _NS)
            if merges is not None:
                sheet.merged = [m.get('ref') for m in merges]
            sheets.append(sheet)
        return sheets


def excel_time(value) -> str | None:
    """Fração de dia do Excel (0 <= x < 2) -> 'HH:MM'. Outros valores: None.

    Horas após a meia-noite da mesma operação podem vir como 1.0x; viram
    '24:MM'... para preservar a ordem da grade (convenção GTFS).
    """
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    if not 0 <= value < 2:
        return None
    minutes = round(value * 24 * 60)
    return f'{minutes // 60:02d}:{minutes % 60:02d}'
