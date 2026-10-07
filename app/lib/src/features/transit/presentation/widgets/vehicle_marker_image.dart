import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const _markerPixels = 128.0;

/// Desenha o marcador do ônibus como PNG para o estilo do mapa: disco âmbar
/// com anel claro e ícone de ônibus. Sem seta: a fonte não informa direção.
Future<Uint8List> renderVehicleMarker({
  required Color background,
  required Color foreground,
  required Color ring,
  required Color shadow,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const center = Offset(_markerPixels / 2, _markerPixels / 2);
  const radius = _markerPixels / 2 - 14;

  canvas.drawCircle(
    center.translate(0, 3),
    radius + 5,
    Paint()
      ..color = shadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
  );
  canvas.drawCircle(center, radius + 6, Paint()..color = ring);
  canvas.drawCircle(center, radius, Paint()..color = background);

  const icon = Icons.directions_bus_rounded;
  final painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 54,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: foreground,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));

  final image = await recorder.endRecording().toImage(
    _markerPixels.toInt(),
    _markerPixels.toInt(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
