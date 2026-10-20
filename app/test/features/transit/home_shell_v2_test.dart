import 'dart:ui' show Tristate;

import 'package:busaogyn/src/app.dart';
import 'package:busaogyn/src/core/config/map_config.dart';
import 'package:busaogyn/src/core/network/api_exception.dart';
import 'package:busaogyn/src/core/settings/theme_mode_cubit.dart';
import 'package:busaogyn/src/core/theme/busao_tokens.dart';
import 'package:busaogyn/src/core/ui/busao_components.dart';
import 'package:busaogyn/src/features/transit/domain/entities/arrival.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/domain/models/transit_snapshot.dart';
import 'package:busaogyn/src/features/transit/domain/repositories/transit_repository.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/home_chrome.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/search_header.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/tracked_vehicle_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Conta quantas vezes o widget do mapa é criado e descartado.
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

Widget _countingMap(BuildContext context, MapSurfaceParams params) =>
    const _CountingMap();

final _now = DateTime(2026, 10, 6, 17);

TransitSnapshot<T> _snapshot<T>(T data) =>
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
  final requestedStops = <String>[];
  final failures = <String, Object>{};

  @override
  Future<TransitSnapshot<List<ArrivalGroup>>> getArrivals(String stopId) async {
    requestedStops.add(stopId);
    final failure = failures[stopId];
    if (failure != null) throw failure;
    return _snapshot(_groups);
  }

  @override
  Future<TransitSnapshot<TrackedVehicle?>> getVehiclePosition({
    required String vehicleNumber,
    required String stopId,
  }) async => _snapshot<TrackedVehicle?>(
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

Future<void> _pump(
  WidgetTester tester,
  _Repository repository, {
  Size size = const Size(390, 844),
  ThemePreferenceStore? themeStore,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    BusaoGynApp(
      locale: const Locale('pt'),
      repository: repository,
      trackingRefreshInterval: null,
      mapBuilder: _countingMap,
      clock: () => _now,
      themeStore: themeStore,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.tap(find.byTooltip('Buscar'));
  await tester.pumpAndSettle();
}

Finder _dock(String label) =>
    find.descendant(of: find.byType(NavDock), matching: find.text(label));

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(_dock(label));
  await tester.pumpAndSettle();
}

TransitMap _map(WidgetTester tester) =>
    tester.widget<TransitMap>(find.byType(TransitMap));

/// Borda do campo de busca: null é a borda padrão do vidro.
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

bool _isSelected(WidgetTester tester, String label) =>
    tester
        .getSemantics(
          find.descendant(
            of: find.byType(NavDock),
            matching: find.bySemanticsLabel(label),
          ),
        )
        .getSemanticsData()
        .flagsCollection
        .isSelected ==
    Tristate.isTrue;

const _offline = ApiException(
  code: 'NETWORK_ERROR',
  message: 'sem rede',
  retryable: true,
);

void main() {
  setUp(() {
    _CountingMap.created = 0;
    _CountingMap.disposed = 0;
  });

  group('inicialização', () {
    testWidgets('abre em Pontos, com quatro destinos', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _Repository());

      expect(find.byType(NavDock), findsOneWidget);
      // Ordem: Linhas, Pontos, Favoritos, Meu ônibus.
      final labels = ['Linhas', 'Pontos', 'Favoritos', 'Meu ônibus'];
      final xs = [for (final l in labels) tester.getCenter(_dock(l)).dx];
      expect(xs, orderedEquals([...xs]..sort()));
      // Pontos é o destino inicial: busca por código e nada de Ajustes no dock.
      expect(_isSelected(tester, 'Pontos'), isTrue);
      expect(_isSelected(tester, 'Linhas'), isFalse);
      expect(_isSelected(tester, 'Favoritos'), isFalse);
      expect(find.text('Digite o código do ponto'), findsOneWidget);
      expect(find.byType(SearchHeader), findsOneWidget);
      expect(_dock('Ajustes'), findsNothing);
      semantics.dispose();
    });
  });

  group('navegação entre os quatro destinos', () {
    testWidgets('alterna Linhas, Favoritos, Meu ônibus e volta a Pontos', (
      tester,
    ) async {
      await _pump(tester, _Repository());

      await _openTab(tester, 'Linhas');
      expect(
        find.text('As linhas estarão disponíveis em breve.'),
        findsOneWidget,
      );
      expect(find.byType(SearchHeader), findsNothing);

      await _openTab(tester, 'Favoritos');
      expect(
        find.text('Seus pontos favoritos aparecerão aqui.'),
        findsOneWidget,
      );
      expect(
        find.text('As linhas estarão disponíveis em breve.'),
        findsNothing,
      );

      await _openTab(tester, 'Meu ônibus');
      expect(find.text('Nenhum ônibus acompanhado'), findsOneWidget);

      await _openTab(tester, 'Pontos');
      expect(find.text('Digite o código do ponto'), findsOneWidget);
      expect(find.byType(SearchHeader), findsOneWidget);
    });

    testWidgets('o código digitado e o ponto carregado sobrevivem à troca', (
      tester,
    ) async {
      final repository = _Repository();
      await _pump(tester, repository);
      await tester.enterText(find.byType(TextField), '3040');
      await tester.pump();

      await _openTab(tester, 'Linhas');
      await _openTab(tester, 'Pontos');
      expect(find.widgetWithText(TextField, '3040'), findsOneWidget);

      await _search(tester, '30402');
      expect(find.text('Ponto 30402'), findsOneWidget);
      await _openTab(tester, 'Favoritos');
      await _openTab(tester, 'Pontos');
      expect(find.text('Ponto 30402'), findsOneWidget);
      expect(find.text('PRÓXIMOS ÔNIBUS'), findsOneWidget);
      // Trocar de aba não consulta de novo.
      expect(repository.requestedStops, ['30402']);
    });

    testWidgets('as chegadas só se atualizam sozinhas com Pontos à vista', (
      tester,
    ) async {
      final repository = _Repository();
      await _pump(tester, repository);
      await _search(tester, '30402');
      expect(repository.requestedStops, hasLength(1));

      await _openTab(tester, 'Linhas');
      await tester.pump(const Duration(minutes: 3));
      expect(repository.requestedStops, hasLength(1));
    });
  });

  group('Ajustes pela TopBar', () {
    testWidgets('abre pela TopBar, com alvo de 48 dp, e volta ao destino', (
      tester,
    ) async {
      await _pump(tester, _Repository());
      final size = tester.getSize(find.byTooltip('Ajustes'));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      await _openTab(tester, 'Favoritos');
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('Tema'), findsOneWidget);
      expect(find.text('Seus pontos favoritos aparecerão aqui.'), findsNothing);

      await tester.tap(find.byTooltip('Fechar ajustes'));
      await tester.pumpAndSettle();
      expect(
        find.text('Seus pontos favoritos aparecerão aqui.'),
        findsOneWidget,
      );
    });

    testWidgets('tocar em Ajustes de novo também volta à aba anterior', (
      tester,
    ) async {
      await _pump(tester, _Repository());
      await _openTab(tester, 'Linhas');
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('Tema'), findsOneWidget);

      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      expect(
        find.text('As linhas estarão disponíveis em breve.'),
        findsOneWidget,
      );
    });

    testWidgets('sair de Ajustes por outro destino do dock', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _Repository());
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      // Com Ajustes aberto, nenhum destino do dock aparece selecionado.
      expect(_isSelected(tester, 'Pontos'), isFalse);

      await _openTab(tester, 'Linhas');
      expect(
        find.text('As linhas estarão disponíveis em breve.'),
        findsOneWidget,
      );
      expect(_isSelected(tester, 'Linhas'), isTrue);
      semantics.dispose();
    });

    testWidgets('tema e fontes de dados continuam funcionando', (tester) async {
      final store = MemoryThemePreferenceStore();
      await _pump(tester, _Repository(), themeStore: store);
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();

      expect(
        find.text('OpenFreeMap · © OpenMapTiles · dados © OpenStreetMap'),
        findsOneWidget,
      );
      await tester.tap(find.text('Noturno'));
      await tester.pumpAndSettle();
      expect(store.read(), ThemeMode.dark);
      expect(_map(tester).styleString, MapConfig.styles.dark);
    });
  });

  group('mapa único e persistente', () {
    testWidgets('uma única criação ao percorrer tudo, e nenhum dispose', (
      tester,
    ) async {
      await _pump(tester, _Repository());
      expect(_CountingMap.created, 1);

      await _search(tester, '30402');
      for (final label in ['Linhas', 'Favoritos', 'Meu ônibus', 'Pontos']) {
        await _openTab(tester, label);
      }
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      // Troca de tema com Ajustes aberto.
      await tester.tap(find.text('Noturno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Fechar ajustes'));
      await tester.pumpAndSettle();
      // Redimensionar (celular → largo → celular).
      tester.view.physicalSize = const Size(1366, 768);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();

      expect(_CountingMap.created, 1, reason: 'o mapa não foi recriado');
      expect(_CountingMap.disposed, 0, reason: 'o mapa não foi descartado');
      expect(find.byKey(const Key('fake-map')), findsOneWidget);
    });

    testWidgets('o mapa fica no índice 0 do Stack em celular e tela larga', (
      tester,
    ) async {
      for (final size in const [Size(390, 844), Size(1366, 768)]) {
        await _pump(tester, _Repository(), size: size);
        final stack = tester.widget<Stack>(
          find
              .ancestor(
                of: find.byKey(const Key('fake-map')),
                matching: find.byType(Stack),
              )
              .last,
        );
        final first = stack.children.first;
        expect(first, isA<Positioned>());
        // O primeiro filho do Stack é o que contém o mapa.
        final firstElement = tester.element(find.byWidget(first));
        expect(
          find.descendant(
            of: find.byWidget(firstElement.widget),
            matching: find.byKey(const Key('fake-map')),
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  group('tracking durante a navegação', () {
    testWidgets('trocar de aba não encerra o acompanhamento', (tester) async {
      final repository = _Repository();
      await _pump(tester, repository);
      await _search(tester, '30402');
      await tester.tap(find.byTooltip('Acompanhar ônibus 20529'));
      await tester.pumpAndSettle();
      expect(find.text('ACOMPANHANDO'), findsOneWidget);
      expect(_map(tester).vehicleNumber, '20529');

      for (final label in ['Linhas', 'Favoritos', 'Pontos']) {
        await _openTab(tester, label);
        expect(_map(tester).vehicleNumber, '20529', reason: 'em $label');
      }
      // Ajustes pela TopBar também não encerra.
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Fechar ajustes'));
      await tester.pumpAndSettle();
      expect(_map(tester).vehicleNumber, '20529');

      await _openTab(tester, 'Meu ônibus');
      expect(find.text('ACOMPANHANDO'), findsOneWidget);
      expect(find.text('Ônibus 20529'), findsOneWidget);
      // O cartão diz o que o rastro mostra e que não há trajeto à frente.
      expect(
        find.textContaining('por onde o ônibus já passou'),
        findsOneWidget,
      );
      expect(find.textContaining('percurso futuro'), findsOneWidget);
    });

    testWidgets('parar o acompanhamento volta a Pontos', (tester) async {
      await _pump(tester, _Repository());
      await _search(tester, '30402');
      await tester.tap(find.byTooltip('Acompanhar ônibus 20529'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Parar de acompanhar'));
      await tester.pumpAndSettle();
      expect(_map(tester).vehicleNumber, isNull);
      expect(find.text('Ponto 30402'), findsOneWidget);
      expect(find.byTooltip('Acompanhar ônibus 20529'), findsOneWidget);
    });
  });

  group('estados vazios e ações', () {
    testWidgets('Linhas e Favoritos levam à busca de pontos', (tester) async {
      await _pump(tester, _Repository());

      for (final tab in ['Linhas', 'Favoritos']) {
        await _openTab(tester, tab);
        // Nenhum botão sem comportamento.
        for (final button in tester.widgetList<FilledButton>(
          find.byType(FilledButton),
        )) {
          expect(button.onPressed, isNotNull);
        }
        await tester.tap(find.text('Buscar um ponto'));
        await tester.pumpAndSettle();
        expect(find.byType(SearchHeader), findsOneWidget, reason: tab);
        expect(find.text('Digite o código do ponto'), findsOneWidget);
        final field = tester.widget<EditableText>(find.byType(EditableText));
        expect(field.focusNode.hasFocus, isTrue, reason: 'foco na busca: $tab');
      }
    });

    testWidgets('com um ponto carregado, a ação volta às chegadas dele', (
      tester,
    ) async {
      await _pump(tester, _Repository());
      await _search(tester, '30402');
      await _openTab(tester, 'Favoritos');
      await tester.tap(find.text('Buscar um ponto'));
      await tester.pumpAndSettle();
      expect(find.text('Ponto 30402'), findsOneWidget);
      expect(find.text('PRÓXIMOS ÔNIBUS'), findsOneWidget);
    });

    testWidgets('Meu ônibus sem tracking tem estado vazio com ação', (
      tester,
    ) async {
      await _pump(tester, _Repository());
      await _openTab(tester, 'Meu ônibus');
      expect(find.text('Nenhum ônibus acompanhado'), findsOneWidget);
      await tester.tap(find.text('Buscar um ponto'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchHeader), findsOneWidget);
    });
  });

  group('fonte grande e layout responsivo', () {
    for (final scale in [1.3, 2.0]) {
      for (final size in const [Size(360, 640), Size(390, 844)]) {
        testWidgets(
          'fonte a ${(scale * 100).round()}% em ${size.width.toInt()} px: '
          'sem overflow, rótulos inteiros e alvos de 48 dp',
          (tester) async {
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await _pump(tester, _Repository(), size: size);
            expect(tester.takeException(), isNull);

            for (final label in [
              'Linhas',
              'Pontos',
              'Favoritos',
              'Meu ônibus',
            ]) {
              // Uma palavra por linha quando necessário: procura cada palavra.
              for (final word in label.split(' ')) {
                expect(
                  find.descendant(
                    of: find.byType(NavDock),
                    matching: find.text(word),
                  ),
                  findsWidgets,
                  reason: '$word a ${scale * 100}%',
                );
              }
            }
            final items = find.descendant(
              of: find.byType(NavDock),
              matching: find.byType(InkWell),
            );
            expect(items, findsNWidgets(4));
            for (final item in items.evaluate()) {
              final box = item.renderObject! as RenderBox;
              expect(box.size.height, greaterThanOrEqualTo(48));
              expect(box.size.width, greaterThanOrEqualTo(48));
            }
            // O dock mede o que a geometria da página calcula.
            final media = MediaQueryData.fromView(
              tester.view,
            ).copyWith(textScaler: TextScaler.linear(scale));
            final width = size.width - Chrome.gutter * 2;
            final expected = Chrome.dockLayout(
              width,
              media.textScaler,
              items: 4,
            ).height;
            expect(tester.getSize(find.byType(NavDock)).height, expected);
            expect(
              tester.getSize(find.byTooltip('Ajustes')).shortestSide,
              greaterThanOrEqualTo(48),
            );

            // Percorre tudo sem overflow.
            for (final tab in ['Linhas', 'Favoritos', 'Meu ônibus', 'Pontos']) {
              await tester.tap(
                find.descendant(
                  of: find.byType(NavDock),
                  matching: find.text(tab.split(' ').first),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: tab);
            }
            await tester.tap(find.byTooltip('Ajustes'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
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
          'layout sem overflow em ${size.width.toInt()} px (${mode.name})',
          (tester) async {
            await _pump(
              tester,
              _Repository(),
              size: size,
              themeStore: MemoryThemePreferenceStore(mode),
            );
            expect(tester.takeException(), isNull);
            await _search(tester, '30402');
            await tester.tap(find.byTooltip('Acompanhar ônibus 20529'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            for (final tab in ['Linhas', 'Favoritos', 'Meu ônibus', 'Pontos']) {
              await _openTab(
                tester,
                tab.split(' ').first == 'Meu' ? 'Meu ônibus' : tab,
              );
              expect(tester.takeException(), isNull, reason: tab);
            }
            await tester.tap(find.byTooltip('Ajustes'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.byKey(const Key('fake-map')), findsOneWidget);
            if (size.width >= Breakpoints.panel) {
              // Tela larga: dock dentro da coluna central.
              expect(
                tester.getSize(find.byType(NavDock)).width,
                lessThanOrEqualTo(Chrome.column),
              );
            }
          },
        );
      }
    }
  });

  group('regressão dos estados offline (PR #33) no HomeShell', () {
    testWidgets('sem internet em Pontos: aviso, retry manual e código', (
      tester,
    ) async {
      final repository = _Repository()..failures['30402'] = _offline;
      await _pump(tester, repository);
      await _search(tester, '30402');

      expect(find.textContaining('Sem conexão'), findsWidgets);
      expect(_fieldBorder(tester), isNull);
      expect(find.text('Chegadas precisam de internet'), findsOneWidget);
      expect(find.text('Digite o código do ponto'), findsNothing);
      expect(find.widgetWithText(TextField, '30402'), findsOneWidget);
      expect(repository.requestedStops, ['30402']);

      // Sem laço automático, mesmo trocando de aba e esperando.
      await _openTab(tester, 'Linhas');
      await tester.pump(const Duration(minutes: 5));
      await _openTab(tester, 'Pontos');
      expect(repository.requestedStops, ['30402']);
      expect(find.widgetWithText(TextField, '30402'), findsOneWidget);
      expect(find.text('Chegadas precisam de internet'), findsOneWidget);

      // Uma consulta por toque; ao voltar a conexão o ponto carrega.
      repository.failures.remove('30402');
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();
      expect(repository.requestedStops, ['30402', '30402']);
      expect(find.text('Ponto 30402'), findsOneWidget);
    });

    testWidgets('atualização que falha mantém a consulta e diz a hora', (
      tester,
    ) async {
      final repository = _Repository();
      await _pump(tester, repository);
      await _search(tester, '30402');

      repository.failures['30402'] = _offline;
      await tester.tap(find.byTooltip('Atualizar chegadas'));
      await tester.pumpAndSettle();
      expect(find.text('PRÓXIMOS ÔNIBUS'), findsOneWidget);
      expect(
        find.textContaining('Mostrando a consulta das 17:00'),
        findsOneWidget,
      );
      expect(find.textContaining('pode já não valer'), findsOneWidget);
    });

    testWidgets('código inválido e ponto inexistente mantêm a borda', (
      tester,
    ) async {
      final repository = _Repository()
        ..failures['99999'] = const ApiException(
          code: 'SOURCE_INVALID_RESPONSE',
          message: 'x',
          retryable: true,
          statusCode: 502,
        );
      await _pump(tester, repository);
      await _search(tester, 'abc');
      expect(_fieldBorder(tester), isNotNull);
      expect(find.text('Tentar de novo'), findsNothing);
      await _search(tester, '99999');
      expect(find.textContaining('Ponto não encontrado'), findsWidgets);
      expect(_fieldBorder(tester), isNotNull);
    });
  });
}
