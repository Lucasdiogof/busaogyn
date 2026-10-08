import 'dart:async';
import 'dart:typed_data';

import 'package:busaogyn/src/core/theme/app_theme.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/tracked_vehicle_map.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/vehicle_map_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Controller nativo simulado: um estilo carregado por vez. Durante a troca
/// de estilo as chamadas falham, e id repetido de source/layer também,
/// como no MapLibre.
class _FakeController extends Fake implements MapLibreMapController {
  final sources = <String>{};
  final layers = <String>{};
  bool styleLoaded = true;

  /// Segura a primeira `addImage` até o teste liberar.
  Completer<void>? firstImageGate;

  @override
  final onFeatureTapped = <OnFeatureInteractionCallback>[];

  @override
  bool get isCameraMoving => false;

  @override
  CameraPosition? get cameraPosition =>
      const CameraPosition(target: LatLng(-16.68, -49.26), zoom: 12);

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  /// `setStyle` nativo: o estilo atual some e o novo ainda não carregou.
  void beginStyleSwitch() {
    styleLoaded = false;
    sources.clear();
    layers.clear();
  }

  void _requireStyle() {
    if (!styleLoaded) throw StateError('estilo ainda carregando');
  }

  @override
  Future<void> addImage(
    String name,
    Uint8List bytes, [
    bool sdf = false,
  ]) async {
    final gate = firstImageGate;
    if (gate != null) {
      firstImageGate = null;
      await gate.future;
    }
    _requireStyle();
  }

  @override
  Future<void> addGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson, {
    String? promoteId,
  }) async {
    _requireStyle();
    if (!sources.add(sourceId)) throw StateError('source $sourceId repetido');
  }

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {
    _requireStyle();
    if (!sources.contains(sourceId)) throw StateError('sem source $sourceId');
  }

  Future<void> _addLayer(String sourceId, String layerId) async {
    _requireStyle();
    if (!sources.contains(sourceId)) throw StateError('sem source $sourceId');
    if (!layers.add(layerId)) throw StateError('layer $layerId repetido');
  }

  @override
  Future<void> addLineLayer(
    String sourceId,
    String layerId,
    LineLayerProperties properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    bool enableInteraction = true,
  }) => _addLayer(sourceId, layerId);

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    SymbolLayerProperties properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    bool enableInteraction = true,
  }) => _addLayer(sourceId, layerId);

  @override
  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    CircleLayerProperties properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    bool enableInteraction = true,
  }) => _addLayer(sourceId, layerId);

  @override
  Future<void> updateContentInsets(
    EdgeInsets insets, [
    bool animated = false,
  ]) async {}

  @override
  Future<bool?> animateCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
  }) async => true;
}

void main() {
  const allLayers = {
    observedTrailLayerId,
    secondaryLayerId,
    vehicleHaloLayerId,
    vehicleLayerId,
  };

  testWidgets('troca de tema no meio da carga do estilo não duplica nem '
      'perde layers', (tester) async {
    late MapSurfaceParams params;
    Widget map(String style) => MaterialApp(
      theme: AppTheme.light(),
      home: TransitMap(
        vehicleNumber: null,
        position: null,
        stale: false,
        styleString: style,
        fallbackStyleString: 'fallback',
        mapBuilder: (context, surface) {
          params = surface;
          return const SizedBox.expand();
        },
      ),
    );

    await tester.pumpWidget(map('claro'));
    final controller = _FakeController();
    params.onMapCreated(controller);

    await tester.runAsync(() async {
      // Carga do estilo claro presa na primeira imagem.
      final gate = controller.firstImageGate = Completer<void>();
      params.onStyleLoaded();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // O usuário troca para o noturno: o nativo começa a trocar o estilo.
      await tester.pumpWidget(map('noturno'));
      controller.beginStyleSwitch();

      // A carga antiga continua e não pode tocar no estilo em troca.
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(controller.sources, isEmpty);
      expect(controller.layers, isEmpty);

      // Estilo noturno carregado: a carga nova cria tudo uma vez só.
      controller.styleLoaded = true;
      params.onStyleLoaded();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });

    expect(controller.layers, allLayers);
    expect(controller.sources, {
      observedTrailSourceId,
      secondarySourceId,
      vehicleSourceId,
    });
  });

  testWidgets('duas trocas rápidas: só a última carga cria layers', (
    tester,
  ) async {
    late MapSurfaceParams params;
    Widget map(String style) => MaterialApp(
      theme: AppTheme.dark(),
      home: TransitMap(
        vehicleNumber: null,
        position: null,
        stale: false,
        styleString: style,
        fallbackStyleString: 'fallback',
        mapBuilder: (context, surface) {
          params = surface;
          return const SizedBox.expand();
        },
      ),
    );

    await tester.pumpWidget(map('a'));
    final controller = _FakeController();
    params.onMapCreated(controller);

    await tester.runAsync(() async {
      params.onStyleLoaded();
      await tester.pumpWidget(map('b'));
      controller.beginStyleSwitch();
      controller.styleLoaded = true;
      params.onStyleLoaded();
      await tester.pumpWidget(map('c'));
      controller.beginStyleSwitch();
      controller.styleLoaded = true;
      params.onStyleLoaded();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });

    expect(controller.layers, allLayers);
  });
}
