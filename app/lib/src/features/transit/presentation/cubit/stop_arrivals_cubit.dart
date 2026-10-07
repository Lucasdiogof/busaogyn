import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/arrival.dart';
import '../../domain/entities/tracked_vehicle.dart';
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

  /// A fonte respondeu, mas sem posição para o ônibus.
  unavailable,

  /// A última consulta falhou; a última posição válida (se houver) é mantida.
  failing,
}

final class TrackingInfo {
  const TrackingInfo({
    required this.vehicleNumber,
    required this.phase,
    this.vehicle,
    this.receivedAt,
    this.message,
  });

  final String vehicleNumber;
  final TrackingPhase phase;

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
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const StopArrivalsInitial());

  final TransitRepository _repository;
  final Duration? trackingRefreshInterval;
  final DateTime Function() _clock;

  Timer? _trackingTimer;
  String? _trackedVehicleNumber;
  String? _trackedStopId;
  bool _positionRequestInFlight = false;

  /// Incrementado a cada novo tracking; respostas de gerações anteriores são
  /// descartadas.
  int _trackingGeneration = 0;

  /// Incrementado a cada consulta de chegadas; só a mais recente é aplicada.
  int _arrivalsGeneration = 0;

  /// Busca um ponto. Repetir o ponto já exibido equivale a [refresh] e
  /// preserva o acompanhamento. Outro ponto só substitui o atual (e encerra
  /// o tracking) quando a busca dá certo; uma falha vira [SearchFeedback]
  /// compacto sem apagar o que já estava na tela.
  Future<void> load(String rawStopId) async {
    final stopId = rawStopId.trim();
    if (!RegExp(r'^\d+$').hasMatch(stopId)) {
      _arrivalsGeneration++;
      _emitSearchError(SearchFeedback.invalidCode);
      return;
    }

    final current = state;
    if (current is StopArrivalsLoaded && current.stopId == stopId) {
      return refresh();
    }

    final generation = ++_arrivalsGeneration;
    if (current is StopArrivalsLoaded) {
      emit(
        current.copyWith(
          searchingStopId: () => stopId,
          searchError: () => null,
        ),
      );
    } else {
      emit(StopArrivalsLoading(stopId: stopId));
    }
    try {
      final arrivals = await _repository.getArrivals(stopId);
      if (generation != _arrivalsGeneration) return;
      _clearTracking();
      emit(
        StopArrivalsLoaded(
          stopId: stopId,
          arrivals: arrivals,
          arrivalsReceivedAt: _clock(),
        ),
      );
    } catch (error) {
      if (generation != _arrivalsGeneration) return;
      _emitSearchError(SearchFeedback.fromError(error, stopId));
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
          searchingStopId: () => null,
          searchError: () => feedback,
        ),
      );
    } else {
      emit(StopArrivalsInitial(searchError: feedback));
    }
  }

  /// Atualiza as chegadas do ponto atual sem mexer no acompanhamento.
  Future<void> refresh() async {
    final current = state;
    if (current is! StopArrivalsLoaded || current.refreshing) return;

    final stopId = current.stopId;
    final generation = ++_arrivalsGeneration;
    emit(
      current.copyWith(
        refreshing: true,
        refreshError: () => null,
        searchingStopId: () => null,
        searchError: () => null,
      ),
    );
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
        ),
      );
    } catch (error) {
      final latest = state;
      if (generation != _arrivalsGeneration ||
          latest is! StopArrivalsLoaded ||
          latest.stopId != stopId) {
        return;
      }
      emit(
        latest.copyWith(
          refreshing: false,
          refreshError: () => _arrivalsMessage(error),
        ),
      );
    }
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

  void pauseTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }

  Future<void> resumeTracking() async {
    if (_trackedVehicleNumber == null || _trackedStopId == null) return;
    await _refreshTrackedVehicle(showInitialError: false);
    _startTrackingTimer();
  }

  void _startTrackingTimer() {
    final interval = trackingRefreshInterval;
    if (interval == null || _trackedVehicleNumber == null) return;

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
          ),
        );
      } else {
        _emitTracking(
          generation,
          (_) => TrackingInfo(
            vehicleNumber: vehicleNumber,
            phase: TrackingPhase.active,
            vehicle: snapshot,
            receivedAt: _clock(),
          ),
        );
      }
    } catch (error) {
      final message = showInitialError
          ? friendlyErrorMessage(error, ErrorSubject.position)
          : 'Posição temporariamente indisponível.';
      _emitTracking(
        generation,
        (previous) => TrackingInfo(
          vehicleNumber: vehicleNumber,
          // Mantém a última posição válida do mesmo ônibus.
          phase: TrackingPhase.failing,
          vehicle: previous?.vehicle,
          receivedAt: previous?.receivedAt,
          message: message,
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
    _clearTracking();
    return super.close();
  }
}
