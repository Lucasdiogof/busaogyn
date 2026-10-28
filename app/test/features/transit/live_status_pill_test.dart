import 'package:busaogyn/src/core/theme/app_theme.dart';
import 'package:busaogyn/src/features/transit/presentation/formatters/transit_labels.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/home_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TopBar(
            status: const LiveStatus(
              'Desatualizado',
              'há 1 min',
              LiveTone.stale,
            ),
            onSettings: () {},
          ),
        ),
      ),
    ),
  );
}

bool _cut(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines;

void main() {
  // A fonte de teste (cada letra um quadrado) é bem mais larga que a Geist:
  // as larguras abaixo reproduzem a falta de espaço de um celular de 390 px.
  testWidgets('sem espaço: o estado aparece inteiro; a idade sai', (
    tester,
  ) async {
    await _pump(tester, 520);
    expect(_cut(tester, 'Desatualizado'), isFalse);
    expect(find.text('há 1 min'), findsNothing);
    // A idade continua para o leitor de tela.
    expect(find.bySemanticsLabel('Desatualizado, há 1 min'), findsOneWidget);
  });

  testWidgets('com espaço: estado e idade juntos', (tester) async {
    await _pump(tester, 700);
    expect(_cut(tester, 'Desatualizado'), isFalse);
    expect(find.text('há 1 min'), findsOneWidget);
  });
}
