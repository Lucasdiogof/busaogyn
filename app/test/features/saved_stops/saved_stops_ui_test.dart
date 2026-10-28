import 'dart:async';

import 'package:busaogyn/src/app.dart';
import 'package:busaogyn/src/core/network/api_exception.dart';
import 'package:busaogyn/src/core/settings/theme_mode_cubit.dart';
import 'package:busaogyn/src/core/ui/busao_components.dart';
import 'package:busaogyn/src/features/saved_stops/domain/saved_stop.dart';
import 'package:busaogyn/src/features/saved_stops/presentation/widgets/saved_stops_widgets.dart';
import 'package:busaogyn/src/features/transit/domain/entities/arrival.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/domain/models/transit_snapshot.dart';
import 'package:busaogyn/src/features/transit/domain/repositories/transit_repository.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/home_chrome.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/search_header.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/tracked_vehicle_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class _CountingMap extends StatefulWidget {
  const _CountingMap();

  static var created = 0;
  static var disposed = 0;

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
  void dispose() {
    _CountingMap.disposed++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(
    key: Key('fake-map'),
    color: Colors.grey,
    child: SizedBox.expand(),
  );
}

Widget _map(BuildContext context, MapSurfaceParams params) =>
    const _CountingMap();

final _now = DateTime(2026, 10, 17, 9);

TransitSnapshot<T> _snap<T>(T data) =>
    TransitSnapshot(data: data, fetchedAt: _now, stale: false, ageSeconds: 0);

const _groups = [
  ArrivalGroup(
    routeId: '020',
    destination: 'T. BIBLIA',
    next: Arrival(
      vehicleId: 'rmtc:20529',
      vehicleNumber: '20529',
      minutes: 4,
      plannedArrival: null,
      predictedArrival: null,
      realtime: true,
      quality: ArrivalQuality.realtime,
    ),
    following: null,
  ),
];

class _Repository implements TransitRepository {
  final requested = <String>[];
  final failures = <String, Object>{};

  /// Pontos cuja resposta espera até o gate abrir.
  final gates = <String, Completer<void>>{};

  @override
  Future<TransitSnapshot<List<ArrivalGroup>>> getArrivals(String stopId) async {
    requested.add(stopId);
    final gate = gates[stopId];
    if (gate != null) await gate.future;
    final failure = failures[stopId];
    if (failure != null) throw failure;
    return _snap(_groups);
  }

  @override
  Future<TransitSnapshot<TrackedVehicle?>> getVehiclePosition({
    required String vehicleNumber,
    required String stopId,
  }) async => _snap<TrackedVehicle?>(
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

const _offline = ApiException(
  code: 'NETWORK_ERROR',
  message: 'sem rede',
  retryable: true,
);

Future<void> _pump(
  WidgetTester tester, {
  _Repository? repository,
  FakeStore? store,
  Size size = const Size(390, 844),
  ThemeMode theme = ThemeMode.light,
  double textScale = 1,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    BusaoGynApp(
      locale: const Locale('pt'),
      repository: repository ?? _Repository(),
      trackingRefreshInterval: null,
      mapBuilder: _map,
      clock: () => _now,
      themeStore: MemoryThemePreferenceStore(theme),
      savedStopsStore: store ?? FakeStore(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String code) async {
  // Com um ponto na tela o campo fica atrás do botão de buscar outro ponto.
  if (find.byType(TextField).evaluate().isEmpty) {
    await tester.tap(find.byTooltip('Buscar outro ponto'));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byType(TextField), code);
  await tester.tap(find.byTooltip('Buscar'));
  await tester.pumpAndSettle();
}

/// Abre uma aba sem esperar o fim das animações: com uma consulta pendente o
/// botão Atualizar gira sem parar e `pumpAndSettle` nunca termina.
Future<void> _openTabNow(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavDock), matching: find.text(label)),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavDock), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Finder _favTile(String code) => find.descendant(
  of: find.byType(FavoritesPanel),
  matching: find.text('Ponto $code', findRichText: true),
);

Finder _recentTile(String code) => find.descendant(
  of: find.byType(RecentStopsSection),
  matching: find.text('Ponto $code', findRichText: true),
);

Finder _iconButton(Finder tooltip) =>
    find.ancestor(of: tooltip, matching: find.byType(IconButton)).first;

Finder _favStar(String code) => find.byTooltip('Favoritar o ponto $code');
Finder _unfavStar(String code) =>
    find.byTooltip('Remover o ponto $code dos favoritos');

Color? _fieldBorder(WidgetTester tester) => tester
    .widget<GlassSurface>(
      find
          .descendant(
            of: find.byType(SearchHeader),
            matching: find.byType(GlassSurface),
          )
          .first,
    )
    .borderColor;

SavedStopsData _data({
  List<String> favorites = const [],
  List<String> recents = const [],
}) => SavedStopsData(
  favorites: [for (final c in favorites) stop(c)],
  recents: [for (final c in recents) stop(c)],
);

void main() {
  setUp(() {
    _CountingMap.created = 0;
    _CountingMap.disposed = 0;
  });

  group('favoritos', () {
    testWidgets('favorita e desfavorita pelo cabeçalho do ponto', (
      tester,
    ) async {
      final store = FakeStore();
      await _pump(tester, store: store);
      await _search(tester, '30402');

      expect(_favStar('30402'), findsOneWidget);
      expect(_unfavStar('30402'), findsNothing);

      await tester.tap(_favStar('30402'));
      await tester.pumpAndSettle();
      // Identifica que o ponto atual é favorito: outra dica e estrela cheia.
      expect(_unfavStar('30402'), findsOneWidget);
      expect(_favStar('30402'), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(codes(store.data.favorites), ['30402']);

      await _openTab(tester, 'Salvos');
      expect(_favTile('30402'), findsOneWidget);
      expect(find.text('1 ponto salvo'), findsOneWidget);

      await _openTab(tester, 'Pontos');
      await tester.tap(_unfavStar('30402'));
      await tester.pumpAndSettle();
      expect(_favStar('30402'), findsOneWidget);
      expect(store.data.favorites, isEmpty);

      await _openTab(tester, 'Salvos');
      expect(
        find.text('Seus pontos favoritos aparecerão aqui.'),
        findsOneWidget,
      );
      expect(find.text('Nenhum ponto salvo'), findsOneWidget);
    });

    testWidgets('a estrela só funciona com o ponto já consultado', (
      tester,
    ) async {
      final repository = _Repository();
      final gate = repository.gates['30402'] = Completer<void>();
      final store = FakeStore();
      await _pump(tester, repository: repository, store: store);

      await tester.enterText(find.byType(TextField), '30402');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pump();
      final loading = tester.widget<IconButton>(_iconButton(_favStar('30402')));
      expect(loading.onPressed, isNull);

      gate.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<IconButton>(_iconButton(_favStar('30402'))).onPressed,
        isNotNull,
      );
      expect(store.saves, hasLength(1)); // só o registro do recente
    });

    testWidgets('lista vazia mantém a ação Buscar um ponto', (tester) async {
      await _pump(tester);
      await _openTab(tester, 'Salvos');
      await _tap(tester, find.text('Buscar um ponto'));
      expect(find.byType(SearchHeader), findsOneWidget);
    });

    testWidgets('os favoritos persistem ao fechar e reabrir o app', (
      tester,
    ) async {
      final store = FakeStore();
      await _pump(tester, store: store);
      await _search(tester, '30402');
      await tester.tap(_favStar('30402'));
      await tester.pumpAndSettle();

      // Fecha o app e abre outro, com o mesmo armazenamento.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _pump(tester, store: store);
      await _openTab(tester, 'Salvos');

      expect(_favTile('30402'), findsOneWidget);
      expect(find.text('1 ponto salvo'), findsOneWidget);
    });

    testWidgets('remove um favorito pela lista', (tester) async {
      final store = FakeStore(initial: _data(favorites: ['30402', '30100']));
      await _pump(tester, store: store);
      await _openTab(tester, 'Salvos');

      await tester.tap(_unfavStar('30402'));
      await tester.pumpAndSettle();
      expect(_favTile('30402'), findsNothing);
      expect(_favTile('30100'), findsOneWidget);
      expect(codes(store.data.favorites), ['30100']);
    });

    testWidgets('tocar num favorito abre Pontos e consulta o código', (
      tester,
    ) async {
      final repository = _Repository();
      await _pump(
        tester,
        repository: repository,
        store: FakeStore(initial: _data(favorites: ['30402', '30100'])),
      );
      await _openTab(tester, 'Salvos');
      repository.requested.clear(); // consulta do resumo dos favoritos
      await _tap(tester, _favTile('30100'));

      expect(repository.requested, ['30100']);
      expect(find.text('Ponto 30100'), findsOneWidget);
      expect(find.text('PRÓXIMOS ÔNIBUS'), findsOneWidget);
      expect(find.byType(FavoritesPanel), findsNothing);
    });

    testWidgets('mostra o nome só quando há nome confiável', (tester) async {
      final store = FakeStore(
        initial: SavedStopsData(
          favorites: [
            stop('30402', name: 'Praça Cívica'),
            stop('30100'),
          ],
        ),
      );
      await _pump(tester, store: store);
      await _openTab(tester, 'Salvos');
      expect(find.text('Praça Cívica'), findsOneWidget);
      expect(_favTile('30402'), findsOneWidget); // o código continua à vista
      expect(_favTile('30100'), findsOneWidget);
    });

    testWidgets('no limite, avisa em vez de remover algum favorito', (
      tester,
    ) async {
      final store = FakeStore(
        initial: SavedStopsData(
          favorites: [
            for (var i = 1; i <= defaultFavoriteStopsLimit; i++) stop('$i'),
          ],
        ),
      );
      await _pump(tester, store: store);
      await _search(tester, '99999');
      await tester.tap(_favStar('99999'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Limite de 50 favoritos'), findsOneWidget);
      expect(store.data.favorites, hasLength(defaultFavoriteStopsLimit));
      expect(_favStar('99999'), findsOneWidget);
    });
  });

  group('chegadas nos favoritos', () {
    testWidgets('mostra as próximas chegadas com a hora da consulta', (
      tester,
    ) async {
      final repository = _Repository();
      await _pump(
        tester,
        repository: repository,
        store: FakeStore(initial: _data(favorites: ['30402'])),
      );
      await _openTab(tester, 'Salvos');

      expect(repository.requested, ['30402']);
      expect(find.textContaining('020', findRichText: true), findsWidgets);
      expect(find.textContaining('Consulta das'), findsOneWidget);
    });

    testWidgets('sem internet diz isso e não mostra previsão', (tester) async {
      final repository = _Repository()..failures['30402'] = _offline;
      await _pump(
        tester,
        repository: repository,
        store: FakeStore(initial: _data(favorites: ['30402'])),
      );
      await _openTab(tester, 'Salvos');

      expect(find.textContaining('Sem conexão'), findsWidgets);
      expect(find.textContaining('Consulta das'), findsNothing);
      expect(find.textContaining(' min', findRichText: true), findsNothing);
    });

    testWidgets('Atualizar chegadas consulta de novo, uma vez por toque', (
      tester,
    ) async {
      final repository = _Repository();
      await _pump(
        tester,
        repository: repository,
        store: FakeStore(initial: _data(favorites: ['30402'])),
      );
      await _openTab(tester, 'Salvos');
      expect(repository.requested, ['30402']);

      await tester.tap(find.text('Atualizar chegadas'));
      await tester.pumpAndSettle();
      expect(repository.requested, ['30402', '30402']);
    });

    testWidgets('reabrir a aba logo em seguida não consulta de novo', (
      tester,
    ) async {
      final repository = _Repository();
      await _pump(
        tester,
        repository: repository,
        store: FakeStore(initial: _data(favorites: ['30402'])),
      );
      await _openTab(tester, 'Salvos');
      await _openTab(tester, 'Linhas');
      await _openTab(tester, 'Salvos');
      expect(repository.requested, ['30402']);
    });

    testWidgets('linha favorita mostra só a sua linha', (tester) async {
      final repository = _Repository();
      await _pump(
        tester,
        repository: repository,
        store: FakeStore(
          initial: SavedStopsData(
            lines: [
              SavedLine(
                stopCode: '30402',
                routeId: '999',
                at: DateTime.utc(2026, 10, 17),
              ),
            ],
          ),
        ),
      );
      await _openTab(tester, 'Salvos');

      // A fonte não traz a linha 999 neste ponto: nada de chegada inventada.
      expect(
        find.textContaining('Nenhuma chegada prevista agora'),
        findsOneWidget,
      );
    });
  });

  group('aba Linhas', () {
    testWidgets('sem consulta nenhuma explica e leva à busca', (tester) async {
      await _pump(tester);
      await _openTab(tester, 'Linhas');
      expect(
        find.text('As linhas estarão disponíveis em breve.'),
        findsOneWidget,
      );
      expect(find.text('Buscar um ponto'), findsOneWidget);
    });

    testWidgets('lista as linhas vistas e toque consulta o ponto', (
      tester,
    ) async {
      final repository = _Repository();
      await _pump(tester, repository: repository);
      await _search(tester, '30402');
      repository.requested.clear();

      await _openTab(tester, 'Linhas');
      expect(find.text('LINHAS VISTAS'), findsOneWidget);
      expect(find.text('no ponto 30402'), findsOneWidget);
      // Sem ordem de percurso, sentido ou minutos: só onde a linha apareceu.
      expect(find.textContaining(' min'), findsNothing);

      await tester.tap(find.text('no ponto 30402'));
      await tester.pumpAndSettle();
      expect(find.text('Ponto 30402'), findsOneWidget);
    });
  });

  group('linhas favoritas', () {
    Finder lineStar(String route, String stop) =>
        find.byTooltip('Favoritar a linha $route neste ponto');
    Finder lineUnstar(String route, String stop) =>
        find.byTooltip('Remover a linha $route do ponto $stop dos favoritos');

    testWidgets('favorita a linha no ponto, lista em Favoritos e remove', (
      tester,
    ) async {
      final store = FakeStore();
      await _pump(tester, store: store);
      await _search(tester, '30402');

      await _tap(tester, lineStar('020', '30402').first);
      expect(store.data.lines.single.stopCode, '30402');
      expect(store.data.lines.single.routeId, '020');
      expect(lineUnstar('020', '30402'), findsOneWidget);
      // Favoritar a linha não favorita o ponto.
      expect(store.data.favorites, isEmpty);

      await _openTab(tester, 'Salvos');
      expect(find.text('LINHAS FAVORITAS'), findsOneWidget);
      expect(
        find.byTooltip('Remover a linha 020 do ponto 30402 dos favoritos'),
        findsOneWidget,
      );
      // Só linha favorita: não cai no estado vazio.
      expect(find.text('Seus pontos favoritos aparecerão aqui.'), findsNothing);

      await tester.tap(
        find.byTooltip('Remover a linha 020 do ponto 30402 dos favoritos'),
      );
      await tester.pumpAndSettle();
      expect(store.data.lines, isEmpty);
      expect(
        find.text('Seus pontos favoritos aparecerão aqui.'),
        findsOneWidget,
      );
    });

    testWidgets('tocar na linha favorita consulta o ponto', (tester) async {
      final repository = _Repository();
      final store = FakeStore(
        initial: SavedStopsData(
          lines: [
            SavedLine(
              stopCode: '30100',
              routeId: '020',
              at: DateTime.utc(2026, 10, 17),
            ),
          ],
        ),
      );
      await _pump(tester, repository: repository, store: store);
      await _openTab(tester, 'Salvos');
      repository.requested.clear(); // consulta do resumo dos favoritos

      await tester.tap(
        find.bySemanticsLabel(
          'Consultar as chegadas da linha 020 no ponto 30100',
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.requested, ['30100']);
    });
  });

  group('recentes', () {
    testWidgets('registra consultas com sucesso, do mais novo ao mais antigo', (
      tester,
    ) async {
      final store = FakeStore();
      await _pump(tester, store: store);
      await _search(tester, '30402');
      await _search(tester, '30100');
      await _search(tester, '30500');

      expect(codes(store.data.recents), ['30500', '30100', '30402']);
      // A seção não repete o ponto que já está na tela.
      expect(_recentTile('30500'), findsNothing);
      expect(_recentTile('30100'), findsOneWidget);
      expect(_recentTile('30402'), findsOneWidget);
      final first = tester.getTopLeft(_recentTile('30100')).dy;
      final second = tester.getTopLeft(_recentTile('30402')).dy;
      expect(first, lessThan(second));
    });

    testWidgets('reconsultar move o ponto para o início, sem duplicar', (
      tester,
    ) async {
      final store = FakeStore();
      await _pump(tester, store: store);
      await _search(tester, '30402');
      await _search(tester, '30100');
      await _search(tester, '30402');
      expect(codes(store.data.recents), ['30402', '30100']);

      // Mesmo ponto já na tela: reconsultar também registra, sem duplicar.
      await _search(tester, '30402');
      expect(codes(store.data.recents), ['30402', '30100']);
    });

    testWidgets('o limite de 10 vale na interface', (tester) async {
      final store = FakeStore();
      await _pump(tester, store: store);
      for (var i = 1; i <= 12; i++) {
        await _search(tester, '${30000 + i}');
      }
      expect(store.data.recents, hasLength(defaultRecentStopsLimit));
      expect(store.data.recents.first.code, '30012');
      expect(store.data.recents.any((s) => s.code == '30001'), isFalse);
    });

    testWidgets('código inválido e consulta com erro não entram', (
      tester,
    ) async {
      final repository = _Repository()
        ..failures['30402'] = _offline
        ..failures['30100'] = const ApiException(
          code: 'SOURCE_UNAVAILABLE',
          message: 'x',
          retryable: true,
          statusCode: 503,
        );
      final store = FakeStore();
      await _pump(tester, repository: repository, store: store);

      await _search(tester, 'abc');
      await _search(tester, '30402');
      await _search(tester, '30100');
      expect(store.saves, isEmpty);
      expect(store.data.recents, isEmpty);

      // A consulta que dá certo entra, e só ela.
      await _search(tester, '30500');
      expect(codes(store.data.recents), ['30500']);
    });

    testWidgets('atualização que falha não registra de novo', (tester) async {
      final repository = _Repository();
      final store = FakeStore();
      await _pump(tester, repository: repository, store: store);
      await _search(tester, '30402');
      final saves = store.saves.length;

      repository.failures['30402'] = _offline;
      await tester.tap(find.byTooltip('Atualizar chegadas'));
      await tester.pumpAndSettle();
      expect(store.saves, hasLength(saves));
    });

    testWidgets('reconsultar o mesmo ponto e falhar não registra de novo', (
      tester,
    ) async {
      final repository = _Repository();
      final store = FakeStore();
      await _pump(tester, repository: repository, store: store);
      await _search(tester, '30402');
      await _search(tester, '30100');
      expect(codes(store.data.recents), ['30100', '30402']);
      final saves = store.saves.length;

      // O mesmo código do ponto na tela, digitado de novo, com a rede caída.
      await _search(tester, '30100');
      repository.failures['30100'] = _offline;
      await _search(tester, '30100');
      expect(find.textContaining('Mostrando a consulta'), findsOneWidget);

      // A reconsulta que falhou não foi uma consulta com sucesso.
      expect(store.saves.length, saves + 1); // só a que deu certo antes
      expect(codes(store.data.recents), ['30100', '30402']);

      // E a pendência não vaza: uma atualização que dá certo depois não
      // vira registro.
      repository.failures.remove('30100');
      final before = store.saves.length;
      await tester.tap(find.byTooltip('Atualizar chegadas'));
      await tester.pumpAndSettle();
      expect(store.saves, hasLength(before));
    });

    testWidgets('retry depois do erro registra uma única vez', (tester) async {
      final repository = _Repository()..failures['30402'] = _offline;
      final store = FakeStore();
      await _pump(tester, repository: repository, store: store);
      await _search(tester, '30402');
      expect(store.data.recents, isEmpty);

      repository.failures.remove('30402');
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();
      expect(codes(store.data.recents), ['30402']);
      expect(store.saves, hasLength(1));
    });

    testWidgets('aparecem em Pontos antes de qualquer consulta', (
      tester,
    ) async {
      await _pump(
        tester,
        store: FakeStore(initial: _data(recents: ['30500', '30100', '30402'])),
      );
      expect(find.text('Digite o código do ponto'), findsOneWidget);
      expect(find.text('RECENTES'), findsOneWidget);
      final ys = [
        for (final c in ['30500', '30100', '30402'])
          tester.getTopLeft(_recentTile(c)).dy,
      ];
      expect(ys, orderedEquals([...ys]..sort()));
    });

    testWidgets('sem recentes, a seção explica que está vazia', (tester) async {
      await _pump(tester);
      expect(find.text('RECENTES'), findsOneWidget);
      expect(
        find.text('Os pontos que você consultar aparecerão aqui.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Limpar'), findsNothing);
    });

    testWidgets('tocar num recente consulta o ponto de novo', (tester) async {
      final repository = _Repository();
      await _pump(
        tester,
        repository: repository,
        store: FakeStore(initial: _data(recents: ['30100'])),
      );
      await _tap(tester, _recentTile('30100'));
      expect(repository.requested, ['30100']);
      expect(find.text('Ponto 30100'), findsOneWidget);
    });

    testWidgets('remove um item dos recentes', (tester) async {
      final store = FakeStore(initial: _data(recents: ['30100', '30402']));
      await _pump(tester, store: store);
      await _tap(tester, find.byTooltip('Remover o ponto 30100 dos recentes'));
      expect(_recentTile('30100'), findsNothing);
      expect(_recentTile('30402'), findsOneWidget);
      expect(codes(store.data.recents), ['30402']);
    });

    testWidgets('limpar pede confirmação e preserva os favoritos', (
      tester,
    ) async {
      final store = FakeStore(
        initial: _data(favorites: ['30500'], recents: ['30100', '30402']),
      );
      await _pump(tester, store: store);

      // Cancelar não apaga nada.
      await _tap(tester, find.widgetWithText(TextButton, 'Limpar'));
      expect(find.text('Limpar recentes?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(codes(store.data.recents), ['30100', '30402']);

      // Confirmar apaga só o histórico.
      await _tap(tester, find.widgetWithText(TextButton, 'Limpar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Limpar'));
      await tester.pumpAndSettle();
      expect(store.data.recents, isEmpty);
      expect(codes(store.data.favorites), ['30500']);
      expect(
        find.text('Os pontos que você consultar aparecerão aqui.'),
        findsOneWidget,
      );
    });
  });

  group('consultas por toque: sem duplicar e sem resposta velha', () {
    testWidgets('tocar duas vezes no mesmo favorito consulta uma vez', (
      tester,
    ) async {
      final repository = _Repository();
      final gate = repository.gates['30402'] = Completer<void>();
      await _pump(
        tester,
        repository: repository,
        store: FakeStore(initial: _data(favorites: ['30402'])),
      );
      await _openTabNow(tester, 'Salvos');
      repository.requested.clear(); // consulta do resumo dos favoritos
      await tester.tap(_favTile('30402'));
      await tester.pump();

      // Volta a Favoritos com a consulta em andamento e toca de novo.
      await tester.tap(
        find.descendant(
          of: find.byType(NavDock),
          matching: find.text('Salvos'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(_favTile('30402'));
      await tester.pump();
      expect(repository.requested, ['30402']);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Ponto 30402'), findsOneWidget);
      expect(repository.requested, ['30402']);
    });

    testWidgets('resposta antiga não sobrescreve a mais recente', (
      tester,
    ) async {
      final repository = _Repository();
      final gateA = repository.gates['30100'] = Completer<void>();
      final gateB = repository.gates['30402'] = Completer<void>();
      final store = FakeStore(initial: _data(favorites: ['30100', '30402']));
      await _pump(tester, repository: repository, store: store);
      await _openTabNow(tester, 'Salvos');
      repository.requested.clear(); // consulta do resumo dos favoritos

      await tester.tap(_favTile('30100'));
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(NavDock),
          matching: find.text('Salvos'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(_favTile('30402'));
      await tester.pump();
      expect(repository.requested, ['30100', '30402']);

      // A segunda responde primeiro; a primeira, atrasada, chega depois.
      gateB.complete();
      await tester.pumpAndSettle();
      gateA.complete();
      await tester.pumpAndSettle();

      expect(find.text('Ponto 30402'), findsOneWidget);
      expect(find.text('Ponto 30100'), findsNothing);
      expect(codes(store.data.recents), ['30402']);
    });
  });

  group('offline', () {
    testWidgets('abre favoritos e recentes sem internet e diz que a previsão '
        'precisa de conexão', (tester) async {
      final repository = _Repository()..failures['30402'] = _offline;
      final store = FakeStore(
        initial: _data(favorites: ['30402'], recents: ['30100']),
      );
      await _pump(tester, repository: repository, store: store);

      // Tenta consultar um favorito offline: estado do PR #33, sem borda.
      await _openTab(tester, 'Salvos');
      await _tap(tester, _favTile('30402'));
      expect(find.text('Chegadas precisam de internet'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(_fieldBorder(tester), isNull);
      expect(find.text('PRÓXIMOS ÔNIBUS'), findsNothing);
      // Os recentes continuam à mão, e nenhum horário antigo aparece.
      expect(_recentTile('30100'), findsOneWidget);
      expect(find.textContaining('min'), findsNothing);

      // Favoritos seguem abertos e avisam que previsão precisa de conexão.
      await _openTab(tester, 'Salvos');
      expect(_favTile('30402'), findsOneWidget);
      expect(
        find.textContaining('Sem conexão. Você pode abrir'),
        findsOneWidget,
      );
      expect(
        find.textContaining('A consulta precisa de internet'),
        findsOneWidget,
      );
      expect(store.data.recents.any((s) => s.code == '30402'), isFalse);

      // Voltou a conexão: o mesmo código consulta e entra nos recentes.
      repository.failures.remove('30402');
      await _openTab(tester, 'Pontos');
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();
      expect(find.text('Ponto 30402'), findsOneWidget);
      expect(codes(store.data.recents).first, '30402');
    });

    testWidgets('falha da fonte tem aviso próprio nas listas', (tester) async {
      final repository = _Repository()
        ..failures['30402'] = const ApiException(
          code: 'SOURCE_UNAVAILABLE',
          message: 'RMTC arrivals source returned HTTP 502.',
          retryable: true,
          statusCode: 503,
        );
      await _pump(
        tester,
        repository: repository,
        store: FakeStore(initial: _data(favorites: ['30402'])),
      );
      await _openTab(tester, 'Salvos');
      await _tap(tester, _favTile('30402'));
      await _openTab(tester, 'Salvos');
      expect(
        find.textContaining('A última consulta não foi concluída'),
        findsOneWidget,
      );
      expect(find.textContaining('HTTP 502'), findsNothing);
    });
  });

  group('armazenamento', () {
    testWidgets('mostra o carregamento discreto e depois a lista', (
      tester,
    ) async {
      final gate = Completer<void>();
      final store = FakeStore(initial: _data(favorites: ['30402']))
        ..loadGate = gate;
      await _pump(tester, store: store, settle: false);
      await tester.tap(
        find.descendant(
          of: find.byType(NavDock),
          matching: find.text('Salvos'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SkeletonBlock), findsWidgets);
      expect(find.text('Carregando…'), findsOneWidget);
      expect(find.text('Seus pontos favoritos aparecerão aqui.'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(_favTile('30402'), findsOneWidget);
      expect(find.byType(SkeletonBlock), findsNothing);
    });

    testWidgets('falha ao salvar avisa e mantém a lista', (tester) async {
      final store = FakeStore()..saveError = StateError('sem espaço');
      await _pump(tester, store: store);
      await _search(tester, '30402');
      await tester.tap(_favStar('30402'));
      await tester.pumpAndSettle();

      await _openTab(tester, 'Salvos');
      expect(_favTile('30402'), findsOneWidget);
      expect(
        find.textContaining('Não foi possível salvar agora'),
        findsOneWidget,
      );
    });

    testWidgets('armazenamento corrompido começa vazio e avisa', (
      tester,
    ) async {
      await _pump(tester, store: FakeStore(unreadable: true));
      await _openTab(tester, 'Salvos');
      expect(
        find.textContaining('Não foi possível ler os pontos salvos'),
        findsOneWidget,
      );
      expect(
        find.text('Seus pontos favoritos aparecerão aqui.'),
        findsOneWidget,
      );
    });

    testWidgets('sem armazenamento do aparelho, avisa que vale só na sessão', (
      tester,
    ) async {
      await _pump(tester, store: FakeStore(isPersistent: false));
      await _openTab(tester, 'Salvos');
      expect(
        find.textContaining('Este aparelho não guardou os pontos'),
        findsOneWidget,
      );
    });
  });

  group('acessibilidade e layout', () {
    testWidgets('alvos de toque de pelo menos 48 dp', (tester) async {
      await _pump(
        tester,
        store: FakeStore(
          initial: _data(favorites: ['30402'], recents: ['30100']),
        ),
      );
      void expectTarget(Finder finder, String what) {
        final size = tester.getSize(finder.first);
        expect(size.height, greaterThanOrEqualTo(48), reason: what);
        expect(size.width, greaterThanOrEqualTo(48), reason: what);
      }

      expectTarget(
        find.ancestor(of: _recentTile('30100'), matching: find.byType(InkWell)),
        'linha do recente',
      );
      expectTarget(
        find.byTooltip('Remover o ponto 30100 dos recentes'),
        'remover recente',
      );
      expectTarget(find.widgetWithText(TextButton, 'Limpar'), 'Limpar');

      await _openTab(tester, 'Salvos');
      expectTarget(
        find.byTooltip('Remover o ponto 30402 dos favoritos'),
        'remover favorito',
      );
      expect(tester.getSize(_favTile('30402')).height, greaterThan(10));
      final row = find.ancestor(
        of: _favTile('30402'),
        matching: find.byType(InkWell),
      );
      expectTarget(row, 'linha do favorito');

      await _openTab(tester, 'Pontos');
      await _search(tester, '30402');
      expectTarget(
        _iconButton(_unfavStar('30402')),
        'estrela (ponto favorito)',
      );
    });

    for (final scale in [1.3, 2.0]) {
      for (final size in const [Size(360, 640), Size(390, 844)]) {
        testWidgets(
          'fonte a ${(scale * 100).round()}% em ${size.width.toInt()} px sem '
          'overflow',
          (tester) async {
            await _pump(
              tester,
              size: size,
              textScale: scale,
              store: FakeStore(
                initial: _data(
                  favorites: ['30402', '30100', '30500'],
                  recents: ['30601', '30602', '30603'],
                ),
              ),
            );
            expect(tester.takeException(), isNull);

            await _openTab(tester, 'Salvos');
            expect(tester.takeException(), isNull);
            await _openTab(tester, 'Pontos');
            await _search(tester, '30402');
            expect(tester.takeException(), isNull);
            await tester.tap(
              _favStar('30402').evaluate().isEmpty
                  ? _unfavStar('30402')
                  : _favStar('30402'),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.tap(find.byTooltip('Buscar outro ponto'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            // Diálogo de confirmação também cabe.
            final clear = find.widgetWithText(TextButton, 'Limpar');
            if (clear.evaluate().isNotEmpty) {
              await _tap(tester, clear);
              expect(find.text('Limpar recentes?'), findsOneWidget);
              expect(tester.takeException(), isNull);
              await tester.tap(find.text('Cancelar'));
              await tester.pumpAndSettle();
            }
          },
        );
      }
    }

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final size in const [
        Size(360, 640),
        Size(430, 932),
        Size(768, 1024),
        Size(1366, 768),
      ]) {
        testWidgets(
          'tema ${mode.name} em ${size.width.toInt()} px sem overflow',
          (tester) async {
            await _pump(
              tester,
              size: size,
              theme: mode,
              store: FakeStore(
                initial: _data(
                  favorites: ['30402', '30100'],
                  recents: ['30601', '30602'],
                ),
              ),
            );
            expect(tester.takeException(), isNull);
            await _openTab(tester, 'Salvos');
            expect(tester.takeException(), isNull);
            expect(_favTile('30402'), findsOneWidget);
            await _openTab(tester, 'Pontos');
            expect(_recentTile('30601'), findsOneWidget);
            await _search(tester, '30402');
            expect(tester.takeException(), isNull);
            await tester.tap(find.byTooltip('Ajustes'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('mapa e tracking preservados', () {
    testWidgets('o mapa é criado uma vez e o tracking sobrevive a tudo', (
      tester,
    ) async {
      final repository = _Repository();
      final store = FakeStore(
        initial: _data(favorites: ['30500'], recents: ['30100']),
      );
      await _pump(tester, repository: repository, store: store);
      expect(_CountingMap.created, 1);

      await _search(tester, '30402');
      await tester.tap(find.byTooltip('Acompanhar ônibus 20529'));
      await tester.pumpAndSettle();
      TransitMap map() => tester.widget<TransitMap>(find.byType(TransitMap));
      expect(map().vehicleNumber, '20529');

      // Favoritos e recentes não encerram o acompanhamento.
      await _openTab(tester, 'Salvos');
      expect(map().vehicleNumber, '20529');
      await _openTab(tester, 'Pontos');
      await tester.tap(_favStar('30402'));
      await tester.pumpAndSettle();
      expect(map().vehicleNumber, '20529');
      await _openTab(tester, 'Salvos');
      // Reconsultar o mesmo ponto é uma atualização: o tracking continua.
      await _tap(tester, _favTile('30402'));
      expect(find.text('Ponto 30402'), findsOneWidget);
      expect(map().vehicleNumber, '20529');

      // Limpar recentes (com diálogo) também não mexe no mapa.
      await _tap(tester, find.widgetWithText(TextButton, 'Limpar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Limpar'));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('tracking-bar-open')));
      expect(find.text('ACOMPANHANDO'), findsOneWidget);

      expect(_CountingMap.created, 1);
      expect(_CountingMap.disposed, 0);
    });
  });
}
