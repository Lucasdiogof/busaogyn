import 'dart:convert';

import 'package:busaogyn/src/features/catalog/data/catalog_codec.dart';
import 'package:busaogyn/src/features/catalog/domain/network_geojson.dart';
import 'package:busaogyn/src/features/catalog/domain/route_geometry.dart';
import 'package:busaogyn/src/features/catalog/domain/route_match.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_fixture.dart';

GeoPosition _p(double lat, double lon) =>
    GeoPosition(latitude: lat, longitude: lon);

List<Map<String, dynamic>> _features(Map<String, dynamic> c) =>
    (c['features'] as List).cast<Map<String, dynamic>>();

void main() {
  final catalog = fixtureCatalog();

  group('geometria', () {
    test('polyline: vetor de referência do algoritmo', () {
      final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(points.map((p) => (p.latitude, p.longitude)), [
        (38.5, -120.2),
        (40.7, -120.95),
        (43.252, -126.453),
      ]);
      expect(() => decodePolyline('_p~iF~ps|U_'), throwsFormatException);
    });

    test('coordenadas negativas (Goiânia) com o texto exato do exportador', () {
      // Gerado pelo Python (encode_polyline) para (-16.68, -49.30) e
      // (-16.6795, -49.295): pega regressão de sinal (bug do `~` no Web).
      final points = decodePolyline('~xxdB~{{kHcBg^');
      expect(points.first.latitude, -16.68);
      expect(points.first.longitude, -49.30);
      expect(points.last.latitude, closeTo(-16.6795, 1e-9));
    });

    test('codifica e decodifica sem perder precisão de 1e-5', () {
      final pts = fixtureOutbound();
      final back = decodePolyline(encodePolyline(pts));
      for (var i = 0; i < pts.length; i++) {
        expect(back[i].latitude, closeTo(pts[i].$1, 1e-6));
        expect(back[i].longitude, closeTo(pts[i].$2, 1e-6));
      }
    });

    test('projeção e trecho futuro', () {
      final line = RouteLine(decodePolyline(encodePolyline(fixtureOutbound())));
      expect(line.lengthM, closeTo(5330, 30));
      final mid = line.project(_p(-16.6802, -49.275));
      expect(mid.distanceM, closeTo(22, 2));
      expect(mid.alongM, closeTo(line.lengthM / 2, 20));
      final ahead = line.sliceFrom(mid.alongM);
      expect(ahead.first.longitude, closeTo(-49.275, 1e-4));
      expect(ahead.last.longitude, closeTo(-49.25, 1e-6));
      expect(line.sliceFrom(0).length, line.points.length);
    });

    test('zoom de enquadramento: maior para trajeto curto, limitado', () {
      final city = GeoBounds.of([_p(-16.80, -49.40), _p(-16.55, -49.15)]);
      final street = GeoBounds.of([_p(-16.680, -49.270), _p(-16.675, -49.265)]);
      final zCity = fitZoom(city, widthPx: 340, heightPx: 300);
      final zStreet = fitZoom(street, widthPx: 340, heightPx: 300);
      expect(zCity, inInclusiveRange(9, 12));
      expect(zStreet, greaterThan(zCity));
      expect(fitZoom(street, widthPx: 340, heightPx: 300, maxZoom: 15), 15);
      expect(fitZoom(city, widthPx: 0, heightPx: 300), 9);
      expect(city.center.latitude, closeTo(-16.675, 1e-9));
    });

    test('enquadramento cobre todos os pontos', () {
      final b = GeoBounds.of([_p(-16.7, -49.3), _p(-16.6, -49.2)]);
      expect((b.south, b.west, b.north, b.east), (-16.7, -49.3, -16.6, -49.2));
    });
  });

  group('catálogo com trajetos', () {
    test('trajetos por linha, variante e sentido', () {
      final shapes = catalog.shapesOf('1');
      expect(shapes.map((s) => (s.variantId, s.direction)), [
        ('001-1', 'i'),
        ('001-1', 'v'),
        ('001-2', 'i'),
      ]);
      expect(catalog.version.shapeToleranceM, 3.0);
      expect(catalog.shapesOf('042').map((s) => s.variantId), [
        '042-1',
        '042-21',
      ]);
    });

    test('trajeto malformado é descartado', () {
      final map = fixtureCatalogMap();
      (map['shapes']! as Map)['rows'] = [
        ['x', '001', null, 'i', null, 'abc', 1, 1],
        ['y', '001', '001-1', 'i', null, 42, 1, 1],
      ];
      expect(decodeCatalog(jsonEncode(map)).shapes, isEmpty);
    });
  });

  group('GeoJSON das camadas', () {
    test('pontos: só os com coordenada, com id para o toque', () {
      final stops = _features(stopsCollection(catalog));
      expect(stops.map((f) => f['properties']['id']), [
        '00294',
        '1201',
        '1202',
        '40999',
      ]);
      expect(stops.first['geometry']['coordinates'], [-49.26, -16.68]);
      // Android/iOS devolvem o id da feição (não a propriedade): sem ele, o
      // toque abria "Ponto null".
      for (final f in stops) {
        expect(f['id'], f['properties']['id']);
      }
      final route = _features(lineStopsCollection(catalog, '001'));
      expect(route, isNotEmpty);
      for (final f in route) {
        expect(f['id'], isA<String>());
      }
    });

    test('trajeto: ativo, sentido e demais esmaecidos', () {
      final shapes = catalog.shapesOf('001');
      final route = _features(routeCollection(shapes, shapes[1].id));
      expect(
        route.map((f) => (f['properties']['dir'], f['properties']['active'])),
        [('i', false), ('v', true), ('i', false)],
      );
      final ends = _features(routeEndsCollection(shapes[1]));
      expect(ends.map((f) => f['properties']['end']), ['start', 'end']);
      expect(ends.first['geometry']['coordinates'], [-49.25, -16.68]);
    });

    test('pontos da linha: pertencimento oficial, sem ordem', () {
      final ids = _features(
        lineStopsCollection(catalog, '042'),
      ).map((f) => f['properties']['id']);
      expect(ids, ['00294', '1201']);
      expect(_features(lineStopsCollection(catalog, null)), isEmpty);
    });

    test('o builder reaproveita coleções que não mudaram', () {
      final builder = NetworkOverlayBuilder(catalog);
      final a = builder.build(selectedStopId: '1201');
      final b = builder.build(selectedStopId: '1201');
      expect(identical(a.stops, b.stops), isTrue);
      expect(identical(a.selectedStop, b.selectedStop), isTrue);
      final shape = catalog.shapesOf('001').first;
      final c = builder.build(
        selectedStopId: '1201',
        routeLineId: '001',
        routeShapeId: shape.id,
      );
      expect(identical(a.route, c.route), isFalse);
      expect(_features(c.route), hasLength(3));
      expect(_features(c.routeStops).map((f) => f['properties']['id']), [
        '00294',
        '1202',
      ]);
      final d = builder.build(selectedStopId: '1201');
      expect(_features(d.route), isEmpty);
      expect(identical(a.stops, d.stops), isTrue);
    });
  });

  group('associação do ônibus a um trajeto (experimental)', () {
    const name = 'T. Fictício Norte / Centro Imaginário';
    RouteMatch match({
      String? routeId = '001',
      String? routeName = name,
      String? destination = 'CENTRO IMAGINARIO',
      GeoPosition? position,
      List<GeoPosition>? trail,
    }) => matchTrackedRoute(
      catalog: catalog,
      routeId: routeId,
      routeName: routeName,
      destination: destination,
      position: position ?? _p(-16.6801, -49.282),
      trail:
          trail ??
          [_p(-16.6801, -49.290), _p(-16.6801, -49.286), _p(-16.6801, -49.282)],
    );

    test('confirmado: nome, destino, posição e avanço concordam', () {
      final m = match();
      expect(m.level, RouteMatchLevel.confirmed);
      expect(m.shape!.variantId, '001-1');
      expect(m.shape!.direction, 'i');
      expect(m.future.first.longitude, closeTo(-49.282, 1e-4));
      expect(m.future.last.longitude, closeTo(-49.25, 1e-6));
    });

    test('destino do outro extremo = volta', () {
      final m = match(
        destination: 'T FICTICIO NORTE',
        position: _p(-16.6801, -49.286),
        trail: [_p(-16.6801, -49.282), _p(-16.6801, -49.286)],
      );
      expect(m.level, RouteMatchLevel.confirmed);
      expect(m.shape!.direction, 'v');
    });

    test('recusa: itinerário ausente, desconhecido ou de várias variantes', () {
      expect(match(routeName: null).reason, RouteMatchReason.routeNameMissing);
      expect(
        match(routeName: 'Outra coisa / Qualquer').reason,
        RouteMatchReason.routeNameNoMatch,
      );
      final map = fixtureCatalogMap();
      final variants = map['variants']! as Map<String, Object?>;
      final rows = [
        ...(variants['rows']! as List),
        [
          '001-9',
          '001',
          '001-9',
          name,
          'Sublinha',
          'OPERAÇÃO',
          null,
          null,
          null,
          null,
        ],
      ];
      map['variants'] = {...variants, 'rows': rows};
      final twin = matchTrackedRoute(
        catalog: decodeCatalog(jsonEncode(map)),
        routeId: '001',
        routeName: name,
        destination: 'CENTRO IMAGINARIO',
        position: _p(-16.6801, -49.282),
      );
      expect(twin.level, RouteMatchLevel.ambiguous);
      expect(twin.reason, RouteMatchReason.routeNameSeveral);
      expect(twin.future, isEmpty);
    });

    test('recusa: destino não indica sentido', () {
      final m = match(destination: 'BAIRRO QUALQUER');
      expect(m.level, RouteMatchLevel.ambiguous);
      expect(m.reason, RouteMatchReason.directionUnknown);
      expect(m.future, isEmpty);
    });

    test('recusa: ônibus fora do trajeto', () {
      final m = match(position: _p(-16.69, -49.282));
      expect(m.reason, RouteMatchReason.offRoute);
      expect(m.future, isEmpty);
    });

    test('recusa: deslocamento contrário ao sentido', () {
      final m = match(
        trail: [
          _p(-16.6801, -49.274),
          _p(-16.6801, -49.278),
          _p(-16.6801, -49.282),
        ],
      );
      expect(m.reason, RouteMatchReason.movingBackwards);
      expect(m.future, isEmpty);
    });

    test('pendente: sem deslocamento suficiente nada é desenhado', () {
      final m = match(trail: const []);
      expect(m.level, RouteMatchLevel.pending);
      expect(m.future, isEmpty);
      expect(trackRouteCollection(m)['features'], isEmpty);
    });

    test('sem posição atual (expirada) ou sem trajeto: indisponível', () {
      final noPosition = matchTrackedRoute(
        catalog: catalog,
        routeId: '001',
        routeName: name,
        destination: 'CENTRO IMAGINARIO',
        position: null,
      );
      expect(noPosition.reason, RouteMatchReason.noPosition);
      expect(match(routeId: 'NS9').reason, RouteMatchReason.noShapes);
    });

    test('só a associação confirmada vira camada (oficial + futuro)', () {
      final layer = _features(trackRouteCollection(match()));
      expect(layer.map((f) => f['properties']['kind']), ['official', 'future']);
    });
  });

  group('desempenho com volume real', () {
    test('7,5 mil pontos e 900 trajetos', () {
      final extra = [
        for (var i = 0; i < 7500; i++)
          [
            '${10000 + i}',
            'ped',
            'RUA',
            'R$i',
            null,
            'B${i % 300}',
            'GOIÂNIA',
            -16.6 - (i % 100) * 0.003,
            -49.3 + (i ~/ 100) * 0.003,
            ['001'],
            null,
          ],
      ];
      final shapes = [
        for (var i = 0; i < 900; i++)
          [
            's$i',
            '001',
            '001-1',
            i.isEven ? 'i' : 'v',
            null,
            encodePolyline([
              for (var k = 0; k < 100; k++)
                (-16.68 + k * 1e-4, -49.3 + i * 1e-4),
            ]),
            1000,
            100,
          ],
      ];
      final map = fixtureCatalogMap(extraStops: extra);
      (map['shapes']! as Map)['rows'] = shapes;
      final watch = Stopwatch()..start();
      final big = decodeCatalog(jsonEncode(map));
      final decodeMs = watch.elapsedMilliseconds;
      watch.reset();
      final stops = stopsCollection(big);
      final stopsMs = watch.elapsedMilliseconds;
      watch.reset();
      var vertices = 0;
      for (final s in big.shapes) {
        vertices += s.points.length;
      }
      final shapesMs = watch.elapsedMilliseconds;
      watch.reset();
      final builder = NetworkOverlayBuilder(big);
      for (var i = 0; i < 50; i++) {
        builder.build(routeLineId: '001', routeShapeId: 's${i % 900}');
      }
      final switchMs = watch.elapsedMilliseconds;
      expect(_features(stops), hasLength(7500 + 4));
      expect(vertices, 90000);
      // Folgas largas para CI lento; medições reais estão na documentação.
      expect(decodeMs, lessThan(4000));
      expect(stopsMs, lessThan(1500));
      expect(shapesMs, lessThan(1500));
      expect(switchMs, lessThan(8000));
      // ignore: avoid_print
      print(
        'perf: decode=${decodeMs}ms pontos=${stopsMs}ms trajetos=${shapesMs}ms 50trocas=${switchMs}ms',
      );
    });

    test('associação com trilha cheia é rápida', () {
      final shape = catalog.shapesOf('001').first;
      final trail = [
        for (var i = 0; i < 20; i++) _p(-16.6801, -49.299 + i * 0.0005),
      ];
      final watch = Stopwatch()..start();
      for (var i = 0; i < 200; i++) {
        matchTrackedRoute(
          catalog: catalog,
          routeId: '001',
          routeName: shape.variantId == '001-1'
              ? 'T. Fictício Norte / Centro Imaginário'
              : null,
          destination: 'CENTRO IMAGINARIO',
          position: trail.last,
          trail: trail,
        );
      }
      expect(watch.elapsedMilliseconds, lessThan(2000));
    });
  });
}
