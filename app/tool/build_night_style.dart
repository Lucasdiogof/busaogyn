// Gera assets/map/liberty-night.json a partir do Liberty do OpenFreeMap.
//
//   dart run tool/build_night_style.dart [url-do-estilo]
//
// Rodar de novo só quando o Liberty mudar (por exemplo, nova versão do
// sprite). A saída é determinística e versionada no repositório; o app não
// baixa nem processa estilo para montar o tema noturno.
import 'dart:convert';
import 'dart:io';

import 'package:busaogyn/src/core/map/night_style.dart';

Future<void> main(List<String> args) async {
  final url = args.isNotEmpty
      ? args.first
      : 'https://tiles.openfreemap.org/styles/liberty';
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) {
      stderr.writeln('HTTP ${response.statusCode} ao baixar $url');
      exitCode = 1;
      return;
    }
    final body = await response.transform(utf8.decoder).join();
    final style = jsonDecode(body) as Map<String, dynamic>;
    final night = deriveNightStyle(style, sourceUrl: url);
    final out = File('assets/map/liberty-night.json');
    await out.writeAsString(
      '${const JsonEncoder.withIndent(' ').convert(night)}\n',
    );
    stdout.writeln(
      'OK: ${out.path} (${(night['layers'] as List).length} layers, '
      'sprite ${night['sprite']})',
    );
  } finally {
    client.close();
  }
}
