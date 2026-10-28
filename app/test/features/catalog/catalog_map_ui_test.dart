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

/// Sem internet: toda consulta falha.
class _OfflineRepository extends _Repository {
  _OfflineRepository() : super(routeName: null);

  @override
  Future<TransitSnapshot<List<ArrivalGroup>>> getArrivals(String stopId) =>
      Future.error(Exception('sem conexão'));

  @override
  Future<TransitSnapshot<TrackedVehicle?>> getVehiclePosition({
    required String vehicleNumber,
    required String stopId,
  }) => Future.error(Exception('sem conexão'));
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
    expect(find.byKey(const ValueKey('next-stops')), findsNothing);

    // Duas atualizações de GPS andando para leste: confirmado.
    await tester.pump(const Duration(seconds: 15));
    await _settle(tester);
    await tester.pump(const Duration(seconds: 15));
    await _settle(tester);
    expect(find.byKey(const ValueKey('route-match-confirmed')), findsOneWidget);
    final track = _features(_map(tester).network!.trackRoute);
    expect(track.map((f) => f['properties']['kind']), ['official', 'future']);
    expect(find.textContaining('Sem previsão de horário'), findsOneWidget);
    // Sequência estimada confiável: próximos pontos, o 1º em destaque
    // (1202, a 500 m, já ficou para trás).
    expect(find.byKey(const ValueKey('next-stops')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('next-stops-confident-true')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('next-stop-0')),
        matching: find.textContaining('00294'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('next-stop-2')), findsNothing);
    expect(
      find.textContaining('Sem previsão de chegada por ponto'),
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

  testWidgets('horários: tipo de dia, validade, marcas e filtro por código', (
    tester,
  ) async {
    await _pump(tester, _Repository(routeName: null));
    await tester.tap(_dock('Linhas'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'catalog-line-001');
    await tester.ensureVisible(find.byKey(const ValueKey('timetable-001')));
    await tester.pumpAndSettle();

    // 27/10/2026 é terça: abre em dias úteis, com aviso de vigência.
    expect(find.byKey(const ValueKey('timetable-recent')), findsOneWidget);
    expect(find.textContaining('vigência não confirmada'), findsOneWidget);
    final times = find.byKey(const ValueKey('timetable-times-weekday'));
    final clocks = tester
        .widgetList<Text>(
          find.descendant(of: times, matching: find.byType(Text)),
        )
        .map((t) => t.data)
        .where((t) => RegExp(r'^\d\d:\d\d$').hasMatch(t ?? ''))
        .toList();
    expect(clocks, ['05:30', '05:45', '06:00', '06:40', '08:20', '00:15']);
    expect(find.text('6 partidas'), findsOneWidget);
    expect(find.text('06:40'), findsOneWidget); // duplicidade exibida uma vez
    expect(find.textContaining('×2: repetido na planilha'), findsOneWidget);
    expect(find.textContaining('+1'), findsWidgets);
    expect(find.textContaining('MI'), findsWidgets);
    expect(find.textContaining('não de passagem nos pontos'), findsOneWidget);
    expect(find.text('Planilha: Fictício · OSO 0001/2026'), findsOneWidget);
    expect(find.text('001-7 (sem cadastro)'), findsOneWidget);

    await _tapKey(tester, 'timetable-code-001-2');
    expect(find.text('1 partida'), findsOneWidget);
    await _tapKey(tester, 'timetable-code-all');
    await _tapKey(tester, 'timetable-day-saturday');
    expect(find.text('1 partida'), findsOneWidget);
    await _tapKey(tester, 'timetable-day-sundayHoliday');
    expect(find.byKey(const ValueKey('timetable-empty-day')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('horários antigos só com aviso; sem dados, indisponível', (
    tester,
  ) async {
    await _pump(tester, _Repository(routeName: null));
    await tester.tap(_dock('Linhas'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'catalog-line-042');
    await tester.ensureVisible(find.byKey(const ValueKey('timetable-042')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('timetable-old')), findsOneWidget);
    expect(find.byKey(const ValueKey('timetable-times-weekday')), findsNothing);
    await _tapKey(tester, 'timetable-show-old');
    expect(find.byKey(const ValueKey('timetable-old-shown')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('timetable-times-weekday')),
      findsOneWidget,
    );

    await _tapKey(tester, 'catalog-line-back');
    await _tapKey(tester, 'catalog-line-NS9');
    await tester.ensureVisible(find.byKey(const ValueKey('timetable-NS9')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('timetable-insufficient')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('timetable-times-weekday')), findsNothing);
  });

  testWidgets('sequência: estimada na ida, sem ordem na volta, nenhuma', (
    tester,
  ) async {
    await _pump(tester, _Repository(routeName: null));
    await tester.tap(_dock('Linhas'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'catalog-line-001');
    expect(find.byKey(const ValueKey('sequence-estimated')), findsOneWidget);
    expect(find.text('PARADAS ESTIMADAS · IDA (3)'), findsOneWidget);
    expect(find.textContaining('Não é a sequência oficial'), findsOneWidget);
    expect(find.textContaining('posição incerta'), findsOneWidget);
    expect(find.textContaining('1 ponto ficou de fora'), findsOneWidget);
    expect(find.byKey(const ValueKey('sequence-stop-2')), findsOneWidget);

    await _tapKey(tester, _volta);
    expect(find.byKey(const ValueKey('sequence-partial')), findsOneWidget);
    expect(find.text('PONTOS PERTO DESTE TRAJETO (2)'), findsOneWidget);
    expect(
      find.textContaining('Sem confiança suficiente para ordenar'),
      findsOneWidget,
    );

    await _tapKey(
      tester,
      'catalog-shape-001-2i - T. FICTICIO NORTE / HOSPITAL TESTE - IDA',
    );
    expect(find.byKey(const ValueKey('sequence-none')), findsOneWidget);

    // Toque numa parada abre o ponto; o itinerário volta ao trajeto e o
    // reenquadra (mesmo trajeto já ativo).
    await _tapKey(tester, _ida);
    await _tapKey(tester, 'sequence-stop-1');
    expect(
      find.byKey(const ValueKey('catalog-stop-facts-00294')),
      findsOneWidget,
    );
    final pointFocus = _map(tester).network!.focus!;
    expect(pointFocus.point, isNotNull);
    // Painel expandido: a troca de conteúdo cancela a animação da folha;
    // o enquadramento não pode ficar esperando por ela.
    await tester.drag(
      find.byType(DraggableScrollableSheet),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await _tapKey(
      tester,
      'itinerary-001-1i - T. FICTICIO NORTE / CENTRO IMAGINARIO - IDA',
    );
    final routeFocus = _map(tester).network!.focus!;
    expect(routeFocus.bounds, isNotNull);
    expect(routeFocus.serial, greaterThan(pointFocus.serial));
  });

  testWidgets('ponto: contexto no itinerário abre a linha com o trajeto', (
    tester,
  ) async {
    await _pump(tester, _Repository(routeName: null));
    _map(tester).onStopTap!('00294');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('itinerary-00294')), findsOneWidget);
    expect(find.text('001-1 · Ida — parada 2 de 3'), findsOneWidget);
    expect(find.text('042-1 · Ida — parada 1 de 2'), findsOneWidget);
    await _tapKey(
      tester,
      'itinerary-001-1i - T. FICTICIO NORTE / CENTRO IMAGINARIO - IDA',
    );
    expect(
      find.byKey(const ValueKey('catalog-line-detail-001')),
      findsOneWidget,
    );
    expect(find.text('No mapa: 001-1 · Ida'), findsOneWidget);
    // Enquadra o trajeto (não fica no ponto).
    expect(_map(tester).network!.focus!.bounds, isNotNull);

    // Ponto sem sequência confiável: sem bloco de itinerário (sem ruído).
    _map(tester).onStopTap!('40999');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('itinerary-40999')), findsNothing);
  });

  testWidgets('offline: horários e sequência vêm só do catálogo', (
    tester,
  ) async {
    await _pump(tester, _OfflineRepository());
    await tester.tap(_dock('Linhas'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'catalog-line-001');
    expect(find.byKey(const ValueKey('sequence-estimated')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('timetable-001')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('timetable-times-weekday')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('planejador: origem pela busca, destino no mapa, baldeação', (
    tester,
  ) async {
    await _pump(tester, _Repository(routeName: null));
    await _tapKey(tester, 'planner-open');
    expect(find.byKey(const ValueKey('trip-planner')), findsOneWidget);
    expect(find.textContaining('Funciona sem internet'), findsOneWidget);

    // Origem pela busca local (nada sai do aparelho).
    await tester.enterText(
      find.byKey(const ValueKey('planner-input-origin')),
      'trindade',
    );
    await tester.pumpAndSettle();
    await _tapKey(tester, 'planner-result-origin-1202');
    expect(find.byKey(const ValueKey('planner-origin-1202')), findsOneWidget);
    // O mapa vai até a origem escolhida.
    expect(_map(tester).network!.focus!.point!.longitude, -49.49);

    // Destino tocando no mapa: preenche o campo, não abre o ponto.
    await _tapKey(tester, 'planner-pick-destination');
    expect(
      find.byKey(const ValueKey('planner-picking-destination')),
      findsOneWidget,
    );
    _map(tester).onStopTap!('1201');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('planner-destination-1201')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('catalog-stop-facts-1201')), findsNothing);

    await _tapKey(tester, 'planner-search');
    expect(find.byKey(const ValueKey('planner-option-0')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('planner-reliability-estimated')),
      findsOneWidget,
    );
    expect(find.text('2 ônibus · 1 baldeação'), findsOneWidget);
    // Extensão no formato do idioma (vírgula em pt), medida no trajeto.
    expect(find.textContaining('3,8 km pelo trajeto'), findsOneWidget);
    expect(find.textContaining('Sem tempo de viagem'), findsOneWidget);

    // Mapa: dois trechos, pontos da viagem, pontos gerais fora, enquadrado.
    final network = _map(tester).network!;
    final kinds = [
      for (final f in _features(network.plan)) f['properties']['kind'],
    ];
    expect(kinds, ['leg1', 'leg2', 'origin', 'transfer', 'destination']);
    expect(_features(network.stops), isEmpty);
    expect(network.focus!.bounds, isNotNull);
    expect(_features(network.route), isEmpty);

    // Inverter: limpa o resultado; o contrário não tem evidência.
    await _tapKey(tester, 'planner-swap');
    expect(_features(_map(tester).network!.plan), isEmpty);
    await _tapKey(tester, 'planner-search');
    expect(
      find.byKey(const ValueKey('planner-status-noRoute')),
      findsOneWidget,
    );

    // Mesmo ponto.
    await _tapKey(tester, 'planner-clear-destination');
    await _tapKey(tester, 'planner-pick-destination');
    _map(tester).onStopTap!('1201');
    await tester.pumpAndSettle();
    await _tapKey(tester, 'planner-search');
    expect(
      find.byKey(const ValueKey('planner-status-sameStop')),
      findsOneWidget,
    );

    // Fechar volta ao mapa normal sem recriar o mapa.
    await _tapKey(tester, 'planner-close');
    expect(find.byKey(const ValueKey('trip-planner')), findsNothing);
    expect(_features(_map(tester).network!.plan), isEmpty);
    expect(_features(_map(tester).network!.stops), hasLength(4));
    expect(_CountingMap.created, 1);
  });

  testWidgets('planejador funciona offline e não mexe no tracking', (
    tester,
  ) async {
    await _pump(tester, _OfflineRepository());
    await _tapKey(tester, 'planner-open');
    await _tapKey(tester, 'planner-pick-origin');
    _map(tester).onStopTap!('1202');
    await tester.pumpAndSettle();
    await _tapKey(tester, 'planner-pick-destination');
    _map(tester).onStopTap!('00294');
    await tester.pumpAndSettle();
    await _tapKey(tester, 'planner-search');
    expect(find.text('1 ônibus · direto'), findsOneWidget);
    expect(_map(tester).vehicleNumber, isNull);
    expect(tester.takeException(), isNull);
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
        // Sequência, horários e marcas no detalhe da linha.
        await tester.ensureVisible(find.byKey(const ValueKey('timetable-001')));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        _map(tester).onStopTap!('00294');
        await _settle(tester);
        expect(tester.takeException(), isNull);
        // Planejador com resultado.
        await tester.tap(_dock('Pontos'));
        await _settle(tester);
        await _tapKey(tester, 'planner-open');
        await _tapKey(tester, 'planner-pick-origin');
        _map(tester).onStopTap!('1202');
        await _settle(tester);
        await _tapKey(tester, 'planner-pick-destination');
        _map(tester).onStopTap!('1201');
        await _settle(tester);
        await _tapKey(tester, 'planner-search');
        await tester.ensureVisible(
          find.byKey(const ValueKey('planner-option-0')),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
        await _tapKey(tester, 'planner-close');
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
