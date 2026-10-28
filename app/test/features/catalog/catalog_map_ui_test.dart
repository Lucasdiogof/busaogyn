import 'package:busaogyn/src/app.dart';
import 'package:busaogyn/src/features/transit/domain/entities/arrival.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/domain/models/transit_snapshot.dart';
import 'package:busaogyn/src/features/transit/domain/repositories/transit_repository.dart';
import 'package:busaogyn/src/features/transit/presentation/cubit/stop_arrivals_cubit.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/home_chrome.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/search_header.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/tracked_vehicle_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_fixture.dart';

final _now = DateTime(2026, 10, 27, 17);

/// Ônibus 90001 na linha 001, andando para leste pelo trajeto de ida da
/// fixture (uma posição nova a cada consulta, com `fetchedAt` crescente).
class _Repository implements TransitRepository {
  _Repository({required this.routeName});

  final String? routeName;
  final String destination = 'CENTRO IMAGINARIO';
  var _calls = 0;

  @override
  Future<TransitSnapshot<List<ArrivalGroup>>> getArrivals(
    String stopId,
  ) async => TransitSnapshot(
    data: const [
      ArrivalGroup(
        routeId: '001',
        destination: 'CENTRO IMAGINARIO',
        next: Arrival(
          vehicleId: 'rmtc:90001',
          vehicleNumber: '90001',
          minutes: 3,
          plannedArrival: null,
          predictedArrival: null,
          realtime: true,
          quality: ArrivalQuality.realtime,
        ),
        following: null,
      ),
    ],
    fetchedAt: _now,
    stale: false,
    ageSeconds: 0,
  );

  @override
  Future<TransitSnapshot<TrackedVehicle?>> getVehiclePosition({
    required String vehicleNumber,
    required String stopId,
  }) async {
    final i = _calls++;
    return TransitSnapshot<TrackedVehicle?>(
      data: TrackedVehicle(
        id: 'rmtc:90001',
        vehicleNumber: '90001',
        routeId: '001',
        routeName: routeName,
        destination: destination,
        position: GeoPosition(
          latitude: -16.6801,
          longitude: -49.290 + i * 0.004,
        ),
        accessible: null,
        punctuality: VehiclePunctuality.unknown,
      ),
      fetchedAt: _now.add(Duration(seconds: 15 * i)),
      stale: false,
      ageSeconds: 0,
    );
  }
}

/// Conta quantas vezes a superfície do mapa é criada.
class _CountingMap extends StatefulWidget {
  const _CountingMap();
  static var created = 0;

  @override
  State<_CountingMap> createState() => _CountingMapState();
}

class _CountingMapState extends State<_CountingMap> {
  @override
  void initState() {
    super.initState();
    _CountingMap.created++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

Future<void> _pump(
  WidgetTester tester,
  _Repository repo, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _CountingMap.created = 0;
  await tester.pumpWidget(
    BusaoGynApp(
      locale: const Locale('pt'),
      repository: repo,
      trackingRefreshInterval: const Duration(seconds: 15),
      arrivalsRefreshInterval: null,
      secondaryRefreshInterval: null,
      mapBuilder: (context, params) => const _CountingMap(),
      clock: () => _now,
      catalog: fixtureCatalog(),
    ),
  );
  await tester.pumpAndSettle();
}

TransitMap _map(WidgetTester tester) =>
    tester.widget<TransitMap>(find.byType(TransitMap));

List<Map<String, dynamic>> _features(Map<String, dynamic> c) =>
    (c['features'] as List).cast<Map<String, dynamic>>();

/// Em telas estreitas o rótulo do dock vira uma palavra por linha.
Finder _dock(String label) => find
    .descendant(
      of: find.byType(NavDock),
      matching: find.byWidgetPredicate(
        // Com rótulo partido em palavras (uma por Text), a última identifica.
        (w) =>
            w is Text && (w.data == label || w.data == label.split(' ').last),
      ),
    )
    .first;

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await _settle(tester);
  await tester.tap(finder);
  await _settle(tester);
}

const _ida =
    'catalog-shape-001-1i - T. FICTICIO NORTE / CENTRO IMAGINARIO - IDA';
const _volta =
    'catalog-shape-001-1v - T. FICTICIO NORTE / CENTRO IMAGINARIO - VOLTA';

Future<void> _startTracking(WidgetTester tester) async {
  final context = tester.element(find.byType(NavDock));
  await context.read<StopArrivalsCubit>().load('00294');
  await tester.pumpAndSettle();
  await context.read<StopArrivalsCubit>().track('90001');
  await _settle(tester);
}

/// Com tracking ativo o status ao vivo redesenha sempre: pumpAndSettle não
/// termina. Avança o tempo o suficiente para animações e consultas.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets(
    'pontos sempre no mapa; ponto tocado abre o detalhe e é destacado',
    (tester) async {
      await _pump(tester, _Repository(routeName: null));
      final network = _map(tester).network!;
      expect(_features(network.stops), hasLength(4));
      expect(_features(network.selectedStop), isEmpty);

      _map(tester).onStopTap!('1201');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('catalog-stop-facts-1201')),
        findsOneWidget,
      );
      final selected = _features(_map(tester).network!.selectedStop);
      expect(selected.single['properties']['id'], '1201');
      final focus = _map(tester).network!.focus!;
      expect((focus.point!.latitude, focus.point!.longitude), (-16.8, -49.24));
    },
  );

  testWidgets('busca foca o mapa no ponto escolhido', (tester) async {
    await _pump(tester, _Repository(routeName: null));
    await tester.enterText(
      find.descendant(
        of: find.byType(SearchHeader),
        matching: find.byType(TextField),
      ),
      'trindade',
    );
    await tester.pumpAndSettle();
    await _tapKey(tester, 'catalog-stop-1202');
    expect(_map(tester).network!.focus!.point!.longitude, -49.49);
  });

  testWidgets('linha: trajeto no mapa, alterna ida/volta e variante, limpa', (
    tester,
  ) async {
    await _pump(tester, _Repository(routeName: null));
    await tester.tap(_dock('Linhas'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'catalog-line-001');

    // Abre com a variante principal, ida, enquadrada.
    var route = _features(_map(tester).network!.route);
    expect(
      route
          .where((f) => f['properties']['active'] == true)
          .single['properties']['dir'],
      'i',
    );
    expect(_map(tester).network!.focus!.bounds, isNotNull);
    expect(find.text('No mapa: 001-1 · Ida'), findsOneWidget);
    expect(_features(_map(tester).network!.routeStops), hasLength(2));
    expect(_features(_map(tester).network!.routeEnds), hasLength(2));

    await _tapKey(tester, _volta);
    route = _features(_map(tester).network!.route);
    expect(
      route
          .where((f) => f['properties']['active'] == true)
          .single['properties']['dir'],
      'v',
    );
    expect(find.text('No mapa: 001-1 · Volta'), findsOneWidget);

    await _tapKey(
      tester,
      'catalog-shape-001-2i - T. FICTICIO NORTE / HOSPITAL TESTE - IDA',
    );
    route = _features(_map(tester).network!.route);
    expect(
      route
          .where((f) => f['properties']['active'] == true)
          .single['properties']['variant'],
      '001-2',
    );

    await _tapKey(tester, 'catalog-clear-route');
    expect(_features(_map(tester).network!.route), isEmpty);
    expect(find.byKey(const ValueKey('catalog-route-banner')), findsNothing);

    await _tapKey(tester, _ida);
    await _tapKey(tester, 'catalog-line-back');
    expect(_features(_map(tester).network!.route), isEmpty);
    expect(_CountingMap.created, 1);
  });

  testWidgets('linha sem trajeto no catálogo não desenha nada', (tester) async {
    await _pump(tester, _Repository(routeName: null));
    await tester.tap(_dock('Linhas'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'catalog-line-NS9');
    expect(_features(_map(tester).network!.route), isEmpty);
    expect(find.byKey(const ValueKey('catalog-route-banner')), findsNothing);
  });

  testWidgets('Meu ônibus: associação confirmada desenha oficial + futuro', (
    tester,
  ) async {
    await _pump(
      tester,
      _Repository(routeName: 'T. Fictício Norte / Centro Imaginário'),
    );
    await _startTracking(tester);
    await tester.tap(_dock('Meu ônibus'));
    await _settle(tester);

    // Uma amostra só: variante achada, sentido ainda não confirmado.
    expect(find.byKey(const ValueKey('route-match-pending')), findsOneWidget);
    expect(_features(_map(tester).network!.trackRoute), isEmpty);

    // Duas atualizações de GPS andando para leste: confirmado.
    await tester.pump(const Duration(seconds: 15));
    await _settle(tester);
    await tester.pump(const Duration(seconds: 15));
    await _settle(tester);
    expect(find.byKey(const ValueKey('route-match-confirmed')), findsOneWidget);
    final track = _features(_map(tester).network!.trackRoute);
    expect(track.map((f) => f['properties']['kind']), ['official', 'future']);
    expect(
      find.textContaining('Não há previsão de horário nem de próximo ponto'),
      findsOneWidget,
    );

    // Rastro observado continua sendo do tracking, intacto.
    expect(_map(tester).observedTrail, hasLength(3));
    expect(_map(tester).vehicleNumber, '90001');
    expect(_CountingMap.created, 1);
    context(tester).read<StopArrivalsCubit>().stopTracking();
  });

  testWidgets('Meu ônibus: itinerário desconhecido recusa e não desenha', (
    tester,
  ) async {
    await _pump(tester, _Repository(routeName: 'Itinerário que não existe'));
    await _startTracking(tester);
    await tester.tap(_dock('Meu ônibus'));
    await _settle(tester);
    await tester.pump(const Duration(seconds: 15));
    await _settle(tester);
    await tester.pump(const Duration(seconds: 15));
    await _settle(tester);
    expect(find.byKey(const ValueKey('route-match-ambiguous')), findsOneWidget);
    expect(
      find.textContaining('o itinerário informado não está no cadastro'),
      findsOneWidget,
    );
    expect(_features(_map(tester).network!.trackRoute), isEmpty);
    expect(_map(tester).observedTrail, hasLength(3));
    context(tester).read<StopArrivalsCubit>().stopTracking();
  });

  testWidgets('tema e abas não recriam o mapa nem perdem rota e tracking', (
    tester,
  ) async {
    await _pump(
      tester,
      _Repository(routeName: 'T. Fictício Norte / Centro Imaginário'),
    );
    await _startTracking(tester);
    await tester.tap(_dock('Linhas'));
    await _settle(tester);
    await _tapKey(tester, 'catalog-line-001');
    await tester.tap(find.byTooltip('Ajustes'));
    await _settle(tester);
    await tester.tap(find.text('Noturno'));
    await _settle(tester);
    await tester.tap(_dock('Favoritos'));
    await _settle(tester);
    expect(_CountingMap.created, 1);
    expect(_features(_map(tester).network!.route), hasLength(3));
    expect(_map(tester).vehicleNumber, '90001');
    expect(tester.takeException(), isNull);
    context(tester).read<StopArrivalsCubit>().stopTracking();
  });

  for (final (size, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(390, 844), 2.0),
    (const Size(1024, 1366), 1.3),
  ]) {
    testWidgets(
      'sem overflow: linha no mapa e Meu ônibus em ${size.width.toInt()} px a ${scale * 100}%',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pump(
          tester,
          _Repository(routeName: 'T. Fictício Norte / Centro Imaginário'),
          size: size,
        );
        await tester.tap(_dock('Linhas'));
        await _settle(tester);
        await _tapKey(tester, 'catalog-line-001');
        await _startTracking(tester);
        await tester.tap(_dock('Meu ônibus'));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        context(tester).read<StopArrivalsCubit>().stopTracking();
      },
    );
  }
}

BuildContext context(WidgetTester tester) =>
    tester.element(find.byType(NavDock));
