import 'package:busaogyn/src/app.dart';
import 'package:busaogyn/src/features/transit/domain/entities/arrival.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/domain/models/transit_snapshot.dart';
import 'package:busaogyn/src/features/transit/domain/repositories/transit_repository.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/tracked_vehicle_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sem platform view nativa no flutter_test.
Widget _fakeMap(BuildContext context, MapSurfaceParams params) {
  return const ColoredBox(
    key: Key('fake-map'),
    color: Colors.grey,
    child: SizedBox.expand(),
  );
}

final _now = DateTime(2026, 10, 6, 17);

TransitSnapshot<T> _snapshot<T>(T data) =>
    TransitSnapshot(data: data, fetchedAt: _now, stale: false, ageSeconds: 0);

class _FakeTransitRepository implements TransitRepository {
  _FakeTransitRepository({this.withPosition = true});

  final bool withPosition;
  final requestedStops = <String>[];

  @override
  Future<TransitSnapshot<List<ArrivalGroup>>> getArrivals(String stopId) async {
    requestedStops.add(stopId);
    return _snapshot(const [
      ArrivalGroup(
        routeId: '020',
        destination: 'T. BIBLIA',
        next: Arrival(
          vehicleId: 'rmtc:20529',
          vehicleNumber: '20529',
          minutes: 0,
          plannedArrival: '14:02',
          predictedArrival: '14:03',
          realtime: true,
          quality: ArrivalQuality.realtime,
        ),
        following: Arrival(
          vehicleId: null,
          vehicleNumber: null,
          minutes: 17,
          plannedArrival: '14:19',
          predictedArrival: null,
          realtime: false,
          quality: ArrivalQuality.scheduled,
        ),
      ),
      ArrivalGroup(
        routeId: '003',
        destination: 'T MARANATA',
        next: Arrival(
          vehicleId: 'rmtc:20648',
          vehicleNumber: '20648',
          minutes: 9,
          plannedArrival: null,
          predictedArrival: null,
          realtime: true,
          quality: ArrivalQuality.unknown,
        ),
        following: null,
      ),
    ]);
  }

  @override
  Future<TransitSnapshot<TrackedVehicle?>> getVehiclePosition({
    required String vehicleNumber,
    required String stopId,
  }) async {
    if (!withPosition) return _snapshot<TrackedVehicle?>(null);
    return _snapshot<TrackedVehicle?>(
      const TrackedVehicle(
        id: 'rmtc:20529',
        vehicleNumber: '20529',
        routeId: '020',
        routeName: 'Linha 020',
        destination: 'T. BIBLIA',
        position: GeoPosition(latitude: -16.7, longitude: -49.2),
        accessible: true,
        punctuality: VehiclePunctuality.onTime,
      ),
    );
  }
}

Future<void> _pumpApp(
  WidgetTester tester,
  _FakeTransitRepository repository, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    BusaoGynApp(
      repository: repository,
      trackingRefreshInterval: null,
      mapBuilder: _fakeMap,
      clock: () => _now,
    ),
  );
}

Future<void> _search(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).last,
  );
}

void main() {
  testWidgets('mapa aparece antes de qualquer busca, sem marcador', (
    tester,
  ) async {
    await _pumpApp(tester, _FakeTransitRepository());

    expect(find.byKey(const Key('fake-map')), findsOneWidget);
    expect(find.text('Digite o código do ponto'), findsWidgets);
    expect(find.byTooltip('Centralizar ônibus'), findsNothing);
  });

  testWidgets('aceita só dígitos e preserva zeros à esquerda', (tester) async {
    final repository = _FakeTransitRepository();
    await _pumpApp(tester, repository);

    await _search(tester, 'ab00300');

    expect(repository.requestedStops, ['00300']);
    expect(find.text('Ponto 00300'), findsOneWidget);
  });

  testWidgets('distingue tempo real, programado e não confirmado', (
    tester,
  ) async {
    await _pumpApp(tester, _FakeTransitRepository());
    await _search(tester, '30402');

    expect(find.text('< 1 min'), findsOneWidget);
    expect(find.text('Tempo real'), findsOneWidget);
    expect(find.byIcon(Icons.sensors_rounded), findsWidgets);
    expect(find.text('17 min'), findsOneWidget);
    expect(find.text('Programado'), findsOneWidget);

    await _scrollTo(tester, find.text('Informação não confirmada'));
    expect(find.text('Informação não confirmada'), findsOneWidget);
    // Qualidade desconhecida não vira tempo real nem oferece acompanhar.
    expect(find.widgetWithText(OutlinedButton, 'Acompanhar'), findsOneWidget);
  });

  testWidgets('acompanha um ônibus em tempo real', (tester) async {
    await _pumpApp(tester, _FakeTransitRepository());
    await _search(tester, '30402');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Acompanhar'));
    await tester.pumpAndSettle();

    // Pill do cartão + botão da chegada.
    expect(find.text('Acompanhando'), findsNWidgets(2));
    expect(find.text('Ônibus 20529'), findsWidgets);
    expect(find.text('No horário'), findsOneWidget);
    expect(find.text('Acessível'), findsOneWidget);
    expect(find.text('Dados atualizados recentemente'), findsOneWidget);
    // Coordenadas cruas não aparecem como informação de produto.
    expect(find.textContaining('-16.7'), findsNothing);
    expect(find.byTooltip('Centralizar ônibus'), findsOneWidget);
    expect(find.byKey(const Key('fake-map')), findsOneWidget);

    await tester.tap(find.byTooltip('Parar de acompanhar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Centralizar ônibus'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Acompanhar'), findsOneWidget);
  });

  testWidgets('sem posição o botão não fica girando', (tester) async {
    await _pumpApp(tester, _FakeTransitRepository(withPosition: false));
    await _search(tester, '30402');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Acompanhar'));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Sem posição'), findsOneWidget);
    expect(find.text('Posição indisponível'), findsWidgets);
    expect(find.byTooltip('Centralizar ônibus'), findsNothing);
  });

  for (final size in const [
    Size(360, 740),
    Size(390, 844),
    Size(430, 932),
    Size(768, 1024),
    Size(1366, 768),
  ]) {
    testWidgets('layout sem overflow em ${size.width.toInt()} px', (
      tester,
    ) async {
      await _pumpApp(tester, _FakeTransitRepository(), size: size);
      await _search(tester, '30402');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Acompanhar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('fake-map')), findsOneWidget);
      expect(find.text('Acompanhando'), findsWidgets);
    });
  }
}
