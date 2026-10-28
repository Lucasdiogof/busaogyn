"""Testes dos parsers e regras de normalização. Só dados sintéticos.

    cd data/cmtc && python3 -I -m unittest discover -s pipeline/tests -v
"""

import io
import os
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from cmtc.geo import Polyline, haversine_m, simplify  # noqa: E402
from cmtc.ids import in_rmtc, parse_coordinate, parse_line_code, stop_code  # noqa: E402
from cmtc.kml import read_kml_bytes  # noqa: E402
from cmtc.schedules import excel_date, parse_sheet  # noqa: E402
from cmtc.sequence import Match, Params, assign_direction, build_sequence, street_hint  # noqa: E402
from cmtc.sources import _text_direction  # noqa: E402
from cmtc.xlsx import Sheet, col_index, col_letters, excel_time, read_workbook  # noqa: E402


class LineCodes(unittest.TestCase):
    def test_numbered_keeps_leading_zeros(self):
        c = parse_line_code('003-1')
        self.assertEqual((c.base, c.variant, c.direction, c.variant_key), ('003', '1', None, '003-1'))

    def test_kmz_suffix_and_two_digit_variant(self):
        c = parse_line_code('113-21v')
        self.assertEqual((c.base, c.variant, c.direction), ('113', '21', 'v'))
        self.assertEqual(parse_line_code('NS1-1i').base, 'NS1')

    def test_integer_from_spreadsheet_is_padded_like_the_api(self):
        self.assertEqual(parse_line_code(27).base, '027')
        self.assertEqual(parse_line_code('214').variant, None)

    def test_special_and_invalid(self):
        self.assertEqual(parse_line_code('MGP-07').kind, 'special')
        self.assertIsNone(parse_line_code('linha 3'))
        self.assertIsNone(parse_line_code(None))

    def test_text_direction(self):
        self.assertEqual(_text_direction('T. BIBLIA / X - IDA'), 'i')
        self.assertEqual(_text_direction('T. BIBLIA / X - VOLTA (L.A.)'), 'v')
        self.assertIsNone(_text_direction('(L.A.) T. BIBLIA / T. SENADOR CANEDO'))


class StopCodes(unittest.TestCase):
    def test_stop_code_is_text_and_keeps_zeros(self):
        self.assertEqual(stop_code(30402), '30402')
        self.assertEqual(stop_code('00294'), '00294')
        self.assertEqual(stop_code(12.0), '12')
        self.assertIsNone(stop_code(12.5))
        self.assertIsNone(stop_code('A12'))
        self.assertIsNone(stop_code(True))


class Coordinates(unittest.TestCase):
    def test_dms_south_west(self):
        lat, s = parse_coordinate('16°42\'26.63"S', 'lat')
        lon, _ = parse_coordinate(' 49° 7\'11.93"O', 'lon')
        self.assertEqual(s, 'dms')
        self.assertAlmostEqual(lat, -16.7073972, places=6)
        self.assertAlmostEqual(lon, -49.1199806, places=6)
        self.assertTrue(in_rmtc(lat, lon))

    def test_swapped_hemisphere_is_rejected(self):
        self.assertEqual(parse_coordinate('16°43\'42.35"S', 'lon')[0], None)
        self.assertEqual(parse_coordinate('49°15\'53.63"O', 'lat')[0], None)

    def test_decimal_and_garbage(self):
        self.assertEqual(parse_coordinate('-16.5', 'lat'), (-16.5, 'decimal'))
        self.assertEqual(parse_coordinate('KMZ', 'lon')[0], None)
        self.assertEqual(parse_coordinate(None, 'lat'), (None, 'ausente'))

    def test_out_of_area(self):
        self.assertFalse(in_rmtc(-6.6, -49.2))


class ExcelValues(unittest.TestCase):
    def test_columns(self):
        self.assertEqual(col_index('A'), 0)
        self.assertEqual(col_index('AA'), 26)
        self.assertEqual(col_letters(27), 'AB')

    def test_time_and_date(self):
        self.assertEqual(excel_time(0.20833333333333334), '05:00')
        self.assertEqual(excel_time(1.0104166666666667), '24:15')
        self.assertIsNone(excel_time(35))
        self.assertIsNone(excel_time('x'))
        self.assertEqual(excel_date(46186), '2026-06-13')
        self.assertIsNone(excel_date(12))


def _xlsx(cells, sheet_name='S1', hidden=False):
    """Monta um .xlsx mínimo em memória com strings compartilhadas e números."""
    strings = []
    rows = {}
    for ref, value in cells.items():
        row = int(''.join(ch for ch in ref if ch.isdigit()))
        if isinstance(value, str):
            if value not in strings:
                strings.append(value)
            xml = f'<c r="{ref}" t="s"><v>{strings.index(value)}</v></c>'
        else:
            xml = f'<c r="{ref}"><v>{value}</v></c>'
        rows.setdefault(row, []).append(xml)
    ns = 'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"'
    sheet = f'<worksheet {ns}><sheetData>' + ''.join(
        f'<row r="{r}">{"".join(c)}</row>' for r, c in sorted(rows.items())) + '</sheetData></worksheet>'
    state = ' state="hidden"' if hidden else ''
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w') as z:
        z.writestr('xl/workbook.xml',
                   f'<workbook {ns} xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
                   f'<sheets><sheet name="{sheet_name}" sheetId="1" r:id="rId1"{state}/></sheets></workbook>')
        z.writestr('xl/_rels/workbook.xml.rels',
                   '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                   '<Relationship Id="rId1" Target="worksheets/sheet1.xml" '
                   'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"/></Relationships>')
        z.writestr('xl/worksheets/sheet1.xml', sheet)
        z.writestr('xl/sharedStrings.xml', f'<sst {ns}>' + ''.join(f'<si><t>{s}</t></si>' for s in strings) + '</sst>')
    return buf.getvalue()


class XlsxReader(unittest.TestCase):
    def test_reads_strings_numbers_and_hidden_flag(self):
        data = _xlsx({'A1': 'NÚMERO', 'B1': 'DENOMINAÇÃO', 'A2': '003-1', 'B2': 'T. Teste', 'C2': 23.07, 'D2': 7}, hidden=True)
        with tempfile.NamedTemporaryFile(suffix='.xlsx', delete=False) as f:
            f.write(data)
        try:
            [sheet] = read_workbook(f.name)
        finally:
            os.unlink(f.name)
        self.assertTrue(sheet.hidden)
        self.assertEqual(sheet.row(1), ['003-1', 'T. Teste', 23.07, 7])
        self.assertIsInstance(sheet.cells[(1, 3)], int)


def _schedule_sheet(rows, hidden=False):
    s = Sheet(name='999', hidden=hidden)
    for (r, c), v in rows.items():
        s.cells[(r, c)] = v
    return s


class Schedules(unittest.TestCase):
    def base(self):
        cells = {
            (8, 1): ' Linha:', (8, 2): 999, (8, 3): 'T. Sintético / Bairro Fictício',
            (10, 1): 'Número da Planilha:', (10, 3): '01 - 2026', (10, 12): 'Data:', (10, 13): 46186,
            (1, 13): 'OSO:  ', (1, 14): '0001/2026',
            (9, 1): 'Concessionárias:', (9, 3): 'Operadora A', (9, 12): 'Tipo de Veículo:', (9, 14): 'Ônibus',
            (15, 1): 'Segunda a Sexta-Feira', (15, 3): 30, (15, 4): 60, (15, 6): 4, (15, 7): 40, (15, 8): 38,
            (15, 9): 20, (15, 11): 22.5, (15, 12): 13.2, (15, 13): 0.20833333333333334, (15, 14): 0.9583333333333334,
            (16, 1): 'Sábados', (16, 3): '-', (16, 4): '-', (16, 6): 0, (16, 7): '-', (16, 8): '-',
            (16, 9): '-', (16, 11): '-', (16, 12): 13.2, (16, 13): '-', (16, 14): '-',
            (19, 1): 'DIA ÚTIL', (19, 6): 'SÁBADO', (19, 11): 'DOMINGO',
            (62, 1): 'Obs.:', (63, 2): 'Mvg - Meia Viagem Início no Retorno',
        }
        for c in (1, 6, 11):
            cells.update({(20, c): 'Nº de Ordem', (20, c + 1): 'Nº da Linha', (20, c + 2): 'Horários', (20, c + 3): 'Operadora'})
        cells.update({
            (21, 1): 1, (21, 2): '999-1', (21, 3): 0.25, (21, 4): 'RA', (21, 5): 'VG',
            (22, 1): 2, (22, 2): '999-2', (22, 3): 1.0104166666666667, (22, 4): 'HP', (22, 5): 'Mvgi',
            (21, 11): 1, (21, 12): '999-1', (21, 13): 0.5, (21, 14): 'RA',
        })
        return cells

    def test_reads_identification_operational_and_departures(self):
        p = parse_sheet(_schedule_sheet(self.base()), 'Fictício.xlsx')
        self.assertEqual(p.layout, 'oso-anexo-ii')
        self.assertEqual((p.line_number, p.line_name, p.oso, p.sheet_date), ('999', 'T. Sintético / Bairro Fictício', '0001/2026', '2026-06-13'))
        self.assertEqual(p.operators, ['Operadora A'])
        self.assertEqual(p.vehicle_type, 'Ônibus')
        self.assertEqual(p.operational['weekday']['service_start'], '05:00')
        self.assertIsNone(p.operational['saturday']['headway_peak_min'])
        got = [(d.day_type, d.variant_code, d.time, d.trip_kind) for d in p.departures]
        self.assertEqual(got, [('weekday', '999-1', '06:00', 'VG'), ('weekday', '999-2', '24:15', 'MVGI'),
                               ('sunday_holiday', '999-1', '12:00', None)])
        self.assertIn('Mvg - Meia Viagem Início no Retorno', p.notes)

    def test_unreadable_time_is_reported_not_guessed(self):
        cells = self.base()
        cells[(21, 8)] = 35
        cells[(21, 6)] = 1
        p = parse_sheet(_schedule_sheet(cells), 'x.xlsx')
        self.assertTrue(any('horário ilegível 35' in i for i in p.issues))
        self.assertFalse(any(d.day_type == 'saturday' for d in p.departures))

    def test_sheet_without_labels_is_unknown(self):
        p = parse_sheet(_schedule_sheet({(0, 0): 'qualquer coisa'}), 'x.xlsx')
        self.assertEqual(p.layout, 'desconhecido')
        self.assertEqual(p.departures, [])


class Kml(unittest.TestCase):
    def test_paths_names_and_coordinates(self):
        kml = b'''<?xml version="1.0"?><kml xmlns="http://www.opengis.net/kml/2.2"><Document><name>D</name>
        <Folder><name>Arco Sul</name><Placemark><name>999-1i - TESTE - IDA</name>
        <LineString><coordinates>-49.1,-16.6,0 -49.2,-16.7,0 bad</coordinates></LineString></Placemark></Folder>
        <Placemark><name>40000 - ESTACAO</name><Point><coordinates>-49.21,-16.66,0</coordinates></Point></Placemark>
        </Document></kml>'''
        line, point = read_kml_bytes(kml)
        self.assertEqual(line.path, ('D', 'Arco Sul'))
        self.assertEqual(line.kind, 'LineString')
        self.assertEqual(line.coords, [(-49.1, -16.6), (-49.2, -16.7)])
        self.assertEqual(line.invalid_coords, 1)
        self.assertEqual((point.name, point.kind), ('40000 - ESTACAO', 'Point'))


# Trajeto sintético: 2 km para leste ao longo da latitude -16.68, depois volta
# 500 m pela mesma via (laço).
_E = 2000 / (111195 * 0.9579)  # ~2 km em graus de longitude nessa latitude
LINE = [(-49.30, -16.68), (-49.30 + _E, -16.68), (-49.30 + _E * 0.75, -16.68)]


def _offset(lon_fraction, north_m):
    return (-49.30 + _E * lon_fraction, -16.68 + north_m / 111195)


class Geometry(unittest.TestCase):
    def test_length_and_projection(self):
        poly = Polyline(LINE[:2])
        self.assertAlmostEqual(poly.length, 2000, delta=15)
        [p] = poly.project_all(*_offset(0.5, 20), max_distance_m=40)
        self.assertAlmostEqual(p.distance_m, 20, delta=0.5)
        self.assertAlmostEqual(p.along_m, 1000, delta=10)
        self.assertEqual(poly.project_all(*_offset(0.5, 60), max_distance_m=40), [])

    def test_loop_yields_two_passes(self):
        passes = Polyline(LINE).project_all(*_offset(0.9, 5), max_distance_m=40)
        self.assertEqual(len(passes), 2)

    def test_simplify_keeps_ends(self):
        dense = [(-49.30 + _E * i / 100, -16.68) for i in range(101)]
        self.assertEqual(simplify(dense, 1), [dense[0], dense[-1]])
        self.assertAlmostEqual(haversine_m(dense[0], dense[-1]), 2000, delta=15)


class Sequence(unittest.TestCase):
    def test_orders_by_position_and_flags_distance(self):
        members = [('3', *_offset(0.8, 5)), ('1', *_offset(0.1, -5)), ('2', *_offset(0.4, 30)), ('9', *_offset(0.5, 300))]
        r = build_sequence('S', '999-1', 'i', LINE[:2], members, Params(tolerance_m=40))
        self.assertEqual([m.stop_id for m in r.sequence], ['1', '2', '3'])
        self.assertEqual(r.unmatched, ['9'])
        self.assertLess(r.sequence[1].confidence, 1.0)
        self.assertEqual(r.sequence[0].confidence, 1.0)

    def test_multi_pass_lowers_confidence(self):
        r = build_sequence('S', '999-1', 'i', LINE, [('5', *_offset(0.9, 5))])
        self.assertEqual(r.sequence[0].passes, 2)
        self.assertLess(r.sequence[0].confidence, 1.0)

    def test_direction_rules(self):
        near = Match('1', 0, 5, 'direita', 1, 1.0)
        far = Match('1', 0, 30, 'direita', 1, 0.8)
        self.assertEqual(assign_direction(near, None)[::2], ('i', 'alta'))
        self.assertEqual(assign_direction(None, near)[::2], ('v', 'alta'))
        self.assertEqual(assign_direction(near, near, 'v')[::2], ('v', 'média'))
        self.assertEqual(assign_direction(near, far)[::2], ('i', 'baixa'))
        self.assertEqual(assign_direction(near, near)[::2], (None, 'ambíguo'))

    def test_street_hint(self):
        self.assertEqual(street_hint('ALPES', ['Av. dos Alpes', 'Av. Itália'], ['Av. Itália']), 'i')
        self.assertIsNone(street_hint('ITÁLIA', ['Av. Itália'], ['Av. Italia']))
        self.assertIsNone(street_hint('X', ['X'], []))


if __name__ == '__main__':
    unittest.main()


class Matching(unittest.TestCase):
    def test_rank_prefers_pattern_that_moves_forward(self):
        from cmtc.matching import rank_patterns
        out_bound = LINE[:2]
        in_bound = list(reversed(out_bound))
        samples = [_offset(0.2, 3), _offset(0.3, 3), _offset(0.4, 3)]
        ranking = rank_patterns(samples, {'A-i': (out_bound, 'X / Y - IDA'), 'A-v': (in_bound, 'Y / X - VOLTA')})
        self.assertEqual(ranking[0].shape_id, 'A-i')
        self.assertFalse(ranking[1].monotonic)
        self.assertGreater(ranking[0].score, ranking[1].score * 2)

    def test_far_samples_score_zero(self):
        from cmtc.matching import rank_patterns
        [c] = rank_patterns([_offset(0.5, 500)], {'A': (LINE[:2], '')})
        self.assertEqual(c.score, 0.0)

    def test_route_name_and_destination(self):
        from cmtc.matching import direction_by_destination, variants_by_route_name
        names = {'003-1': 'T. Maranata / Eixo T-7 / T. Paulo Garcia', '003-7': 'T. Maranata / Eixo T-7 / Praça Cívica'}
        self.assertEqual(variants_by_route_name('T. Maranata / Eixo T-7 / T. Paulo Garcia', names), ['003-1'])
        self.assertEqual(variants_by_route_name(None, names), [])
        self.assertEqual(direction_by_destination('T PAULO GARCIA', names['003-1']), 'i')
        self.assertEqual(direction_by_destination('T MARANATA', names['003-1']), 'v')
        self.assertIsNone(direction_by_destination('T BIBLIA', names['003-1']))


class PolylineEncoding(unittest.TestCase):
    def test_google_reference_vector(self):
        from cmtc.geo import encode_polyline
        # Exemplo da documentação do algoritmo (lat, lon) -> (lon, lat) aqui.
        coords = [(-120.2, 38.5), (-120.95, 40.7), (-126.453, 43.252)]
        self.assertEqual(encode_polyline(coords), '_p~iF~ps|U_ulLnnqC_mqNvxq`@')
