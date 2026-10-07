import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const _markerPixels = 128.0;

/// Desenha o marcador (círculo com ícone de ônibus) como PNG para o estilo.
Future<Uint8List> renderVehicleMarker({
  required Color background,
  required Color foreground,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const center = Offset(_markerPixels / 2, _markerPixels / 2);

  canvas.drawCircle(center, _markerPixels / 2, Paint()..color = foreground);
  canvas.drawCircle(center, _markerPixels / 2 - 8, Paint()..color = background);

  const icon = Icons.directions_bus_rounded;
  final painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 68,
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
