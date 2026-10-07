import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/busao_tokens.dart';
import '../../domain/entities/tracked_vehicle.dart';
import '../cubit/stop_arrivals_cubit.dart';
import '../widgets/arrivals_panel.dart';
import '../widgets/search_header.dart';
import '../widgets/tracked_vehicle_map.dart';

/// Home map-first: o mapa ocupa a tela; busca no topo; chegadas e
/// acompanhamento num bottom sheet (celular) ou painel lateral (telas largas).
class StopArrivalsPage extends StatefulWidget {
  const StopArrivalsPage({this.mapBuilder, this.clock, super.key});

  final VehicleMapBuilder? mapBuilder;
  final DateTime Function()? clock;

  @override
  State<StopArrivalsPage> createState() => _StopArrivalsPageState();
}

class _StopArrivalsPageState extends State<StopArrivalsPage>
    with WidgetsBindingObserver {
  static const _sheetMin = 0.22;
  static const _sheetMid = 0.48;
  static const _sheetMax = 0.92;
  static const _sideWidth = 400.0;

  /// Altura aproximada do cabeçalho flutuante (marca + campo de busca).
  static const _headerHeight = 112.0;

  final _stopController = TextEditingController();
  final _sheetController = DraggableScrollableController();
  final _sheetExtent = ValueNotifier<double>(_sheetMid);

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

    switch (state) {
      case AppLifecycleState.resumed:
        cubit.resumeTracking();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        cubit.pauseTracking();
        return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopController.dispose();
    _sheetController.dispose();
    _sheetExtent.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    context.read<StopArrivalsCubit>().load(_stopController.text);
  }

  void _retry(String? stopId) {
    if (stopId == null) return _search();
    _stopController.text = stopId;
    context.read<StopArrivalsCubit>().load(stopId);
  }

  void _track(String vehicleNumber) {
    context.read<StopArrivalsCubit>().track(vehicleNumber);
    // Abre espaço para o mapa sem esconder o cartão do acompanhamento.
    _animateSheet(0.36);
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

  void _onStateChanged(BuildContext context, StopArrivalsState state) {
    // Resultado novo de ponto: mostra as chegadas.
    if (state is StopArrivalsLoaded && state.tracking == null) {
      if (_sheetExtent.value < _sheetMid - 0.01) _animateSheet(_sheetMid);
    }
  }

  ArrivalsPanel _panel(
    StopArrivalsState state, {
    ScrollController? scroll,
    Widget? header,
  }) {
    final cubit = context.read<StopArrivalsCubit>();
    return ArrivalsPanel(
      state: state,
      scrollController: scroll,
      header: header,
      onRetry: _retry,
      onRefresh: cubit.refresh,
      onTrack: _track,
      onStopTracking: cubit.stopTracking,
      clock: _clock,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final wide = media.size.width >= Breakpoints.panel;
    final safe = media.padding;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: BlocListener<StopArrivalsCubit, StopArrivalsState>(
        listener: _onStateChanged,
        child: Stack(
          children: [
            // Índice 0 fixo em ambos os layouts: o mapa nunca é recriado por
            // estado do Cubit, por arrastar o sheet ou por redimensionar.
            Positioned.fill(
              child: ValueListenableBuilder<double>(
                valueListenable: _sheetExtent,
                builder: (context, extent, _) {
                  final cameraPadding = wide
                      ? EdgeInsets.only(left: _sideWidth + Space.md * 2)
                      : EdgeInsets.only(
                          top: safe.top + _headerHeight,
                          bottom: media.size.height * extent.clamp(0, 0.6),
                        );
                  final controlsPadding = wide
                      ? EdgeInsets.only(
                          top: safe.top + Space.md,
                          right: Space.md,
                        )
                      : EdgeInsets.only(
                          top: safe.top + _headerHeight + Space.md + Space.xs,
                          right: Space.md,
                        );
                  return _MapBinding(
                    mapBuilder: widget.mapBuilder,
                    cameraPadding: cameraPadding,
                    controlsPadding: controlsPadding,
                  );
                },
              ),
            ),
            if (wide)
              _SidePanel(
                key: const ValueKey('side-panel'),
                width: _sideWidth,
                search: _searchHeader(floating: false),
                panelBuilder: (state) => _panel(state),
              )
            else ...[
              _SheetAttribution(
                key: const ValueKey('attribution'),
                extent: _sheetExtent,
              ),
              NotificationListener<DraggableScrollableNotification>(
                key: const ValueKey('sheet'),
                onNotification: (notification) {
                  _sheetExtent.value = notification.extent;
                  return false;
                },
                child: DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: _sheetMid,
                  minChildSize: _sheetMin,
                  maxChildSize: _sheetMax,
                  snap: true,
                  snapSizes: const [_sheetMid],
                  builder: (context, scroll) => _SheetSurface(
                    child: BlocBuilder<StopArrivalsCubit, StopArrivalsState>(
                      builder: (context, state) => _panel(
                        state,
                        scroll: scroll,
                        header: const _SheetHandle(),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                key: const ValueKey('header'),
                top: safe.top + Space.sm,
                left: Space.sm,
                right: Space.sm,
                child: _searchHeader(floating: true),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _searchHeader({required bool floating}) {
    return BlocSelector<StopArrivalsCubit, StopArrivalsState, bool>(
      selector: (state) => state is StopArrivalsLoading,
      builder: (context, loading) => SearchHeader(
        controller: _stopController,
        loading: loading,
        onSearch: _search,
        floating: floating,
      ),
    );
  }
}

typedef _MapData = ({String? vehicleNumber, GeoPosition? position, bool stale});

/// Liga o mapa ao Cubit expondo só o que o mapa precisa; o resto do estado
/// não o reconstrói.
class _MapBinding extends StatelessWidget {
  const _MapBinding({
    required this.mapBuilder,
    required this.cameraPadding,
    required this.controlsPadding,
  });

  final VehicleMapBuilder? mapBuilder;
  final EdgeInsets cameraPadding;
  final EdgeInsets controlsPadding;

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
      builder: (context, data) => TransitMap(
        vehicleNumber: data.vehicleNumber,
        position: data.position,
        stale: data.stale,
        cameraPadding: cameraPadding,
        controlsPadding: controlsPadding,
        mapBuilder: mapBuilder,
      ),
    );
  }
}

class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 12,
      shadowColor: tokens.shadow,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(Radii.panel),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(top: false, child: child),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Painel de chegadas. Arraste para expandir ou recolher',
      child: Center(
        child: Container(
          margin: const EdgeInsets.only(top: Space.xs, bottom: Space.sm),
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: context.tokens.hairline,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
        ),
      ),
    );
  }
}

/// No celular o controle nativo de atribuição fica sob o sheet; esta
/// etiqueta mantém a atribuição do OpenFreeMap/OSM visível acima dele.
class _SheetAttribution extends StatelessWidget {
  const _SheetAttribution({required this.extent, super.key});

  final ValueListenable<double> extent;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final tokens = context.tokens;
    return ValueListenableBuilder<double>(
      valueListenable: extent,
      builder: (context, value, _) {
        if (value > 0.75) return const SizedBox.shrink();
        return Positioned(
          left: Space.sm,
          bottom: height * value + Space.xs,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.floatingSurface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(Radii.chip - 2),
              ),
              child: Text(
                '© OpenFreeMap © OpenMapTiles © OpenStreetMap',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w500,
                  color: tokens.mutedText,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.width,
    required this.search,
    required this.panelBuilder,
    super.key,
  });

  final double width;
  final Widget search;
  final Widget Function(StopArrivalsState state) panelBuilder;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final safe = MediaQuery.of(context).padding;
    return Positioned(
      left: Space.md + safe.left,
      top: Space.md + safe.top,
      bottom: Space.md + safe.bottom,
      width: width,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 8,
        shadowColor: tokens.shadow,
        borderRadius: BorderRadius.circular(Radii.panel),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            search,
            Divider(height: 1, color: tokens.hairline),
            const SizedBox(height: Space.sm),
            Expanded(
              child: BlocBuilder<StopArrivalsCubit, StopArrivalsState>(
                builder: (context, state) => panelBuilder(state),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
