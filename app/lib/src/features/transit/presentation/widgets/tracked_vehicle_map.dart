import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/platform/map_attribution_offset.dart';
import '../../../../core/theme/busao_tokens.dart';
import '../../domain/entities/tracked_vehicle.dart';
import 'camera_follow.dart';
import 'map_follow_controller.dart';
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
    required this.styleString,
    required this.fallbackStyleString,
    this.followController,
    this.styleLoadTimeout = const Duration(seconds: 12),
    this.cameraPadding = EdgeInsets.zero,
    this.controlsPadding = EdgeInsets.zero,
    this.attributionBottom = 0,
    this.showControls = true,
    this.mapBuilder,
    super.key,
  });

  /// Ônibus acompanhado; `null` quando não há tracking.
  final String? vehicleNumber;

  /// Última coordenada recebida da API para [vehicleNumber].
  final GeoPosition? position;

  /// Posição antiga ou com falha recente: o marcador fica esmaecido.
  final bool stale;

  /// Estilo do tema atual (URL ou asset). Trocar recarrega o estilo; o
  /// marcador é recriado em `onStyleLoaded`.
  final String styleString;

  /// Usado quando [styleString] não termina de carregar em
  /// [styleLoadTimeout] (por exemplo, o Liberty noturno empacotado).
  final String fallbackStyleString;
  final Duration styleLoadTimeout;

  /// Expõe o follow para o botão "Centralizar" do painel.
  final MapFollowController? followController;

  /// Área coberta por painéis; a câmera centraliza no espaço visível.
  final EdgeInsets cameraPadding;

  /// Onde ficam os controles flutuantes do mapa.
  final EdgeInsets controlsPadding;

  /// Altura coberta por painéis na base do mapa; o controle nativo de
  /// atribuição do MapLibre fica logo acima dela.
  final double attributionBottom;

  /// Falso quando não há espaço de mapa visível para os controles.
  final bool showControls;
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
  double _attributionBottom = 0;

  /// Estilos que não carregaram nesta sessão; caem no [fallbackStyleString].
  final _failedStyles = <String>{};
  Timer? _styleWatchdog;

  String get _activeStyle => _failedStyles.contains(widget.styleString)
      ? widget.fallbackStyleString
      : widget.styleString;

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

    if (widget.followController != oldWidget.followController) {
      oldWidget.followController?.attach(null);
      widget.followController?.attach(_recenter);
      _report();
    }

    if (widget.styleString != oldWidget.styleString) {
      // O estilo novo apaga imagem, source e layers do ônibus; nada é
      // sincronizado até o próximo onStyleLoaded.
      _styleReady = false;
      _armStyleWatchdog();
    }

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
      _report();
    }

    if (widget.cameraPadding != oldWidget.cameraPadding ||
        widget.attributionBottom != oldWidget.attributionBottom) {
      // Debounce: arrastar o sheet não gera uma chamada nativa por frame.
      _insetsTimer?.cancel();
      _insetsTimer = Timer(_insetsDebounce, () {
        unawaited(_applyInsets());
        _applyAttribution();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _attributionBottom = widget.attributionBottom;
    setWebMapAttributionOffset(_attributionBottom);
    widget.followController?.attach(_recenter);
    _armStyleWatchdog();
  }

  /// Só o mapa real carrega estilo; a superfície de teste não.
  void _armStyleWatchdog() {
    _styleWatchdog?.cancel();
    if (widget.mapBuilder != null) return;
    final style = _activeStyle;
    if (style == widget.fallbackStyleString) return;
    _styleWatchdog = Timer(widget.styleLoadTimeout, () {
      if (!mounted || _activeStyle != style) return;
      debugPrint('BusãoGyn: estilo "$style" não carregou; usando o padrão.');
      setState(() => _failedStyles.add(style));
    });
  }

  void _report() {
    widget.followController?.report(
      following: _following,
      hasVehicle: _vehicleCenter != null,
    );
  }

  void _applyAttribution() {
    if (!mounted || _attributionBottom == widget.attributionBottom) return;
    setState(() => _attributionBottom = widget.attributionBottom);
    setWebMapAttributionOffset(_attributionBottom);
  }

  @override
  void dispose() {
    _insetsTimer?.cancel();
    _styleWatchdog?.cancel();
    widget.followController?.attach(null);
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
    _report();
  }

  /// Chamado a cada carga de estilo, inclusive após troca/recarga: imagem,
  /// source e layers pertencem ao estilo e precisam ser recriados aqui.
  Future<void> _onStyleLoaded() async {
    _styleWatchdog?.cancel();
    final controller = _controller;
    if (controller == null) return;
    _styleReady = false;

    final tokens = context.tokens;
    final marker = await renderVehicleMarker(
      background: tokens.accent,
      foreground: tokens.onAccent,
      ring: Colors.white,
      shadow: Colors.black.withValues(alpha: 0.45),
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
        circleRadius: 26,
        circleColor: _hex(tokens.accent),
        circleOpacity: const [
          'case',
          ['get', 'stale'],
          0.06,
          0.16,
        ],
        circleStrokeColor: _hex(tokens.accent),
        circleStrokeWidth: 1.5,
        circleStrokeOpacity: 0.55,
      ),
      enableInteraction: false,
    );
    await controller.addSymbolLayer(
      vehicleSourceId,
      vehicleLayerId,
      const SymbolLayerProperties(
        iconImage: vehicleImageId,
        iconSize: 0.46,
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
      styleString: _activeStyle,
      initialCameraPosition: params.initialCameraPosition,
      minMaxZoomPreference: const MinMaxZoomPreference(9, 19),
      compassEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      trackCameraPosition: true,
      logoViewPosition: LogoViewPosition.topLeft,
      attributionButtonPosition: AttributionButtonPosition.bottomRight,
      attributionButtonMargins: Point(Space.xs, _attributionBottom + Space.xs),
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
        if (hasVehicle && widget.showControls)
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
    final tokens = context.tokens;
    // Seguindo: discreto. Pausado: âmbar e com rótulo, para o usuário saber
    // como voltar.
    final background = following ? tokens.glass : tokens.accent;
    final foreground = following ? tokens.accentText : tokens.onAccent;

    return Tooltip(
      message: 'Centralizar ônibus',
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: following
            ? 'Centralizar ônibus. Seguindo o ônibus'
            : 'Centralizar ônibus. Seguimento pausado',
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(Radii.field),
            border: Border.all(
              color: following ? tokens.glassBorder : tokens.accent,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.shadow,
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.field),
              onTap: onPressed,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: SizedBox(
                  height: 48,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: following ? Space.sm : Space.md,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          size: 22,
                          color: foreground,
                        ),
                        if (!following) ...[
                          const SizedBox(width: Space.xs),
                          Text(
                            'Centralizar',
                            style: TextStyle(
                              color: foreground,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
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
        ),
      ),
    );
  }
}
