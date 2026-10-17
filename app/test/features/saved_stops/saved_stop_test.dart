import 'package:busaogyn/src/features/saved_stops/domain/saved_stop.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  group('canonicalStopCode', () {
    test('aceita só dígitos e tira espaços das pontas', () {
      expect(canonicalStopCode('30402'), '30402');
      expect(canonicalStopCode('  30402 \n'), '30402');
    });

    test('preserva zeros à esquerda (ADR-0002)', () {
      expect(canonicalStopCode('00294'), '00294');
      expect(canonicalStopCode('00294'), isNot(canonicalStopCode('294')));
    });

    test('rejeita o que não é código de ponto', () {
      for (final bad in [
        null,
        '',
        '   ',
        'abc',
        '30 402',
        '30402a',
        '-30402',
        '30.402',
        '１２３', // dígitos de largura total
        '1' * (maxStopCodeLength + 1),
      ]) {
        expect(canonicalStopCode(bad), isNull, reason: '$bad');
      }
    });
  });

  test('SavedStop mostra o código quando não há nome confiável', () {
    expect(stop('30402').label, '30402');
    expect(stop('30402', name: 'Praça Cívica').label, 'Praça Cívica');
  });

  test('limites são constantes centralizadas', () {
    expect(defaultRecentStopsLimit, 10);
    expect(defaultFavoriteStopsLimit, 50);
  });
}
