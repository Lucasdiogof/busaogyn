import 'package:busaogyn/src/app.dart';
import 'package:busaogyn/src/core/network/api_exception.dart';
import 'package:busaogyn/src/features/catalog/domain/transit_catalog.dart';
import 'package:busaogyn/src/features/saved_stops/domain/saved_stop.dart';
import 'package:busaogyn/src/features/transit/domain/entities/arrival.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/domain/models/transit_snapshot.dart';
import 'package:busaogyn/src/features/transit/domain/repositories/transit_repository.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/home_chrome.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/search_header.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/tracked_vehicle_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../saved_stops/fakes.dart';
import 'catalog_fixture.dart';

final _now = DateTime(2026, 10, 27, 17);

const _groups = [
  ArrivalGroup(
    routeId: '042',
    destination: 'T. FICTICIO SUL',
    next: Arrival(
      vehicleId: 'rmtc:90001',
      vehicleNumber: '90001',
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
  final requestedStops = <String>[];
  Object? failure;

  @override
  Future<TransitSnapshot<List<ArrivalGroup>>> getArrivals(String stopId) async {
    requestedStops.add(stopId);
    if (failure != null) throw failure!;
    return TransitSnapshot(
      data: _groups,
      fetchedAt: _now,
      stale: false,
      ageSeconds: 0,
    );
  }

  @override
  Future<TransitSnapshot<TrackedVehicle?>> getVehiclePosition({
    required String vehicleNumber,
    required String stopId,
  }) async => TransitSnapshot<TrackedVehicle?>(
    data: null,
    fetchedAt: _now,
    stale: false,
    ageSeconds: 0,
  );
}

const _offline = ApiException(
  code: 'NETWORK_ERROR',
  message: 'sem rede',
  retryable: true,
);

Widget _map(BuildContext context, MapSurfaceParams params) =>
    const SizedBox.expand();

Future<FakeStore> _pump(
  WidgetTester tester,
  _Repository repository, {
  TransitCatalog? catalog,
  SavedStopsData? saved,
  Size size = const Size(390, 844),
  double textScale = 1,
  Locale locale = const Locale('pt'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final store = FakeStore(initial: saved);
  await tester.pumpWidget(
    BusaoGynApp(
      locale: locale,
      repository: repository,
      trackingRefreshInterval: null,
      arrivalsRefreshInterval: null,
      secondaryRefreshInterval: null,
      mapBuilder: _map,
      clock: () => _now,
      savedStopsStore: store,
      catalog: catalog,
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Finder _dock(String label) =>
    find.descendant(of: find.byType(NavDock), matching: find.text(label));

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(SearchHeader),
      matching: find.byType(TextField),
    ),
    text,
  );
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('catálogo desligado (produção)', () {
    testWidgets('busca só aceita dígitos e Linhas mostra as linhas vistas', (
      tester,
    ) async {
      final repo = _Repository();
      await _pump(tester, repo);
      await _type(tester, 'rua 12a');
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(SearchHeader),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '12');
      expect(find.text('Digite o código do ponto'), findsOneWidget);
      await tester.tap(_dock('Linhas'));
      await tester.pumpAndSettle();
      expect(
        find.text('As linhas estarão disponíveis em breve.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('catalog-lines-search')), findsNothing);
      expect(find.textContaining('cadastro oficial'), findsNothing);
      // Planejador (dados CMTC) não existe em produção.
      await tester.tap(_dock('Pontos'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('planner-open')), findsNothing);
      expect(find.text('Planejar viagem'), findsNothing);
    });
  });

  group('catálogo ligado (desenvolvimento)', () {
    testWidgets('busca por endereço sem acento, local e sem chamar a API', (
      tester,
    ) async {
      final repo = _Repository();
      await _pump(tester, repo, catalog: fixtureCatalog());
      expect(find.text('Código, rua, bairro ou cidade'), findsOneWidget);
      expect(find.text('Busque um ponto'), findsOneWidget);
      expect(find.text('Digite o código do ponto'), findsNothing);
      await _type(tester, 'av exemplo');
      expect(find.byKey(const ValueKey('catalog-stop-1201')), findsOneWidget);
      expect(find.byKey(const ValueKey('catalog-stop-1202')), findsOneWidget);
      expect(find.text('2 pontos'), findsOneWidget);
      // Enviar texto não consulta a API.
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(repo.requestedStops, isEmpty);
      expect(find.byKey(const ValueKey('catalog-stop-1201')), findsOneWidget);
    });

    testWidgets('por bairro e município; nada encontrado é explicado', (
      tester,
    ) async {
      await _pump(tester, _Repository(), catalog: fixtureCatalog());
      await _type(tester, 'agua clara');
      expect(find.byKey(const ValueKey('catalog-stop-00294')), findsOneWidget);
      await _type(tester, 'TRINDADE');
      expect(find.byKey(const ValueKey('catalog-stop-1202')), findsOneWidget);
      await _type(tester, 'rua que nao existe');
      expect(find.text('Nenhum ponto encontrado'), findsOneWidget);
    });

    testWidgets(
      'detalhe do ponto offline, depois chegadas com dados oficiais acima',
      (tester) async {
        final repo = _Repository()..failure = _offline;
        await _pump(tester, repo, catalog: fixtureCatalog());
        await _type(tester, 'jardim simulado');
        await _tapKey(tester, 'catalog-stop-1201');

        // Detalhes vêm do catálogo local: nenhuma consulta feita.
        expect(repo.requestedStops, isEmpty);
        expect(
          find.byKey(const ValueKey('catalog-stop-facts-1201')),
          findsOneWidget,
        );
        expect(find.text('Ponto 1201'), findsOneWidget);
        expect(find.textContaining('Avenida Exemplo'), findsWidgets);
        expect(find.textContaining('Jardim Simulado'), findsWidgets);
        expect(find.text('Linhas que atendem este ponto'), findsOneWidget);
        expect(find.textContaining('não ônibus a caminho'), findsOneWidget);
        expect(find.textContaining('disponível offline'), findsOneWidget);
        expect(find.textContaining('não publicados'), findsWidgets);

        // Sem internet: a consulta falha e nenhuma previsão aparece.
        await _tapKey(tester, 'catalog-see-arrivals');
        expect(repo.requestedStops, ['1201']);
        expect(find.text('PRÓXIMOS ÔNIBUS'), findsNothing);

        // Com internet: chegadas em tempo real abaixo dos dados oficiais.
        repo.failure = null;
        await _type(tester, 'jardim simulado');
        await _tapKey(tester, 'catalog-stop-1201');
        await _tapKey(tester, 'catalog-see-arrivals');
        expect(find.text('PRÓXIMOS ÔNIBUS'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('catalog-stop-facts-1201')),
          findsOneWidget,
        );
        expect(find.text('Linhas que atendem este ponto'), findsOneWidget);
      },
    );

    testWidgets('código digitado: lista o ponto e o envio consulta chegadas', (
      tester,
    ) async {
      final repo = _Repository();
      await _pump(tester, repo, catalog: fixtureCatalog());
      await _type(tester, '00294');
      expect(find.byKey(const ValueKey('catalog-stop-00294')), findsOneWidget);
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      expect(repo.requestedStops, ['00294']);
      expect(
        find.byKey(const ValueKey('catalog-stop-facts-00294')),
        findsOneWidget,
      );
    });

    testWidgets('código fora do cadastro ainda consulta e avisa', (
      tester,
    ) async {
      final repo = _Repository();
      await _pump(tester, repo, catalog: fixtureCatalog());
      await _type(tester, '30402');
      expect(find.text('Nenhum ponto encontrado'), findsOneWidget);
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      expect(repo.requestedStops, ['30402']);
      expect(
        find.byKey(const ValueKey('catalog-stop-missing')),
        findsOneWidget,
      );
    });

    testWidgets('favoritar pelo detalhe guarda só o código', (tester) async {
      final store = await _pump(
        tester,
        _Repository(),
        catalog: fixtureCatalog(),
      );
      await _type(tester, 'ficticia');
      await _tapKey(tester, 'catalog-stop-00294');
      await tester.ensureVisible(find.byTooltip('Favoritar o ponto 00294'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Favoritar o ponto 00294'));
      await tester.pumpAndSettle();

      expect(store.data.favorites.single.code, '00294');
      expect(store.data.favorites.single.name, isNull);
    });

    testWidgets(
      'favoritos e recentes ganham endereço sem mudar o armazenamento',
      (tester) async {
        final saved = SavedStopsData(
          favorites: [stop('00294')],
          recents: [stop('1202'), stop('77777')],
          lines: [
            SavedLine(stopCode: '1201', routeId: '042', at: DateTime.utc(2026)),
          ],
        );
        final store = await _pump(
          tester,
          _Repository(),
          catalog: fixtureCatalog(),
          saved: saved,
        );
        // Recentes na aba Pontos.
        expect(find.textContaining('Avenida Exemplo'), findsOneWidget);
        expect(find.textContaining('Vila Teste, Trindade'), findsOneWidget);
        // Código fora do catálogo continua só com o código.
        expect(find.text('77777'), findsNothing);
        expect(find.textContaining('77777'), findsOneWidget);
        await tester.tap(_dock('Favoritos'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Rua Fictícia'), findsOneWidget);
        expect(
          find.textContaining('Avenida Exemplo'),
          findsOneWidget,
        ); // linha favorita no ponto 1201
        expect(store.saves, isEmpty);
      },
    );

    testWidgets('aba Linhas: busca, detalhe com variantes e pontos, e volta', (
      tester,
    ) async {
      final saved = SavedStopsData(
        lines: [
          SavedLine(stopCode: '1201', routeId: '042', at: DateTime.utc(2026)),
        ],
      );
      final repo = _Repository();
      await _pump(tester, repo, catalog: fixtureCatalog(), saved: saved);
      await tester.tap(_dock('Linhas'));
      await tester.pumpAndSettle();
      expect(find.text('3 linhas no cadastro oficial'), findsOneWidget);
      expect(
        find.text('042 · 1201'),
        findsOneWidget,
      ); // linha favorita preservada

      await tester.enterText(
        find.byKey(const ValueKey('catalog-lines-search')),
        'hospital',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('catalog-line-001')), findsOneWidget);
      expect(find.byKey(const ValueKey('catalog-line-042')), findsNothing);

      await _tapKey(tester, 'catalog-line-001');
      expect(
        find.byKey(const ValueKey('catalog-line-detail-001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('catalog-variant-001-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('catalog-variant-001-2')),
        findsOneWidget,
      );
      expect(find.textContaining('Operação'), findsWidgets);
      expect(
        find.textContaining('sem ordem de percurso nem sentido'),
        findsOneWidget,
      );
      // Ida/Volta vêm do nome oficial do trajeto (KMZ); a ordem dos pontos
      // continua sem sentido nem sequência.
      expect(
        find.byKey(
          const ValueKey(
            'catalog-shape-001-1i - T. FICTICIO NORTE / CENTRO IMAGINARIO - IDA',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('sem ordem de percurso nem sentido'),
        findsOneWidget,
      );

      // Ponto da linha abre o detalhe na aba Pontos, sem consultar a API.
      await _tapKey(tester, 'catalog-stop-1202');
      expect(
        find.byKey(const ValueKey('catalog-stop-facts-1202')),
        findsOneWidget,
      );
      expect(repo.requestedStops, isEmpty);

      // Voltando a Linhas, o detalhe continua aberto; "Voltar" leva à lista.
      await tester.tap(_dock('Linhas'));
      await tester.pumpAndSettle();
      await _tapKey(tester, 'catalog-line-back');
      expect(find.byKey(const ValueKey('catalog-line-001')), findsOneWidget);
    });

    testWidgets('Ajustes mostra versão, referência e licença pendente', (
      tester,
    ) async {
      await _pump(tester, _Repository(), catalog: fixtureCatalog());
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('Catálogo oficial (desenvolvimento)'), findsOneWidget);
      expect(find.textContaining('redistribuição: pendente'), findsOneWidget);
      expect(find.textContaining('Versão sintetico-1'), findsOneWidget);
    });

    for (final (size, scale) in [
      (const Size(320, 640), 1.0),
      (const Size(390, 844), 2.0),
      (const Size(820, 1180), 1.3),
      (const Size(1366, 900), 1.0),
    ]) {
      testWidgets(
        'sem overflow em ${size.width.toInt()} px e fonte ${scale * 100}%',
        (tester) async {
          await _pump(
            tester,
            _Repository(),
            catalog: fixtureCatalog(),
            size: size,
            textScale: scale,
          );
          await _type(tester, 'exemplo');
          await _tapKey(tester, 'catalog-stop-1201');
          await tester.tap(_dock('Linhas'));
          await tester.pumpAndSettle();
          await _tapKey(tester, 'catalog-line-042');
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final (locale, title) in [
      (const Locale('en'), 'Lines serving this stop'),
      (const Locale('es'), 'Líneas que atienden esta parada'),
    ]) {
      testWidgets('textos em ${locale.languageCode}', (tester) async {
        await _pump(
          tester,
          _Repository(),
          catalog: fixtureCatalog(),
          locale: locale,
        );
        await _type(tester, 'exemplo');
        await _tapKey(tester, 'catalog-stop-1201');
        expect(find.text(title), findsOneWidget);
      });
    }
  });
}
