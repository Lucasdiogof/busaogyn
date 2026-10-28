// Garante que o catálogo oficial da CMTC (licença de redistribuição
// pendente) não entra no código, nos assets nem no Git de produção.
// O artefato compilado é verificado por scripts/check-no-official-catalog.sh.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Marcas que só existem no payload gerado (nunca no código versionado).
const payloadMarkers = ['cmtc-2026-10', '"stops":{"fields"', 'cmtcCatalogJson'];

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('lib/ não importa nada de dev_catalog nem contém o payload', () {
    for (final file in _dartFiles('lib')) {
      final text = file.readAsStringSync();
      final directives = text
          .split('\n')
          .where((l) => RegExp(r'^\s*(import|export|part)\b').hasMatch(l));
      for (final line in directives) {
        expect(line, isNot(contains('dev_catalog')), reason: file.path);
      }
      for (final marker in payloadMarkers) {
        expect(text, isNot(contains(marker)), reason: '${file.path}: $marker');
      }
    }
  });

  test('o entrypoint de produção não liga o catálogo', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('runBusaoGyn()'));
    expect(main, isNot(contains('devCatalogJson')));
  });

  test('nenhum asset declarado aponta para catálogo ou dados da CMTC', () {
    final pubspec = File('pubspec.yaml').readAsStringSync().toLowerCase();
    for (final banned in ['dev_catalog', 'catalog', 'cmtc', 'data/']) {
      expect(pubspec, isNot(contains(banned)), reason: banned);
    }
  });

  test('o catálogo gerado e os dados da CMTC estão fora do Git', () {
    final appIgnore = File('.gitignore').readAsStringSync();
    expect(appIgnore, contains('/dev_catalog/'));
    final dataIgnore = File('../data/cmtc/.gitignore').readAsStringSync();
    for (final dir in ['raw/', 'processed/', 'reports/']) {
      expect(dataIgnore, contains(dir));
    }
  });

  test('build release recusa o catálogo (guarda em bootstrap)', () {
    final bootstrap = File('lib/src/bootstrap.dart').readAsStringSync();
    expect(bootstrap, contains('releaseMode: kReleaseMode'));
    expect(
      bootstrap,
      contains('if (json == null || releaseMode) return null;'),
    );
  });
}
