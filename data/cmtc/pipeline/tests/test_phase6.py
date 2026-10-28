"""Fase 6: estações de corredor, terminais e recuperação por logradouros.
Só dados sintéticos.

    cd data/cmtc && python3 -I -m unittest discover -s pipeline/tests -v
"""

import os
import sys
import unittest
from types import SimpleNamespace

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from cmtc.ids import parse_line_code  # noqa: E402
from cmtc.sequence import Params  # noqa: E402
from cmtc.sources import StopPoint  # noqa: E402
from cmtc.stations import (Station, corridor_lines, find_terminals, read_stations,  # noqa: E402
                           shape_terminals, station_group, terminal_key)
from cmtc.stop_sequences import recover, sequence_shapes, ShapeStops, Entry  # noqa: E402

_E = 2000 / (111195 * 0.9579)
EAST = [(-49.30, -16.68), (-49.30 + _E, -16.68)]
WEST = list(reversed(EAST))


def at(fraction, north_m=0.0):
    return (-49.30 + _E * fraction, -16.68 + north_m / 111195)


def shape(shape_id, coords, direction, variant='999-1'):
    return SimpleNamespace(shape_id=shape_id, code=parse_line_code(variant), direction=direction, coords=coords)


def line(variant, name, type_='Alimentadora'):
    return SimpleNamespace(code=parse_line_code(variant), name=name, type=type_)


class Stations(unittest.TestCase):
    def test_group_and_folder(self):
        self.assertEqual(station_group('AV. ANHANGUERA (PLATAFORMA PALMITO)'), 'PLATAFORMA PALMITO')
        pts = [StopPoint('40000', 'x', 'AV. X (PLATAFORMA A)', ('PEDS', 'EIXO ANHANGUERA'), -49.3, -16.68, []),
               StopPoint('40001', 'x', 'AV. X (PLATAFORMA A)', ('PEDS', 'EIXO ANHANGUERA'), -49.3, -16.68, []),
               StopPoint('123', 'x', None, ('PEDS', 'PEDS GERAL'), -49.3, -16.68, [])]
        st = read_stations(pts)
        self.assertEqual([s.stop_id for s in st], ['40000', '40001'])
        self.assertEqual({s.group for s in st}, {'eixo:PLATAFORMA A'})

    def test_corridor_lines_exclude_non_stopping(self):
        lines = [line('110-1', 'Eixo Anhanguera / T. Alfa / T. Beta', 'Ligação'),
                 line('111-1', 'Eixo Anhanguera / T. Gama / T. Beta', 'Direta'),
                 line('115-1', 'Eixo Anhanguera / Direto / T. Delta', 'Direta'),
                 line('200-1', 'T. Alfa / Bairro', 'Alimentadora')]
        c = corridor_lines(lines)
        self.assertEqual(set(c), {'110', '111', '115'})
        self.assertTrue(c['110'].stops_at_stations)
        self.assertFalse(c['111'].stops_at_stations)  # Direta
        self.assertFalse(c['115'].stops_at_stations)  # Direto
        self.assertEqual(c['110'].evidence, ['denominação do cadastro'])


class Terminals(unittest.TestCase):
    def test_keys(self):
        self.assertEqual(terminal_key('T. Pe. Pelágio'), 'PADRE PELAGIO')
        self.assertEqual(terminal_key('T. Bíblia - Via Alpes'), 'BIBLIA')
        self.assertEqual(terminal_key(' Terminal Rec. do Bosque'), 'RECANTO BOSQUE')
        self.assertIsNone(terminal_key('Centro'))
        self.assertEqual(shape_terminals('T. Alfa / Centro / T. Beta', 'i'), ('ALFA', 'BETA'))
        self.assertEqual(shape_terminals('T. Alfa / Centro / T. Beta', 'v'), ('BETA', 'ALFA'))
        self.assertEqual(shape_terminals('Bairro / Centro', 'i'), (None, None))

    def test_support_and_outliers(self):
        names = {'999-1': 'T. Alfa / T. Beta', '998-1': 'T. Alfa / Bairro', '997-1': 'T. Alfa / Outro'}
        shapes = [shape('a', EAST, 'i', '999-1'), shape('b', EAST, 'i', '998-1'),
                  shape('c', [at(0, 10), at(1)], 'i', '997-1'),
                  shape('d', [at(0.5, 2000), at(1)], 'i', '997-1')]  # extremo longe: não concorda
        t = find_terminals(shapes, names)
        self.assertIn('ALFA', t)
        self.assertEqual(t['ALFA'].support, 3)
        self.assertEqual(t['ALFA'].id, 'T-ALFA')
        self.assertEqual(t['ALFA'].name, 'T. Alfa')
        self.assertNotIn('BETA', t)  # só 1 extremo: suporte insuficiente


class Recovery(unittest.TestCase):
    def mk(self, status, n, amb, rho):
        s = ShapeStops('s', '999', '999-1', 'i', False, 1000.0,
                       [Entry(str(i), i * 10.0, 5.0, 'medium') for i in range(n)],
                       [(f'a{i}', 'x') for i in range(amb)], [], [])
        s.status, s.street_rho = status, rho
        return s

    def test_rules(self):
        s = self.mk('partial', 10, 1, 0.8)
        recover(s)
        self.assertEqual((s.status, s.evidence), ('estimated', 'logradouros'))
        s = self.mk('partial', 10, 5, 0.8)
        recover(s)
        self.assertEqual((s.status, s.evidence), ('ordered', 'logradouros'))  # lista incompleta
        for rho in (None, 0.6):
            s = self.mk('partial', 10, 1, rho)
            recover(s)
            self.assertEqual(s.status, 'partial')
        s = self.mk('partial', 4, 0, 0.9)
        recover(s)
        self.assertEqual(s.status, 'partial')  # poucos pontos
        s = self.mk('estimated', 10, 0, 0.9)
        recover(s)
        self.assertEqual(s.evidence, 'geometria+logradouros')


class CorridorSequences(unittest.TestCase):
    def test_stations_only_for_stopping_corridor_lines(self):
        stations = [Station(str(40000 + i), 'eixo', 'X', f'eixo:{i}', *at(i / 10, 10)) for i in range(1, 8)]
        stations.append(Station('40099', 'eixo', 'Y', 'eixo:Y', *at(0.5, 200)))  # longe
        corridor = corridor_lines([line('110-1', 'Eixo Anhanguera / T. A / T. B', 'Ligação'),
                                   line('111-1', 'Eixo Anhanguera / T. A / T. B', 'Direta')])
        shapes = [shape('110-1i', EAST, 'i', '110-1'), shape('111-1i', EAST, 'i', '111-1')]
        res = {r.shape_id: r for r in sequence_shapes(shapes, {}, {}, {}, Params(), stations=stations,
                                                       corridor=corridor)}
        r = res['110-1i']
        self.assertEqual((r.status, r.evidence, r.stations), ('ordered', 'corredor', 7))
        self.assertEqual([e.stop_id for e in r.entries], [str(40000 + i) for i in range(1, 8)])
        self.assertTrue(all(e.level == 'medium' for e in r.entries))
        self.assertEqual(res['111-1i'].status, 'none')  # direta: passa perto, não para

    def test_terminal_entries_at_ends(self):
        stops = [(str(i), *at(i / 10, 3)) for i in range(1, 9)]
        names = {'999-1': 'T. Alfa / Centro / T. Beta'}
        shapes = [shape('S-i', EAST, 'i'), shape('S2', EAST, 'i', '998-1'), shape('S3', EAST, 'i', '997-1')]
        terminals = find_terminals(shapes, {**names, '998-1': 'T. Alfa / X', '997-1': 'T. Alfa / Y'})
        [r] = [x for x in sequence_shapes([shapes[0]], {'999': stops}, {}, {}, Params(),
                                          terminals=terminals, variant_names=names)]
        self.assertEqual(r.status, 'estimated')
        self.assertEqual(r.entries[0].stop_id, 'T-ALFA')
        self.assertEqual(r.entries[0].level, 'medium')
        self.assertNotIn('T-BETA', [e.stop_id for e in r.entries])  # Beta sem suporte


if __name__ == '__main__':
    unittest.main()
