import 'package:busaogyn/src/app.dart';
import 'package:busaogyn/src/core/config/map_config.dart';
import 'package:busaogyn/src/core/network/api_exception.dart';
import 'package:busaogyn/src/core/settings/theme_mode_cubit.dart';
import 'package:busaogyn/src/features/transit/domain/entities/arrival.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/domain/models/transit_snapshot.dart';
import 'package:busaogyn/src/features/transit/domain/repositories/transit_repository.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/search_header.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/tracked_vehicle_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

TransitSnapshot<T> _snapshot<T>(T data, {bool stale = false}) =>
    TransitSnapshot(data: data, fetchedAt: _now, stale: stale, ageSeconds: 0);

const _realtimeGroups = [
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
];

const _scheduledGroups = [
  ArrivalGroup(
    routeId: '950',
    destination: 'GARAVELO',
    next: Arrival(
      vehicleId: null,
      vehicleNumber: null,
      minutes: 32,
      plannedArrival: '14:30',
      predictedArrival: null,
      realtime: false,
      quality: ArrivalQuality.scheduled,
    ),
    following: null,
  ),
];

class _FakeTransitRepository implements TransitRepository {
  _FakeTransitRepository({
    this.withPosition = true,
    this.groups = _realtimeGroups,
    this.staleArrivals = false,
  });

  final bool withPosition;
  final List<ArrivalGroup> groups;
  final bool staleArrivals;
  final requestedStops = <String>[];

  /// Pontos que falham com o erro dado.
  final failures = <String, Object>{};

  @override
  Future<TransitSnapshot<List<ArrivalGroup>>> getArrivals(String stopId) async {
    requestedStops.add(stopId);
    final failure = failures[stopId];
    if (failure != null) throw failure;
    return _snapshot(groups, stale: staleArrivals);
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
  ThemePreferenceStore? themeStore,
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
      themeStore: themeStore,
    ),
  );
}

Future<void> _search(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.tap(find.byTooltip('Buscar'));
  await tester.pumpAndSettle();
}

Future<void> _track(WidgetTester tester, String vehicle) async {
  await tester.tap(find.byTooltip('Acompanhar ônibus $vehicle'));
  await tester.pumpAndSettle();
}

TransitMap _map(WidgetTester tester) =>
    tester.widget<TransitMap>(find.byType(TransitMap));

void main() {
  testWidgets('mapa aparece antes de qualquer busca, sem marcador nem status', (
    tester,
  ) async {
    await _pumpApp(tester, _FakeTransitRepository());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fake-map')), findsOneWidget);
    expect(find.text('Digite o código do ponto'), findsOneWidget);
    expect(find.byType(SearchHeader), findsOneWidget);
    expect(find.byTooltip('Centralizar ônibus'), findsNothing);
    expect(find.text('Ao vivo'), findsNothing);
    // Dock com os três destinos; "Ponto"/"Acompanhando" não são mais abas.
    expect(find.text('Chegadas'), findsOneWidget);
    expect(find.text('Meu ônibus'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Ponto'), findsNothing);
    expect(find.text('Acompanhando'), findsNothing);
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

    expect(
      find.bySemanticsLabel('Próximo: menos de 1 minuto, Tempo real'),
      findsOneWidget,
    );
    expect(find.text('TEMPO REAL'), findsOneWidget);
    expect(find.text('depois 17 min'), findsNothing);
    expect(find.text('NÃO CONFIRMADO'), findsOneWidget);
    expect(find.text('020'), findsOneWidget);
    expect(find.text('003'), findsOneWidget);
    // Só o ônibus com GPS confirmado pode ser acompanhado.
    expect(find.byTooltip('Acompanhar ônibus 20529'), findsOneWidget);
    expect(find.byTooltip('Acompanhar ônibus 20648'), findsNothing);
  });

  testWidgets('"Ao vivo" só com tempo real recente', (tester) async {
    await _pumpApp(tester, _FakeTransitRepository());
    await _search(tester, '30402');
    expect(find.text('Ao vivo'), findsOneWidget);
  });

  testWidgets('só horário programado não aparece como ao vivo', (tester) async {
    await _pumpApp(tester, _FakeTransitRepository(groups: _scheduledGroups));
    await _search(tester, '30100');

    expect(find.text('Ao vivo'), findsNothing);
    expect(find.text('Programado'), findsOneWidget);
    expect(find.text('PROGRAMADO'), findsOneWidget);
    expect(find.byTooltip('Acompanhar ônibus 20529'), findsNothing);
  });

  testWidgets('dado stale aparece como desatualizado, não ao vivo', (
    tester,
  ) async {
    await _pumpApp(tester, _FakeTransitRepository(staleArrivals: true));
    await _search(tester, '30402');

    expect(find.text('Ao vivo'), findsNothing);
    expect(find.text('Desatualizado'), findsOneWidget);
    expect(
      find.text('A fonte está instável. Mostrando o último dado válido.'),
      findsOneWidget,
    );
  });

  testWidgets('acompanha um ônibus em tempo real na aba Meu ônibus', (
    tester,
  ) async {
    await _pumpApp(tester, _FakeTransitRepository());
    await _search(tester, '30402');
    await _track(tester, '20529');

    // Cabeçalho e cartão: ônibus, linha e para onde vai.
    expect(find.text('Ônibus 20529'), findsOneWidget);
    expect(find.text('Linha 020'), findsOneWidget);
    expect(find.textContaining('Indo para T.'), findsNWidgets(2));
    expect(find.text('ACOMPANHANDO'), findsOneWidget);
    expect(find.text('No horário'), findsOneWidget);
    expect(find.text('Acessível'), findsOneWidget);
    expect(find.text('min até o ponto 30402'), findsOneWidget);
    expect(find.textContaining('deslocamento observado'), findsOneWidget);
    expect(find.textContaining('rota'), findsNothing);
    expect(find.text('Dados atualizados recentemente'), findsOneWidget);
    // No painel e no status do topo.
    expect(find.text('posição há 0 s'), findsOneWidget);
    expect(find.text('há 0 s'), findsOneWidget);
    expect(find.text('Ao vivo'), findsOneWidget);
    // Coordenadas cruas não aparecem como informação de produto.
    expect(find.textContaining('-16.7'), findsNothing);
    expect(find.byTooltip('Centralizar ônibus'), findsOneWidget);
    expect(_map(tester).vehicleNumber, '20529');
    expect(_map(tester).position, isNotNull);
    // Uma única posição real: rastro com 1 ponto e sem direção inventada.
    expect(_map(tester).observedTrail, hasLength(1));
    expect(_map(tester).observedHeading, isNull);

    await tester.tap(find.byTooltip('Parar de acompanhar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Centralizar ônibus'), findsNothing);
    expect(_map(tester).vehicleNumber, isNull);
    expect(_map(tester).observedTrail, isEmpty);
    // Volta às chegadas do mesmo ponto.
    expect(find.text('Ponto 30402'), findsOneWidget);
    expect(find.byTooltip('Acompanhar ônibus 20529'), findsOneWidget);
  });

  testWidgets('pausar o follow e centralizar de novo', (tester) async {
    await _pumpApp(tester, _FakeTransitRepository());
    await _search(tester, '30402');
    await _track(tester, '20529');

    expect(find.text('Seguindo'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Centralizar ônibus. Seguindo o ônibus'),
      findsOneWidget,
    );

    // Toque direto no mapa (área livre entre o cabeçalho e o painel).
    await tester.tapAt(const Offset(120, 220));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Centralizar ônibus. Seguimento pausado'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Centralizar'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Centralizar'));
    await tester.pumpAndSettle();
    expect(find.text('Seguindo'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Centralizar ônibus. Seguindo o ônibus'),
      findsOneWidget,
    );
  });

  testWidgets('sem posição nada fica girando e o status não é ao vivo', (
    tester,
  ) async {
    await _pumpApp(tester, _FakeTransitRepository(withPosition: false));
    await _search(tester, '30402');
    await _track(tester, '20529');

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('POSIÇÃO INDISPONÍVEL'), findsOneWidget);
    expect(find.text('Sem posição'), findsOneWidget);
    expect(find.text('Ao vivo'), findsNothing);
    expect(find.byTooltip('Centralizar ônibus'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Centralizar'), findsOneWidget);
    final center = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Centralizar'),
    );
    expect(center.onPressed, isNull);
  });

  testWidgets('Meu ônibus sem tracking mostra estado vazio', (tester) async {
    await _pumpApp(tester, _FakeTransitRepository());
    await tester.tap(find.text('Meu ônibus'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum ônibus acompanhado'), findsOneWidget);
    expect(find.text('Acompanhe um veículo em tempo real'), findsOneWidget);
    expect(
      find.text('Escolha um ônibus em tempo real nas chegadas de um ponto.'),
      findsOneWidget,
    );
    expect(find.text('Ver chegadas'), findsNothing);
    expect(find.byTooltip('Centralizar ônibus'), findsNothing);

    await tester.tap(find.text('Buscar um ponto'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchHeader), findsOneWidget);
  });

  testWidgets('buscar outro ponto encerra o acompanhamento anterior', (
    tester,
  ) async {
    final repository = _FakeTransitRepository();
    await _pumpApp(tester, repository);
    await _search(tester, '30402');
    await _track(tester, '20529');

    await tester.tap(find.text('Chegadas'));
    await tester.pumpAndSettle();
    // Em Chegadas o acompanhamento é só um banner compacto.
    expect(
      find.bySemanticsLabel(
        'Ônibus 20529 sendo acompanhado. Ver em Meu ônibus',
      ),
      findsOneWidget,
    );
    expect(find.text('ACOMPANHANDO'), findsNothing);
    expect(find.text('min até o ponto 30402'), findsNothing);

    await tester.tap(find.byTooltip('Buscar outro ponto'));
    await tester.pumpAndSettle();
    await _search(tester, '30100');

    expect(repository.requestedStops, ['30402', '30100']);
    expect(find.text('Ponto 30100'), findsOneWidget);
    expect(_map(tester).vehicleNumber, isNull);
  });

  testWidgets('Ajustes troca o tema e o mapa acompanha', (tester) async {
    final store = MemoryThemePreferenceStore();
    await _pumpApp(tester, _FakeTransitRepository(), themeStore: store);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();

    expect(find.text('Tema'), findsOneWidget);
    expect(
      find.text('OpenFreeMap · © OpenMapTiles · dados © OpenStreetMap'),
      findsOneWidget,
    );

    await tester.tap(find.text('Noturno'));
    await tester.pumpAndSettle();
    expect(store.read(), ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.byType(TransitMap))).brightness,
      Brightness.dark,
    );
    expect(_map(tester).styleString, MapConfig.styles.dark);
    expect(_map(tester).fallbackStyleString, MapConfig.styles.fallback);

    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();
    expect(store.read(), ThemeMode.light);
    expect(_map(tester).styleString, MapConfig.styles.light);

    await tester.tap(find.byTooltip('Fechar ajustes'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchHeader), findsOneWidget);
  });

  testWidgets('tema salvo é aplicado ao abrir', (tester) async {
    await _pumpApp(
      tester,
      _FakeTransitRepository(),
      themeStore: MemoryThemePreferenceStore(ThemeMode.dark),
    );
    await tester.pumpAndSettle();
    expect(_map(tester).styleString, MapConfig.nightStyleAsset);
  });

  for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
    for (final size in const [
      Size(360, 740),
      Size(390, 844),
      Size(430, 932),
      Size(768, 1024),
      Size(1366, 768),
    ]) {
      testWidgets(
        'layout sem overflow em ${size.width.toInt()} px (${mode.name})',
        (tester) async {
          await _pumpApp(
            tester,
            _FakeTransitRepository(),
            size: size,
            themeStore: MemoryThemePreferenceStore(mode),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await _search(tester, '30402');
          expect(tester.takeException(), isNull);

          await _track(tester, '20529');
          expect(tester.takeException(), isNull);
          expect(find.text('ACOMPANHANDO'), findsOneWidget);

          await tester.tap(find.text('Ajustes'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('fake-map')), findsOneWidget);
        },
      );
    }
  }

  for (final size in const [Size(390, 844), Size(1366, 768)]) {
    testWidgets('fonte a 200% sem overflow em ${size.width.toInt()} px', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repository = _FakeTransitRepository()
        ..failures['99999'] = const ApiException(
          code: 'SOURCE_INVALID_RESPONSE',
          message: 'x',
          retryable: true,
        );
      await _pumpApp(tester, repository, size: size);
      await tester.pumpAndSettle();
      await _search(tester, '99999');
      expect(tester.takeException(), isNull);
      await _search(tester, '30402');
      expect(tester.takeException(), isNull);

      // O número do ônibus é identidade: uma linha só, mesmo a 200%.
      final number = tester.renderObject<RenderParagraph>(find.text('20529'));
      expect(number.size.height, lessThan(11 * 2 * 1.5));

      await _track(tester, '20529');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('chegadas se atualizam sozinhas só com a aba Chegadas', (
    tester,
  ) async {
    final repository = _FakeTransitRepository();
    await _pumpApp(tester, repository);
    await _search(tester, '30402');
    expect(repository.requestedStops, hasLength(1));

    await tester.pump(const Duration(seconds: 30));
    expect(repository.requestedStops, hasLength(2));

    for (final tab in ['Meu ônibus', 'Ajustes']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 90));
      expect(repository.requestedStops, hasLength(2), reason: tab);
    }

    await tester.tap(find.text('Chegadas'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(repository.requestedStops, hasLength(3));
    expect(repository.requestedStops.toSet(), {'30402'});
  });

  testWidgets('no celular a atribuição fica acima do sheet', (tester) async {
    await _pumpApp(tester, _FakeTransitRepository());
    await tester.pumpAndSettle();

    expect(_map(tester).attributionBottom, greaterThan(70));

    // Expandido ao máximo, o sheet ainda deixa uma faixa de mapa (com a
    // atribuição) abaixo do cabeçalho.
    final sheetTop = tester.getTopLeft(find.byType(DraggableScrollableSheet));
    final headerBottom = tester.getBottomLeft(find.byType(SearchHeader)).dy;
    expect(sheetTop.dy, greaterThan(headerBottom + 32));
  });

  testWidgets('em tela larga a coluna é central e sem sheet', (tester) async {
    await _pumpApp(
      tester,
      _FakeTransitRepository(),
      size: const Size(1366, 768),
    );
    await tester.pumpAndSettle();

    expect(_map(tester).attributionBottom, 0);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    final search = tester.getRect(find.byType(SearchHeader));
    expect(search.left, closeTo(1366 - search.right, 1));
    expect(search.width, lessThanOrEqualTo(460));
  });

  group('erro de busca de ponto', () {
    const notFound = ApiException(
      code: 'SOURCE_INVALID_RESPONSE',
      message: 'RMTC arrivals payload has an unexpected shape.',
      retryable: true,
      statusCode: 502,
    );

    testWidgets('sem ponto anterior: aviso junto do campo, sem tela de erro', (
      tester,
    ) async {
      final repository = _FakeTransitRepository()..failures['99999'] = notFound;
      await _pumpApp(tester, repository);
      await _search(tester, '99999');

      expect(find.text('Não foi possível consultar'), findsNothing);
      expect(find.textContaining('RMTC arrivals payload'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SearchHeader),
          matching: find.byType(SearchErrorNote),
        ),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byKey(const Key('fake-map')), findsOneWidget);
    });

    testWidgets('mantém o ponto válido anterior e o tracking', (tester) async {
      final repository = _FakeTransitRepository()..failures['99999'] = notFound;
      await _pumpApp(tester, repository);
      await _search(tester, '30402');
      await _track(tester, '20529');
      await tester.tap(find.text('Chegadas'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Buscar outro ponto'));
      await tester.pumpAndSettle();
      await _search(tester, '99999');

      expect(find.byType(SearchErrorNote), findsOneWidget);
      expect(find.textContaining('Ponto não encontrado'), findsWidgets);
      // O ponto anterior e o ônibus acompanhado continuam.
      expect(find.byTooltip('Acompanhar ônibus 20529'), findsNothing);
      expect(find.text('PRÓXIMOS ÔNIBUS'), findsOneWidget);
      expect(_map(tester).vehicleNumber, '20529');

      // Editar o código tira o aviso; uma busca válida substitui o ponto.
      await tester.enterText(find.byType(TextField), '3010');
      await tester.pump();
      expect(find.byType(SearchErrorNote), findsNothing);
      await _search(tester, '30100');
      expect(find.text('Ponto 30100'), findsOneWidget);
      expect(find.byType(SearchErrorNote), findsNothing);
    });

    testWidgets('fechar a busca com erro volta ao ponto anterior', (
      tester,
    ) async {
      final repository = _FakeTransitRepository()..failures['99999'] = notFound;
      await _pumpApp(tester, repository);
      await _search(tester, '30402');
      await tester.tap(find.byTooltip('Buscar outro ponto'));
      await tester.pumpAndSettle();
      await _search(tester, '99999');
      expect(find.byType(SearchErrorNote), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.tap(find.byTooltip('Voltar ao ponto'));
      await tester.pumpAndSettle();

      expect(find.text('Ponto 30402'), findsOneWidget);
      expect(find.byType(SearchErrorNote), findsNothing);
    });
  });

  testWidgets('callout de outro ônibus não divide o canto com o Centralizar', (
    tester,
  ) async {
    const twoRealtime = [
      ArrivalGroup(
        routeId: '020',
        destination: 'T. BIBLIA',
        next: Arrival(
          vehicleId: 'rmtc:20529',
          vehicleNumber: '20529',
          minutes: 2,
          plannedArrival: null,
          predictedArrival: null,
          realtime: true,
          quality: ArrivalQuality.realtime,
        ),
        following: Arrival(
          vehicleId: 'rmtc:20777',
          vehicleNumber: '20777',
          minutes: 9,
          plannedArrival: null,
          predictedArrival: null,
          realtime: true,
          quality: ArrivalQuality.realtime,
        ),
      ),
    ];
    await _pumpApp(tester, _FakeTransitRepository(groups: twoRealtime));
    await _search(tester, '30402');
    await _track(tester, '20529');
    expect(_map(tester).showControls, isTrue);
    expect(_map(tester).secondaryVehicles.map((v) => v.vehicleNumber), [
      '20777',
    ]);

    _map(tester).onSecondaryTap!('20777');
    await tester.pumpAndSettle();
    expect(find.text('Acompanhar este ônibus'), findsOneWidget);
    expect(_map(tester).showControls, isFalse);

    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(find.text('Acompanhar este ônibus'), findsNothing);
    expect(_map(tester).showControls, isTrue);
  });

  testWidgets('Meu ônibus vazio com ponto carregado leva às chegadas', (
    tester,
  ) async {
    await _pumpApp(tester, _FakeTransitRepository());
    await _search(tester, '30402');
    await tester.tap(find.text('Meu ônibus'));
    await tester.pumpAndSettle();

    expect(find.text('Buscar um ponto'), findsNothing);
    await tester.tap(find.text('Ver chegadas'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Acompanhar ônibus 20529'), findsOneWidget);
  });

  testWidgets('banner de Chegadas leva ao Meu ônibus', (tester) async {
    await _pumpApp(tester, _FakeTransitRepository());
    await _search(tester, '30402');
    await _track(tester, '20529');
    await tester.tap(find.text('Chegadas'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.bySemanticsLabel(
        'Ônibus 20529 sendo acompanhado. Ver em Meu ônibus',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ACOMPANHANDO'), findsOneWidget);
    expect(find.text('Linha 020'), findsOneWidget);
  });
}
