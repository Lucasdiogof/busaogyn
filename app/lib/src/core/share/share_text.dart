import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';

/// Compartilhamento da plataforma; os testes trocam por um registro.
@visibleForTesting
Future<void> Function(String text) sharePlatform = _platformShare;

Future<void> _platformShare(String text) async {
  final result = await SharePlus.instance.share(ShareParams(text: text));
  if (result.status == ShareResultStatus.unavailable) {
    throw StateError('compartilhamento indisponível');
  }
}

/// Abre o compartilhamento do sistema (Android, iOS, Web Share). Onde não
/// existe (navegador de desktop, por exemplo), copia o texto e avisa. Só o
/// texto mostrado é enviado; nunca a posição do passageiro.
Future<void> shareText(BuildContext context, String text) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await sharePlatform(text);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.shareCopied)));
  }
}
