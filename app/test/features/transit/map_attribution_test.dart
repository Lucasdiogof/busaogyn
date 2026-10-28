import 'package:busaogyn/src/features/transit/presentation/widgets/tracked_vehicle_map.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// A atribuição fica logo acima do painel em todas as plataformas. No iOS o
/// MapLibre já soma o `contentInset` da câmera (Etapa F: o botão ia para o
/// topo, sob a barra de status).
void main() {
  double margin(
    TargetPlatform platform, {
    bool web = false,
    double covered = 400,
    double camera = 400,
  }) => attributionMarginBottom(
    coveredBottom: covered,
    cameraBottom: camera,
    platform: platform,
    isWeb: web,
  );

  test('Android e Web: margem = área coberta pelo painel', () {
    expect(margin(TargetPlatform.android), 408);
    expect(margin(TargetPlatform.iOS, web: true), 408);
  });

  test('iOS: não soma de novo o inset da câmera', () {
    expect(margin(TargetPlatform.iOS), 8);
    // Painel acima de 75% da tela: a câmera limita o inset, o resto vai na margem.
    expect(margin(TargetPlatform.iOS, covered: 700, camera: 633), 75);
    // Painel lateral (sem área coberta embaixo).
    expect(margin(TargetPlatform.iOS, covered: 0, camera: 16), 8);
  });
}
