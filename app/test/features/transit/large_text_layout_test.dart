import 'package:busaogyn/src/app.dart';
import 'package:busaogyn/src/core/settings/theme_mode_cubit.dart';
import 'package:busaogyn/src/core/theme/busao_tokens.dart';
import 'package:busaogyn/src/features/transit/domain/entities/arrival.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/domain/models/transit_snapshot.dart';
import 'package:busaogyn/src/features/transit/domain/repositories/transit_repository.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/arrival_card.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/home_chrome.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/search_header.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/tracked_vehicle_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Palavras de até 10 letras: a fonte do flutter_test (Ahem) é bem mais larga
/// que a Geist, então uma palavra mais longa não cabe nem num cartão inteiro.
const _destination = 'TERMINAL RODOVIARIO PRESIDENTE JUSCELINO KUBITSCHEK';

Widget _fakeMap(BuildContext context, MapSurfaceParams params) =>
    const ColoredBox(key: Key('fake-map'), color: Colors.grey);

final _now = DateTime(2026, 10, 6, 17);

TransitSnapshot<T> _snapshot<T>(T data) =>
    TransitSnapshot(data: data, fetchedAt: _now, stale: false, ageSeconds: 0);

class _Repository implements TransitRepository {
  @override
  Future<TransitSnapshot<List<ArrivalGroup>>> getArrivals(
    String stopId,
  ) async => _snapshot(const [
    ArrivalGroup(
      routeId: '003',
      destination: _destination,
      next: Arrival(
        vehicleId: 'rmtc:20693',
        vehicleNumber: '20693',
        minutes: 3,
        plannedArrival: null,
        predictedArrival: null,
        realtime: true,
        quality: ArrivalQuality.realtime,
      ),
      following: null,
    ),
  ]);

  @override
  Future<TransitSnapshot<TrackedVehicle?>> getVehiclePosition({
    required String vehicleNumber,
    required String stopId,
  }) async => _snapshot<TrackedVehicle?>(
    const TrackedVehicle(
      id: 'rmtc:20693',
      vehicleNumber: '20693',
      routeId: '003',
      routeName: null,
      destination: _destination,
      position: GeoPosition(latitude: -16.7, longitude: -49.2),
      accessible: true,
      punctuality: VehiclePunctuality.onTime,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required double scale,
  required bool dark,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    BusaoGynApp(
      repository: _Repository(),
      trackingRefreshInterval: null,
      mapBuilder: _fakeMap,
      clock: () => _now,
      themeStore: MemoryThemePreferenceStore(
        dark ? ThemeMode.dark : ThemeMode.light,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '30402');
  await tester.tap(find.byTooltip('Buscar'));
  await tester.pumpAndSettle();
}

Future<void> _track(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Acompanhar ônibus 20693'));
  await tester.pumpAndSettle();
}

/// Falha se alguma quebra de linha do parágrafo cair no meio de uma palavra.
/// A última linha não conta quando o texto foi cortado por `maxLines`.
void _expectBreaksBetweenWords(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final text = paragraph.text.toPlainText();
  // Mesmo texto, escala e largura do parágrafo renderizado.
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    maxLines: paragraph.maxLines,
  )..layout(maxWidth: paragraph.constraints.maxWidth);
  var offset = 0;
  var line = 0;
  while (offset < text.length) {
    final range = painter.getLineBoundary(TextPosition(offset: offset));
    line++;
    final last = range.end >= text.length || line >= (paragraph.maxLines ?? 99);
    if (last) break;
    expect(
      text[range.end - 1] == ' ' || text[range.end] == ' ',
      isTrue,
      reason:
          'quebra no meio de palavra: '
          '"${text.substring(range.start, range.end)}" | '
          '"${text.substring(range.end)}"',
    );
    offset = range.end;
  }
  painter.dispose();
}

void main() {
  group('Chrome.headerHeight / dockLayout', () {
    test('com fonte normal mantêm as medidas de sempre', () {
      expect(Chrome.headerHeight(TextScaler.noScaling), Chrome.header);
      for (final width in [328.0, 358.0, 460.0]) {
        final dock = Chrome.dockLayout(width, TextScaler.noScaling);
        expect(dock.labelLines, 1, reason: '$width');
        expect(dock.height, Chrome.dock, reason: '$width');
      }
    });

    test('o cartão de contexto só cresce quando o subtítulo ganha linha', () {
      expect(Chrome.headerHeight(const TextScaler.linear(1.2)), Chrome.header);
      final grown = Chrome.headerHeight(const TextScaler.linear(1.5));
      expect(grown, greaterThan(Chrome.header));
      // Acima de 130% o texto para de crescer, e a altura também.
      expect(Chrome.headerHeight(const TextScaler.linear(2)), grown);
    });

    test('o dock só ganha altura quando "Meu ônibus" não cabe numa linha', () {
      final at150 = Chrome.dockLayout(358, const TextScaler.linear(1.5));
      expect(at150.labelLines, 1);
      expect(at150.height, Chrome.dock);
      final at200 = Chrome.dockLayout(358, const TextScaler.linear(2));
      expect(at200.labelLines, 2);
      expect(at200.height, greaterThan(Chrome.dock));
      // Mais larga (tablet/desktop) a mesma escala ainda cabe em uma linha.
      expect(Chrome.dockLayout(460, const TextScaler.linear(2)).labelLines, 1);
    });
  });

  final combos = <(Size, double)>[
    (const Size(390, 844), 1),
    (const Size(390, 844), 1.5),
    (const Size(390, 844), 2),
    (const Size(1366, 768), 1),
    (const Size(1366, 768), 2),
  ];

  for (final (size, scale) in combos) {
    for (final dark in [false, true]) {
      final name =
          '${size.width.toInt()} px, ${(scale * 100).round()}%, '
          '${dark ? 'escuro' : 'claro'}';

      testWidgets('dock sem corte e com alvo de toque ($name)', (tester) async {
        await _pump(tester, size: size, scale: scale, dark: dark);
        await _track(tester);
        expect(tester.takeException(), isNull);

        final dock = find.byType(AppDock);
        final dockHeight = tester.getSize(dock).height;
        final twoLines = find.descendant(
          of: dock,
          matching: find.text('ônibus'),
        );
        // Contrato: 200% em celular quebra "Meu ônibus" em duas linhas; até
        // 150% (e em tela larga) o rótulo continua numa linha só.
        if (size.width == 390 && scale == 2) {
          expect(twoLines, findsOneWidget, reason: 'rótulo cortado a 200%');
        } else {
          expect(twoLines, findsNothing, reason: 'rótulo quebrou sem precisar');
        }
        if (twoLines.evaluate().isNotEmpty) {
          // Fonte grande em tela estreita: palavras em linhas próprias.
          expect(dockHeight, greaterThan(Chrome.dock));
          expect(
            find.descendant(of: dock, matching: find.text('Meu')),
            findsOneWidget,
          );
        } else {
          expect(
            find.descendant(of: dock, matching: find.text('Meu ônibus')),
            findsOneWidget,
          );
          // Sem fonte grande o dock não cresce para ninguém.
          expect(dockHeight, Chrome.dock);
        }
        if (scale == 1) expect(dockHeight, Chrome.dock);

        // Rótulos nunca cortados: o FittedBox só encolhe, não recorta.
        for (final box in tester.widgetList<FittedBox>(
          find.descendant(of: dock, matching: find.byType(FittedBox)),
        )) {
          expect(box.fit, BoxFit.scaleDown);
        }

        // Alvo de toque mínimo de 48 px em cada aba.
        for (final tab in ['Chegadas', 'Ajustes']) {
          final item = find.ancestor(
            of: find.descendant(of: dock, matching: find.text(tab)),
            matching: find.byType(InkWell),
          );
          expect(tester.getSize(item.first).height, greaterThanOrEqualTo(48));
        }

        // Chegadas e Ajustes continuam funcionando.
        await tester.tap(
          find.descendant(of: dock, matching: find.text('Ajustes')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.descendant(of: dock, matching: find.text('Chegadas')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('destino longo sem corte no meio da palavra ($name)', (
        tester,
      ) async {
        await _pump(tester, size: size, scale: scale, dark: dark);

        // Cartão de chegadas: a maior palavra cabe sem reduzir a fonte.
        final card = find.byType(DestinationText);
        expect(card, findsOneWidget);
        if (scale >= Chrome.largeTextScale) {
          // Fonte grande: o destino ganha a largura do cartão e não encolhe.
          expect(
            tester.renderObject<RenderDestinationText>(card).fontSize,
            14,
            reason: 'fonte reduzida demais',
          );
        }

        await _track(tester);
        expect(tester.takeException(), isNull);

        // Cabeçalho do Meu ônibus: no máximo duas linhas, sem estourar a
        // altura, quebrando só entre palavras.
        final header = find.byType(ContextHeader);
        final subtitle = find.descendant(
          of: header,
          matching: find.textContaining('Indo para'),
        );
        expect(subtitle, findsOneWidget);
        expect(
          tester.getSize(header).height,
          Chrome.headerHeight(TextScaler.linear(scale)),
        );
        final lines = Chrome.headerSubtitleLines(TextScaler.linear(scale));
        expect(tester.renderObject<RenderParagraph>(subtitle).maxLines, lines);
        _expectBreaksBetweenWords(tester, subtitle);

        // Painel do ônibus acompanhado.
        final panel = find.textContaining('Indo para').last;
        _expectBreaksBetweenWords(tester, panel);

        // Ficha de detalhes: o destino inteiro, só quebrando entre palavras.
        await tester.ensureVisible(find.text('Detalhes do ônibus'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Detalhes do ônibus'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final full = find.text(_destination);
        if (full.evaluate().isNotEmpty) {
          _expectBreaksBetweenWords(tester, full.first);
        }
      });
    }
  }
}
