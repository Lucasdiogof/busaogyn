import 'dart:async';
import 'dart:math' show Point;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/platform/map_attribution_offset.dart';
import '../../../../core/theme/busao_tokens.dart';
import '../../domain/entities/map_vehicle.dart';
import '../../domain/entities/tracked_vehicle.dart';
import 'camera_follow.dart';
import 'map_follow_controller.dart';
import '../../domain/models/observed_movement.dart';
import 'vehicle_map_data.dart';
import 'vehicle_marker_image.dart';
import 'vehicle_motion.dart';

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
    this.observedHeading,
    this.observedTrail = const [],
    required this.styleString,
    required this.fallbackStyleString,
    this.followController,
    this.styleLoadTimeout = const Duration(seconds: 12),
    this.cameraPadding = EdgeInsets.zero,
    this.controlsPadding = EdgeInsets.zero,
    this.attributionBottom = 0,
    this.showControls = true,
    this.secondaryVehicles = const [],
    this.onSecondaryTap,
    this.onMapTap,
    this.mapBuilder,
    super.key,
  });

  /// Ônibus acompanhado; `null` quando não há tracking.
  final String? vehicleNumber;

  /// Última coordenada recebida da API para [vehicleNumber].
  final GeoPosition? position;

  /// Posição antiga ou com falha recente: o marcador fica esmaecido.
  final bool stale;

  /// Direção observada do último deslocamento real do acompanhado (graus a
  /// partir do norte); `null` mantém o desenho com a frente para cima.
  final double? observedHeading;

  /// Posições reais recentes do acompanhado, desenhadas atrás dele.
  final List<GeoPosition> observedTrail;

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

  /// Outros ônibus em tempo real do ponto, com posição real. Nunca movem a
  /// câmera nem roubam o foco do ônibus acompanhado.
  final List<MapVehicle> secondaryVehicles;

  /// Toque num ônibus secundário (recebe o número do veículo).
  final ValueChanged<String>? onSecondaryTap;

  /// Toque no mapa fora de qualquer ônibus.
  final VoidCallback? onMapTap;
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

class _TransitMapState extends State<TransitMap>
    with SingleTickerProviderStateMixin {
  static const _cameraDuration = Duration(milliseconds: 700);
  static const _insetsDebounce = Duration(milliseconds: 150);

  /// Ônibus acompanhado maior que os demais; a frente gira conforme a
  /// direção observada.
  static const _trackedIconSize = 0.30;
  static const _secondaryIconSize = 0.20;

  /// Intervalo mínimo entre envios ao mapa durante a transição (~28 fps).
  static const _pushInterval = Duration(milliseconds: 36);

  final _follow = CameraFollow();
  final _motion = VehicleMotion();
  final _clock = Stopwatch()..start();
  late final Ticker _ticker;
  Duration _lastPush = Duration.zero;
  MapLibreMapController? _controller;
  bool _styleReady = false;

  /// Direção exibida do acompanhado e sua transição pelo menor arco.
  double? _shownHeading;
  double _headingFrom = 0;
  double? _headingTarget;
  Duration? _headingStart;

  /// Incrementado a cada carga de estilo; uma carga anterior que ainda
  /// estava esperando não adiciona sources/layers duplicados no estilo novo.
  int _styleLoad = 0;
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
      // Outro ônibus: a direção do anterior não vale para ele.
      _shownHeading = null;
      _headingTarget = null;
      _headingStart = null;
    }

    if (widget.observedHeading != oldWidget.observedHeading ||
        widget.vehicleNumber != oldWidget.vehicleNumber) {
      _setHeadingTarget(widget.observedHeading);
    }
    if (!identical(widget.observedTrail, oldWidget.observedTrail)) {
      unawaited(_pushTrail());
    }

    final positionChanged = vehiclePositionChanged(
      oldWidget.position,
      widget.position,
    );
    if (positionChanged ||
        widget.stale != oldWidget.stale ||
        widget.vehicleNumber != oldWidget.vehicleNumber ||
        !identical(widget.secondaryVehicles, oldWidget.secondaryVehicles)) {
      unawaited(_syncVehicle(follow: positionChanged && _follow.following));
      _report();
    }

    if (widget.cameraPadding != oldWidget.cameraPadding ||
        widget.attributionBottom != oldWidget.attributionBottom) {
      // Debounce: arrastar o sheet não gera uma chamada nativa por frame.
      _insetsTimer?.cancel();
      _insetsTimer = Timer(_insetsDebounce, () {
        unawaited(_applyInsetsAndRefollow());
        _applyAttribution();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
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
    _ticker.dispose();
    _controller?.onFeatureTapped.remove(_onFeatureTapped);
    _insetsTimer?.cancel();
    _styleWatchdog?.cancel();
    widget.followController?.attach(null);
    _controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    // Controller novo (mapa recriado): nada do estilo anterior existe nele.
    _controller?.removeListener(_onControllerChanged);
    _controller?.onFeatureTapped.remove(_onFeatureTapped);
    _controller = controller;
    controller.onFeatureTapped.add(_onFeatureTapped);
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

  /// Chamado a cada carga de estilo, inclusive após troca/recarga: imagens,
  /// sources e layers pertencem ao estilo e precisam ser recriados aqui.
  Future<void> _onStyleLoaded() async {
    _styleWatchdog?.cancel();
    final controller = _controller;
    if (controller == null) return;
    _styleReady = false;
    final load = ++_styleLoad;
    bool superseded() =>
        !mounted || !identical(controller, _controller) || load != _styleLoad;

    final tokens = context.tokens;
    final brightness = Theme.of(context).brightness;
    final images = <String, Uint8List>{};
    for (final variant in MarkerVariant.values) {
      images[busImageIds[variant]!] = await renderBusMarker(
        busMarkerStyle(variant, tokens: tokens, brightness: brightness),
      );
    }
    if (superseded()) return;

    for (final entry in images.entries) {
      await controller.addImage(entry.key, entry.value);
    }
    if (superseded()) return;

    // Rastro observado no fundo, depois os secundários; o acompanhado (halo +
    // ônibus) sempre por cima.
    await controller.addGeoJsonSource(
      observedTrailSourceId,
      observedTrailFeatureCollection(widget.observedTrail),
    );
    await controller.addLineLayer(
      observedTrailSourceId,
      observedTrailLayerId,
      LineLayerProperties(
        lineColor: _hex(_trailColor(tokens, brightness)),
        lineWidth: 3,
        lineOpacity: brightness == Brightness.dark ? 0.45 : 0.5,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      enableInteraction: false,
    );
    if (superseded()) return;

    await controller.addGeoJsonSource(
      secondarySourceId,
      secondaryFeatureCollection(
        widget.secondaryVehicles,
        (number) => _motion.shown(_secondaryKey(number)),
      ),
      promoteId: 'vehicleNumber',
    );
    await controller.addSymbolLayer(
      secondarySourceId,
      secondaryLayerId,
      SymbolLayerProperties(
        iconImage: _variantImageExpression,
        iconSize: _secondaryIconSize,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconOpacity: const [
          'case',
          ['get', 'stale'],
          0.7,
          0.92,
        ],
      ),
    );

    await controller.addGeoJsonSource(
      vehicleSourceId,
      vehicleFeatureCollection(
        _motion.shown(_trackedKey),
        stale: widget.stale,
        heading: _shownHeading,
      ),
    );
    await controller.addCircleLayer(
      vehicleSourceId,
      vehicleHaloLayerId,
      CircleLayerProperties(
        circleRadius: 34,
        circleColor: _hex(tokens.accent),
        circleOpacity: const [
          'case',
          ['get', 'stale'],
          0.05,
          0.16,
        ],
        circleStrokeColor: _hex(tokens.accent),
        circleStrokeWidth: 1.5,
        circleStrokeOpacity: const [
          'case',
          ['get', 'stale'],
          0.25,
          0.55,
        ],
      ),
      enableInteraction: false,
    );
    await controller.addSymbolLayer(
      vehicleSourceId,
      vehicleLayerId,
      SymbolLayerProperties(
        iconImage: _variantImageExpression,
        iconSize: _trackedIconSize,
        // Frente do desenho = topo da imagem = norte; gira pela direção
        // observada, alinhado ao mapa.
        iconRotate: const ['get', 'heading'],
        iconRotationAlignment: 'map',
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconOpacity: const [
          'case',
          ['get', 'stale'],
          0.75,
          1.0,
        ],
      ),
      enableInteraction: false,
    );
    if (superseded()) return;
    _styleReady = true;
    await _applyInsets();
    // As posições podem ter mudado enquanto o estilo carregava.
    await _syncVehicle(follow: _follow.following);
  }

  static final _variantImageExpression = [
    'match',
    ['get', 'variant'],
    MarkerVariant.stale.name,
    busImageIds[MarkerVariant.stale]!,
    MarkerVariant.tracked.name,
    busImageIds[MarkerVariant.tracked]!,
    busImageIds[MarkerVariant.secondary]!,
  ];

  String? get _trackedNumber => widget.vehicleNumber;
  String get _trackedKey => 'T:${widget.vehicleNumber}';
  static String _secondaryKey(String number) => 'S:$number';

  /// Novos insets (painel mudou de altura): no Web isso corta a animação de
  /// câmera em curso; seguindo o ônibus, recentraliza no espaço visível.
  Future<void> _applyInsetsAndRefollow() async {
    await _applyInsets();
    if (!mounted || !_styleReady) return;
    if (_follow.following && _vehicleCenter != null) await _centerOnVehicle();
  }

  Future<void> _applyInsets() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    _follow.beginProgrammaticMove(Duration.zero);
    await controller.updateContentInsets(widget.cameraPadding);
  }

  /// Registra as últimas posições reais; a transição A → B é visual e só
  /// acontece entre duas coordenadas recebidas.
  void _applyTargets() {
    final now = _clock.elapsed;
    _motion.retainOnly({
      if (_trackedNumber != null) _trackedKey,
      for (final vehicle in widget.secondaryVehicles)
        _secondaryKey(vehicle.vehicleNumber),
    });
    if (_trackedNumber != null) {
      _motion.setTarget(_trackedKey, widget.position, now);
    }
    for (final vehicle in widget.secondaryVehicles) {
      _motion.setTarget(
        _secondaryKey(vehicle.vehicleNumber),
        vehicle.position,
        now,
      );
    }
    if (_motion.animating && !_ticker.isActive) _ticker.start();
  }

  Future<void> _syncVehicle({required bool follow}) async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;

    _applyTargets();
    // Sem posição o source fica vazio: nenhum marcador fictício.
    await _pushVehicles(tracked: true, secondary: true);
    if (follow) await _centerOnVehicle();
  }

  Future<void> _pushVehicles({
    required bool tracked,
    required bool secondary,
  }) async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;
    _lastPush = _clock.elapsed;
    if (tracked) {
      await controller.setGeoJsonSource(
        vehicleSourceId,
        vehicleFeatureCollection(
          _motion.shown(_trackedKey),
          stale: widget.stale,
          heading: _shownHeading,
        ),
      );
    }
    if (secondary) {
      await controller.setGeoJsonSource(
        secondarySourceId,
        secondaryFeatureCollection(
          widget.secondaryVehicles,
          (number) => _motion.shown(_secondaryKey(number)),
        ),
      );
    }
  }

  /// Nova direção observada: gira do ângulo exibido até ela pelo menor
  /// arco, no mesmo tempo da transição de posição.
  void _setHeadingTarget(double? target) {
    if (target == null) {
      _shownHeading = null;
      _headingTarget = null;
      _headingStart = null;
      return;
    }
    if (_headingTarget == target) return;
    _headingFrom = _shownHeading ?? 0;
    _headingTarget = target;
    _headingStart = _clock.elapsed;
    if (!_ticker.isActive) _ticker.start();
  }

  /// Avança a rotação; `true` enquanto ainda gira.
  bool _tickHeading(Duration now) {
    final start = _headingStart;
    final target = _headingTarget;
    if (start == null || target == null) return false;
    final t =
        (now - start).inMicroseconds / markerTransitionDuration.inMicroseconds;
    _shownHeading = interpolateAngle(_headingFrom, target, t);
    if (t >= 1) {
      _shownHeading = target;
      _headingStart = null;
      return false;
    }
    return true;
  }

  Future<void> _pushTrail() async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;
    await controller.setGeoJsonSource(
      observedTrailSourceId,
      observedTrailFeatureCollection(widget.observedTrail),
    );
  }

  static Color _trailColor(BusaoTokens tokens, Brightness brightness) =>
      brightness == Brightness.dark
      ? tokens.accent
      : Color.lerp(tokens.accent, tokens.accentText, 0.35)!;

  void _onTick(Duration _) {
    final now = _clock.elapsed;
    final animatingBefore = _motion.animatingIds.toList();
    final headingBefore = _headingStart != null;
    final headingAnimating = _tickHeading(now);
    final stillAnimating = _motion.tick(now) || headingAnimating;
    if (!stillAnimating) _ticker.stop();
    // Durante a transição limita o ritmo; o quadro final (exatamente em B)
    // sempre é enviado.
    if (stillAnimating && now - _lastPush < _pushInterval) return;
    unawaited(
      _pushVehicles(
        tracked: animatingBefore.contains(_trackedKey) || headingBefore,
        secondary: animatingBefore.any((id) => id.startsWith('S:')),
      ),
    );
  }

  void _onFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId == secondaryLayerId) widget.onSecondaryTap?.call(id);
  }

  Future<void> _centerOnVehicle() async {
    final controller = _controller;
    final center = _vehicleCenter;
    if (controller == null || center == null) return;

    final zoom = controller.cameraPosition?.zoom ?? 0;
    final needsZoom = _zoomOnNextCenter && zoom < TransitMap.trackingZoom - 1;
    final update = needsZoom
        ? CameraUpdate.newLatLngZoom(center, TransitMap.trackingZoom)
        : CameraUpdate.newLatLng(center);
    // Só deixa de aproximar quando o zoom já chegou: uma animação cortada
    // (por exemplo, por insets do painel mudando) aproxima de novo.
    if (!needsZoom) _zoomOnNextCenter = false;
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
      onMapClick: (_, _) => widget.onMapTap?.call(),
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
    final others = widget.secondaryVehicles.length;
    final fullLabel = others == 0
        ? label
        : '$label. ${others == 1 ? 'Mais 1 ônibus' : 'Mais $others ônibus'} '
              'em tempo real a caminho do ponto';

    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          label: fullLabel,
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
