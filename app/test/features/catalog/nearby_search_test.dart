import 'package:busaogyn/src/features/catalog/domain/nearby.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_fixture.dart';

void main() {
  final catalog = fixtureCatalog();

  group('pontos perto', () {
    test('ordena pela distância em linha reta e respeita o raio', () {
      // Mais perto de 00294 (-16.68, -49.26) que de qualquer outro ponto.
      const at = GeoPosition(latitude: -16.70, longitude: -49.255);
      final near = nearbyStops(catalog, at, radiusM: 20000);
      final ids = [for (final n in near) n.stop.id];
      expect(ids.first, '00294');
      expect(ids, contains('1201'));
      expect(near.first.meters, lessThan(near[1].meters));
      for (var i = 1; i < near.length; i++) {
        expect(near[i].meters, greaterThanOrEqualTo(near[i - 1].meters));
      }
      // Ponto sem coordenada (1203) nunca aparece.
      expect(ids, isNot(contains('1203')));
      expect(nearbyStops(catalog, at, radiusM: 1000), isEmpty);
    });

    test('limite de resultados', () {
      const at = GeoPosition(latitude: -16.7, longitude: -49.3);
      expect(nearbyStops(catalog, at, radiusM: 1e6, limit: 2), hasLength(2));
    });
  });

  group('busca tolerante', () {
    test('acento e caixa não importam; exata não é aproximada', () {
      final r = catalog.findStops('PRAÇA cívica');
      expect(r.approximate, isFalse);
      expect(r.results.first.item.id, '1203');
    });

    test('um erro de digitação em palavra longa vira aproximado', () {
      final r = catalog.findStops('fictcia');
      expect(r.approximate, isTrue);
      expect([for (final x in r.results) x.item.id], contains('00294'));
    });

    test('palavra curta, código e dois erros não são aproximados', () {
      expect(catalog.findStops('exm').results, isEmpty);
      expect(catalog.findStops('99999').results, isEmpty);
      expect(catalog.findStops('fictcai').results, isEmpty);
    });
  });
}
