import 'package:busaogyn/src/features/catalog/domain/route_match.dart';
import 'package:busaogyn/src/features/catalog/domain/stop_sequence.dart';
import 'package:busaogyn/src/features/catalog/domain/timetable.dart';
import 'package:busaogyn/src/features/catalog/domain/transit_catalog.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_fixture.dart';

const _shapeI = '001-1i - T. FICTICIO NORTE / CENTRO IMAGINARIO - IDA';
const _shapeV = '001-1v - T. FICTICIO NORTE / CENTRO IMAGINARIO - VOLTA';

GeoPosition _at(double lon, [double lat = -16.6801]) =>
    GeoPosition(latitude: lat, longitude: lon);

void main() {
  final catalog = fixtureCatalog();

  group('quadros de horário', () {
    test('decodifica validade, proveniência e descarta o malformado', () {
      final t001 = catalog.timetablesOf('1').single;
      expect(t001.validity, TimetableValidity.recent);
      expect(
        (t001.source, t001.sheetDate, t001.oso, t001.issues),
        ('Fictício', '2026-06-13', '0001/2026', 2),
      );
      // '42' vira '042' (mesma normalização da API).
      expect(
        catalog.timetablesOf('042').single.validity,
        TimetableValidity.old,
      );
      expect(
        catalog.timetablesOf('NS9').single.validity,
        TimetableValidity.insufficient,
      );
      expect(catalog.timetables, hasLength(3)); // linha ausente descartada
      // Dia desconhecido e minutos inválidos não entram.
      final trips = catalog.tripsOf('Fictício_ .xlsx:001');
      expect(trips, hasLength(4));
      expect(trips.first.minutes, [360, 330, 400, 400, 1455]);
      expect(catalog.version.timetablesDelivered, '2026-10-28');
    });

    test(
      'partidas em ordem cronológica, duplicidade marcada, após meia-noite',
      () {
        final trips = catalog.tripsOf('Fictício_ .xlsx:001');
        final weekday = departuresOf(trips, ServiceDay.weekday);
        expect(weekday.map((d) => d.minutes), [330, 345, 360, 400, 500, 1455]);
        final dup = weekday.firstWhere((d) => d.minutes == 400);
        expect(dup.repeated, 2);
        final late = weekday.last;
        expect((late.clock, late.nextDay), ('00:15', true));
        expect(
          weekday.firstWhere((d) => d.minutes == 345).kind,
          TripKind.halfStartsAtTurn,
        );
        expect(
          weekday.firstWhere((d) => d.minutes == 500).code,
          '001-7',
        ); // sem cadastro, mas não escondido
        expect(
          departuresOf(
            trips,
            ServiceDay.weekday,
            codes: {'001-2'},
          ).single.clock,
          '05:45',
        );
        expect(departuresOf(trips, ServiceDay.saturday).single.clock, '07:00');
        expect(departuresOf(trips, ServiceDay.sundayHoliday), isEmpty);
      },
    );

    test('tipo de dia pela data (feriado não é deduzido)', () {
      expect(serviceDayOf(DateTime(2026, 10, 28)), ServiceDay.weekday);
      expect(serviceDayOf(DateTime(2026, 10, 31)), ServiceDay.saturday);
      expect(serviceDayOf(DateTime(2026, 11, 1)), ServiceDay.sundayHoliday);
      // 15/11 é feriado e domingo; 20/11 (feriado) cai numa sexta: dia útil.
      expect(serviceDayOf(DateTime(2026, 11, 20)), ServiceDay.weekday);
    });
  });

  group('sequência estimada', () {
    test('decodifica entradas e ignora as malformadas', () {
      final seq = catalog.sequenceOf(_shapeI)!;
      expect(seq.status, SequenceStatus.estimated);
      expect(seq.entries.map((e) => (e.stopId, e.alongM, e.level)), [
        ('1202', 500, StopLevel.high),
        ('00294', 4264, StopLevel.high),
        ('1203', 4800, StopLevel.medium),
      ]);
      expect(seq.ambiguous, ['40999']);
      expect(catalog.sequenceOf(_shapeV)!.status, SequenceStatus.partial);
      expect(catalog.sequenceOf(_shapeV)!.stopIds, ['00294', '1202']);
      expect(catalog.sequenceOf('qualquer'), isNull); // status desconhecido
      expect(catalog.sequenceOf(null), isNull);
    });

    test('contexto do ponto: só sequências estimadas', () {
      final places = catalog.itineraryOf('00294');
      expect(places.map((p) => (p.$1.variantId, p.$1.direction, p.$2)), [
        ('001-1', 'i', 2),
        ('042-1', 'i', 1),
      ]);
      expect(catalog.itineraryOf('1203').single.$2, 3);
      expect(catalog.itineraryOf('40999'), isEmpty); // ambíguo não entra
    });
  });

  group('próximos pontos', () {
    RouteMatch confirmedAt(double lon) => matchTrackedRoute(
      catalog: catalog,
      routeId: '001',
      routeName: 'T. Fictício Norte / Centro Imaginário',
      destination: 'CENTRO IMAGINARIO',
      position: _at(lon),
      trail: [_at(lon - 0.004), _at(lon - 0.002)],
    );

    test('só com associação confirmada e sequência confiável', () {
      final m = confirmedAt(-49.282); // ~1,9 km
      expect(m.confirmed, isTrue);
      final next = nextStopsFor(m, catalog.sequenceOf(_shapeI));
      expect(next.available, isTrue);
      expect(next.remaining.map((e) => e.stopId), ['00294', '1203']);
      expect(next.nextConfident, isTrue);

      expect(
        nextStopsFor(m, catalog.sequenceOf(_shapeV)).reason,
        NextStopsReason.sequenceUnreliable,
      );
      expect(nextStopsFor(m, null).reason, NextStopsReason.sequenceUnreliable);
      final pending = matchTrackedRoute(
        catalog: catalog,
        routeId: '001',
        routeName: 'T. Fictício Norte / Centro Imaginário',
        destination: 'CENTRO IMAGINARIO',
        position: _at(-49.282),
      );
      expect(pending.level, RouteMatchLevel.pending);
      expect(
        nextStopsFor(pending, catalog.sequenceOf(_shapeI)).reason,
        NextStopsReason.notConfirmed,
      );
      // GPS vencido: o app passa posição nula; nada de próximos pontos.
      final stale = matchTrackedRoute(
        catalog: catalog,
        routeId: '001',
        routeName: 'T. Fictício Norte / Centro Imaginário',
        destination: 'CENTRO IMAGINARIO',
        position: null,
      );
      expect(
        nextStopsFor(stale, catalog.sequenceOf(_shapeI)).reason,
        NextStopsReason.notConfirmed,
      );
    });

    test('passar perto não basta: ponto só passa 40 m depois', () {
      // 00294 está a ~4264 m; ônibus a ~4,25 km (antes) e ~4,33 km (depois).
      final before = nextStopsFor(
        confirmedAt(-49.2601),
        catalog.sequenceOf(_shapeI),
      );
      expect(before.remaining.first.stopId, '00294');
      final after = nextStopsFor(
        confirmedAt(-49.2593),
        catalog.sequenceOf(_shapeI),
      );
      expect(after.remaining.first.stopId, '1203');
      expect(after.nextConfident, isFalse); // nível médio: sem destaque
      final end = nextStopsFor(
        confirmedAt(-49.2505),
        catalog.sequenceOf(_shapeI),
      );
      expect(end.reason, NextStopsReason.endOfRoute);
    });
  });

  group('associação com retorno pelo mesmo trecho', () {
    // Trajeto que vai 4 km a leste e volta pela mesma via.
    final loop = TransitCatalog(
      version: catalog.version,
      lines: const [CatalogLine(id: '777', name: 'Teste')],
      variants: const [
        CatalogVariant(
          id: '777-1',
          lineId: '777',
          code: '777-1',
          name: 'T. Alfa / Retorno Beta',
        ),
      ],
      stops: const [],
      shapes: [
        CatalogShape(
          id: '777-1i',
          lineId: '777',
          variantId: '777-1',
          direction: 'i',
          encoded: encodePolyline([
            (-16.68, -49.30),
            (-16.68, -49.26),
            (-16.68, -49.30),
          ]),
        ),
      ],
    );
    RouteMatch m(List<double> lons) => matchTrackedRoute(
      catalog: loop,
      routeId: '777',
      routeName: 'T. Alfa / Retorno Beta',
      destination: 'RETORNO BETA',
      position: _at(lons.last),
      trail: [for (final l in lons.take(lons.length - 1)) _at(l)],
    );

    test('só a posição: duas passagens possíveis, ambíguo', () {
      expect(m([-49.28]).reason, RouteMatchReason.repeatedSection);
    });

    test('o rastro decide a passagem (ida e depois volta)', () {
      final going = m([-49.29, -49.285, -49.28]);
      expect(going.confirmed, isTrue);
      expect(going.alongM, closeTo(2132, 30));
      final coming = m([-49.27, -49.275, -49.28]);
      expect(coming.confirmed, isTrue);
      expect(coming.alongM, closeTo(6396, 30));
    });

    test('geometria sinuosa: cadeias que convergem confirmam', () {
      // Desvio em volta de uma quadra (metros a partir de -16.68, -49.30).
      (double, double) xy(double x, double y) =>
          (-16.68 + y / 111195, -49.30 + x / (111195 * 0.9579));
      GeoPosition at(double x, double y) {
        final (lat, lon) = xy(x, y);
        return GeoPosition(latitude: lat, longitude: lon);
      }

      final block = TransitCatalog(
        version: catalog.version,
        lines: loop.lines,
        variants: loop.variants,
        stops: const [],
        shapes: [
          CatalogShape(
            id: '777-1i',
            lineId: '777',
            variantId: '777-1',
            direction: 'i',
            encoded: encodePolyline([
              xy(0, 0),
              xy(600, 0),
              xy(600, 70),
              xy(620, 70),
              xy(620, 0),
              xy(2000, 0),
            ]),
          ),
        ],
      );
      final m = matchTrackedRoute(
        catalog: block,
        routeId: '777',
        routeName: 'T. Alfa / Retorno Beta',
        destination: 'RETORNO BETA',
        position: at(700, 3),
        trail: [at(610, 5), at(640, 3)],
      );
      expect(m.confirmed, isTrue);
      expect(m.alongM, closeTo(840, 5));
    });

    test('avanço incompatível com o deslocamento é salto', () {
      // Trajeto em U: do início ao fim da volta são ~1 km em linha reta e
      // ~5 km pelo trajeto.
      final u = TransitCatalog(
        version: catalog.version,
        lines: loop.lines,
        variants: loop.variants,
        stops: const [],
        shapes: [
          CatalogShape(
            id: '777-1i',
            lineId: '777',
            variantId: '777-1',
            direction: 'i',
            encoded: encodePolyline([
              (-16.68, -49.30),
              (-16.68, -49.28),
              (-16.67, -49.28),
              (-16.67, -49.30),
            ]),
          ),
        ],
      );
      final jump = matchTrackedRoute(
        catalog: u,
        routeId: '777',
        routeName: 'T. Alfa / Retorno Beta',
        destination: 'RETORNO BETA',
        position: _at(-49.30, -16.67),
        trail: [_at(-49.30, -16.68)],
      );
      expect(jump.reason, RouteMatchReason.gpsJump);
    });
  });
}
