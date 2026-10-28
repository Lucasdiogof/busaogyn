import 'dart:convert';
import 'dart:io';

import 'package:busaogyn/src/app.dart';
import 'package:busaogyn/src/core/l10n/l10n.dart';
import 'package:busaogyn/src/features/transit/domain/entities/arrival.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/domain/models/transit_snapshot.dart';
import 'package:busaogyn/src/features/transit/domain/repositories/transit_repository.dart';
import 'package:busaogyn/src/features/transit/presentation/formatters/error_messages.dart';
import 'package:busaogyn/src/features/transit/presentation/formatters/transit_labels.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/home_chrome.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/tracked_vehicle_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _keys(Map<String, dynamic> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

/// Nomes de placeholder de uma mensagem ICU: `{name}` e `{name, plural, ...}`.
Set<String> _placeholders(String message) => {
  for (final match in RegExp(r'\{(\w+)(?:,|\})').allMatches(message))
    match.group(1)!,
}..removeAll({'plural', 'other'});

final _now = DateTime(2026, 10, 6, 17);

TransitSnapshot<T> _snapshot<T>(T data) =>
    TransitSnapshot(data: data, fetchedAt: _now, stale: false, ageSeconds: 0);

class _Repository implements TransitRepository {
  @override
  Future<TransitSnapshot<List<ArrivalGroup>>> getArrivals(
    String stopId,
  ) async => _snapshot(const [
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
  ]);

  @override
  Future<TransitSnapshot<TrackedVehicle?>> getVehiclePosition({
    required String vehicleNumber,
    required String stopId,
  }) async => _snapshot<TrackedVehicle?>(null);
}

Widget _map(BuildContext context, MapSurfaceParams params) =>
    const ColoredBox(color: Colors.grey, child: SizedBox.expand());

void main() {
  tearDown(() => useLocale(const Locale('pt')));

  group('ARB', () {
    test('en e es têm exatamente as chaves do modelo em português', () {
      final pt = _keys(_arb('pt'));
      expect(_keys(_arb('en')), pt);
      expect(_keys(_arb('es')), pt);
    });

    test('cada tradução usa os mesmos placeholders do português', () {
      final pt = _arb('pt');
      for (final locale in ['en', 'es']) {
        final other = _arb(locale);
        for (final key in _keys(pt)) {
          if (key.startsWith('@@')) continue;
          expect(
            _placeholders(other[key] as String),
            _placeholders(pt[key] as String),
            reason: '$locale / $key',
          );
        }
      }
    });
  });

  group('idioma', () {
    test('só pt, en e es são atendidos; o resto cai em português', () {
      expect(resolveAppLocale(const Locale('en', 'US')), const Locale('en'));
      expect(resolveAppLocale(const Locale('es', 'MX')), const Locale('es'));
      expect(resolveAppLocale(const Locale('pt', 'BR')), const Locale('pt'));
      expect(resolveAppLocale(const Locale('fr')), const Locale('pt'));
      expect(resolveAppLocale(null), const Locale('pt'));
    });

    test('formatadores seguem o idioma em uso', () {
      useLocale(const Locale('en'));
      expect(qualityLabel(ArrivalQuality.realtime), 'Real time');
      expect(minutesSemantics(1), '1 minute');
      expect(minutesSemantics(3), '3 minutes');
      expect(headingToLabel('T. BIBLIA'), startsWith('Heading to T.'));
      expect(
        friendlyErrorMessage(const FormatException('x'), ErrorSubject.arrivals),
        contains('unexpected format'),
      );

      useLocale(const Locale('es'));
      expect(qualityLabel(ArrivalQuality.realtime), 'Tiempo real');
      expect(minutesSemantics(1), '1 minuto');
      expect(minutesSemantics(3), '3 minutos');
      expect(headingToLabel('T. BIBLIA'), startsWith('Rumbo a T.'));

      useLocale(const Locale('pt'));
      expect(minutesSemantics(3), '3 minutos');
      expect(headingToLabel(null), 'Destino não informado');
    });
  });

  group('app', () {
    Future<void> pump(WidgetTester tester, Locale locale) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        BusaoGynApp(
          locale: locale,
          repository: _Repository(),
          trackingRefreshInterval: null,
          mapBuilder: _map,
          clock: () => _now,
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder dock(String label) =>
        find.descendant(of: find.byType(NavDock), matching: find.text(label));

    for (final (locale, labels, intro) in [
      (const Locale('en'), ['Stops', 'Lines', 'Saved'], 'Enter the stop code'),
      (
        const Locale('es'),
        ['Paradas', 'Líneas', 'Guardados'],
        'Escribe el código de la parada',
      ),
    ]) {
      testWidgets('${locale.languageCode}: dock e tela inicial traduzidos', (
        tester,
      ) async {
        await pump(tester, locale);
        for (final label in labels) {
          expect(dock(label), findsOneWidget);
        }
        expect(find.text(intro), findsOneWidget);
        expect(find.text('Linhas'), findsNothing);
      });

      testWidgets('${locale.languageCode}: chegadas do ponto', (tester) async {
        await pump(tester, locale);
        await tester.enterText(find.byType(TextField), '30402');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(find.text('020'), findsOneWidget);
        expect(
          find.text(locale.languageCode == 'en' ? 'REAL TIME' : 'TIEMPO REAL'),
          findsWidgets,
        );
        expect(find.textContaining('Ponto'), findsNothing);
      });
    }
  });

  // Em pt a regra CLDR põe o 0 na categoria "one": sem `=0`, o gen-l10n
  // mostrava "1 linha" para zero.
  test('plurais com zero não viram singular', () {
    for (final (locale, zero) in [
      ('pt', '0 linhas'),
      ('en', '0 lines'),
      ('es', '0 líneas'),
    ]) {
      final t = lookupAppLocalizations(Locale(locale));
      expect(t.linesCount(0), zero);
      expect(t.linesCount(1), isNot(zero));
    }
    final pt = lookupAppLocalizations(const Locale('pt'));
    expect(pt.minutesLong(0), '0 minutos');
    expect(pt.catalogResultsCount(0), 'Nenhum ponto');
    expect(pt.catalogResultsCount(1), '1 ponto');
    expect(pt.catalogVariantCount(2), '2 variantes');
  });

  test('todo plural do modelo tem a forma =0', () {
    final pt = _arb('pt');
    for (final entry in pt.entries) {
      final value = entry.value;
      if (value is String && value.contains(', plural,')) {
        expect(value, contains('=0{'), reason: entry.key);
      }
    }
  });
}
