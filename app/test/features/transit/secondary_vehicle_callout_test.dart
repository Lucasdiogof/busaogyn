import 'package:busaogyn/src/core/theme/app_theme.dart';
import 'package:busaogyn/src/features/transit/domain/entities/map_vehicle.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/secondary_vehicle_callout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('destino longo a ${(scale * 100).round()}% quebra só entre '
        'palavras e sem overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      const destination = 'TERMINAL RODOVIARIO PRESIDENTE JUSCELINO KUBITSCHEK';
      await tester.pumpWidget(
        _host(
          SecondaryVehicleCallout(
            vehicle: MapVehicle(
              vehicleNumber: '50462',
              routeId: '020',
              destination: destination,
              position: const GeoPosition(latitude: -16.68, longitude: -49.25),
              isTracked: false,
              stale: false,
              ageSeconds: 4,
            ),
            onTrack: () {},
            onClose: () {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(destination),
      );
      expect(paragraph.maxLines, 2);
      final text = paragraph.text.toPlainText();
      final painter = TextPainter(
        text: paragraph.text,
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
        maxLines: 2,
      )..layout(maxWidth: paragraph.constraints.maxWidth);
      final first = painter.getLineBoundary(const TextPosition(offset: 0));
      if (first.end < text.length) {
        expect(
          text[first.end - 1] == ' ' || text[first.end] == ' ',
          isTrue,
          reason:
              'quebra no meio de palavra: "${text.substring(0, first.end)}"',
        );
      }
      painter.dispose();

      // Fonte grande: o destino sai da linha da placa e ocupa a largura do
      // painel, então a maior palavra não precisa ser partida.
      if (scale >= 1.3) {
        expect(
          tester.getSize(find.text(destination)).width,
          greaterThan(tester.getSize(find.text('Ônibus 50462')).width),
        );
      }
    });
  }
}
