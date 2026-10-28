import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/map_config.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
import '../../../catalog/domain/network_geojson.dart';
import '../../../catalog/domain/route_geometry.dart';
import '../../../catalog/domain/route_match.dart';
import '../../../catalog/domain/transit_catalog.dart';
import '../../../catalog/presentation/catalog_access.dart';
import '../../../catalog/presentation/catalog_widgets.dart';
import '../../../saved_stops/domain/saved_stop.dart';
import '../../../saved_stops/presentation/cubit/saved_stops_cubit.dart';
import '../../../saved_stops/presentation/widgets/saved_stops_widgets.dart';
import '../../domain/entities/map_vehicle.dart';
import '../../domain/entities/tracked_vehicle.dart';
import '../cubit/map_vehicles_cubit.dart';
import '../cubit/stop_arrivals_cubit.dart';
import '../formatters/transit_labels.dart';
import '../widgets/arrivals_panel.dart';
import '../widgets/home_chrome.dart';
import '../widgets/map_follow_controller.dart';
import '../widgets/search_header.dart';
import '../widgets/secondary_vehicle_callout.dart';
import '../widgets/settings_panel.dart';
import '../widgets/tracked_vehicle_map.dart';
import '../widgets/tracking_card.dart';

/// Home map-first: o mapa ocupa a tela inteira e tudo flutua sobre ele —
/// marca e status no topo, cartão de contexto, painel (bottom sheet no
/// celular, coluna central em telas largas) e o dock com Linhas, Pontos,
/// Favoritos e Meu ônibus, com Ajustes na TopBar.
class StopArrivalsPage extends StatefulWidget {
  const StopArrivalsPage({this.mapBuilder, this.clock, super.key});

  final VehicleMapBuilder? mapBuilder;
  final DateTime Function()? clock;

  @override
  State<StopArrivalsPage> createState() => _StopArrivalsPageState();
}

/// Posições dos elementos flutuantes para um tamanho de tela.
class _Geometry {
  _Geometry(MediaQueryData media, {int dockItems = 3})
    : size = media.size,
      safe = media.padding,
      wide = media.size.width >= Breakpoints.panel {
    final columnWidth = wide
        ? math.min(Chrome.column, size.width - Chrome.gutter * 2)
        : size.width - Chrome.gutter * 2;
    left = wide ? (size.width - columnWidth) / 2 : Chrome.gutter;
    width = columnWidth;
    top = safe.top + Space.sm;
    headerHeight = Chrome.headerHeight(media.textScaler);
    dockLayout = Chrome.dockLayout(
      columnWidth,
      media.textScaler,
      items: dockItems,
    );
    headerTop = top + Chrome.pill + 10;
    headerBottom = headerTop + headerHeight;
    dockBottom = math.max(safe.bottom, Space.xs) + Space.xs;
    dockTop = size.height - dockBottom - dockLayout.height;
    panelBottom = size.height - dockTop + Space.xs;
  }

  /// Faixa de mapa que sempre sobra sob o cabeçalho com o painel aberto.
  static const mapBand = 56.0;

  final Size size;
  final EdgeInsets safe;
  final bool wide;
  late final double left;
  late final double width;
  late final double top;
  late final double headerHeight;
  late final ({int labelLines, double height}) dockLayout;
  late final double headerTop;
  late final double headerBottom;
  late final double dockBottom;
  late final double dockTop;

  /// Distância da base da tela até a base do painel (acima do dock).
  late final double panelBottom;

  /// Topo máximo do painel.
  double get panelTop => headerBottom + mapBand;

  /// Altura disponível para o painel.
  double get panelArea => size.height - panelBottom - panelTop;
}

class _StopArrivalsPageState extends State<StopArrivalsPage>
    with WidgetsBindingObserver {
  static const _sheetMid = 0.56;
  static const _sheetMax = 1.0;
  static const _sheetMinPixels = 132.0;

  final _stopController = TextEditingController();
  final _searchFocus = FocusNode();
  final _sheetController = DraggableScrollableController();
  final _sheetExtent = ValueNotifier<double>(_sheetMid);

  /// Altura real do painel em telas largas (para a câmera e a atribuição).
  final _panelHeight = ValueNotifier<double>(0);
  final _follow = MapFollowController();

  /// Pontos (ou Chegadas, no dock atual) é o destino inicial.
  HomeTab _tab = HomeTab.stop;

  /// Destino a que Ajustes volta (navegação v2, onde abre pela TopBar).
  HomeTab _tabBeforeSettings = HomeTab.stop;

  /// Ônibus secundário tocado no mapa (mostra o callout).
  String? _selectedSecondary;

  /// Detalhes do ônibus acompanhado abertos no painel Meu ônibus.
  bool _vehicleDetails = false;

  /// Campo de busca aberto por cima de um ponto já exibido.
  bool _searching = false;

  /// Código enviado na última busca, para fechar o campo quando ela der
  /// certo.
  String? _pendingSearch;

  /// Código da última busca ainda sem resultado, para registrar nos recentes
  /// só quando ela der certo (v2).
  String? _pendingRecord;

  /// Catálogo oficial ligado (só em desenvolvimento); `null` = como antes.
  TransitCatalog? get _catalog => context.catalog;

  /// Ponto escolhido no catálogo, com detalhes à vista (antes das chegadas).
  String? _previewStop;

  /// Último texto enviado como busca de chegadas; enquanto o campo mostra
  /// esse mesmo texto, o painel mostra o resultado da consulta, não a lista
  /// do catálogo.
  String? _submittedQuery;

  /// Aba Linhas com catálogo: busca e linha aberta.
  final _linesQuery = TextEditingController();
  String? _openLine;

  /// Rede no mapa (só com catálogo): coleções reaproveitadas entre builds.
  NetworkOverlayBuilder? _networkBuilder;
  NetworkOverlayBuilder? get _network {
    final catalog = _catalog;
    if (catalog == null) return null;
    final builder = _networkBuilder;
    if (builder != null && identical(builder.catalog, catalog)) return builder;
    return _networkBuilder = NetworkOverlayBuilder(catalog);
  }

  /// Trajeto oficial mostrado no mapa (linha + Placemark).
  String? _routeLine;
  String? _routeShape;

  /// Último pedido de câmera (ponto ou trajeto); o serial distingue pedidos.
  MapFocus? _focus;
  int _focusSerial = 0;

  /// Leva o mapa ao ponto do catálogo, se ele tiver coordenada.
  void _focusOnStop(String code) {
    final stop = _catalog?.stop(code);
    final position = stop == null ? null : stopPosition(stop);
    if (position == null) return;
    setState(() => _focus = MapFocus.point(++_focusSerial, position));
  }

  /// Mostra um trajeto oficial no mapa e enquadra a geometria.
  Future<void> _showRoute(String shapeId) async {
    final catalog = _catalog;
    if (catalog == null) return;
    final shape = catalog.shapes.where((s) => s.id == shapeId).firstOrNull;
    if (shape == null) return;
    setState(() {
      _routeLine = shape.lineId;
      _routeShape = shape.id;
    });
    // Painel aberto por cima do mapa: baixa antes de enquadrar, senão o
    // trajeto caberia numa faixa mínima.
    if (_sheetExtent.value > _sheetMid + 0.01 && _sheetController.isAttached) {
      await _sheetController.animateTo(
        _sheetMid,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    // O painel muda de altura com o trajeto; enquadra com a margem nova.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _routeShape != shape.id) return;
    setState(
      () =>
          _focus = MapFocus.bounds(++_focusSerial, GeoBounds.of(shape.points)),
    );
  }

  /// Volta ao mapa normal (sem trajeto).
  void _clearRoute() => setState(() {
    _routeLine = null;
    _routeShape = null;
  });

  /// Abre (ou fecha) o detalhe de uma linha; ao abrir, mostra o trajeto da
  /// variante principal (ida, se houver).
  void _openLineDetail(String? lineId) {
    setState(() => _openLine = lineId);
    final catalog = _catalog;
    if (lineId == null || catalog == null) {
      _clearRoute();
      return;
    }
    final shapes = catalog.shapesOf(lineId);
    if (shapes.isEmpty) {
      _clearRoute();
      return;
    }
    final principal = catalog
        .variantsOf(lineId)
        .where((v) => v.characteristic == 'Principal')
        .map((v) => v.id)
        .toSet();
    final ordered = [...shapes]
      ..sort((a, b) {
        final pa = principal.contains(a.variantId) ? 0 : 1;
        final pb = principal.contains(b.variantId) ? 0 : 1;
        if (pa != pb) return pa - pb;
        final va = a.variantId.compareTo(b.variantId);
        if (va != 0) return va;
        return (a.direction ?? 'z').compareTo(b.direction ?? 'z');
      });
    unawaited(_showRoute(ordered.first.id));
  }

  /// Associação experimental do ônibus acompanhado a um trajeto oficial.
  RouteMatch? _routeMatch(StopArrivalsState state) {
    final catalog = _catalog;
    if (catalog == null || state is! StopArrivalsLoaded) return null;
    final tracking = state.tracking;
    if (tracking == null) return null;
    final snapshot = tracking.vehicle;
    final vehicle = snapshot?.data;
    // Posição antiga ou com falha não vale como atual: nada é desenhado.
    final outdated =
        (snapshot?.stale ?? false) || tracking.phase != TrackingPhase.active;
    return matchTrackedRoute(
      catalog: catalog,
      routeId: vehicle?.routeId,
      routeName: vehicle?.routeName,
      destination: vehicle?.destination,
      position: outdated ? null : vehicle?.position,
      trail: tracking.movement.observedTrail,
    );
  }

  DateTime Function() get _clock => widget.clock ?? DateTime.now;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Chegadas só se atualizam sozinhas com a aba delas à vista.
    context.read<StopArrivalsCubit>().setArrivalsVisible(_tab == HomeTab.stop);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final cubit = context.read<StopArrivalsCubit>();
    final vehicles = context.read<MapVehiclesCubit>();

    switch (state) {
      case AppLifecycleState.resumed:
        cubit.resume();
        vehicles.resume();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        cubit.pause();
        vehicles.pause();
        return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopController.dispose();
    _linesQuery.dispose();
    _searchFocus.dispose();
    _sheetController.dispose();
    _sheetExtent.dispose();
    _panelHeight.dispose();
    _follow.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    final text = _stopController.text.trim();
    // Com catálogo, texto (rua, bairro…) é busca local: a lista já está no
    // painel e nada vai para a API.
    if (_catalog != null && !RegExp(r'^\d+$').hasMatch(text)) return;
    _submittedQuery = text;
    final cubit = context.read<StopArrivalsCubit>();
    // Com um ponto na tela, a busca só fecha quando der certo (ver
    // _onStateChanged); se falhar, o campo continua com o aviso.
    _pendingSearch = _stopController.text.trim();
    _pendingRecord = _pendingSearch;
    if (cubit.state is! StopArrivalsLoaded) {
      setState(() => _searching = false);
    }
    cubit.load(_stopController.text);
  }

  /// Favorito ou recente tocado: abre Pontos e consulta o código. Se a mesma
  /// consulta já está em andamento, só mostra Pontos (nada de consulta em
  /// duplicidade); a geração do cubit descarta respostas de buscas antigas.
  void _openStop(String code) {
    if (_previewStop != null) setState(() => _previewStop = null);
    _focusOnStop(code);
    final state = context.read<StopArrivalsCubit>().state;
    final inFlight =
        (state is StopArrivalsLoading && state.stopId == code) ||
        (state is StopArrivalsLoaded && state.searchingStopId == code);
    _select(HomeTab.stop);
    if (inFlight) return;
    _stopController.text = code;
    _search();
  }

  Future<void> _toggleFavorite(String code) async {
    final result = await context.read<SavedStopsCubit>().toggleFavorite(code);
    if (!mounted || result != FavoriteResult.limitReached) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.favoriteStopsLimit(defaultFavoriteStopsLimit)),
        ),
      );
  }

  /// Aviso para as listas quando a última consulta falhou por conexão ou
  /// pela fonte.
  String? _connectionNotice(StopArrivalsState state) {
    final feedback = switch (state) {
      StopArrivalsInitial(:final searchError) => searchError,
      StopArrivalsLoaded(:final searchError) => searchError,
      _ => null,
    };
    if (feedback == null || !feedback.isConnectivity) return null;
    return feedback.kind == SearchFeedbackKind.offline
        ? l10n.noticeOffline
        : l10n.noticeQueryIncomplete;
  }

  void _recordIfSucceeded(StopArrivalsState state) {
    final pending = _pendingRecord;
    if (pending == null) return;
    final failed = switch (state) {
      StopArrivalsInitial(:final searchError) => searchError != null,
      StopArrivalsLoaded() =>
        state.searchError != null ||
            (state.stopId == pending && state.refreshError != null),
      StopArrivalsLoading() => false,
    };
    if (failed) {
      _pendingRecord = null;
      return;
    }
    if (state is StopArrivalsLoaded &&
        state.stopId == pending &&
        state.searchingStopId == null &&
        !state.refreshing &&
        state.refreshError == null) {
      _pendingRecord = null;
      unawaited(context.read<SavedStopsCubit>().recordQuery(pending));
    }
  }

  /// Mostra os detalhes de um ponto do catálogo (offline), sem consultar a API.
  void _openPreview(String code) {
    FocusScope.of(context).unfocus();
    setState(() => _previewStop = code);
    _select(HomeTab.stop);
    _focusOnStop(code);
  }

  /// Fecha os detalhes e volta à busca, com o texto que estava no campo.
  void _closePreview() {
    setState(() {
      _previewStop = null;
      if (context.read<StopArrivalsCubit>().state is StopArrivalsLoaded) {
        _searching = true;
      }
    });
  }

  void _searchExample(String stopId) {
    _stopController.text = stopId;
    _search();
  }

  void _openSearch() {
    _stopController.clear();
    setState(() => _searching = true);
    _searchFocus.requestFocus();
  }

  void _cancelSearch() {
    FocusScope.of(context).unfocus();
    context.read<StopArrivalsCubit>().clearSearchError();
    _pendingSearch = null;
    setState(() => _searching = false);
  }

  void _track(String vehicleNumber) {
    final cubit = context.read<StopArrivalsCubit>();
    final current = cubit.state;
    // Outro ônibus: a ficha começa compacta.
    if (current is! StopArrivalsLoaded ||
        current.tracking?.vehicleNumber != vehicleNumber) {
      setState(() => _vehicleDetails = false);
    }
    cubit.track(vehicleNumber);
    _select(HomeTab.tracking);
  }

  /// Toque no próprio ônibus acompanhado: abre a ficha dele.
  void _showTrackedDetails() {
    setState(() {
      _selectedSecondary = null;
      _vehicleDetails = true;
    });
    _select(HomeTab.tracking);
  }

  void _trackSecondary(String vehicleNumber) {
    setState(() => _selectedSecondary = null);
    _track(vehicleNumber);
  }

  void _stopTracking() {
    context.read<StopArrivalsCubit>().stopTracking();
    _select(HomeTab.stop);
  }

  /// Ajustes pela TopBar (v2): abre e, tocando de novo, volta ao destino em
  /// que o usuário estava.
  void _toggleSettings() {
    _select(_tab == HomeTab.settings ? _tabBeforeSettings : HomeTab.settings);
  }

  /// Fecha Ajustes: volta ao destino anterior.
  void _closeSettings() => _select(_tabBeforeSettings);

  /// Linhas e Favoritos sem dados: leva à busca de pontos, que é o que
  /// funciona hoje. Sem ponto na tela, o campo de código já recebe o foco.
  void _goToStopSearch() {
    _select(HomeTab.stop);
    if (context.read<StopArrivalsCubit>().state is! StopArrivalsLoaded) {
      _searchFocus.requestFocus();
    }
  }

  void _select(HomeTab tab) {
    if (tab == HomeTab.settings && _tab != HomeTab.settings) {
      _tabBeforeSettings = _tab;
    }
    if (tab != HomeTab.stop) FocusScope.of(context).unfocus();
    if (_tab != tab) setState(() => _tab = tab);
    context.read<StopArrivalsCubit>().setArrivalsVisible(tab == HomeTab.stop);
    if (_sheetExtent.value < _sheetMid - 0.01) _animateSheet(_sheetMid);
  }

  void _animateSheet(double size) {
    if (!_sheetController.isAttached) return;
    unawaited(
      _sheetController.animateTo(
        size,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  /// Entrega ao coordenador de ônibus do mapa o que as chegadas já sabem.
  void _syncMapVehicles(StopArrivalsState state) {
    final vehicles = context.read<MapVehiclesCubit>();
    switch (state) {
      case StopArrivalsLoaded():
        final tracking = state.tracking;
        final snapshot = tracking?.vehicle;
        vehicles.sync(
          stopId: state.stopId,
          groups: state.arrivals.data,
          trackedVehicleNumber: tracking?.vehicleNumber,
          trackedVehicle: snapshot?.data,
          trackedAgeSeconds: snapshot?.ageSeconds ?? 0,
          trackedStale:
              (snapshot?.stale ?? false) ||
              (tracking != null && tracking.phase != TrackingPhase.active),
        );
      case StopArrivalsLoading(:final stopId):
        vehicles.sync(stopId: stopId, groups: const []);
      case StopArrivalsInitial():
        vehicles.sync(stopId: null, groups: const []);
    }
  }

  void _onStateChanged(BuildContext context, StopArrivalsState state) {
    _syncMapVehicles(state);
    _recordIfSucceeded(state);
    if (state is StopArrivalsLoaded &&
        state.searchingStopId == null &&
        state.searchError == null &&
        state.stopId == _pendingSearch) {
      _pendingSearch = null;
      if (_searching) setState(() => _searching = false);
    }
    if (_selectedSecondary != null &&
        (state is! StopArrivalsLoaded ||
            state.tracking?.vehicleNumber == _selectedSecondary)) {
      setState(() => _selectedSecondary = null);
    }
    // Resultado novo de ponto: mostra as chegadas.
    if (state is StopArrivalsLoaded &&
        state.tracking == null &&
        _tab == HomeTab.stop &&
        _sheetExtent.value < _sheetMid - 0.01) {
      _animateSheet(_sheetMid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final geometry = _Geometry(MediaQuery.of(context), dockItems: 4);
    final styles = MapConfig.styles;
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: BlocListener<StopArrivalsCubit, StopArrivalsState>(
        listener: _onStateChanged,
        child: Stack(
          children: [
            // Índice 0 fixo em ambos os layouts: o mapa nunca é recriado por
            // estado do Cubit, por aba, por arrastar o sheet, por tema ou por
            // redimensionar.
            Positioned.fill(
              child: ListenableBuilder(
                listenable: Listenable.merge([_sheetExtent, _panelHeight]),
                builder: (context, _) => _MapBinding(
                  mapBuilder: widget.mapBuilder,
                  styleString: styles.forBrightness(brightness),
                  fallbackStyleString: styles.fallback,
                  followController: _follow,
                  layout: _mapLayout(geometry),
                  onSecondaryTap: (number) =>
                      setState(() => _selectedSecondary = number),
                  onTrackedTap: _showTrackedDetails,
                  onMapTap: () {
                    if (_selectedSecondary != null) {
                      setState(() => _selectedSecondary = null);
                    }
                  },
                  network: _network,
                  previewStopId: _previewStop,
                  routeLineId: _routeLine,
                  routeShapeId: _routeShape,
                  focus: _focus,
                  onStopTap: _openPreview,
                ),
              ),
            ),
            if (geometry.wide)
              Positioned(
                key: const ValueKey('column-panel'),
                left: geometry.left,
                width: geometry.width,
                bottom: geometry.panelBottom,
                // Com trajeto no mapa, o painel fica na metade de baixo.
                top: _routeLine == null
                    ? geometry.panelTop
                    : math.max(geometry.panelTop, geometry.size.height * 0.5),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _SizeReporter(
                    onHeight: (height) => _panelHeight.value = height,
                    child: _ColumnPanel(child: _panelContent()),
                  ),
                ),
              )
            else
              Positioned(
                key: const ValueKey('sheet'),
                left: geometry.left,
                width: geometry.width,
                top: geometry.panelTop,
                bottom: geometry.panelBottom,
                child: NotificationListener<DraggableScrollableNotification>(
                  onNotification: (notification) {
                    _sheetExtent.value = notification.extent;
                    return false;
                  },
                  child: DraggableScrollableSheet(
                    controller: _sheetController,
                    initialChildSize: _sheetMid,
                    minChildSize: _sheetMinFor(geometry),
                    maxChildSize: _sheetMax,
                    snap: true,
                    snapSizes: const [_sheetMid],
                    builder: (context, scroll) => _SheetSurface(
                      scrollController: scroll,
                      child: _panelContent(),
                    ),
                  ),
                ),
              ),
            Positioned(
              key: const ValueKey('top-bar'),
              left: geometry.left,
              width: geometry.width,
              top: geometry.top,
              child: BlocBuilder<StopArrivalsCubit, StopArrivalsState>(
                builder: (context, state) => PeriodicRebuild(
                  builder: (context) => TopBar(
                    status: liveStatus(state, _clock()),
                    onSettings: _toggleSettings,
                    settingsSelected: _tab == HomeTab.settings,
                  ),
                ),
              ),
            ),
            Positioned(
              key: const ValueKey('header'),
              left: geometry.left,
              width: geometry.width,
              top: geometry.headerTop,
              child: _header(),
            ),
            Positioned(
              key: const ValueKey('secondary-callout'),
              left: geometry.left,
              width: geometry.width,
              top: geometry.headerBottom + Space.xs,
              child: BlocBuilder<MapVehiclesCubit, MapVehiclesState>(
                builder: (context, state) {
                  final number = _selectedSecondary;
                  final vehicle = number == null
                      ? null
                      : state.byNumber(number);
                  if (vehicle == null) return const SizedBox.shrink();
                  return SecondaryVehicleCallout(
                    vehicle: vehicle,
                    onTrack: () => _trackSecondary(vehicle.vehicleNumber),
                    onClose: () => setState(() => _selectedSecondary = null),
                  );
                },
              ),
            ),
            Positioned(
              key: const ValueKey('dock'),
              left: geometry.left,
              width: geometry.width,
              bottom: geometry.dockBottom,
              child: BlocSelector<StopArrivalsCubit, StopArrivalsState, bool>(
                selector: (state) =>
                    state is StopArrivalsLoaded && state.tracking != null,
                builder: (context, trackingActive) => NavDock(
                  selected: _tab,
                  onSelected: _select,
                  trackingActive: trackingActive,
                  layout: geometry.dockLayout,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _sheetMinFor(_Geometry geometry) =>
      (_sheetMinPixels / geometry.panelArea).clamp(0.12, _sheetMid - 0.1);

  _MapLayout _mapLayout(_Geometry g) {
    final double coveredBottom;
    if (g.wide) {
      coveredBottom = g.panelBottom + _panelHeight.value;
    } else {
      final sheetTop =
          g.size.height - g.panelBottom - g.panelArea * _sheetExtent.value;
      coveredBottom = g.size.height - sheetTop;
    }
    final mapTop = g.headerBottom;
    final visible = g.size.height - coveredBottom - mapTop;

    return _MapLayout(
      cameraPadding: EdgeInsets.only(
        top: mapTop,
        bottom: math.min(coveredBottom, g.size.height * 0.75),
      ),
      // Celular: à direita, sob o cabeçalho. Largo: à esquerda da coluna,
      // na altura do cabeçalho; cresce para a esquerda quando pausado.
      controlsPadding: g.wide
          ? EdgeInsets.only(
              top: g.headerTop + (g.headerHeight - 48) / 2,
              right: g.size.width - g.left + Space.sm,
            )
          : EdgeInsets.only(top: mapTop + Space.sm, right: Chrome.gutter),
      // Em telas largas o canto inferior direito do mapa fica livre.
      attributionBottom: g.wide ? 0 : coveredBottom,
      // Sem faixa de mapa suficiente o botão cobriria a atribuição. No
      // celular o callout de outro ônibus ocupa o mesmo canto (o cartão de
      // acompanhamento mantém o próprio "Centralizar").
      showControls:
          g.wide ||
          (visible >= 48 + Space.sm + _Geometry.mapBand &&
              _selectedSecondary == null),
    );
  }

  Widget _header() {
    return BlocBuilder<StopArrivalsCubit, StopArrivalsState>(
      builder: (context, state) {
        final (Key key, Widget child) = switch (_tab) {
          HomeTab.stop => _stopHeader(state),
          HomeTab.tracking => _trackingHeader(state),
          HomeTab.lines => (
            const ValueKey('header-lines'),
            ContextHeader(
              leading: const HeaderTile(
                Icons.format_list_bulleted_rounded,
                filled: false,
              ),
              title: l10n.dockLines,
              subtitle: Text(
                _catalog == null
                    ? l10n.comingSoon
                    : l10n.catalogLinesHeaderSubtitle(_catalog!.lines.length),
              ),
            ),
          ),
          HomeTab.favorites => (
            const ValueKey('header-favorites'),
            ContextHeader(
              leading: const HeaderTile(
                Icons.star_outline_rounded,
                filled: false,
              ),
              title: l10n.dockFavorites,
              subtitle: BlocBuilder<SavedStopsCubit, SavedStopsState>(
                builder: (context, saved) {
                  final count = saved.favorites.length;
                  return Text(
                    saved.loading
                        ? l10n.loading
                        : count == 0
                        ? l10n.savedStopsNone
                        : l10n.savedStopsCount(count),
                  );
                },
              ),
            ),
          ),
          HomeTab.settings => (
            const ValueKey('header-settings'),
            ContextHeader(
              leading: const HeaderTile(Icons.tune_rounded),
              title: l10n.settings,
              subtitle: Text(l10n.settingsSubtitle),
              action: IconButton(
                tooltip: l10n.settingsClose,
                onPressed: _closeSettings,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
        };
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, -0.08),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: key, child: child),
        );
      },
    );
  }

  (Key, Widget) _stopHeader(StopArrivalsState state) {
    final catalog = _catalog;
    final preview = _previewStop;
    if (catalog != null && preview != null) {
      final stop = catalog.stop(preview);
      return (
        ValueKey('header-preview-$preview'),
        ContextHeader(
          leading: const HeaderTile(Icons.location_on_outlined),
          title: l10n.catalogStopTitle(preview),
          subtitle: Text(
            stop?.place ?? stop?.address ?? l10n.catalogStopNotFound,
          ),
          action: IconButton(
            tooltip: l10n.catalogPreviewClose,
            onPressed: _closePreview,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      );
    }
    final stopId = switch (state) {
      StopArrivalsLoaded(:final stopId) => stopId,
      StopArrivalsLoading(:final stopId) => stopId,
      _ => null,
    };
    final searchError = switch (state) {
      StopArrivalsInitial(:final searchError) => searchError,
      StopArrivalsLoaded(:final searchError) => searchError,
      _ => null,
    };
    // Buscando outro ponto ou com erro de busca: o campo continua à vista
    // sobre o ponto válido anterior, que não sai da tela.
    final searchingOther =
        state is StopArrivalsLoaded && state.searchingStopId != null;

    // `stopId == null` repetido aqui para o Dart promover o tipo abaixo.
    if (stopId == null || _isSearchVisible(state)) {
      return (
        const ValueKey('header-search'),
        SearchHeader(
          controller: _stopController,
          focusNode: _searchFocus,
          allowText: catalog != null,
          loading: state is StopArrivalsLoading || searchingOther,
          error: searchError,
          onEdited: context.read<StopArrivalsCubit>().clearSearchError,
          onRetry: _search,
          onSearch: _search,
          onCancel: state is StopArrivalsLoaded && !searchingOther
              ? _cancelSearch
              : null,
        ),
      );
    }

    final searchButton = IconButton(
      tooltip: l10n.searchAnotherStop,
      onPressed: _openSearch,
      icon: const Icon(Icons.search_rounded),
    );
    return (
      ValueKey('header-stop-$stopId'),
      ContextHeader(
        leading: const HeaderTile(Icons.location_on_outlined),
        title: '${l10n.stopWord} $stopId',
        subtitle: state is StopArrivalsLoaded
            ? PeriodicRebuild(
                builder: (context) {
                  final freshness = arrivalsFreshness(state, _clock());
                  final lines = state.arrivals.data.length;
                  return Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: l10n.linesCount(lines),
                          style: TextStyle(color: context.tokens.accentText),
                        ),
                        TextSpan(
                          text:
                              ' · ${state.refreshing ? l10n.refreshing : freshness.text.toLowerCase()}',
                          style: freshness.tone == FreshnessTone.stale
                              ? TextStyle(color: context.tokens.unconfirmed)
                              : null,
                        ),
                      ],
                    ),
                  );
                },
              )
            : Text(l10n.queryingArrivals),
        tallAction: true,
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FavoriteToggleButton(
              code: stopId,
              // Só um ponto já consultado com sucesso pode ser favorito.
              enabled: state is StopArrivalsLoaded,
              onPressed: () => _toggleFavorite(stopId),
            ),
            searchButton,
          ],
        ),
      ),
    );
  }

  /// O campo de busca está à vista na aba Pontos (sem ponto, buscando outro
  /// ou com erro de busca).
  bool _isSearchVisible(StopArrivalsState state) {
    final stopId = switch (state) {
      StopArrivalsLoaded(:final stopId) => stopId,
      StopArrivalsLoading(:final stopId) => stopId,
      _ => null,
    };
    final searchError = switch (state) {
      StopArrivalsInitial(:final searchError) => searchError,
      StopArrivalsLoaded(:final searchError) => searchError,
      _ => null,
    };
    return _searching ||
        stopId == null ||
        state is StopArrivalsInitial ||
        (state is StopArrivalsLoaded && state.searchingStopId != null) ||
        searchError != null;
  }

  (Key, Widget) _trackingHeader(StopArrivalsState state) {
    final tracking = state is StopArrivalsLoaded ? state.tracking : null;
    if (state is! StopArrivalsLoaded || tracking == null) {
      return (
        const ValueKey('header-tracking-empty'),
        ContextHeader(
          leading: const HeaderTile(
            Icons.directions_bus_outlined,
            filled: false,
          ),
          title: l10n.dockTracking,
          subtitle: Text(l10n.trackingHeaderSubtitle),
        ),
      );
    }

    final vehicle = tracking.vehicle?.data;
    final match = trackedArrival(state.arrivals.data, tracking.vehicleNumber);
    final routeId = vehicle?.routeId ?? match?.group.routeId;
    final destination = vehicle?.destination ?? match?.group.destination;
    final tokens = context.tokens;

    return (
      ValueKey('header-tracking-${tracking.vehicleNumber}'),
      ContextHeader(
        leading: routeId != null
            ? RoutePlate(routeId, filled: true)
            : const HeaderTile(Icons.directions_bus_rounded),
        title: l10n.busNumber(tracking.vehicleNumber),
        semanticsLabel: routeId != null
            ? l10n.trackingHeaderSemanticsRoute(
                tracking.vehicleNumber,
                routeId,
                headingToLabel(destination),
              )
            : l10n.trackingHeaderSemantics(
                tracking.vehicleNumber,
                headingToLabel(destination),
              ),
        subtitle: Text(
          headingToLabel(destination),
          style: TextStyle(
            color: destination == null ? null : tokens.accentText,
          ),
        ),
        action: IconButton(
          tooltip: l10n.stopTracking,
          onPressed: _stopTracking,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    );
  }

  Widget _panelContent() {
    return BlocBuilder<StopArrivalsCubit, StopArrivalsState>(
      builder: (context, state) {
        final cubit = context.read<StopArrivalsCubit>();
        final catalog = _catalog;
        final arrivals = ArrivalsPanel(
          state: state,
          onRefresh: cubit.refresh,
          onTrack: _track,
          onOpenTracking: () => _select(HomeTab.tracking),
          onExample: _searchExample,
          onRetrySearch: _search,
          above: catalog != null && state is StopArrivalsLoaded
              ? CatalogStopFacts(
                  catalog: catalog,
                  stopId: state.stopId,
                  compact: true,
                )
              : null,
          below: RecentStopsSection(
            onOpen: _openStop,
            excludeCode: state is StopArrivalsLoaded ? state.stopId : null,
            showEmpty: state is StopArrivalsInitial,
          ),
        );
        final Widget child = switch (_tab) {
          HomeTab.stop when catalog != null && _previewStop != null =>
            StopPreview(
              key: ValueKey('preview-$_previewStop'),
              catalog: catalog,
              stopId: _previewStop!,
              onSeeArrivals: () => _openStop(_previewStop!),
            ),
          HomeTab.stop when catalog != null && _isSearchVisible(state) =>
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _stopController,
              builder: (context, value, _) {
                final query = value.text.trim();
                if (query.isEmpty || query == _submittedQuery) return arrivals;
                return StopSearchResults(
                  catalog: catalog,
                  query: query,
                  onSelect: _openPreview,
                );
              },
            ),
          HomeTab.stop => arrivals,
          HomeTab.tracking => switch (state) {
            StopArrivalsLoaded(:final tracking?) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TrackingCard(
                  state: state,
                  tracking: tracking,
                  onStop: _stopTracking,
                  clock: _clock,
                  followController: _follow,
                  detailsExpanded: _vehicleDetails,
                  onToggleDetails: () =>
                      setState(() => _vehicleDetails = !_vehicleDetails),
                ),
                if (_routeMatch(state) case final match?) ...[
                  const SizedBox(height: Space.sm),
                  RouteMatchNote(match: match),
                ],
              ],
            ),
            _ => _TrackingEmpty(
              hasStop: state is StopArrivalsLoaded,
              onOpenStop: () => _select(HomeTab.stop),
            ),
          },
          HomeTab.lines when catalog != null => CatalogLinesPanel(
            catalog: catalog,
            query: _linesQuery,
            openLineId: _openLine,
            onOpenLine: _openLineDetail,
            activeShapeId: _routeShape,
            onShowRoute: _showRoute,
            onClearRoute: _clearRoute,
            onOpenStop: _openPreview,
          ),
          HomeTab.lines => SeenLinesPanel(
            currentStopId: state is StopArrivalsLoaded ? state.stopId : null,
            currentGroups: state is StopArrivalsLoaded
                ? state.arrivals.data
                : const [],
            onOpen: _openStop,
            onSearchStop: _goToStopSearch,
          ),
          HomeTab.favorites => FavoritesPanel(
            onOpen: _openStop,
            onSearchStop: _goToStopSearch,
            connectionNotice: _connectionNotice(state),
          ),
          HomeTab.settings => const SettingsPanel(),
        };
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(_tab), child: child),
        );
      },
    );
  }
}

class _TrackingEmpty extends StatelessWidget {
  const _TrackingEmpty({required this.hasStop, required this.onOpenStop});

  final bool hasStop;
  final VoidCallback onOpenStop;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MessageView(
          icon: Icons.directions_bus_outlined,
          title: l10n.noTrackedBusTitle,
          body: l10n.noTrackedBusBody,
          action: FilledButton.icon(
            onPressed: onOpenStop,
            icon: const Icon(Icons.location_on_outlined, size: 20),
            label: Text(hasStop ? l10n.viewArrivals : l10n.searchStopAction),
          ),
        ),
        const SizedBox(height: Space.sm),
        FootNote(child: Text(l10n.noTrackedBusNote)),
      ],
    );
  }
}

/// Medidas que o mapa recebe do layout.
@immutable
class _MapLayout {
  const _MapLayout({
    required this.cameraPadding,
    required this.controlsPadding,
    required this.attributionBottom,
    required this.showControls,
  });

  final EdgeInsets cameraPadding;
  final EdgeInsets controlsPadding;
  final double attributionBottom;
  final bool showControls;
}

typedef _MapData = ({
  String? vehicleNumber,
  GeoPosition? position,
  bool stale,
  double? heading,
  List<GeoPosition> trail,
  String? stopId,
  String? routeId,
  String? routeName,
  String? destination,
});

/// Liga o mapa ao Cubit expondo só o que o mapa precisa; o resto do estado
/// não o reconstrói.
class _MapBinding extends StatelessWidget {
  const _MapBinding({
    required this.mapBuilder,
    required this.styleString,
    required this.fallbackStyleString,
    required this.followController,
    required this.layout,
    required this.onSecondaryTap,
    required this.onTrackedTap,
    required this.onMapTap,
    this.network,
    this.previewStopId,
    this.routeLineId,
    this.routeShapeId,
    this.focus,
    this.onStopTap,
  });

  /// Rede do catálogo de desenvolvimento; `null` = mapa de sempre.
  final NetworkOverlayBuilder? network;
  final String? previewStopId;
  final String? routeLineId;
  final String? routeShapeId;
  final MapFocus? focus;
  final ValueChanged<String>? onStopTap;

  final ValueChanged<String> onSecondaryTap;
  final VoidCallback onTrackedTap;
  final VoidCallback onMapTap;
  final VehicleMapBuilder? mapBuilder;
  final String styleString;
  final String fallbackStyleString;
  final MapFollowController followController;
  final _MapLayout layout;

  static _MapData _select(StopArrivalsState state) {
    if (state is! StopArrivalsLoaded || state.tracking == null) {
      return (
        vehicleNumber: null,
        position: null,
        stale: false,
        heading: null,
        trail: const <GeoPosition>[],
        stopId: state is StopArrivalsLoaded ? state.stopId : null,
        routeId: null,
        routeName: null,
        destination: null,
      );
    }
    final tracking = state.tracking!;
    final snapshot = tracking.vehicle;
    return (
      vehicleNumber: tracking.vehicleNumber,
      position: snapshot?.data?.position,
      stale:
          (snapshot?.stale ?? false) || tracking.phase != TrackingPhase.active,
      heading: tracking.movement.observedHeading,
      trail: tracking.movement.observedTrail,
      stopId: state.stopId,
      routeId: snapshot?.data?.routeId,
      routeName: snapshot?.data?.routeName,
      destination: snapshot?.data?.destination,
    );
  }

  NetworkOverlay? _overlay(_MapData data) {
    final builder = network;
    if (builder == null) return null;
    // Trajeto do ônibus só com associação confirmada (ver route_match.dart).
    final match = data.vehicleNumber == null
        ? null
        : matchTrackedRoute(
            catalog: builder.catalog,
            routeId: data.routeId,
            routeName: data.routeName,
            destination: data.destination,
            position: data.stale ? null : data.position,
            trail: data.trail,
          );
    return builder.build(
      selectedStopId: previewStopId ?? data.stopId,
      routeLineId: routeLineId,
      routeShapeId: routeShapeId,
      trackMatch: match,
      focus: focus,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<StopArrivalsCubit, StopArrivalsState, _MapData>(
      selector: _select,
      builder: (context, data) =>
          BlocSelector<MapVehiclesCubit, MapVehiclesState, List<MapVehicle>>(
            selector: (state) => state.secondaries,
            builder: (context, secondaries) => TransitMap(
              network: _overlay(data),
              onStopTap: onStopTap,
              secondaryVehicles: secondaries,
              onSecondaryTap: onSecondaryTap,
              onTrackedTap: onTrackedTap,
              onMapTap: onMapTap,
              vehicleNumber: data.vehicleNumber,
              position: data.position,
              stale: data.stale,
              observedHeading: data.heading,
              observedTrail: data.trail,
              styleString: styleString,
              fallbackStyleString: fallbackStyleString,
              followController: followController,
              cameraPadding: layout.cameraPadding,
              controlsPadding: layout.controlsPadding,
              attributionBottom: layout.attributionBottom,
              showControls: layout.showControls,
              mapBuilder: mapBuilder,
            ),
          ),
    );
  }
}

/// Bottom sheet flutuante (celular): vidro com cantos arredondados, alça e
/// lista rolável ligada ao [DraggableScrollableSheet].
class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.scrollController, required this.child});

  final ScrollController scrollController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: Radii.panel,
      solid: true,
      // No Web o padrão não arrasta com mouse; sem isso o sheet não abre
      // nem recolhe num navegador de desktop estreito.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, Space.md),
          children: [const _SheetHandle(), child],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: l10n.panelHandleLabel,
      child: Center(
        child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: Space.sm),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: context.tokens.strongText.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
        ),
      ),
    );
  }
}

/// Painel da coluna central (tablet/desktop): cresce com o conteúdo até o
/// espaço disponível e então rola.
class _ColumnPanel extends StatelessWidget {
  const _ColumnPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: Radii.panel,
      solid: true,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, Space.md),
        children: [child],
      ),
    );
  }
}

/// Informa a altura do filho após cada layout.
class _SizeReporter extends StatefulWidget {
  const _SizeReporter({required this.onHeight, required this.child});

  final ValueChanged<double> onHeight;
  final Widget child;

  @override
  State<_SizeReporter> createState() => _SizeReporterState();
}

class _SizeReporterState extends State<_SizeReporter> {
  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _report();
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: Builder(
          builder: (context) {
            _report();
            return widget.child;
          },
        ),
      ),
    );
  }

  void _report() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is RenderBox && box.hasSize) widget.onHeight(box.size.height);
    });
  }
}
