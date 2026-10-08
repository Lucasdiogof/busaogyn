import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/arrival.dart';
import '../../domain/entities/tracked_vehicle.dart';
import '../../domain/models/observed_movement.dart';
import '../../domain/models/transit_snapshot.dart';
import '../../domain/repositories/transit_repository.dart';
import '../formatters/error_messages.dart';
import '../formatters/search_feedback.dart';

export '../formatters/search_feedback.dart'
    show SearchFeedback, SearchFeedbackKind;

sealed class StopArrivalsState {
  const StopArrivalsState();
}

final class StopArrivalsInitial extends StopArrivalsState {
  const StopArrivalsInitial({this.searchError});

  /// Última busca falhou e ainda não há ponto carregado.
  final SearchFeedback? searchError;
}

final class StopArrivalsLoading extends StopArrivalsState {
  const StopArrivalsLoading({this.stopId});

  final String? stopId;
}

/// Fase do acompanhamento, sempre explícita: nenhuma falha deixa a UI
/// presa em "buscando".
enum TrackingPhase {
  /// Primeira posição ainda não respondeu.
  searching,

  /// Última consulta trouxe uma posição.
  active,

  /// A fonte respondeu sem posição utilizável para o ônibus (sem
  /// coordenada ou com dado inválido): não é falha de conexão.
  unavailable,

  /// Falha de conexão ou serviço; a última posição válida (se houver) é
  /// mantida.
  failing,
}

final class TrackingInfo {
  const TrackingInfo({
    required this.vehicleNumber,
    required this.phase,
    this.vehicle,
    this.receivedAt,
    this.message,
    this.movement = ObservedMovement.empty,
  });

  final String vehicleNumber;
  final TrackingPhase phase;

  /// Direção e rastro observados, só com posições reais deste ônibus nesta
  /// sessão; some ao trocar de ônibus ou parar o acompanhamento.
  final ObservedMovement movement;

  /// Último snapshot com posição válida do ônibus acompanhado.
  final TransitSnapshot<TrackedVehicle?>? vehicle;

  /// Relógio local de quando [vehicle] chegou, para envelhecer o
  /// `ageSeconds` da API sem inventar timestamp de GPS.
  final DateTime? receivedAt;
  final String? message;
}

final class StopArrivalsLoaded extends StopArrivalsState {
  const StopArrivalsLoaded({
    required this.stopId,
    required this.arrivals,
    this.arrivalsReceivedAt,
    this.tracking,
    this.refreshing = false,
    this.refreshError,
    this.searchingStopId,
    this.searchError,
  });

  final String stopId;
  final TransitSnapshot<List<ArrivalGroup>> arrivals;

  /// Relógio local de quando [arrivals] chegou.
  final DateTime? arrivalsReceivedAt;
  final TrackingInfo? tracking;
  final bool refreshing;

  /// Falha ao atualizar chegadas já exibidas; o conteúdo anterior continua.
  final String? refreshError;

  /// Outro ponto sendo buscado; este continua na tela até a busca dar certo.
  final String? searchingStopId;

  /// A busca de outro ponto falhou; este ponto continua válido na tela.
  final SearchFeedback? searchError;

  String? get trackingVehicleNumber => tracking?.vehicleNumber;
  TransitSnapshot<TrackedVehicle?>? get trackedVehicle => tracking?.vehicle;
  String? get trackingError => tracking?.message;
  TrackingPhase? get trackingPhase => tracking?.phase;

  StopArrivalsLoaded copyWith({
    TransitSnapshot<List<ArrivalGroup>>? arrivals,
    DateTime? arrivalsReceivedAt,
    TrackingInfo? Function()? tracking,
    bool? refreshing,
    String? Function()? refreshError,
    String? Function()? searchingStopId,
    SearchFeedback? Function()? searchError,
  }) {
    return StopArrivalsLoaded(
      stopId: stopId,
      arrivals: arrivals ?? this.arrivals,
      arrivalsReceivedAt: arrivalsReceivedAt ?? this.arrivalsReceivedAt,
      tracking: tracking != null ? tracking() : this.tracking,
      refreshing: refreshing ?? this.refreshing,
      refreshError: refreshError != null ? refreshError() : this.refreshError,
      searchingStopId: searchingStopId != null
          ? searchingStopId()
          : this.searchingStopId,
      searchError: searchError != null ? searchError() : this.searchError,
    );
  }
}

class StopArrivalsCubit extends Cubit<StopArrivalsState> {
  StopArrivalsCubit(
    this._repository, {
    this.trackingRefreshInterval = const Duration(seconds: 15),
    this.arrivalsRefreshInterval = const Duration(seconds: 30),
    this.resumeRefreshAfter = const Duration(seconds: 10),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const StopArrivalsInitial());

  final TransitRepository _repository;
  final Duration? trackingRefreshInterval;

  /// Atualização automática das chegadas, só com a aba Chegadas visível e o
  /// app em primeiro plano; `null` desliga.
  final Duration? arrivalsRefreshInterval;

  /// Intervalo mínimo para uma consulta imediata ao retomar o app.
  final Duration resumeRefreshAfter;
  final DateTime Function() _clock;

  Timer? _trackingTimer;

  /// App em segundo plano: nenhuma consulta que termine depois disso pode
  /// religar um timer; só [resume] o faz.
  bool _paused = false;
  String? _trackedVehicleNumber;
  String? _trackedStopId;
  bool _positionRequestInFlight = false;
  DateTime? _lastPositionAttemptAt;

  /// Incrementado a cada novo tracking; respostas de gerações anteriores são
  /// descartadas.
  int _trackingGeneration = 0;

  /// Incrementado a cada consulta de chegadas; só a mais recente é aplicada.
  int _arrivalsGeneration = 0;

  /// Único timer das chegadas: um disparo agendado para
  /// [arrivalsRefreshInterval] depois da última consulta concluída. Não
  /// existe enquanto uma consulta está em voo.
  Timer? _arrivalsTimer;

  /// Aba Chegadas visível (informado pela página).
  bool _arrivalsVisible = false;

  /// Fim da última consulta de chegadas (sucesso ou falha), no relógio local.
  DateTime? _arrivalsCycleAt;

  /// Consulta de atualização em voo, compartilhada por automático e manual.
  Future<void>? _refreshInFlight;
  Object? _refreshToken;

  /// O usuário pediu (ou entrou na) atualização em voo: falha vira aviso.
  bool _refreshManual = false;

  /// Busca um ponto. Repetir o ponto já exibido equivale a [refresh] e
  /// preserva o acompanhamento. Outro ponto só substitui o atual (e encerra
  /// o tracking) quando a busca dá certo; uma falha vira [SearchFeedback]
  /// compacto sem apagar o que já estava na tela.
  Future<void> load(String rawStopId) async {
    final stopId = rawStopId.trim();
    if (!RegExp(r'^\d+$').hasMatch(stopId)) {
      _arrivalsGeneration++;
      _forgetRefresh();
      _emitSearchError(SearchFeedback.invalidCode);
      _armArrivals();
      return;
    }

    final current = state;
    if (current is StopArrivalsLoaded && current.stopId == stopId) {
      return refresh();
    }

    final generation = ++_arrivalsGeneration;
    _forgetRefresh();
    if (current is StopArrivalsLoaded) {
      emit(
        current.copyWith(
          // Uma atualização em voo deste ponto perde para a busca nova.
          refreshing: false,
          searchingStopId: () => stopId,
          searchError: () => null,
        ),
      );
    } else {
      emit(StopArrivalsLoading(stopId: stopId));
    }
    // Durante a busca o ponto atual não se atualiza sozinho.
    _armArrivals();
    try {
      final arrivals = await _repository.getArrivals(stopId);
      if (generation != _arrivalsGeneration) return;
      _clearTracking();
      _arrivalsCycleAt = _clock();
      emit(
        StopArrivalsLoaded(
          stopId: stopId,
          arrivals: arrivals,
          arrivalsReceivedAt: _arrivalsCycleAt,
        ),
      );
      _armArrivals();
    } catch (error) {
      if (generation != _arrivalsGeneration) return;
      _emitSearchError(SearchFeedback.fromError(error, stopId));
      // O ponto anterior (se houver) retoma o próprio ciclo.
      _armArrivals();
    }
  }

  /// Some o retorno de erro da busca (por exemplo, ao editar o código).
  void clearSearchError() {
    final current = state;
    if (current is StopArrivalsInitial && current.searchError != null) {
      emit(const StopArrivalsInitial());
    } else if (current is StopArrivalsLoaded && current.searchError != null) {
      emit(current.copyWith(searchError: () => null));
    }
  }

  void _emitSearchError(SearchFeedback feedback) {
    final current = state;
    if (current is StopArrivalsLoaded) {
      emit(
        current.copyWith(
          refreshing: false,
          searchingStopId: () => null,
          searchError: () => feedback,
        ),
      );
    } else {
      emit(StopArrivalsInitial(searchError: feedback));
    }
  }

  /// Atualiza as chegadas do ponto atual sem mexer no acompanhamento.
  /// Pedido do usuário: mostra "atualizando" e, se falhar, um aviso. Se a
  /// atualização automática já está em voo, reaproveita a mesma consulta.
  Future<void> refresh() => _refreshArrivals(manual: true);

  /// Aba Chegadas visível ou não. Ao voltar para ela, dado com mais de
  /// [arrivalsRefreshInterval] é atualizado na hora.
  void setArrivalsVisible(bool visible) {
    if (_arrivalsVisible == visible) return;
    _arrivalsVisible = visible;
    _armArrivals();
  }

  Future<void> _refreshArrivals({required bool manual}) {
    final current = state;
    if (current is! StopArrivalsLoaded) return Future.value();
    if (manual) {
      _refreshManual = true;
      emit(
        current.copyWith(
          refreshing: true,
          refreshError: () => null,
          searchingStopId: () => null,
          searchError: () => null,
        ),
      );
    } else if (!_autoRefreshAllowed) {
      return Future.value();
    }

    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    _arrivalsTimer?.cancel();
    _arrivalsTimer = null;
    final stopId = current.stopId;
    final generation = ++_arrivalsGeneration;
    final token = _refreshToken = Object();

    Future<void> run() async {
      try {
        final arrivals = await _repository.getArrivals(stopId);
        final latest = state;
        if (generation != _arrivalsGeneration ||
            latest is! StopArrivalsLoaded ||
            latest.stopId != stopId) {
          return;
        }
        emit(
          latest.copyWith(
            arrivals: arrivals,
            arrivalsReceivedAt: _clock(),
            refreshing: false,
            refreshError: () => null,
          ),
        );
      } catch (error) {
        final latest = state;
        if (generation != _arrivalsGeneration ||
            latest is! StopArrivalsLoaded ||
            latest.stopId != stopId) {
          return;
        }
        // Falha isolada do automático: os dados anteriores ficam, sem aviso;
        // a próxima tentativa é só no intervalo normal.
        if (_refreshManual) {
          emit(
            latest.copyWith(
              refreshing: false,
              refreshError: () => _arrivalsMessage(error),
            ),
          );
        }
      } finally {
        if (identical(_refreshToken, token)) {
          _forgetRefresh();
          _arrivalsCycleAt = _clock();
          _armArrivals();
        }
      }
    }

    final future = run();
    // Se a consulta já terminou (erro síncrono), não fica marcada em voo.
    if (identical(_refreshToken, token)) _refreshInFlight = future;
    return future;
  }

  bool get _autoRefreshAllowed {
    final current = state;
    return arrivalsRefreshInterval != null &&
        _arrivalsVisible &&
        !_paused &&
        current is StopArrivalsLoaded &&
        current.searchingStopId == null;
  }

  /// (Re)agenda o único timer das chegadas, ou atualiza na hora se o dado
  /// já passou do intervalo. Sem condição para rodar, só cancela.
  void _armArrivals() {
    _arrivalsTimer?.cancel();
    _arrivalsTimer = null;
    final interval = arrivalsRefreshInterval;
    if (interval == null || !_autoRefreshAllowed || _refreshInFlight != null) {
      return;
    }
    final now = _clock();
    final last = _arrivalsCycleAt ?? now;
    final wait = interval - now.difference(last);
    if (wait <= Duration.zero) {
      unawaited(_refreshArrivals(manual: false));
      return;
    }
    _arrivalsTimer = Timer(wait, () {
      _arrivalsTimer = null;
      unawaited(_refreshArrivals(manual: false));
    });
  }

  /// A atualização em voo deixa de valer (a geração já foi trocada).
  void _forgetRefresh() {
    _refreshInFlight = null;
    _refreshToken = null;
    _refreshManual = false;
  }

  Future<void> track(String vehicleNumber) async {
    final current = state;
    if (current is! StopArrivalsLoaded) return;

    _trackingTimer?.cancel();
    final switching = _trackedVehicleNumber != vehicleNumber;
    _trackedVehicleNumber = vehicleNumber;
    _trackedStopId = current.stopId;
    _trackingGeneration++;
    // Uma requisição do veículo anterior não pode bloquear a do novo.
    _positionRequestInFlight = false;

    final previous = current.tracking;
    emit(
      current.copyWith(
        tracking: () => TrackingInfo(
          vehicleNumber: vehicleNumber,
          // Ao trocar de ônibus, a posição do anterior não pode aparecer como
          // se fosse a do novo.
          phase: switching || previous?.vehicle == null
              ? TrackingPhase.searching
              : previous!.phase,
          vehicle: switching ? null : previous?.vehicle,
          receivedAt: switching ? null : previous?.receivedAt,
          movement: switching
              ? ObservedMovement.empty
              : previous?.movement ?? ObservedMovement.empty,
        ),
      ),
    );

    await _refreshTrackedVehicle(showInitialError: true);
    _startTrackingTimer();
  }

  void stopTracking() {
    _clearTracking();
    final current = state;
    if (current is StopArrivalsLoaded && current.tracking != null) {
      emit(current.copyWith(tracking: () => null));
    }
  }

  /// App em segundo plano: para os timers do acompanhamento e das chegadas.
  void pause() {
    _paused = true;
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _armArrivals();
  }

  /// Ao voltar ao app: o acompanhamento consulta na hora só se a última
  /// tentativa já tem [resumeRefreshAfter], e as chegadas só se passaram de
  /// [arrivalsRefreshInterval]; alternar janelas rapidamente não gera rajada.
  Future<void> resume() async {
    _paused = false;
    _armArrivals();
    if (_trackedVehicleNumber == null || _trackedStopId == null) return;
    final last = _lastPositionAttemptAt;
    if (last == null || _clock().difference(last) >= resumeRefreshAfter) {
      await _refreshTrackedVehicle(showInitialError: false);
    }
    _startTrackingTimer();
  }

  void _startTrackingTimer() {
    final interval = trackingRefreshInterval;
    if (interval == null || _paused || _trackedVehicleNumber == null) return;

    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(interval, (_) {
      unawaited(_refreshTrackedVehicle(showInitialError: false));
    });
  }

  Future<void> _refreshTrackedVehicle({required bool showInitialError}) async {
    if (_positionRequestInFlight) return;

    final vehicleNumber = _trackedVehicleNumber;
    final stopId = _trackedStopId;
    if (vehicleNumber == null ||
        stopId == null ||
        state is! StopArrivalsLoaded) {
      return;
    }

    final generation = _trackingGeneration;
    _positionRequestInFlight = true;
    _lastPositionAttemptAt = _clock();
    try {
      final snapshot = await _repository.getVehiclePosition(
        vehicleNumber: vehicleNumber,
        stopId: stopId,
      );
      if (snapshot.data?.position == null) {
        _emitTracking(
          generation,
          (previous) => TrackingInfo(
            vehicleNumber: vehicleNumber,
            phase: TrackingPhase.unavailable,
            vehicle: previous?.vehicle,
            receivedAt: previous?.receivedAt,
            message: 'A fonte não informou a posição deste ônibus agora.',
            movement: previous?.movement ?? ObservedMovement.empty,
          ),
        );
      } else {
        _emitTracking(
          generation,
          (previous) => TrackingInfo(
            vehicleNumber: vehicleNumber,
            phase: TrackingPhase.active,
            vehicle: snapshot,
            receivedAt: _clock(),
            // Só posições reais entram; stale/repetidas são ignoradas.
            movement:
                (previous?.vehicleNumber == vehicleNumber
                        ? previous!.movement
                        : ObservedMovement.empty)
                    .observe(
                      snapshot.data!.position!,
                      sampledAt: snapshot.fetchedAt,
                      stale: snapshot.stale,
                    ),
          ),
        );
      }
    } catch (error) {
      // Resposta sem dado utilizável do ônibus não é "conexão instável".
      final connectivity = isConnectivityError(error);
      final message = !connectivity
          ? 'A fonte não informou a posição deste ônibus agora.'
          : showInitialError
          ? friendlyErrorMessage(error, ErrorSubject.position)
          : 'Posição temporariamente indisponível.';
      _emitTracking(
        generation,
        (previous) => TrackingInfo(
          vehicleNumber: vehicleNumber,
          // Mantém a última posição válida do mesmo ônibus.
          phase: connectivity
              ? TrackingPhase.failing
              : TrackingPhase.unavailable,
          vehicle: previous?.vehicle,
          receivedAt: previous?.receivedAt,
          message: message,
          movement: previous?.movement ?? ObservedMovement.empty,
        ),
      );
    } finally {
      if (generation == _trackingGeneration) _positionRequestInFlight = false;
    }
  }

  void _emitTracking(
    int generation,
    TrackingInfo Function(TrackingInfo? previous) build,
  ) {
    final latest = state;
    if (latest is! StopArrivalsLoaded || generation != _trackingGeneration) {
      return;
    }
    emit(latest.copyWith(tracking: () => build(latest.tracking)));
  }

  String _arrivalsMessage(Object error) =>
      friendlyErrorMessage(error, ErrorSubject.arrivals);

  void _clearTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _trackedVehicleNumber = null;
    _trackedStopId = null;
    _positionRequestInFlight = false;
    _trackingGeneration++;
  }

  @override
  Future<void> close() {
    // Consultas de chegadas em voo não emitem depois de fechar.
    _arrivalsGeneration++;
    _arrivalsTimer?.cancel();
    _arrivalsTimer = null;
    _forgetRefresh();
    _clearTracking();
    return super.close();
  }
}
