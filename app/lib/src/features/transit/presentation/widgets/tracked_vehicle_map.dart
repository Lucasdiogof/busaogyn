import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/config/map_config.dart';
import '../../domain/entities/tracked_vehicle.dart';
import 'vehicle_map_data.dart';
import 'vehicle_marker_image.dart';

/// Constrói a superfície do mapa nativo; substituível em testes.
typedef VehicleMapBuilder =
    Widget Function(
      BuildContext context, {
      required LatLng initialTarget,
      required MapCreatedCallback onMapCreated,
      required OnStyleLoadedCallback onStyleLoaded,
    });

class TrackedVehicleMap extends StatefulWidget {
  const TrackedVehicleMap({required this.vehicle, this.mapBuilder, super.key});

  final TrackedVehicle vehicle;
  final VehicleMapBuilder? mapBuilder;

  @override
  State<TrackedVehicleMap> createState() => _TrackedVehicleMapState();
}

class _TrackedVehicleMapState extends State<TrackedVehicleMap> {
  static const _initialZoom = 16.0;
  static const _cameraDuration = Duration(milliseconds: 800);

  MapLibreMapController? _controller;
  bool _styleReady = false;

  LatLng? get _vehicleCenter {
    final position = widget.vehicle.position;
    if (position == null) return null;
    return LatLng(position.latitude, position.longitude);
  }

  @override
  void didUpdateWidget(covariant TrackedVehicleMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    final current = widget.vehicle.position;
    if (current == null ||
        !vehiclePositionChanged(oldWidget.vehicle.position, current)) {
      return;
    }
    _syncVehicle(follow: true);
  }

  void _onMapCreated(MapLibreMapController controller) {
    // Controller novo (mapa recriado): nada do estilo anterior existe nele.
    _controller = controller;
    _styleReady = false;
  }

  /// Chamado a cada carga de estilo, inclusive após troca/recarga: imagem,
  /// source e layer pertencem ao estilo e precisam ser recriados aqui.
  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    _styleReady = false;

    final scheme = Theme.of(context).colorScheme;
    final marker = await renderVehicleMarker(
      background: scheme.primary,
      foreground: scheme.onPrimary,
    );
    if (!mounted || !identical(controller, _controller)) return;

    await controller.addImage(vehicleImageId, marker);
    await controller.addGeoJsonSource(
      vehicleSourceId,
      vehicleFeatureCollection(widget.vehicle.position),
    );
    await controller.addSymbolLayer(
      vehicleSourceId,
      vehicleLayerId,
      const SymbolLayerProperties(
        iconImage: vehicleImageId,
        iconSize: 0.5,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
      enableInteraction: false,
    );
    _styleReady = true;
    // A posição pode ter mudado enquanto o estilo carregava.
    await _syncVehicle(follow: false);
  }

  Future<void> _syncVehicle({required bool follow}) async {
    final controller = _controller;
    if (controller == null || !_styleReady || _vehicleCenter == null) return;

    await controller.setGeoJsonSource(
      vehicleSourceId,
      vehicleFeatureCollection(widget.vehicle.position),
    );
    if (follow) await _centerOnVehicle();
  }

  Future<void> _centerOnVehicle() async {
    final controller = _controller;
    final center = _vehicleCenter;
    if (controller == null || center == null) return;

    await controller.animateCamera(
      CameraUpdate.newLatLng(center),
      duration: _cameraDuration,
    );
  }

  Widget _buildNativeMap(BuildContext context, LatLng center) {
    final builder = widget.mapBuilder;
    if (builder != null) {
      return builder(
        context,
        initialTarget: center,
        onMapCreated: _onMapCreated,
        onStyleLoaded: _onStyleLoaded,
      );
    }

    return MapLibreMap(
      styleString: MapConfig.styleUrl,
      initialCameraPosition: CameraPosition(target: center, zoom: _initialZoom),
      minMaxZoomPreference: const MinMaxZoomPreference(3, 19),
      compassEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      logoViewPosition: LogoViewPosition.topLeft,
      attributionButtonPosition: AttributionButtonPosition.bottomRight,
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _vehicleCenter;
    if (center == null) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 220,
        child: Semantics(
          label: 'Mapa com a posição do ônibus ${widget.vehicle.vehicleNumber}',
          child: Stack(
            children: [
              _buildNativeMap(context, center),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton.filledTonal(
                  onPressed: _centerOnVehicle,
                  tooltip: 'Centralizar ônibus',
                  icon: const Icon(Icons.my_location_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
