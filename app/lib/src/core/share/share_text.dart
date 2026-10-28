import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';

/// Compartilhamento da plataforma; os testes trocam por um registro.
@visibleForTesting
Future<void> Function(String text, Rect? origin) sharePlatform = _platformShare;

Future<void> _platformShare(String text, Rect? origin) async {
  final result = await SharePlus.instance.share(
    // Sem Web Share (navegador de desktop), o plugin abriria um e-mail; o
    // app prefere copiar o texto (shareText).
    ShareParams(
      text: text,
      sharePositionOrigin: origin,
      mailToFallbackEnabled: false,
    ),
  );
  if (result.status == ShareResultStatus.unavailable) {
    throw StateError('compartilhamento indisponível');
  }
}

/// Abre o compartilhamento do sistema (Android, iOS, Web Share). Onde não
/// existe (navegador de desktop, por exemplo), copia o texto e avisa. Só o
/// texto mostrado é enviado; nunca a posição do passageiro.
///
/// [context] deve ser o do botão tocado: o iOS (iPhone desde o 26 e iPad)
/// exige a área de origem da folha e recusa o compartilhamento sem ela.
Future<void> shareText(BuildContext context, String text) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final box = context.findRenderObject();
  final origin = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  try {
    await sharePlatform(text, origin);
  } catch (error) {
    // Só o tipo/mensagem do erro, nunca o texto compartilhado.
    debugPrint('Compartilhamento indisponível: $error');
    var copied = true;
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (error) {
      // O navegador pode recusar a área de transferência.
      debugPrint('Cópia recusada: $error');
      copied = false;
    }
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(copied ? l10n.shareCopied : l10n.shareUnavailable),
        ),
      );
  }
}
