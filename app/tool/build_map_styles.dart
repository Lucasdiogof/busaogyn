// Gera assets/map/busao-dark.json e assets/map/busao-light.json a partir do
// Liberty do OpenFreeMap.
//
//   dart run tool/build_map_styles.dart [url-do-estilo | arquivo.json]
//
// Rodar de novo só quando o Liberty mudar (por exemplo, nova versão do
// sprite) ou quando as regras de lib/src/core/map/busao_style.dart mudarem. A
// saída é determinística e versionada no repositório; o app não baixa nem
// processa estilo para montar o mapa.
import 'dart:convert';
import 'dart:io';

import 'package:busaogyn/src/core/map/busao_style.dart';

const _libertyUrl = 'https://tiles.openfreemap.org/styles/liberty';

Future<void> main(List<String> args) async {
  final input = args.isNotEmpty ? args.first : _libertyUrl;
  final String body;
  if (input.startsWith('http')) {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(input));
      final response = await request.close();
      if (response.statusCode != 200) {
        stderr.writeln('HTTP ${response.statusCode} ao baixar $input');
        exitCode = 1;
        return;
      }
      body = await response.transform(utf8.decoder).join();
    } finally {
      client.close();
    }
  } else {
    body = await File(input).readAsString();
  }
  final liberty = jsonDecode(body) as Map<String, dynamic>;

  final unhandled = <String>{};
  for (final theme in BusaoMapTheme.values) {
    final style = buildBusaoStyle(
      liberty,
      theme,
      sourceUrl: _libertyUrl,
      onUnhandled: unhandled.add,
    );
    final out = File('assets/map/busao-${theme.name}.json');
    await out.writeAsString(
      '${const JsonEncoder.withIndent(' ').convert(style)}\n',
    );
    stdout.writeln(
      'OK: ${out.path} (${(style['layers'] as List).length} layers, '
      'sprite ${style['sprite']})',
    );
  }
  if (unhandled.isNotEmpty) {
    stderr.writeln(
      'Atenção: camadas do Liberty sem regra (mantidas como estão): '
      '${unhandled.toList()..sort()}',
    );
  }
}
