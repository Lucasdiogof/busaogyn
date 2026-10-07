import 'package:busaogyn/src/app.dart';
import 'package:busaogyn/src/features/transit/domain/entities/arrival.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/domain/models/transit_snapshot.dart';
import 'package:busaogyn/src/features/transit/domain/repositories/transit_repository.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _fakeMap(
  BuildContext context, {
  required LatLng initialTarget,
  required MapCreatedCallback onMapCreated,
  required OnStyleLoadedCallback onStyleLoaded,
}) {
  return const ColoredBox(
    key: Key('fake-map'),
    color: Colors.grey,
    child: SizedBox.expand(),
  );
}

class _FakeTransitRepository implements TransitRepository {
  @override
  Future<TransitSnapshot<List<ArrivalGroup>>> getArrivals(String stopId) async {
    return TransitSnapshot(
      data: const [
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
          following: null,
        ),
      ],
      fetchedAt: DateTime(2026, 10, 6, 17),
      stale: false,
      ageSeconds: 0,
    );
  }

  @override
  Future<TransitSnapshot<TrackedVehicle?>> getVehiclePosition({
    required String vehicleNumber,
    required String stopId,
  }) async {
    return TransitSnapshot(
      data: const TrackedVehicle(
        id: 'rmtc:20529',
        vehicleNumber: '20529',
        routeId: '020',
        routeName: 'Linha 020',
        destination: 'T. BIBLIA',
        position: GeoPosition(latitude: -16.7, longitude: -49.2),
        accessible: true,
        punctuality: VehiclePunctuality.onTime,
      ),
      fetchedAt: DateTime(2026, 10, 6, 17),
      stale: false,
      ageSeconds: 0,
    );
  }
}

void main() {
  testWidgets('searches a stop and tracks a realtime vehicle', (tester) async {
    await tester.pumpWidget(
      BusaoGynApp(
        repository: _FakeTransitRepository(),
        trackingRefreshInterval: null,
        mapBuilder: _fakeMap,
      ),
    );

    await tester.enterText(find.byType(TextField), '00300');
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await tester.pumpAndSettle();

    expect(find.text('Ponto 00300'), findsOneWidget);
    expect(find.text('020'), findsOneWidget);
    expect(find.text('< 1 min'), findsOneWidget);
    expect(find.text('● Tempo real'), findsOneWidget);
    expect(find.text('Ônibus 20529'), findsOneWidget);
    expect(
      find.text(
        'Acompanhe um ônibus em tempo real para ver sua posição no mapa.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Acompanhar'));
    await tester.pumpAndSettle();

    expect(find.text('No horário'), findsOneWidget);
    expect(find.text('Acessível'), findsOneWidget);
    expect(find.textContaining('Posição:'), findsOneWidget);
    expect(
      find.text(
        'Acompanhe um ônibus em tempo real para ver sua posição no mapa.',
      ),
      findsNothing,
    );
    expect(find.byTooltip('Centralizar ônibus'), findsOneWidget);
    expect(find.byKey(const Key('fake-map')), findsOneWidget);
  });
}
