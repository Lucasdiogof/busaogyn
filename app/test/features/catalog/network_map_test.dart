import 'dart:math' show Point;
import 'dart:typed_data';

import 'package:busaogyn/src/core/theme/app_theme.dart';
import 'package:busaogyn/src/core/theme/busao_tokens.dart';
import 'package:busaogyn/src/features/catalog/domain/network_geojson.dart';
import 'package:busaogyn/src/features/catalog/domain/route_geometry.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/network_map_layers.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/tracked_vehicle_map.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/vehicle_map_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'catalog_fixture.dart';

/// Controller nativo simulado (mesmas regras do teste de estilo existente:
/// id repetido falha, chamadas durante troca de estilo falham) e registro
/// do que foi enviado.
class _FakeController extends Fake implements MapLibreMapController {
  final sources = <String>{};
  final layers = <String>{};
  final lineColors = <String, Object?>{};
  final pushed = <String>[];
  final cameras = <CameraUpdate>[];
  bool styleLoaded = true;

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

  void beginStyleSwitch() {
    styleLoaded = false;
    sources.clear();
    layers.clear();
  }

  void _require() {
    if (!styleLoaded) throw StateError('estilo carregando');
  }

  @override
  Future<void> addImage(
    String name,
    Uint8List bytes, [
    bool sdf = false,
  ]) async => _require();

  @override
  Future<void> addGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson, {
    String? promoteId,
  }) async {
    _require();
    if (!sources.add(sourceId)) throw StateError('source $sourceId repetido');
  }

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    _require();
    if (!sources.add(sourceId)) throw StateError('source $sourceId repetido');
  }

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {
    _require();
    if (!sources.contains(sourceId)) throw StateError('sem source $sourceId');
    pushed.add(sourceId);
  }

  Future<void> _addLayer(String sourceId, String layerId) async {
    _require();
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
  }) {
    lineColors[layerId] = properties.lineColor;
    return _addLayer(sourceId, layerId);
  }

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
  }) async {
    cameras.add(cameraUpdate);
    return true;
  }
}

const _baseLayers = {
  observedTrailLayerId,
  secondaryLayerId,
  vehicleHaloLayerId,
  vehicleLayerId,
};

void main() {
  final catalog = fixtureCatalog();
  late MapSurfaceParams params;

  Widget map({
    required NetworkOverlay? network,
    String style = 'claro',
    ThemeData? theme,
    ValueChanged<String>? onStopTap,
    String? vehicle,
    GeoPosition? position,
    EdgeInsets cameraPadding = EdgeInsets.zero,
  }) => MaterialApp(
    theme: theme ?? AppTheme.light(),
    home: TransitMap(
      vehicleNumber: vehicle,
      position: position,
      stale: false,
      styleString: style,
      fallbackStyleString: 'fallback',
      network: network,
      onStopTap: onStopTap,
      cameraPadding: cameraPadding,
      mapBuilder: (context, surface) {
        params = surface;
        return const SizedBox.expand();
      },
    ),
  );

  Future<void> loadStyle(WidgetTester tester, _FakeController controller) =>
      tester.runAsync(() async {
        params.onStyleLoaded();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });

  testWidgets('com a rede: cria pontos e trajetos abaixo dos ônibus, uma vez', (
    tester,
  ) async {
    final builder = NetworkOverlayBuilder(catalog);
    await tester.pumpWidget(map(network: builder.build()));
    final controller = _FakeController();
    params.onMapCreated(controller);
    await loadStyle(tester, controller);
    expect(controller.layers, {..._baseLayers, ...netLayerIds});
    expect(controller.sources, containsAll(netSourceIds));
  });

  testWidgets('trajeto e 1º trecho da viagem com contorno escuro por baixo', (
    tester,
  ) async {
    final builder = NetworkOverlayBuilder(catalog);
    await tester.pumpWidget(map(network: builder.build()));
    final controller = _FakeController();
    params.onMapCreated(controller);
    await loadStyle(tester, controller);
    final order = controller.layers.toList();
    expect(
      order.indexOf(netRouteCasingLayerId),
      lessThan(order.indexOf(netRouteOutboundLayerId)),
    );
    expect(
      order.indexOf(netPlanLeg1CasingLayerId),
      lessThan(order.indexOf(netPlanLeg1LayerId)),
    );
    // Tema claro: âmbar escuro (contraste do amarelo sobre o mapa claro).
    final hex = (BusaoTokens.light.accentText.toARGB32() & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0');
    expect(controller.lineColors[netRouteCasingLayerId], '#$hex');
  });

  testWidgets('sem a rede (produção): só as camadas de sempre', (tester) async {
    await tester.pumpWidget(map(network: null));
    final controller = _FakeController();
    params.onMapCreated(controller);
    await loadStyle(tester, controller);
    expect(controller.layers, _baseLayers);
  });

  testWidgets('troca de tema: recria tudo uma vez, sem duplicar', (
    tester,
  ) async {
    final builder = NetworkOverlayBuilder(catalog);
    final shape = catalog.shapesOf('001').first;
    final overlay = builder.build(routeLineId: '001', routeShapeId: shape.id);
    await tester.pumpWidget(map(network: overlay));
    final controller = _FakeController();
    params.onMapCreated(controller);
    await loadStyle(tester, controller);

    await tester.pumpWidget(
      map(network: overlay, style: 'noturno', theme: AppTheme.dark()),
    );
    controller.beginStyleSwitch();
    controller.styleLoaded = true;
    await loadStyle(tester, controller);
    expect(controller.layers, {..._baseLayers, ...netLayerIds});
  });

  testWidgets('só o que mudou vai ao nativo', (tester) async {
    final builder = NetworkOverlayBuilder(catalog);
    await tester.pumpWidget(map(network: builder.build()));
    final controller = _FakeController();
    params.onMapCreated(controller);
    await loadStyle(tester, controller);
    controller.pushed.clear();

    await tester.pumpWidget(
      map(network: builder.build(selectedStopId: '1201')),
    );
    await tester.pump();
    expect(controller.pushed, [netSelectedSourceId]);

    controller.pushed.clear();
    final shape = catalog.shapesOf('001')[1];
    await tester.pumpWidget(
      map(
        network: builder.build(
          selectedStopId: '1201',
          routeLineId: '001',
          routeShapeId: shape.id,
        ),
      ),
    );
    await tester.pump();
    // Com trajeto, os pontos gerais saem (só os da linha ficam).
    expect(controller.pushed.toSet(), {
      netRouteSourceId,
      netRouteEndsSourceId,
      netRouteStopsSourceId,
      netStopsSourceId,
    });

    // Sem trajeto de novo, mudar só o ponto selecionado não reenvia os
    // pontos gerais.
    await tester.pumpWidget(
      map(network: builder.build(selectedStopId: '1201')),
    );
    await tester.pump();
    controller.pushed.clear();
    await tester.pumpWidget(
      map(network: builder.build(selectedStopId: '1202')),
    );
    await tester.pump();
    expect(controller.pushed, [netSelectedSourceId]);
  });

  testWidgets('foco: um movimento de câmera por pedido', (tester) async {
    final builder = NetworkOverlayBuilder(catalog);
    await tester.pumpWidget(map(network: builder.build()));
    final controller = _FakeController();
    params.onMapCreated(controller);
    await loadStyle(tester, controller);
    controller.cameras.clear();

    final focus = MapFocus.point(
      1,
      const GeoPosition(latitude: -16.8, longitude: -49.24),
    );
    await tester.pumpWidget(map(network: builder.build(focus: focus)));
    await tester.pump();
    await tester.pumpWidget(map(network: builder.build(focus: focus)));
    await tester.pump();
    expect(controller.cameras, hasLength(1));

    final bounds = MapFocus.bounds(
      2,
      GeoBounds.of(catalog.shapesOf('001').first.points),
    );
    await tester.pumpWidget(map(network: builder.build(focus: bounds)));
    await tester.pump();
    expect(controller.cameras, hasLength(2));
  });

  testWidgets('painel muda logo depois de enquadrar: refaz o enquadramento', (
    tester,
  ) async {
    final builder = NetworkOverlayBuilder(catalog);
    await tester.pumpWidget(map(network: builder.build()));
    final controller = _FakeController();
    params.onMapCreated(controller);
    await loadStyle(tester, controller);
    controller.cameras.clear();
    final bounds = MapFocus.bounds(
      1,
      GeoBounds.of(catalog.shapesOf('001').first.points),
    );
    final framed = builder.build(focus: bounds);
    await tester.pumpWidget(
      map(network: framed, cameraPadding: const EdgeInsets.only(bottom: 400)),
    );
    await tester.pump();
    expect(controller.cameras, hasLength(1));
    // Teclado fecha / painel recolhe: insets novos refazem o enquadramento
    // (no iOS a troca de inset interrompia a animação no meio).
    await tester.pumpWidget(
      map(network: framed, cameraPadding: const EdgeInsets.only(bottom: 120)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(controller.cameras, hasLength(2));
  });

  testWidgets('foco pedido antes do estilo carregar é aplicado depois', (
    tester,
  ) async {
    final builder = NetworkOverlayBuilder(catalog);
    final focus = MapFocus.point(
      7,
      const GeoPosition(latitude: -16.8, longitude: -49.24),
    );
    await tester.pumpWidget(map(network: builder.build()));
    final controller = _FakeController();
    params.onMapCreated(controller);
    await tester.pumpWidget(map(network: builder.build(focus: focus)));
    expect(controller.cameras, isEmpty);
    await loadStyle(tester, controller);
    expect(controller.cameras, hasLength(1));
  });

  testWidgets('toque num ponto chama onStopTap; em grupo, aproxima', (
    tester,
  ) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      map(
        network: NetworkOverlayBuilder(catalog).build(),
        onStopTap: tapped.add,
      ),
    );
    final controller = _FakeController();
    params.onMapCreated(controller);
    await loadStyle(tester, controller);
    controller.cameras.clear();
    for (final callback in controller.onFeatureTapped) {
      callback(
        const Point(1, 1),
        const LatLng(-16.8, -49.24),
        '1201',
        netStopsLayerId,
        null,
      );
      callback(
        const Point(1, 1),
        const LatLng(-16.8, -49.24),
        '99',
        netClusterLayerId,
        null,
      );
      // Com trajeto aberto, os anéis dos pontos da linha também abrem o ponto.
      callback(
        const Point(1, 1),
        const LatLng(-16.68, -49.26),
        '00294',
        netRouteStopsLayerId,
        null,
      );
    }
    await tester.pump();
    expect(tapped, ['1201', '00294']);
    expect(controller.cameras, hasLength(1));
  });

  testWidgets('trajeto do ônibus atualiza sem mexer nas outras camadas', (
    tester,
  ) async {
    final builder = NetworkOverlayBuilder(catalog);
    await tester.pumpWidget(map(network: builder.build()));
    final controller = _FakeController();
    params.onMapCreated(controller);
    await loadStyle(tester, controller);
    controller.pushed.clear();
    final shape = catalog.shapesOf('001').first;
    await tester.pumpWidget(
      map(
        network: NetworkOverlay(
          stops: builder.build().stops,
          route: builder.build().route,
          routeEnds: builder.build().routeEnds,
          routeStops: builder.build().routeStops,
          selectedStop: builder.build().selectedStop,
          trackRoute: featureCollection([
            {
              'type': 'Feature',
              'properties': {'kind': 'future'},
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [shape.points.first.longitude, shape.points.first.latitude],
                  [shape.points.last.longitude, shape.points.last.latitude],
                ],
              },
            },
          ]),
        ),
      ),
    );
    await tester.pump();
    expect(controller.pushed, [netTrackSourceId]);
  });
}
