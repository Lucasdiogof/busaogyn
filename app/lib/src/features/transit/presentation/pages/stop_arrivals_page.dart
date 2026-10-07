import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/map_config.dart';
import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
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
/// celular, coluna central em telas largas) e o dock com Ponto,
/// Acompanhando e Ajustes.
class StopArrivalsPage extends StatefulWidget {
  const StopArrivalsPage({this.mapBuilder, this.clock, super.key});

  final VehicleMapBuilder? mapBuilder;
  final DateTime Function()? clock;

  @override
  State<StopArrivalsPage> createState() => _StopArrivalsPageState();
}

/// Posições dos elementos flutuantes para um tamanho de tela.
class _Geometry {
  _Geometry(MediaQueryData media)
    : size = media.size,
      safe = media.padding,
      wide = media.size.width >= Breakpoints.panel {
    final columnWidth = wide
        ? math.min(Chrome.column, size.width - Chrome.gutter * 2)
        : size.width - Chrome.gutter * 2;
    left = wide ? (size.width - columnWidth) / 2 : Chrome.gutter;
    width = columnWidth;
    top = safe.top + Space.sm;
    headerTop = top + Chrome.pill + 10;
    headerBottom = headerTop + Chrome.header;
    dockBottom = math.max(safe.bottom, Space.xs) + Space.xs;
    dockTop = size.height - dockBottom - Chrome.dock;
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

  HomeTab _tab = HomeTab.stop;

  /// Ônibus secundário tocado no mapa (mostra o callout).
  String? _selectedSecondary;

  /// Campo de busca aberto por cima de um ponto já exibido.
  bool _searching = false;

  /// Código enviado na última busca, para fechar o campo quando ela der
  /// certo.
  String? _pendingSearch;

  DateTime Function() get _clock => widget.clock ?? DateTime.now;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final cubit = context.read<StopArrivalsCubit>();
    final vehicles = context.read<MapVehiclesCubit>();

    switch (state) {
      case AppLifecycleState.resumed:
        cubit.resumeTracking();
        vehicles.resume();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        cubit.pauseTracking();
        vehicles.pause();
        return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopController.dispose();
    _searchFocus.dispose();
    _sheetController.dispose();
    _sheetExtent.dispose();
    _panelHeight.dispose();
    _follow.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    final cubit = context.read<StopArrivalsCubit>();
    // Com um ponto na tela, a busca só fecha quando der certo (ver
    // _onStateChanged); se falhar, o campo continua com o aviso.
    _pendingSearch = _stopController.text.trim();
    if (cubit.state is! StopArrivalsLoaded) {
      setState(() => _searching = false);
    }
    cubit.load(_stopController.text);
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
    context.read<StopArrivalsCubit>().track(vehicleNumber);
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

  void _select(HomeTab tab) {
    if (tab != HomeTab.stop) FocusScope.of(context).unfocus();
    if (_tab != tab) setState(() => _tab = tab);
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
    final geometry = _Geometry(MediaQuery.of(context));
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
                  onMapTap: () {
                    if (_selectedSecondary != null) {
                      setState(() => _selectedSecondary = null);
                    }
                  },
                ),
              ),
            ),
            if (geometry.wide)
              Positioned(
                key: const ValueKey('column-panel'),
                left: geometry.left,
                width: geometry.width,
                bottom: geometry.panelBottom,
                top: geometry.panelTop,
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
                  builder: (context) =>
                      TopBar(status: liveStatus(state, _clock())),
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
                builder: (context, trackingActive) => AppDock(
                  selected: _tab,
                  onSelected: _select,
                  trackingActive: trackingActive,
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
              top: g.headerTop + (Chrome.header - 48) / 2,
              right: g.size.width - g.left + Space.sm,
            )
          : EdgeInsets.only(top: mapTop + Space.sm, right: Chrome.gutter),
      // Em telas largas o canto inferior direito do mapa fica livre.
      attributionBottom: g.wide ? 0 : coveredBottom,
      // Sem faixa de mapa suficiente o botão cobriria a atribuição.
      showControls: g.wide || visible >= 48 + Space.sm + _Geometry.mapBand,
    );
  }

  Widget _header() {
    return BlocBuilder<StopArrivalsCubit, StopArrivalsState>(
      builder: (context, state) {
        final (Key key, Widget child) = switch (_tab) {
          HomeTab.stop => _stopHeader(state),
          HomeTab.tracking => _trackingHeader(state),
          HomeTab.settings => (
            const ValueKey('header-settings'),
            ContextHeader(
              leading: const HeaderTile(Icons.tune_rounded),
              title: 'Ajustes',
              subtitle: const Text('Aparência e sobre'),
              action: IconButton(
                tooltip: 'Fechar ajustes',
                onPressed: () => _select(HomeTab.stop),
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
    final showSearch =
        _searching ||
        stopId == null ||
        state is StopArrivalsInitial ||
        searchingOther ||
        searchError != null;

    if (showSearch) {
      return (
        const ValueKey('header-search'),
        SearchHeader(
          controller: _stopController,
          focusNode: _searchFocus,
          loading: state is StopArrivalsLoading || searchingOther,
          error: searchError,
          onEdited: context.read<StopArrivalsCubit>().clearSearchError,
          onSearch: _search,
          onCancel: state is StopArrivalsLoaded && !searchingOther
              ? _cancelSearch
              : null,
        ),
      );
    }

    return (
      ValueKey('header-stop-$stopId'),
      ContextHeader(
        leading: const HeaderTile(Icons.location_on_outlined),
        title: 'Ponto $stopId',
        subtitle: state is StopArrivalsLoaded
            ? PeriodicRebuild(
                builder: (context) {
                  final freshness = arrivalsFreshness(state, _clock());
                  final lines = state.arrivals.data.length;
                  return Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: lines == 1 ? '1 linha' : '$lines linhas',
                          style: TextStyle(color: context.tokens.accentText),
                        ),
                        TextSpan(
                          text:
                              ' · ${state.refreshing ? 'atualizando…' : freshness.text.toLowerCase()}',
                          style: freshness.tone == FreshnessTone.stale
                              ? TextStyle(color: context.tokens.unconfirmed)
                              : null,
                        ),
                      ],
                    ),
                  );
                },
              )
            : const Text('consultando chegadas…'),
        action: IconButton(
          tooltip: 'Buscar outro ponto',
          onPressed: _openSearch,
          icon: const Icon(Icons.search_rounded),
        ),
      ),
    );
  }

  (Key, Widget) _trackingHeader(StopArrivalsState state) {
    final tracking = state is StopArrivalsLoaded ? state.tracking : null;
    if (state is! StopArrivalsLoaded || tracking == null) {
      return (
        const ValueKey('header-tracking-empty'),
        const ContextHeader(
          leading: HeaderTile(Icons.directions_bus_outlined, filled: false),
          title: 'Acompanhando',
          subtitle: Text('nenhum ônibus agora'),
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
        title: 'Ônibus ${tracking.vehicleNumber}',
        semanticsLabel:
            'Ônibus ${tracking.vehicleNumber}'
            '${destination != null ? ', destino $destination' : ''}'
            ', ponto ${state.stopId}',
        subtitle: Text.rich(
          TextSpan(
            children: [
              if (destination != null)
                TextSpan(
                  text: '${destinationLabel(destination).toUpperCase()} · ',
                  style: TextStyle(color: tokens.accentText),
                ),
              TextSpan(text: 'ponto ${state.stopId}'),
            ],
          ),
        ),
        action: IconButton(
          tooltip: 'Parar de acompanhar',
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
        final Widget child = switch (_tab) {
          HomeTab.stop => ArrivalsPanel(
            state: state,
            onRefresh: cubit.refresh,
            onTrack: _track,
            onOpenTracking: () => _select(HomeTab.tracking),
            onExample: _searchExample,
          ),
          HomeTab.tracking => switch (state) {
            StopArrivalsLoaded(:final tracking?) => TrackingCard(
              state: state,
              tracking: tracking,
              onStop: _stopTracking,
              clock: _clock,
              followController: _follow,
            ),
            _ => _TrackingEmpty(
              hasStop: state is StopArrivalsLoaded,
              onOpenStop: () => _select(HomeTab.stop),
            ),
          },
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
          title: 'Nenhum ônibus acompanhado',
          body: hasStop
              ? 'Nas chegadas do ponto, toque no número de um ônibus em '
                    'tempo real para acompanhá-lo no mapa.'
              : 'Consulte um ponto e toque no número de um ônibus em tempo '
                    'real para acompanhá-lo no mapa.',
          action: FilledButton.icon(
            onPressed: onOpenStop,
            icon: const Icon(Icons.location_on_outlined, size: 20),
            label: Text(hasStop ? 'Ver chegadas' : 'Buscar um ponto'),
          ),
        ),
        const SizedBox(height: Space.sm),
        const FootNote(
          child: Text(
            'Só ônibus com GPS informado pela RMTC podem ser acompanhados. '
            'Horários programados não têm posição.',
          ),
        ),
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

typedef _MapData = ({String? vehicleNumber, GeoPosition? position, bool stale});

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
    required this.onMapTap,
  });

  final ValueChanged<String> onSecondaryTap;
  final VoidCallback onMapTap;
  final VehicleMapBuilder? mapBuilder;
  final String styleString;
  final String fallbackStyleString;
  final MapFollowController followController;
  final _MapLayout layout;

  static _MapData _select(StopArrivalsState state) {
    if (state is! StopArrivalsLoaded || state.tracking == null) {
      return (vehicleNumber: null, position: null, stale: false);
    }
    final tracking = state.tracking!;
    final snapshot = tracking.vehicle;
    return (
      vehicleNumber: tracking.vehicleNumber,
      position: snapshot?.data?.position,
      stale:
          (snapshot?.stale ?? false) || tracking.phase != TrackingPhase.active,
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
              secondaryVehicles: secondaries,
              onSecondaryTap: onSecondaryTap,
              onMapTap: onMapTap,
              vehicleNumber: data.vehicleNumber,
              position: data.position,
              stale: data.stale,
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
      label: 'Painel. Arraste para expandir ou recolher',
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
