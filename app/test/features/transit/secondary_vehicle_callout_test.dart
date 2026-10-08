import 'package:busaogyn/src/core/theme/app_theme.dart';
import 'package:busaogyn/src/features/transit/domain/entities/map_vehicle.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/secondary_vehicle_callout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: Center(child: child)),
  );
}

MapVehicle _vehicle({bool stale = false}) {
  return MapVehicle(
    vehicleNumber: '50462',
    routeId: '020',
    destination: 'T BIBLIA',
    position: const GeoPosition(latitude: -16.68, longitude: -49.25),
    isTracked: false,
    stale: stale,
    ageSeconds: 4,
  );
}

void main() {
  testWidgets('mostra só linha, destino e número, e oferece acompanhar', (
    tester,
  ) async {
    var tracked = 0;
    var closed = 0;
    await tester.pumpWidget(
      _host(
        SecondaryVehicleCallout(
          vehicle: _vehicle(),
          onTrack: () => tracked++,
          onClose: () => closed++,
        ),
      ),
    );

    expect(find.text('Ônibus 50462'), findsOneWidget);
    expect(find.text('020'), findsOneWidget);
    // Espaço sem quebra depois do prefixo curto do destino.
    expect(find.text('T BIBLIA'), findsOneWidget);
    expect(find.text('Posição possivelmente desatualizada'), findsNothing);

    await tester.tap(find.text('Acompanhar este ônibus'));
    expect(tracked, 1);
    await tester.tap(find.byTooltip('Fechar'));
    expect(closed, 1);
  });

  testWidgets('avisa quando a posição pode estar desatualizada', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SecondaryVehicleCallout(
          vehicle: _vehicle(stale: true),
          onTrack: () {},
          onClose: () {},
        ),
      ),
    );

    expect(find.text('Posição possivelmente desatualizada'), findsOneWidget);
  });
}
