import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/arrival.dart';
import '../../domain/entities/tracked_vehicle.dart';
import '../../domain/models/transit_snapshot.dart';
import '../../domain/repositories/transit_repository.dart';

sealed class StopArrivalsState {
  const StopArrivalsState();
}

final class StopArrivalsInitial extends StopArrivalsState {
  const StopArrivalsInitial();
}

final class StopArrivalsLoading extends StopArrivalsState {
  const StopArrivalsLoading();
}

final class StopArrivalsFailure extends StopArrivalsState {
  const StopArrivalsFailure(this.message);

  final String message;
}

final class StopArrivalsLoaded extends StopArrivalsState {
  const StopArrivalsLoaded({
    required this.stopId,
    required this.arrivals,
    this.trackedVehicle,
    this.trackingVehicleNumber,
    this.trackingError,
  });

  final String stopId;
  final TransitSnapshot<List<ArrivalGroup>> arrivals;
  final TransitSnapshot<TrackedVehicle?>? trackedVehicle;
  final String? trackingVehicleNumber;
  final String? trackingError;
}

class StopArrivalsCubit extends Cubit<StopArrivalsState> {
  StopArrivalsCubit(
    this._repository, {
    this.trackingRefreshInterval = const Duration(seconds: 15),
  }) : super(const StopArrivalsInitial());

  final TransitRepository _repository;
  final Duration? trackingRefreshInterval;

  Timer? _trackingTimer;
  String? _trackedVehicleNumber;
  String? _trackedStopId;
  bool _positionRequestInFlight = false;

  Future<void> load(String rawStopId) async {
    _clearTracking();

    final stopId = rawStopId.trim();
    if (!RegExp(r'^\d+$').hasMatch(stopId)) {
      emit(const StopArrivalsFailure('Informe um código de ponto válido.'));
      return;
    }

    emit(const StopArrivalsLoading());
    try {
      final arrivals = await _repository.getArrivals(stopId);
      emit(StopArrivalsLoaded(stopId: stopId, arrivals: arrivals));
    } on ApiException catch (error) {
      emit(StopArrivalsFailure(error.message));
    } on FormatException {
      emit(
        const StopArrivalsFailure(
          'A API retornou dados em formato inesperado.',
        ),
      );
    } catch (_) {
      emit(
        const StopArrivalsFailure(
          'Não foi possível consultar este ponto agora.',
        ),
      );
    }
  }

  Future<void> track(String vehicleNumber) async {
    final current = state;
    if (current is! StopArrivalsLoaded) return;

    _trackingTimer?.cancel();
    _trackedVehicleNumber = vehicleNumber;
    _trackedStopId = current.stopId;

    emit(
      StopArrivalsLoaded(
        stopId: current.stopId,
        arrivals: current.arrivals,
        trackedVehicle: current.trackedVehicle,
        trackingVehicleNumber: vehicleNumber,
      ),
    );

    await _refreshTrackedVehicle(showInitialError: true);
    _startTrackingTimer();
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
    final current = state;
    if (vehicleNumber == null ||
        stopId == null ||
        current is! StopArrivalsLoaded) {
      return;
    }

    _positionRequestInFlight = true;
    try {
      final vehicle = await _repository.getVehiclePosition(
        vehicleNumber: vehicleNumber,
        stopId: stopId,
      );

      final latest = state;
      if (latest is StopArrivalsLoaded &&
          _trackedVehicleNumber == vehicleNumber &&
          _trackedStopId == stopId) {
        emit(
          StopArrivalsLoaded(
            stopId: latest.stopId,
            arrivals: latest.arrivals,
            trackedVehicle: vehicle,
          ),
        );
      }
    } on ApiException catch (error) {
      _emitTrackingFailure(
        showInitialError
            ? error.message
            : 'Posição temporariamente indisponível.',
      );
    } catch (_) {
      _emitTrackingFailure(
        showInitialError
            ? 'Não foi possível localizar este ônibus agora.'
            : 'Posição temporariamente indisponível.',
      );
    } finally {
      _positionRequestInFlight = false;
    }
  }

  void _emitTrackingFailure(String message) {
    final latest = state;
    if (latest is! StopArrivalsLoaded) return;

    emit(
      StopArrivalsLoaded(
        stopId: latest.stopId,
        arrivals: latest.arrivals,
        trackedVehicle: latest.trackedVehicle,
        trackingError: message,
      ),
    );
  }

  void _clearTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _trackedVehicleNumber = null;
    _trackedStopId = null;
    _positionRequestInFlight = false;
  }

  @override
  Future<void> close() {
    _clearTracking();
    return super.close();
  }
}
