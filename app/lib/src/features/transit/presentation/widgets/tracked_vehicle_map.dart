import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/config/map_config.dart';
import '../../../../core/theme/busao_tokens.dart';
import '../../domain/entities/tracked_vehicle.dart';
import 'camera_follow.dart';
import 'vehicle_map_data.dart';
import 'vehicle_marker_image.dart';

/// Parâmetros que a superfície nativa do mapa precisa receber.
class MapSurfaceParams {
  const MapSurfaceParams({
    required this.initialCameraPosition,
    required this.onMapCreated,
    required this.onStyleLoaded,
    required this.onCameraMove,
    required this.onCameraIdle,
  });

  final CameraPosition initialCameraPosition;
  final MapCreatedCallback onMapCreated;
  final OnStyleLoadedCallback onStyleLoaded;
  final OnCameraMoveCallback onCameraMove;
  final OnCameraIdleCallback onCameraIdle;
}

/// Constrói a superfície do mapa nativo; substituível em testes.
typedef VehicleMapBuilder =
    Widget Function(BuildContext context, MapSurfaceParams params);

/// Mapa principal, montado uma única vez. Recebe só a posição real do ônibus
/// acompanhado (ou nada) e nunca é reconstruído por mudanças de estado.
class TransitMap extends StatefulWidget {
  const TransitMap({
    required this.vehicleNumber,
    required this.position,
    required this.stale,
    this.cameraPadding = EdgeInsets.zero,
    this.controlsPadding = EdgeInsets.zero,
    this.mapBuilder,
    super.key,
  });

  /// Ônibus acompanhado; `null` quando não há tracking.
  final String? vehicleNumber;

  /// Última coordenada recebida da API para [vehicleNumber].
  final GeoPosition? position;

  /// Posição antiga ou com falha recente: o marcador fica esmaecido.
  final bool stale;

  /// Área coberta por painéis; a câmera centraliza no espaço visível.
  final EdgeInsets cameraPadding;

  /// Onde ficam os controles flutuantes do mapa.
  final EdgeInsets controlsPadding;
  final VehicleMapBuilder? mapBuilder;

  /// Contexto inicial: centro de Goiânia. Não representa ponto nem ônibus.
  static const initialCamera = CameraPosition(
    target: LatLng(-16.6869, -49.2648),
    zoom: 11.5,
  );

  static const trackingZoom = 16.0;

  @override
  State<TransitMap> createState() => _TransitMapState();
}

class _TransitMapState extends State<TransitMap> {
  static const _cameraDuration = Duration(milliseconds: 700);
  static const _insetsDebounce = Duration(milliseconds: 150);

  final _follow = CameraFollow();
  MapLibreMapController? _controller;
  bool _styleReady = false;
  bool _wasCameraMoving = false;
  bool _following = true;
  Timer? _insetsTimer;

  /// O próximo centralizar deve aproximar (primeira posição de um ônibus).
  bool _zoomOnNextCenter = true;

  LatLng? get _vehicleCenter {
    final position = widget.position;
    if (position == null) return null;
    return LatLng(position.latitude, position.longitude);
  }

  @override
  void didUpdateWidget(covariant TransitMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.vehicleNumber != oldWidget.vehicleNumber) {
      _follow.resume();
      _zoomOnNextCenter = true;
      _setFollowing(true);
    }

    final positionChanged = vehiclePositionChanged(
      oldWidget.position,
      widget.position,
    );
    if (positionChanged ||
        widget.stale != oldWidget.stale ||
        widget.vehicleNumber != oldWidget.vehicleNumber) {
      unawaited(_syncVehicle(follow: positionChanged && _follow.following));
    }

    if (widget.cameraPadding != oldWidget.cameraPadding) {
      _insetsTimer?.cancel();
      _insetsTimer = Timer(_insetsDebounce, _applyInsets);
    }
  }

  @override
  void dispose() {
    _insetsTimer?.cancel();
    _controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    // Controller novo (mapa recriado): nada do estilo anterior existe nele.
    _controller?.removeListener(_onControllerChanged);
    _controller = controller;
    _styleReady = false;
    _wasCameraMoving = false;
    controller.addListener(_onControllerChanged);
  }

  /// Borda de subida de `isCameraMoving` = `movestart` nativo.
  void _onControllerChanged() {
    final moving = _controller?.isCameraMoving ?? false;
    if (moving && !_wasCameraMoving) _onCameraMovement();
    _wasCameraMoving = moving;
  }

  void _onCameraMovement() {
    // Antes da primeira posição não há o que seguir; mexer no mapa nesse
    // intervalo não impede a centralização inicial.
    if (_vehicleCenter == null) return;
    if (_follow.onCameraMovement()) _setFollowing(false);
  }

  void _onUserPointer() {
    if (_vehicleCenter == null) return;
    if (_follow.onUserInteraction()) _setFollowing(false);
  }

  void _setFollowing(bool value) {
    if (_following == value || !mounted) return;
    setState(() => _following = value);
  }

  /// Chamado a cada carga de estilo, inclusive após troca/recarga: imagem,
  /// source e layers pertencem ao estilo e precisam ser recriados aqui.
  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    _styleReady = false;

    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final marker = await renderVehicleMarker(
      background: scheme.primary,
      foreground: Colors.white,
      plate: tokens.plate,
    );
    if (!mounted || !identical(controller, _controller)) return;

    await controller.addImage(vehicleImageId, marker);
    await controller.addGeoJsonSource(
      vehicleSourceId,
      vehicleFeatureCollection(widget.position, stale: widget.stale),
    );
    await controller.addCircleLayer(
      vehicleSourceId,
      vehicleHaloLayerId,
      CircleLayerProperties(
        circleRadius: 22,
        circleColor: _hex(scheme.primary),
        circleOpacity: const [
          'case',
          ['get', 'stale'],
          0.08,
          0.18,
        ],
        circleStrokeColor: _hex(scheme.primary),
        circleStrokeWidth: 1,
        circleStrokeOpacity: 0.35,
      ),
      enableInteraction: false,
    );
    await controller.addSymbolLayer(
      vehicleSourceId,
      vehicleLayerId,
      const SymbolLayerProperties(
        iconImage: vehicleImageId,
        iconSize: 0.5,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconOpacity: [
          'case',
          ['get', 'stale'],
          0.55,
          1.0,
        ],
      ),
      enableInteraction: false,
    );
    _styleReady = true;
    await _applyInsets();
    // A posição pode ter mudado enquanto o estilo carregava.
    await _syncVehicle(follow: _follow.following);
  }

  Future<void> _applyInsets() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    _follow.beginProgrammaticMove(Duration.zero);
    await controller.updateContentInsets(widget.cameraPadding);
  }

  Future<void> _syncVehicle({required bool follow}) async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;

    // Sem posição o source fica vazio: nenhum marcador fictício.
    await controller.setGeoJsonSource(
      vehicleSourceId,
      vehicleFeatureCollection(widget.position, stale: widget.stale),
    );
    if (follow) await _centerOnVehicle();
  }

  Future<void> _centerOnVehicle() async {
    final controller = _controller;
    final center = _vehicleCenter;
    if (controller == null || center == null) return;

    final zoom = controller.cameraPosition?.zoom ?? 0;
    final update = _zoomOnNextCenter && zoom < TransitMap.trackingZoom - 1
        ? CameraUpdate.newLatLngZoom(center, TransitMap.trackingZoom)
        : CameraUpdate.newLatLng(center);
    _zoomOnNextCenter = false;
    _follow.beginProgrammaticMove(_cameraDuration);
    await controller.animateCamera(update, duration: _cameraDuration);
  }

  void _recenter() {
    _follow.resume();
    _setFollowing(true);
    unawaited(_centerOnVehicle());
  }

  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  Widget _buildSurface(BuildContext context) {
    final params = MapSurfaceParams(
      initialCameraPosition: TransitMap.initialCamera,
      onMapCreated: _onMapCreated,
      onStyleLoaded: _onStyleLoaded,
      onCameraMove: (_) => _onCameraMovement(),
      onCameraIdle: () {},
    );
    final builder = widget.mapBuilder;
    if (builder != null) return builder(context, params);

    return MapLibreMap(
      styleString: MapConfig.styleUrl,
      initialCameraPosition: params.initialCameraPosition,
      minMaxZoomPreference: const MinMaxZoomPreference(9, 19),
      compassEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      trackCameraPosition: true,
      logoViewPosition: LogoViewPosition.topLeft,
      attributionButtonPosition: AttributionButtonPosition.bottomRight,
      onMapCreated: params.onMapCreated,
      onStyleLoadedCallback: params.onStyleLoaded,
      onCameraMove: params.onCameraMove,
      onCameraIdle: params.onCameraIdle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasVehicle = _vehicleCenter != null;
    final label = switch ((widget.vehicleNumber, hasVehicle)) {
      (final number?, true) =>
        'Mapa com a posição do ônibus $number informada pela fonte'
            '${widget.stale ? ', possivelmente desatualizada' : ''}',
      (final number?, false) =>
        'Mapa. Posição do ônibus $number ainda não disponível',
      _ => 'Mapa de Goiânia. Nenhum ônibus acompanhado',
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          label: label,
          container: true,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _onUserPointer(),
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) _onUserPointer();
            },
            child: _buildSurface(context),
          ),
        ),
        if (hasVehicle)
          Positioned(
            top: widget.controlsPadding.top,
            right: widget.controlsPadding.right,
            child: _RecenterButton(following: _following, onPressed: _recenter),
          ),
      ],
    );
  }
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.following, required this.onPressed});

  final bool following;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return Tooltip(
      message: 'Centralizar ônibus',
      child: Semantics(
        button: true,
        label: following
            ? 'Centralizar ônibus. Seguindo o ônibus'
            : 'Centralizar ônibus. Seguimento pausado',
        excludeSemantics: true,
        child: Material(
          color: following ? tokens.floatingSurface : scheme.primary,
          elevation: 3,
          shadowColor: tokens.shadow,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onPressed,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: following ? Space.sm : Space.md,
                  vertical: Space.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      following
                          ? Icons.gps_fixed_rounded
                          : Icons.center_focus_strong_rounded,
                      size: 20,
                      color: following ? scheme.primary : scheme.onPrimary,
                    ),
                    if (!following) ...[
                      const SizedBox(width: Space.xs),
                      Text(
                        'Centralizar ônibus',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
