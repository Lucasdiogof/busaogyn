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
    this.led,
    this.dashedOutline = false,
  });

  /// Letreiro de LED na frente (cor da marca); `null` = apagado.
  final Color? led;

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
        detail: Color.lerp(tokens.accent, Colors.black, 0.18)!,
        outline: dark ? const Color(0xFFFFF4D6) : const Color(0xFF1A1300),
        shadow: shadow,
        // Acompanhado: letreiro aceso (âmbar claro sobre o vidro escuro).
        led: const Color(0xFFFFE08A),
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

/// Ônibus visto de cima, com a frente para o topo da imagem. Linguagem da
/// marca BusãoGyn (não de operadora): corpo bem arredondado, letreiro de LED
/// na frente (o "BUSÃO GYN" da logo), para-brisa, um único bagageiro de teto
/// e vidro traseiro. Poucas formas grandes: continua legível com ~36 px.
/// Frente para cima = 0° (norte): o acompanhado gira pela direção observada;
/// secundários ficam assim (a fonte não informa direção).
///
/// Com [headingArrow], uma seta à frente marca a direção observada pelo
/// deslocamento recente. Não indica rota nem destino.
Future<Uint8List> renderBusMarker(
  BusMarkerStyle style, {
  bool headingArrow = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final pad = headingArrow ? _arrowPad : 0.0;
  if (headingArrow) {
    // Chevron arredondado (mesma linguagem das setas de trajeto do mapa).
    final arrow = Path()
      ..moveTo(60, 6)
      ..lineTo(86, 36)
      ..quadraticBezierTo(88, 40, 83, 39)
      ..lineTo(60, 30)
      ..lineTo(37, 39)
      ..quadraticBezierTo(32, 40, 34, 36)
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

  final outer = rrect(16, 6, 104, 170, 30);
  final body = rrect(22, 12, 98, 164, 25);

  canvas.drawRRect(
    outer.shift(const Offset(0, 4)),
    Paint()
      ..color = style.shadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
  );

  // Retrovisores.
  final mirrorPaint = Paint()..color = style.outline;
  canvas.drawRRect(rrect(8, 34, 18, 48, 5), mirrorPaint);
  canvas.drawRRect(rrect(102, 34, 112, 48, 5), mirrorPaint);

  if (style.dashedOutline) {
    _strokeDashed(canvas, outer, Paint()..color = style.outline, 5);
  } else {
    canvas.drawRRect(outer, Paint()..color = style.outline);
  }
  canvas.drawRRect(body, Paint()..color = style.body);

  // Letreiro: faixa escura na frente; aceso só no ônibus acompanhado.
  canvas.drawRRect(rrect(32, 18, 88, 34, 6), Paint()..color = style.glass);
  final led = style.led;
  if (led != null) {
    canvas.drawRRect(rrect(38, 23, 82, 29, 3), Paint()..color = led);
  }

  // Para-brisa com um reflexo.
  canvas.drawRRect(rrect(30, 38, 90, 66, 10), Paint()..color = style.glass);
  canvas.drawRRect(
    rrect(37, 43, 70, 47, 2),
    Paint()..color = Colors.white.withValues(alpha: 0.22),
  );

  // Bagageiro de teto (uma forma só).
  canvas.drawRRect(rrect(38, 80, 82, 140, 10), Paint()..color = style.detail);

  // Vidro traseiro.
  canvas.drawRRect(rrect(36, 148, 84, 158, 5), Paint()..color = style.glass);

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
