// Percorre o app real no tema escuro (API e mapa de produção) para gerar as
// capturas da loja. Para cada tela o teste grava o nome em
// `<systemTemp>/busaogyn_shot`; o script do host lê o arquivo com `run-as`,
// tira a captura do emulador (com barra de status) e apaga o arquivo.
import 'dart:io';

import 'package:busaogyn/src/app.dart';
import 'package:busaogyn/src/core/config/api_config.dart';
import 'package:busaogyn/src/core/network/api_client.dart';
import 'package:busaogyn/src/core/settings/theme_mode_cubit.dart';
import 'package:busaogyn/src/features/saved_stops/data/memory_saved_stops_store.dart';
import 'package:busaogyn/src/features/transit/data/repositories/http_transit_repository.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/home_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _stop = String.fromEnvironment('SHOT_STOP', defaultValue: '30402');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('capturas da loja', (tester) async {
    await tester.pumpWidget(
      BusaoGynApp(
        repository: HttpTransitRepository(
          ApiClient(baseUrl: ApiConfig.baseUrl),
        ),
        locale: const Locale('pt'),
        themeStore: MemoryThemePreferenceStore(ThemeMode.dark),
        savedStopsStore: MemorySavedStopsStore(),
      ),
    );
    await _idle(tester, const Duration(seconds: 12));
    await _shot(tester, '01_inicio');

    await _tap(tester, find.text('Exemplo: $_stop'));
    final loaded = await _waitFor(tester, find.text('PRÓXIMOS ÔNIBUS'));
    _log('chegadas carregadas: $loaded');
    await _idle(tester, const Duration(seconds: 8));
    await _shot(tester, '02_chegadas');

    await _tap(tester, find.byTooltip('Favoritar o ponto $_stop'));
    await _tap(tester, _tooltipStartingWith('Favoritar a linha').first);

    final track = _tooltipStartingWith('Acompanhar ônibus ');
    if (track.evaluate().isNotEmpty) {
      await _tap(tester, track.first);
      final live = await _waitFor(
        tester,
        find.text('ACOMPANHANDO'),
        timeout: const Duration(seconds: 45),
      );
      _log('acompanhando: $live');
      await _idle(tester, const Duration(seconds: 10));
      await _shot(tester, '03_meu_onibus');
    } else {
      _log('nenhum ônibus com GPS no ponto $_stop agora');
    }

    await _tap(tester, _dock('Favoritos'));
    await _idle(tester, const Duration(seconds: 8));
    await _shot(tester, '04_favoritos');

    await _tap(tester, _dock('Linhas'));
    await _idle(tester, const Duration(seconds: 3));
    await _shot(tester, '05_linhas');

    await _tap(tester, find.byTooltip('Ajustes'));
    await _idle(tester, const Duration(seconds: 3));
    await _shot(tester, '06_ajustes');
  }, timeout: const Timeout(Duration(minutes: 10)));
}

Finder _dock(String word) => find.descendant(
  of: find.byType(NavDock),
  matching: find.textContaining(word),
);

Finder _tooltipStartingWith(String prefix) => find.byWidgetPredicate(
  (widget) => widget is Tooltip && (widget.message ?? '').startsWith(prefix),
);

void _log(String message) => debugPrint('BUSAOGYN_LOG $message');

/// Deixa o app rodar em tempo real (mapa, rede e animações).
Future<void> _idle(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (finder.evaluate().isNotEmpty) return true;
    await _idle(tester, const Duration(milliseconds: 300));
  }
  return finder.evaluate().isNotEmpty;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (!await _waitFor(tester, finder, timeout: const Duration(seconds: 10))) {
    _log('não encontrado: $finder');
    return;
  }
  await tester.ensureVisible(finder.first);
  await _idle(tester, const Duration(milliseconds: 600));
  await tester.tap(finder.first, warnIfMissed: false);
  await _idle(tester, const Duration(milliseconds: 800));
}

/// O painel guarda a rolagem entre abas; cada captura começa do topo.
void _scrollPanelToTop(WidgetTester tester) {
  final panel = find.byWidgetPredicate(
    (widget) =>
        widget.key == const ValueKey('sheet') ||
        widget.key == const ValueKey('column-panel'),
  );
  final scrollables = find.descendant(
    of: panel,
    matching: find.byType(Scrollable),
  );
  for (final element in scrollables.evaluate()) {
    final state = (element as StatefulElement).state as ScrollableState;
    final scroll = state.position;
    if (scroll.pixels != scroll.minScrollExtent) {
      scroll.jumpTo(scroll.minScrollExtent);
    }
  }
}

/// Avisa o host e espera ele confirmar a captura (apagando o arquivo).
Future<void> _shot(WidgetTester tester, String name) async {
  _scrollPanelToTop(tester);
  await _idle(tester, const Duration(seconds: 1));
  final signal = File('${Directory.systemTemp.path}/busaogyn_shot');
  await signal.writeAsString(name, flush: true);
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (signal.existsSync() && DateTime.now().isBefore(end)) {
    await _idle(tester, const Duration(milliseconds: 200));
  }
  if (signal.existsSync()) {
    _log('captura não confirmada: $name (${signal.path})');
    signal.deleteSync();
  } else {
    _log('capturada: $name');
  }
}
