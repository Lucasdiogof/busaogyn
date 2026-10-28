"""Fase 4: quadros de horários, sequência estimada e regras de tracking.
Só dados sintéticos.

    cd data/cmtc && python3 -I -m unittest discover -s pipeline/tests -v
"""

import os
import sys
import unittest
from types import SimpleNamespace

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from cmtc.geo import Polyline  # noqa: E402
from cmtc.ids import parse_line_code  # noqa: E402
from cmtc.schedules import Departure, ScheduleSheet  # noqa: E402
from cmtc.sequence import Params  # noqa: E402
from cmtc.stop_sequences import sequence_shapes  # noqa: E402
from cmtc.timetables import (INSUFFICIENT, OLD, RECENT, CONFIRMED, build_timetables,  # noqa: E402
                             classify_validity, delivered_date, source_label, to_minutes)
from cmtc.tracking import (Shape, direction_by_destination, match_tracked_route,  # noqa: E402
                           next_stops, tokens)

_E = 2000 / (111195 * 0.9579)  # ~2 km de longitude
EAST = [(-49.30, -16.68), (-49.30 + _E, -16.68)]
WEST = list(reversed(EAST))
# Vai 2 km para leste e volta 2 km pela mesma via (retorno).
OUT_AND_BACK = [(-49.30, -16.68), (-49.30 + _E, -16.68), (-49.30, -16.68)]


def at(fraction, north_m=0.0):
    return (-49.30 + _E * fraction, -16.68 + north_m / 111195)


def sheet(name='999', date='2026-06-13', deps=(), hidden=False, line='999'):
    return ScheduleSheet(file='Fictício_ .xlsx', sheet=name, hidden=hidden, layout='oso-anexo-ii',
                         line_number=line, line_name='T. Sintético / Bairro', sheet_date=date,
                         departures=[Departure(dt, i, v, t, None, k, 20 + i) for i, (dt, v, t, k) in enumerate(deps)])


class Timetables(unittest.TestCase):
    def test_minutes_after_midnight_and_labels(self):
        self.assertEqual(to_minutes('05:10'), 310)
        self.assertEqual(to_minutes('24:15'), 1455)
        self.assertIsNone(to_minutes('5h10'))
        self.assertIsNone(to_minutes('10:75'))
        self.assertEqual(source_label('Araguaia_ .xlsx'), 'Araguaia')
        self.assertEqual(delivered_date('Planilhas Horárias _ 28-10-2026'), '2026-10-28')

    def test_validity_never_presumed(self):
        cls = lambda d, **k: classify_validity(d, '2026-10-28', has_departures=True, conflict=False, **k)[0]  # noqa: E731
        self.assertEqual(cls('2026-03-01'), RECENT)  # 2026 sozinho não confirma
        self.assertEqual(cls('2025-12-03'), OLD)
        self.assertEqual(cls('2022-01-10'), OLD)
        self.assertEqual(cls(None), INSUFFICIENT)
        self.assertEqual(cls('2026-11-01'), INSUFFICIENT)  # depois da entrega
        self.assertEqual(cls('2026-03-01', confirmed_by='Ofício X'), CONFIRMED)
        self.assertEqual(classify_validity('2026-03-01', '2026-10-28', has_departures=False, conflict=False)[0], INSUFFICIENT)

    def test_provenance_variant_duplicates_and_order_are_kept(self):
        deps = [('weekday', '999-1', '06:00', 'VG'), ('weekday', '999-1', '06:00', 'VG'),
                ('weekday', '999-7', '05:50', 'MVGI'), ('weekday', '999-2', '24:15', None),
                ('saturday', '999', '07:00', 'XX')]
        [tt] = build_timetables([sheet(deps=deps)], {'999-1', '999-2'}, '2026-10-28')
        self.assertEqual(tt.id, 'Fictício_ .xlsx:999')
        self.assertEqual(len(tt.trips), 5)  # nada descartado
        self.assertEqual([t.duplicate for t in tt.trips], [False, True, False, False, False])
        self.assertTrue(tt.trips[2].out_of_order)
        self.assertEqual([t.variant_key for t in tt.trips], ['999-1', '999-1', None, '999-2', None])
        self.assertEqual(tt.trips[3].minutes, 1455)
        self.assertIsNone(tt.trips[4].kind)
        self.assertEqual(tt.trips[0].row, 20)
        self.assertTrue(any('999-7 sem registro' in i for i in tt.issues))
        self.assertTrue(any('tipo de viagem desconhecido' in i for i in tt.issues))
        self.assertEqual(tt.validity, RECENT)

    def test_conflicting_sheets_are_insufficient_identical_are_not(self):
        a = sheet('A', deps=[('weekday', '999-1', '06:00', 'VG')])
        b = sheet('B', deps=[('weekday', '999-1', '06:30', 'VG')])
        c = sheet('C', deps=[('weekday', '999-1', '06:00', 'VG')])
        got = {t.sheet: t.validity for t in build_timetables([a, b], {'999-1'}, '2026-10-28')}
        self.assertEqual(got, {'A': INSUFFICIENT, 'B': INSUFFICIENT})
        got = {t.sheet: t.validity for t in build_timetables([a, c], {'999-1'}, '2026-10-28')}
        self.assertEqual(got, {'A': RECENT, 'C': RECENT})

    def test_hidden_and_old_sheets(self):
        hid = sheet('H', deps=[('weekday', '999-1', '06:00', 'VG')], hidden=True)
        old = sheet('O', date='2024-02-01', deps=[('weekday', '999-1', '06:00', 'VG')], line='998')
        got = {t.sheet: t.validity for t in build_timetables([hid, old], {'999-1'}, '2026-10-28')}
        self.assertEqual(got, {'H': INSUFFICIENT, 'O': OLD})


def _shape(shape_id, coords, direction, variant='999-1'):
    return SimpleNamespace(shape_id=shape_id, code=parse_line_code(variant), direction=direction, coords=coords)


class StopSequences(unittest.TestCase):
    P = Params(tolerance_m=25)

    def run_seq(self, shapes, stops, streets=None):
        members = {'999': [(sid, *xy) for sid, xy in stops]}
        return {r.shape_id: r for r in sequence_shapes(shapes, members, streets or {}, {}, self.P)}

    def test_order_levels_and_unassociated(self):
        stops = [(str(i), at(i / 10, 3)) for i in range(1, 9)] + [('far', at(0.5, 300))]
        r = self.run_seq([_shape('S-i', EAST, 'i')], stops)['S-i']
        self.assertEqual([e.stop_id for e in r.entries], [str(i) for i in range(1, 9)])
        self.assertTrue(all(e.level == 'high' for e in r.entries))
        self.assertEqual(r.unassociated, ['far'])
        self.assertEqual(r.status, 'estimated')

    def test_repeated_pass_keeps_both_positions(self):
        stops = [(str(i), at(i / 10, 3)) for i in range(1, 9)]
        r = self.run_seq([_shape('L-i', OUT_AND_BACK, 'i')], stops)['L-i']
        self.assertEqual(len(r.entries), 16)  # cada ponto, duas passagens
        self.assertTrue(all(e.level == 'medium' and e.passes == 2 for e in r.entries))
        self.assertEqual(r.status, 'partial')  # sem pontos de confiança alta

    def test_opposite_direction_and_ambiguous_are_not_forced(self):
        # Ida no eixo; volta 30 m ao norte (via dupla).
        north = [(x, y + 30 / 111195) for x, y in WEST]
        stops = [('s1', at(0.2, -8)), ('s2', at(0.5, 8)), ('n1', at(0.4, 38)), ('mid', at(0.6, 15))]
        r = self.run_seq([_shape('A-i', EAST, 'i'), _shape('A-v', north, 'v')], stops)
        self.assertEqual([(e.stop_id, e.level) for e in r['A-i'].entries], [('s1', 'high'), ('s2', 'medium')])
        self.assertEqual(r['A-i'].unassociated, ['n1'])
        self.assertIn('s2', r['A-v'].other_direction)  # perto dos dois, 14 m mais perto da ida
        self.assertEqual([e.stop_id for e in r['A-v'].entries], ['n1'])
        self.assertIn('mid', [sid for sid, _ in r['A-i'].ambiguous])
        self.assertIn('mid', [sid for sid, _ in r['A-v'].ambiguous])

    def test_street_order_contradiction_downgrades_status(self):
        stops = [(str(i), at(i / 10, 3)) for i in range(1, 9)]
        # Logradouros oficiais na ordem inversa da geometria.
        street_of = {str(i): f'RUA {chr(64 + i)}' for i in range(1, 9)}
        streets = {'999-1': ([f'Rua {chr(64 + i)}' for i in range(8, 0, -1)], [])}
        members = {'999': [(sid, *xy) for sid, xy in stops]}
        [r] = sequence_shapes([_shape('S-i', EAST, 'i')], members, streets, street_of, self.P)
        self.assertLess(r.street_rho, 0)
        self.assertEqual(r.status, 'partial')

    def test_no_members(self):
        r = self.run_seq([_shape('S-i', EAST, 'i')], [])['S-i']
        self.assertEqual(r.status, 'none')


VARIANTS = {'999-1': 'T. Alfa / Centro / T. Beta', '999-2': 'T. Alfa / T. Gama'}


def shapes():
    return [Shape('999-1i', '999-1', 'i', Polyline(EAST)), Shape('999-1v', '999-1', 'v', Polyline(WEST))]


def match(**k):
    args = dict(variants=VARIANTS, shapes=shapes(), route_name='T. Alfa / Centro / T. Beta',
                destination='T BETA', position=at(0.5, 5), trail=[at(0.3, 5), at(0.4, 5)])
    args.update(k)
    return match_tracked_route(**args)


class Tracking(unittest.TestCase):
    def test_tokens_match_app(self):
        self.assertEqual(tokens('Praça Cívica, nº 3 — Pq.'), ['praca', 'civica', 'no', '3', 'parque'])
        self.assertEqual(direction_by_destination('T BETA', VARIANTS['999-1']), 'i')
        self.assertEqual(direction_by_destination('TERMINAL ALFA', VARIANTS['999-1']), 'v')

    def test_confirmed_and_refusals(self):
        m = match()
        self.assertEqual((m.level, m.shape.id), ('confirmed', '999-1i'))
        self.assertAlmostEqual(m.along_m, 1000, delta=15)
        self.assertEqual(match(destination='T ALFA', trail=[at(0.7, 5), at(0.6, 5)]).shape.id, '999-1v')
        self.assertEqual(match(position=None).reason, 'noPosition')
        self.assertEqual(match(route_name=None).reason, 'routeNameMissing')
        self.assertEqual(match(route_name='Outro / Nome').reason, 'routeNameNoMatch')
        self.assertEqual(match(destination='BAIRRO QUALQUER').reason, 'directionUnknown')
        self.assertEqual(match(position=at(0.5, 200)).reason, 'offRoute')
        self.assertEqual(match(trail=[at(0.7, 5), at(0.6, 5)]).reason, 'movingBackwards')
        self.assertEqual(match(trail=[at(0.495, 5)]).reason, 'waitingMovement')
        self.assertEqual(match(shapes=[]).reason, 'noShapes')

    def test_direction_by_movement_when_destination_is_a_middle_part(self):
        # Destino "CENTRO" é o trecho do meio de 'T. Alfa / Centro / T. Beta'
        # (caso real: "ST AEROPORTO" na linha 016). Decide o deslocamento.
        east = match(destination='CENTRO')
        self.assertEqual((east.level, east.shape.id), ('confirmed', '999-1i'))
        west = match(destination='CENTRO', trail=[at(0.7, 5), at(0.6, 5)])
        self.assertEqual((west.level, west.shape.id), ('confirmed', '999-1v'))
        # Sem deslocamento ainda: os dois sentidos servem -> aguarda.
        self.assertEqual(match(destination='CENTRO', trail=[]).reason, 'waitingMovement')
        # Ida e volta pelo mesmo traçado no mesmo sentido: indecidível.
        same = [Shape('999-1i', '999-1', 'i', Polyline(EAST)), Shape('999-1v', '999-1', 'v', Polyline(EAST))]
        self.assertEqual(match(destination='CENTRO', shapes=same).reason, 'directionUnknown')

    def test_gps_jump(self):
        # Trajeto em U (leste, norte 1 km, oeste): do início ao fim da volta são
        # ~1 km em linha reta, mas ~3 km pelo trajeto.
        north = 1000 / 111195
        u = [Shape('999-1i', '999-1', 'i', Polyline([at(0), at(0.5), (at(0.5)[0], -16.68 + north), (at(0)[0], -16.68 + north)]))]
        self.assertEqual(match(shapes=u, trail=[at(0.0)], position=(at(0)[0], -16.68 + north)).reason, 'gpsJump')
        # Avanço compatível com o deslocamento continua valendo.
        self.assertEqual(match(trail=[at(0.0, 5)], position=at(0.9, 5)).level, 'confirmed')

    def test_repeated_section(self):
        loop = [Shape('999-1i', '999-1', 'i', Polyline(OUT_AND_BACK))]
        # Só a posição atual: duas passagens possíveis -> ambíguo.
        self.assertEqual(match(shapes=loop, trail=[]).reason, 'repeatedSection')
        # Indo para leste com o rastro: só a 1ª passagem é coerente.
        m = match(shapes=loop)
        self.assertEqual(m.level, 'confirmed')
        self.assertAlmostEqual(m.along_m, 1000, delta=15)
        # Voltando para oeste: só a 2ª passagem é coerente.
        m = match(shapes=loop, trail=[at(0.7, 5), at(0.6, 5)])
        self.assertEqual(m.level, 'confirmed')
        self.assertAlmostEqual(m.along_m, 3000, delta=15)

    def test_winding_geometry_converges(self):
        # Desvio em volta de uma quadra: a 1ª amostra tem duas passagens a até
        # 50 m, mas as duas cadeias chegam ao mesmo lugar -> confirmado.
        def xy(x, y):
            return (-49.30 + x / (111195 * 0.9579), -16.68 + y / 111195)
        block = [Shape('999-1i', '999-1', 'i', Polyline([xy(0, 0), xy(600, 0), xy(600, 70), xy(620, 70),
                                                          xy(620, 0), xy(2000, 0)]))]
        m = match(shapes=block, trail=[xy(610, 5), xy(640, 3)], position=xy(700, 3))
        self.assertEqual(m.level, 'confirmed')
        self.assertAlmostEqual(m.along_m, 840, delta=5)

    def test_next_stops(self):
        entries = [('a', 300.0, 'high'), ('b', 980.0, 'high'), ('c', 1200.0, 'medium'), ('d', 1800.0, 'high')]
        m = match()  # along ~1000
        n = next_stops(m, 'estimated', entries)
        self.assertTrue(n.available)
        self.assertEqual([e[0] for e in n.remaining], ['b', 'c', 'd'])  # 'b' 20 m atrás: não basta para passado
        self.assertTrue(n.next_confident)
        n = next_stops(match(position=at(0.52, 5)), 'estimated', entries)  # ~1040: 'b' ficou 60 m atrás
        self.assertEqual([e[0] for e in n.remaining], ['c', 'd'])
        self.assertFalse(n.next_confident)  # 'c' é médio: lista sem destaque
        self.assertEqual(next_stops(m, 'partial', entries).reason, 'sequenceUnreliable')
        self.assertEqual(next_stops(match(trail=[at(0.495, 5)]), 'estimated', entries).reason, 'notConfirmed')
        self.assertEqual(next_stops(match(position=at(0.99, 5), trail=[at(0.9, 5)]), 'estimated', entries).reason, 'endOfRoute')


if __name__ == '__main__':
    unittest.main()
