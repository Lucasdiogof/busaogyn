import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/map_config.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/share/share_text.dart';
import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
import '../../../catalog/domain/network_geojson.dart';
import '../../../catalog/domain/route_geometry.dart';
import '../../../catalog/domain/route_match.dart';
import '../../../catalog/domain/stop_sequence.dart';
import '../../../catalog/domain/transit_catalog.dart';
import '../../../catalog/domain/trip_planner.dart';
import '../../../catalog/presentation/catalog_access.dart';
import '../../../catalog/presentation/catalog_schedule_widgets.dart';
import '../../../catalog/presentation/catalog_widgets.dart';
import '../../../catalog/presentation/nearby_widgets.dart';
import '../../../catalog/presentation/share_texts.dart';
import '../../../catalog/presentation/trip_planner_widgets.dart';
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
import '../widgets/tracking_bar.dart';
import '../widgets/tracking_card.dart';

/// Home map-first: o mapa ocupa a tela inteira e tudo flutua sobre ele —
/// marca e status no topo, cartão de contexto, painel (bottom sheet no
/// celular, coluna central em telas largas) e o dock com Linhas, Pontos,
/// Favoritos e Meu ônibus, com Ajustes na TopBar.
class StopArrivalsPage extends StatefulWidget {
  const StopArrivalsPage({
    this.mapBuilder,
    this.clock,
    this.locationService = const DeviceLocationService(),
    super.key,
  });

  final VehicleMapBuilder? mapBuilder;
  final DateTime Function()? clock;
  final LocationService locationService;

  @override
  State<StopArrivalsPage> createState() => _StopArrivalsPageState();
}

/// Posições dos elementos flutuantes para um tamanho de tela.
///
/// Celular: tudo numa coluna sobre o mapa, com o painel como bottom sheet.
/// Tablet e desktop ([wide]): coluna lateral à esquerda (cabeçalho, painel de
/// altura inteira, barra de acompanhamento e dock) e o mapa livre à direita.
class _Geometry {
  _Geometry(MediaQueryData media, {int dockItems = 3, bool trackingBar = false})
    : size = media.size,
      safe = media.padding,
      wide = media.size.width >= Breakpoints.panel {
    // Margens laterais seguras: em paisagem, o recorte da câmera (notch/ilha)
    // fica de um dos lados e cobriria o painel.
    final usable = size.width - safe.left - safe.right - Chrome.gutter * 2;
    final columnWidth = wide
        ? (size.width * 0.38).clamp(Chrome.sidePanelMin, Chrome.sidePanelMax)
        : usable;
    left = Chrome.gutter + safe.left;
    width = math.min(columnWidth, usable);
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
    barTop = trackingBar ? dockTop - Space.xs - Chrome.trackingBar : null;
    // Celular com teclado aberto: o painel termina acima dele. Antes a lista
    // seguia por baixo do teclado e o campo focado (planejador) sumia.
    final keyboard = wide ? 0.0 : media.viewInsets.bottom + Space.xs;
    panelBottom = math.max(
      size.height - (barTop ?? dockTop) + Space.xs,
      keyboard,
    );
  }

  /// Faixa de mapa que sempre sobra sob o cabeçalho com o painel aberto.
  static const mapBand = 56.0;

  /// Topo da barra de acompanhamento, quando visível.
  late final double? barTop;

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

  /// Topo máximo do painel (no painel lateral não há faixa de mapa a
  /// preservar: o mapa fica ao lado).
  double get panelTop => headerBottom + (wide ? Space.xs : mapBand);

  /// Altura disponível para o painel.
  double get panelArea => size.height - panelBottom - panelTop;
}

class _StopArrivalsPageState extends State<StopArrivalsPage>
    with WidgetsBindingObserver {
  static const _sheetMid = 0.56;
  static const _sheetMax = 1.0;

  /// Recolhido: só a alça e a linha de resumo do painel.
  static const _sheetMinPixels = _SheetTop.height + Space.xxs;

  final _stopController = TextEditingController();
  final _searchFocus = FocusNode();
  final _sheetController = DraggableScrollableController();
  final _sheetExtent = ValueNotifier<double>(_sheetMid);

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

  /// Planejador de viagens (só com catálogo); estado sobrevive à troca de aba.
  TripPlannerController? _plannerController;
  TripPlannerController? get _planner {
    final catalog = _catalog;
    if (catalog == null) return null;
    final current = _plannerController;
    if (current != null && identical(current.catalog, catalog)) return current;
    current?.removeListener(_onPlannerChanged);
    return _plannerController = TripPlannerController(catalog)
      ..addListener(_onPlannerChanged);
  }

  TripOption? _shownPlan;
  (String?, String?) _plannerEnds = (null, null);

  /// "Perto de mim" (só com catálogo): a posição vive só aqui, em memória.
  NearbyController? _nearbyController;
  NearbyController? get _nearby {
    final catalog = _catalog;
    if (catalog == null) return null;
    final current = _nearbyController;
    if (current != null && identical(current.catalog, catalog)) return current;
    current?.removeListener(_onNearbyChanged);
    return _nearbyController = NearbyController(catalog, widget.locationService)
      ..addListener(_onNearbyChanged);
  }

  /// Posição encontrada: o mapa mostra você e os pontos mais perto.
  void _onNearbyChanged() {
    if (!mounted) return;
    final nearby = _nearbyController!;
    setState(() {});
    final me = nearby.fix?.position;
    if (nearby.status != NearbyStatus.located || me == null) return;
    final around = [
      me,
      for (final near in nearby.stops.take(4)) ?stopPosition(near.stop),
    ];
    if (around.length == 1) {
      setState(() => _focus = MapFocus.point(++_focusSerial, me));
    } else {
      unawaited(
        _frame(
          GeoBounds.of(around),
          stillWanted: () => identical(nearby.fix?.position, me),
        ),
      );
    }
  }

  /// Alternativa escolhida: sai o trajeto de linha, entra a viagem
  /// enquadrada.
  void _onPlannerChanged() {
    if (!mounted) return;
    final planner = _plannerController!;
    final option = planner.active ? planner.selectedOption : null;
    final collapse = planner.selectionByUser;
    // Origem/destino recém-escolhidos: o mapa vai até o ponto.
    final ends = (planner.origin, planner.destination);
    final changed = ends.$1 != _plannerEnds.$1
        ? ends.$1
        : ends.$2 != _plannerEnds.$2
        ? ends.$2
        : null;
    _plannerEnds = ends;
    if (changed != null && option == null) _focusOnStop(changed);
    final reframe = planner.selectionSerial != _planSelectionSerial;
    _planSelectionSerial = planner.selectionSerial;
    setState(() {
      if (!identical(option, _shownPlan) || (reframe && option != null)) {
        _shownPlan = option;
        if (option != null) {
          _routeLine = null;
          _routeShape = null;
          unawaited(
            _frame(
              tripBounds(option),
              stillWanted: () => identical(_shownPlan, option),
              // Escolha do passageiro: prioriza o mapa. A 1ª alternativa,
              // escolhida pela busca, não esconde a lista.
              collapse: collapse,
            ),
          );
        }
      }
    });
  }

  /// Toque num ponto do mapa: preenche o campo do planejador, se ele estiver
  /// esperando; senão abre o ponto.
  void _onMapStopTap(String code) {
    if (_planner?.pickFromMap(code) ?? false) {
      _focusOnStop(code);
      return;
    }
    _openPreview(code);
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

  /// Mostra um trajeto oficial no mapa e enquadra a geometria. Com
  /// [collapse] (escolha explícita de Ida/Volta), recolhe o painel.
  Future<void> _showRoute(String shapeId, {bool collapse = false}) async {
    final catalog = _catalog;
    if (catalog == null) return;
    final shape = catalog.shapes.where((s) => s.id == shapeId).firstOrNull;
    if (shape == null) return;
    setState(() {
      _routeLine = shape.lineId;
      _routeShape = shape.id;
    });
    await _frame(
      GeoBounds.of(shape.points),
      stillWanted: () => _routeShape == shape.id,
      collapse: collapse,
    );
  }

  /// Enquadra [bounds] depois de o painel se acomodar (ele baixa ou encolhe
  /// com um trajeto/viagem no mapa; senão o enquadramento caberia numa
  /// faixa mínima).
  Future<void> _frame(
    GeoBounds bounds, {
    required bool Function() stillWanted,
    bool collapse = false,
  }) async {
    final target = collapse ? _sheetMinSize : _sheetMid;
    if (_sheetExtent.value > target + 0.01) {
      _animateSheet(target);
      // Sem await: se o conteúdo do painel troca no meio, a animação é
      // cancelada e o futuro dela nunca completa (o enquadramento ficaria
      // para sempre esperando).
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
    }
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !stillWanted()) return;
    setState(() => _focus = MapFocus.bounds(++_focusSerial, bounds));
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

  /// Abre a linha de um trajeto já com ele no mapa (contexto do ponto no
  /// itinerário estimado).
  void _openRoute(String shapeId) {
    final shape = _catalog?.shape(shapeId);
    if (shape == null) return;
    setState(() => _openLine = shape.lineId);
    _select(HomeTab.lines);
    unawaited(_showRoute(shapeId));
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
      // Inativo ainda está à vista: no Web é só a janela sem foco (outro
      // monitor, outra janela); no celular é passageiro (central de
      // controle) e sempre passa por "hidden" antes de sair da tela.
      case AppLifecycleState.inactive:
        return;
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
    _plannerController
      ?..removeListener(_onPlannerChanged)
      ..dispose();
    _nearbyController
      ?..removeListener(_onNearbyChanged)
      ..dispose();
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

  /// Salva (ou tira das salvas) a origem → destino do planejador.
  Future<void> _toggleSavedTrip(bool saved) async {
    final planner = _planner;
    if (planner == null) return;
    final cubit = context.read<SavedStopsCubit>();
    final from = planner.origin, to = planner.destination;
    if (saved) {
      if (from != null && to != null) await cubit.removeTrip(from, to);
      return;
    }
    final result = await cubit.saveTrip(from, to);
    if (!mounted) return;
    final message = switch (result) {
      TripSaveResult.saved => l10n.tripSavedNotice,
      TripSaveResult.limitReached => l10n.tripsLimit(defaultSavedTripsLimit),
      _ => null,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Abre uma viagem salva: o itinerário é recalculado agora, com o catálogo
  /// atual. Ponto que sumiu do catálogo vira aviso, não uma rota inventada.
  void _openTrip(SavedTrip trip) {
    final catalog = _catalog;
    final planner = _planner;
    if (catalog == null || planner == null) return;
    if (catalog.stop(trip.from) == null || catalog.stop(trip.to) == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.tripMissingStop)));
      return;
    }
    _select(HomeTab.plan);
    planner
      ..set(PlannerField.origin, trip.from)
      ..set(PlannerField.destination, trip.to)
      ..search();
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
    // A viagem planejada só fica no mapa com Planejar aberto; origem,
    // destino e resultados continuam guardados.
    _planner?.setActive(tab == HomeTab.plan);
    context.read<StopArrivalsCubit>().setArrivalsVisible(tab == HomeTab.stop);
    if (_sheetExtent.value < _sheetMid - 0.01) _animateSheet(_sheetMid);
  }

  /// Fração do painel recolhido (alça + resumo), conforme a tela atual.
  double _sheetMinSize = 0.12;

  /// Teclado aberto no último build (celular).
  bool _keyboardOpen = false;

  /// Rolagem da lista do painel (a alça e o resumo ficam no topo dela).
  ScrollController? _sheetScroll;

  /// Último "Ver no mapa" já enquadrado.
  int _planSelectionSerial = 0;

  void _animateSheet(double size) {
    if (!_sheetController.isAttached) return;
    // Recolhido só mostra o começo da lista: volta ao topo para a alça e o
    // resumo ficarem à vista (senão sobrava um pedaço cortado de um cartão).
    final scroll = _sheetScroll;
    if (size <= _sheetMinSize + 0.01 &&
        scroll != null &&
        scroll.hasClients &&
        scroll.offset > 0) {
      scroll.jumpTo(0);
    }
    final duration = motion(context, const Duration(milliseconds: 280));
    // animateTo não aceita duração zero (movimento reduzido): salta direto.
    if (duration == Duration.zero) return _sheetController.jumpTo(size);
    unawaited(
      _sheetController.animateTo(
        size,
        duration: duration,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  /// Alça e botão do painel: recolhido ↔ intermediário ↔ expandido.
  void _toggleSheet({bool toMap = false}) {
    final extent = _sheetExtent.value;
    if (toMap || extent > _sheetMid + 0.01) {
      _animateSheet(toMap ? _sheetMinSize : _sheetMid);
    } else if (extent < _sheetMid - 0.01) {
      _animateSheet(_sheetMid);
    } else {
      _animateSheet(_sheetMax);
    }
  }

  /// Voltar (gesto ou botão do sistema): desfaz o contexto mais recente antes
  /// de sair do app.
  bool get _canExit =>
      _tab == HomeTab.stop &&
      _previewStop == null &&
      !_searching &&
      _routeLine == null;

  void _handleBack() {
    if (_previewStop != null) return _closePreview();
    if (_searching) return _cancelSearch();
    if (_tab == HomeTab.lines && _openLine != null) {
      return _openLineDetail(null);
    }
    if (_tab == HomeTab.settings) return _closeSettings();
    if (_tab != HomeTab.stop) return _select(HomeTab.stop);
    if (_routeLine != null) _clearRoute();
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
    final tracking = context.select<StopArrivalsCubit, bool>(
      (c) =>
          c.state is StopArrivalsLoaded &&
          (c.state as StopArrivalsLoaded).tracking != null,
    );
    final showBar = tracking && _tab != HomeTab.tracking;
    final media = MediaQuery.of(context);
    // Ao abrir o teclado num campo do painel (celular), o painel vai à altura
    // máxima: acima do teclado cabem o campo e as primeiras sugestões.
    final keyboardOpen = media.viewInsets.bottom > 0;
    if (keyboardOpen != _keyboardOpen) {
      _keyboardOpen = keyboardOpen;
      if (keyboardOpen && _sheetExtent.value < _sheetMax - 0.01) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _keyboardOpen) _animateSheet(_sheetMax);
        });
      }
    }
    final geometry = _Geometry(
      media,
      dockItems: _catalog == null ? 3 : 4,
      trackingBar: showBar,
    );
    _sheetMinSize = _sheetMinFor(geometry);
    final styles = MapConfig.styles;
    final brightness = Theme.of(context).brightness;

    return PopScope(
      canPop: _canExit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
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
                  listenable: _sheetExtent,
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
                    plan: _shownPlan,
                    me: _nearbyController?.fix?.position,
                    onStopTap: _onMapStopTap,
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
                  child: _ColumnPanel(child: _panelContent()),
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
                      minChildSize: _sheetMinSize,
                      maxChildSize: _sheetMax,
                      snap: true,
                      snapSizes: const [_sheetMid],
                      builder: (context, scroll) => _SheetSurface(
                        scrollController: _sheetScroll = scroll,
                        // O resumo acompanha o estado das chegadas (carregando,
                        // erro, carregado) sem depender de outro rebuild.
                        top: BlocBuilder<StopArrivalsCubit, StopArrivalsState>(
                          builder: (context, _) =>
                              ValueListenableBuilder<double>(
                                valueListenable: _sheetExtent,
                                builder: (context, extent, _) => _SheetTop(
                                  summary: _sheetSummary(),
                                  collapsed: extent <= _sheetMinSize + 0.02,
                                  onToggle: _toggleSheet,
                                  onShowMap: () => _toggleSheet(toMap: true),
                                ),
                              ),
                        ),
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
                // Tela larga: no mapa, ao lado do painel lateral.
                left: geometry.wide
                    ? geometry.left + geometry.width + Chrome.gutter
                    : geometry.left,
                width: geometry.wide
                    ? math.min(
                        380,
                        geometry.size.width -
                            geometry.left -
                            geometry.width -
                            geometry.safe.right -
                            Chrome.gutter * 2,
                      )
                    : geometry.width,
                top: geometry.wide
                    ? geometry.top
                    : geometry.headerBottom + Space.xs,
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
              if (geometry.barTop case final barTop?)
                Positioned(
                  key: const ValueKey('tracking-bar-slot'),
                  left: geometry.left,
                  width: geometry.width,
                  top: barTop,
                  child: BlocBuilder<StopArrivalsCubit, StopArrivalsState>(
                    builder: (context, state) => switch (state) {
                      StopArrivalsLoaded(:final tracking?) => TrackingBar(
                        state: state,
                        tracking: tracking,
                        onOpen: () => _select(HomeTab.tracking),
                        onStop: _stopTracking,
                      ),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ),
              Positioned(
                key: const ValueKey('dock'),
                left: geometry.left,
                width: geometry.width,
                bottom: geometry.dockBottom,
                child: NavDock(
                  selected: _tab,
                  onSelected: _select,
                  showPlan: _catalog != null,
                  layout: geometry.dockLayout,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Resumo de uma linha no topo do painel (sempre visível, mesmo
  /// recolhido). Não repete o rótulo do dock: diz o que o painel contém.
  String _sheetSummary() {
    final state = context.read<StopArrivalsCubit>().state;
    return switch (_tab) {
      // O cabeçalho já diz "Ponto X": o resumo diz onde ele fica.
      HomeTab.stop when _previewStop != null =>
        _catalog?.stop(_previewStop)?.address ?? l10n.sheetSummaryStops,
      HomeTab.stop => switch (state) {
        StopArrivalsLoaded(:final stopId, :final arrivals) =>
          l10n.sheetSummaryStop(stopId, l10n.linesCount(arrivals.data.length)),
        StopArrivalsLoading(:final stopId?) => l10n.sheetSummaryStop(
          stopId,
          l10n.queryingArrivals,
        ),
        _ when _nearbyController?.status == NearbyStatus.located =>
          l10n.nearbySummary(_nearbyController!.stops.length),
        _ => l10n.sheetSummaryStops,
      },
      HomeTab.plan => switch (_planner?.plan) {
        final plan? when plan.options.isNotEmpty => l10n.plannerResultsTitle(
          plan.options.length,
        ),
        _ => l10n.sheetSummaryPlan,
      },
      HomeTab.lines =>
        _openLine == null
            ? l10n.sheetSummaryLines
            : l10n.sheetSummaryLine(_openLine!),
      HomeTab.saved => l10n.sheetSummarySaved,
      HomeTab.tracking => l10n.sheetSummaryTracking,
      HomeTab.settings => l10n.settingsSubtitle,
    };
  }

  double _sheetMinFor(_Geometry geometry) =>
      (_sheetMinPixels / geometry.panelArea).clamp(0.12, _sheetMid - 0.1);

  _MapLayout _mapLayout(_Geometry g) {
    if (g.wide) {
      // Painel lateral: o mapa visível é tudo à direita da coluna.
      final panelRight = g.left + g.width + Chrome.gutter;
      return _MapLayout(
        cameraPadding: EdgeInsets.fromLTRB(
          panelRight,
          g.top,
          Chrome.gutter + g.safe.right,
          Chrome.gutter,
        ),
        controlsPadding: EdgeInsets.only(
          top: g.top,
          right: Chrome.gutter + g.safe.right,
        ),
        attributionBottom: 0,
        showControls: true,
      );
    }
    final sheetTop =
        g.size.height - g.panelBottom - g.panelArea * _sheetExtent.value;
    final coveredBottom = g.size.height - sheetTop;
    final mapTop = g.headerBottom;
    final visible = g.size.height - coveredBottom - mapTop;

    return _MapLayout(
      cameraPadding: EdgeInsets.only(
        top: mapTop,
        bottom: math.min(coveredBottom, g.size.height * 0.75),
      ),
      // À direita, sob o cabeçalho.
      controlsPadding: EdgeInsets.only(
        top: mapTop + Space.sm,
        right: Chrome.gutter + g.safe.right,
      ),
      attributionBottom: coveredBottom,
      // Sem faixa de mapa suficiente o botão cobriria a atribuição; o
      // callout de outro ônibus ocupa o mesmo canto (o cartão de
      // acompanhamento mantém o próprio "Centralizar").
      showControls:
          visible >= 48 + Space.sm + _Geometry.mapBand &&
          _selectedSecondary == null,
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
                    ? l10n.seenLinesHeader
                    : l10n.catalogLinesHeaderSubtitle(_catalog!.lines.length),
              ),
            ),
          ),
          HomeTab.plan => (
            const ValueKey('header-plan'),
            ContextHeader(
              leading: const HeaderTile(Icons.alt_route_rounded),
              title: l10n.plannerTitle,
              subtitle: Text(l10n.plannerHeaderSubtitle),
            ),
          ),
          HomeTab.saved => (
            const ValueKey('header-saved'),
            ContextHeader(
              leading: const HeaderTile(
                Icons.bookmark_border_rounded,
                filled: false,
              ),
              title: l10n.dockSaved,
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
          duration: motion(context, const Duration(milliseconds: 220)),
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
          title: stop?.kind == CatalogStopKind.terminal
              ? stop!.address ?? preview
              : l10n.catalogStopTitle(preview),
          subtitle: Text(
            stop?.kind == CatalogStopKind.terminal
                ? l10n.catalogTerminalTag
                : stop?.place ?? stop?.address ?? l10n.catalogStopNotFound,
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
            Builder(
              builder: (button) => IconButton(
                key: const ValueKey('share-stop'),
                tooltip: l10n.shareStopAction,
                onPressed: () => shareText(
                  button,
                  stopShareText(stopId, stop: catalog?.stop(stopId)),
                ),
                icon: Icon(Icons.adaptive.share),
              ),
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
          above: switch (state) {
            StopArrivalsLoaded(:final stopId) when catalog != null =>
              CatalogStopFacts(catalog: catalog, stopId: stopId, compact: true),
            StopArrivalsInitial() when _nearby != null => NearbyStopsSection(
              controller: _nearby!,
              onOpenStop: _openPreview,
            ),
            _ => null,
          },
          below: RecentStopsSection(
            onOpen: _openStop,
            excludeCode: state is StopArrivalsLoaded ? state.stopId : null,
            showEmpty: state is StopArrivalsInitial,
          ),
        );
        final planner = _planner;
        final Widget child = switch (_tab) {
          HomeTab.plan when planner != null =>
            BlocSelector<SavedStopsCubit, SavedStopsState, bool>(
              selector: (saved) =>
                  saved.isSavedTrip(planner.origin, planner.destination),
              builder: (context, saved) => TripPlannerPanel(
                controller: planner,
                onOpenStop: _focusOnStop,
                saved: saved,
                onToggleSave: () => _toggleSavedTrip(saved),
              ),
            ),
          // Sem catálogo não há Planejar (o dock nem mostra a aba).
          HomeTab.plan => arrivals,
          HomeTab.stop when catalog != null && _previewStop != null =>
            StopPreview(
              key: ValueKey('preview-$_previewStop'),
              catalog: catalog,
              stopId: _previewStop!,
              onSeeArrivals: () => _openStop(_previewStop!),
              onOpenRoute: _openRoute,
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
                  officialRouteShown: _routeMatch(state)?.confirmed ?? false,
                ),
                if (_routeMatch(state) case final match?) ...[
                  const SizedBox(height: Space.sm),
                  RouteMatchNote(match: match),
                  const SizedBox(height: Space.sm),
                  NextStopsCard(
                    catalog: catalog!,
                    next: nextStopsFor(
                      match,
                      catalog.sequenceOf(match.shape?.id),
                    ),
                    onOpenStop: _openPreview,
                  ),
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
            onShowRoute: (id) => _showRoute(id, collapse: true),
            onClearRoute: _clearRoute,
            onOpenStop: _openPreview,
            now: _clock,
          ),
          HomeTab.lines => SeenLinesPanel(
            currentStopId: state is StopArrivalsLoaded ? state.stopId : null,
            currentGroups: state is StopArrivalsLoaded
                ? state.arrivals.data
                : const [],
            onOpen: _openStop,
            onSearchStop: _goToStopSearch,
          ),
          // Salvos: favoritos e, logo abaixo, os recentes.
          HomeTab.saved => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (catalog != null) ...[
                SavedTripsSection(catalog: catalog, onOpen: _openTrip),
              ],
              FavoritesPanel(
                onOpen: _openStop,
                onSearchStop: _goToStopSearch,
                connectionNotice: _connectionNotice(state),
              ),
              const SizedBox(height: Space.md),
              RecentStopsSection(
                onOpen: _openStop,
                excludeCode: state is StopArrivalsLoaded ? state.stopId : null,
                showEmpty: false,
                showHint: false,
                hideFavorites: true,
              ),
            ],
          ),
          HomeTab.settings => const SettingsPanel(),
        };
        return AnimatedSwitcher(
          duration: motion(context, const Duration(milliseconds: 220)),
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
    this.plan,
    this.me,
    this.onStopTap,
  });

  /// Posição do passageiro, só depois de "Perto de mim".
  final GeoPosition? me;

  /// Viagem planejada selecionada (só desenho; não é rastreamento).
  final TripOption? plan;

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
      plan: plan,
      me: me,
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

/// Bottom sheet flutuante (celular): superfície sólida, topo fixo (alça e
/// resumo) e lista rolável ligada ao [DraggableScrollableSheet].
class _SheetSurface extends StatelessWidget {
  const _SheetSurface({
    required this.scrollController,
    required this.top,
    required this.child,
  });

  final ScrollController scrollController;
  final Widget top;
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
          // O teclado já empurra o painel inteiro (`_Geometry.panelBottom`).
          padding: const EdgeInsets.fromLTRB(12, 0, 12, Space.md),
          children: [top, child],
        ),
      ),
    );
  }
}

/// Topo do painel: alça (toque alterna recolhido, intermediário e
/// expandido) e uma linha de resumo com "Ver mapa"/"Mostrar painel". Com o
/// painel recolhido, é o que fica à vista: o passageiro sempre sabe o que o
/// painel contém e como trazê-lo de volta.
class _SheetTop extends StatelessWidget {
  const _SheetTop({
    required this.summary,
    required this.collapsed,
    required this.onToggle,
    required this.onShowMap,
  });

  /// Altura fixa (o resumo e o botão escalam até 130%), para o painel
  /// recolhido ter sempre a mesma medida.
  static const height = 68.0;

  final String summary;
  final bool collapsed;
  final VoidCallback onToggle;
  final VoidCallback onShowMap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: Chrome.headerMaxTextScale,
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            FocusLink(
              onTap: onToggle,
              builder: (_, focus) => Semantics(
                button: true,
                label: l10n.panelHandleLabel,
                hint: collapsed ? l10n.sheetShowPanel : l10n.sheetHandleHint,
                onIncrease: collapsed ? onToggle : null,
                onDecrease: collapsed ? null : onShowMap,
                excludeSemantics: true,
                // Toque e foco no próprio nó: o excludeSemantics esconde os do
                // InkWell, e sem eles leitor de tela e Tab no Web não alcançam o botão.
                onTap: onToggle,
                focusable: true,
                focused: focus.focused,
                onFocus: focus.request,
                child: InkWell(
                  key: const ValueKey('sheet-handle'),
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  child: SizedBox(
                    width: 72,
                    height: 20,
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: tokens.strongText.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      summary,
                      key: const ValueKey('sheet-summary'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tokens.softText,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('sheet-toggle'),
                    onPressed: collapsed ? onToggle : onShowMap,
                    icon: Icon(
                      collapsed
                          ? Icons.expand_less_rounded
                          : Icons.map_outlined,
                      size: 18,
                    ),
                    label: Text(
                      collapsed ? l10n.sheetShowPanel : l10n.sheetShowMap,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painel lateral (tablet/desktop): altura inteira da coluna, conteúdo rola.
class _ColumnPanel extends StatelessWidget {
  const _ColumnPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: Radii.panel,
      solid: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, Space.md),
        children: [child],
      ),
    );
  }
}
