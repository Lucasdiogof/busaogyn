import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/busao_tokens.dart';
import '../../domain/entities/map_vehicle.dart';

const _busWidth = 120.0;
const _busHeight = 176.0;

/// Espaço acima (seta) e abaixo (simetria) na imagem com direção: o ônibus
/// continua no centro, que é o eixo da rotação.
const _arrowPad = 44.0;

/// Cores de um marcador de ônibus.
@immutable
class BusMarkerStyle {
  const BusMarkerStyle({
    required this.body,
    required this.glass,
    required this.detail,
    required this.outline,
    required this.shadow,
    this.dashedOutline = false,
  });

  final Color body;
  final Color glass;
  final Color detail;
  final Color outline;
  final Color shadow;

  /// Contorno tracejado: posição antiga, que não é a atual.
  final bool dashedOutline;
}

/// Estilos por variante e tema. Só estado visual: nada de operadora, modelo
/// ou pintura de frota.
BusMarkerStyle busMarkerStyle(
  MarkerVariant variant, {
  required BusaoTokens tokens,
  required Brightness brightness,
}) {
  final dark = brightness == Brightness.dark;
  final shadow = Colors.black.withValues(alpha: dark ? 0.55 : 0.35);
  switch (variant) {
    case MarkerVariant.tracked:
      return BusMarkerStyle(
        body: tokens.accent,
        glass: const Color(0xFF14110A),
        detail: Color.lerp(tokens.accent, Colors.black, 0.2)!,
        outline: dark ? const Color(0xFFFFF4D6) : const Color(0xFF1A1300),
        shadow: shadow,
      );
    case MarkerVariant.secondary:
      return BusMarkerStyle(
        body: dark ? const Color(0xFFB3AEA0) : const Color(0xFF706B5F),
        glass: dark ? const Color(0xFF2A2720) : const Color(0xFF1F1D17),
        detail: dark ? const Color(0xFF9A9588) : const Color(0xFF5B574C),
        outline: dark ? const Color(0xFF0B0A08) : Colors.white,
        shadow: shadow,
      );
    case MarkerVariant.stale:
      return BusMarkerStyle(
        body: dark ? const Color(0xFF6F6B60) : const Color(0xFFA29D90),
        glass: dark ? const Color(0xFF1B1912) : const Color(0xFF2A2720),
        detail: dark ? const Color(0xFF5C584F) : const Color(0xFF8C887B),
        outline: tokens.unconfirmed,
        shadow: shadow,
        dashedOutline: true,
      );
  }
}

/// Ônibus visto de cima, com a frente para o topo da imagem: corpo
/// retangular de cantos arredondados, para-brisa, painéis do teto, vidro
/// traseiro e retrovisores. Frente para cima = 0° (norte): o acompanhado
/// gira pela direção observada; secundários ficam assim (a fonte não informa
/// direção).
///
/// Com [headingArrow], uma seta à frente do para-brisa marca a direção
/// observada pelo deslocamento recente. Não indica rota nem destino.
Future<Uint8List> renderBusMarker(
  BusMarkerStyle style, {
  bool headingArrow = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final pad = headingArrow ? _arrowPad : 0.0;
  if (headingArrow) {
    final arrow = Path()
      ..moveTo(60, 4)
      ..lineTo(88, 38)
      ..lineTo(60, 28)
      ..lineTo(32, 38)
      ..close();
    canvas.drawPath(
      arrow,
      Paint()
        ..color = style.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(arrow, Paint()..color = style.body);
    canvas.translate(0, pad);
  }

  RRect rrect(double l, double t, double r, double b, double radius) =>
      RRect.fromLTRBR(l, t, r, b, Radius.circular(radius));

  final outer = rrect(18, 6, 102, 170, 24);
  final body = rrect(23, 11, 97, 165, 19);

  canvas.drawRRect(
    outer.shift(const Offset(0, 4)),
    Paint()
      ..color = style.shadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
  );

  // Retrovisores.
  final mirrorPaint = Paint()..color = style.outline;
  canvas.drawRRect(rrect(11, 30, 19, 44, 4), mirrorPaint);
  canvas.drawRRect(rrect(101, 30, 109, 44, 4), mirrorPaint);

  if (style.dashedOutline) {
    _strokeDashed(canvas, outer, Paint()..color = style.outline, 5);
  } else {
    canvas.drawRRect(outer, Paint()..color = style.outline);
  }
  canvas.drawRRect(body, Paint()..color = style.body);

  // Para-brisa com um reflexo.
  canvas.drawRRect(rrect(31, 19, 89, 53, 10), Paint()..color = style.glass);
  canvas.drawRRect(
    rrect(37, 24, 83, 29, 2.5),
    Paint()..color = Colors.white.withValues(alpha: 0.22),
  );

  // Painéis do teto (ar-condicionado e escotilhas).
  final roof = Paint()..color = style.detail;
  canvas.drawRRect(rrect(34, 66, 86, 94, 7), roof);
  canvas.drawRRect(rrect(34, 102, 86, 130, 7), roof);

  // Vidro traseiro.
  canvas.drawRRect(rrect(37, 142, 83, 155, 6), Paint()..color = style.glass);

  final image = await recorder.endRecording().toImage(
    _busWidth.toInt(),
    (_busHeight + pad * 2).toInt(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void _strokeDashed(Canvas canvas, RRect rrect, Paint paint, double width) {
  final path = Path()..addRRect(rrect);
  final stroke = paint
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      canvas.drawPath(metric.extractPath(distance, distance + 9), stroke);
      distance += 16;
    }
  }
}
