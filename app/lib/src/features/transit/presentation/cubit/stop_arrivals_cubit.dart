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
  StopArrivalsCubit(this._repository) : super(const StopArrivalsInitial());

  final TransitRepository _repository;

  Future<void> load(String rawStopId) async {
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
      emit(const StopArrivalsFailure('A API retornou dados em formato inesperado.'));
    } catch (_) {
      emit(const StopArrivalsFailure('Não foi possível consultar este ponto agora.'));
    }
  }

  Future<void> track(String vehicleNumber) async {
    final current = state;
    if (current is! StopArrivalsLoaded) return;

    emit(
      StopArrivalsLoaded(
        stopId: current.stopId,
        arrivals: current.arrivals,
        trackedVehicle: current.trackedVehicle,
        trackingVehicleNumber: vehicleNumber,
      ),
    );

    try {
      final vehicle = await _repository.getVehiclePosition(
        vehicleNumber: vehicleNumber,
        stopId: current.stopId,
      );
      emit(
        StopArrivalsLoaded(
          stopId: current.stopId,
          arrivals: current.arrivals,
          trackedVehicle: vehicle,
        ),
      );
    } on ApiException catch (error) {
      emit(
        StopArrivalsLoaded(
          stopId: current.stopId,
          arrivals: current.arrivals,
          trackedVehicle: current.trackedVehicle,
          trackingError: error.message,
        ),
      );
    } catch (_) {
      emit(
        StopArrivalsLoaded(
          stopId: current.stopId,
          arrivals: current.arrivals,
          trackedVehicle: current.trackedVehicle,
          trackingError: 'Não foi possível localizar este ônibus agora.',
        ),
      );
    }
  }
}
