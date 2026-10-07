import 'package:busaogyn/src/features/transit/presentation/widgets/arrival_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<double> _render(WidgetTester tester, double width) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: width,
          child: const DestinationText(
            'T MARANATA',
            style: TextStyle(fontSize: 14),
          ),
        ),
      ),
    ),
  );
  return tester
      .renderObject<RenderDestinationText>(find.byType(DestinationText))
      .fontSize;
}

void main() {
  testWidgets('com espaço mantém o tamanho da fonte', (tester) async {
    expect(await _render(tester, 300), 14);
  });

  testWidgets('palavra que não cabe reduz a fonte em vez de quebrar', (
    tester,
  ) async {
    // No flutter_test cada caractere da fonte de teste mede o tamanho da
    // fonte: "MARANATA" (8) a 14 px = 112 px, maior que 100 px.
    final size = await _render(tester, 100);
    expect(size, lessThan(14));
    expect(size, greaterThanOrEqualTo(11));
    expect(8 * size, lessThanOrEqualTo(100));
  });

  testWidgets('nunca abaixo do mínimo', (tester) async {
    expect(await _render(tester, 40), 11);
  });

  testWidgets('espaço não separável conta como parte da palavra', (
    tester,
  ) async {
    // "T MARANATA" (como sai de destinationLabel) é uma unidade só:
    // 10 caracteres a 14 px = 140 px; em 120 px a fonte precisa reduzir.
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 120,
            child: DestinationText(
              'T MARANATA',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      ),
    );
    final size = tester
        .renderObject<RenderDestinationText>(find.byType(DestinationText))
        .fontSize;
    expect(10 * size, lessThanOrEqualTo(120));
  });
}
