import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/transit_repository.dart';
import 'route_vehicles_state.dart';

final class RouteVehiclesCubit extends Cubit<RouteVehiclesState> {
  RouteVehiclesCubit({
    required TransitRepository repository,
    this.refreshInterval = const Duration(seconds: 15),
  })  : _repository = repository,
        super(const RouteVehiclesState());

  final TransitRepository _repository;
  final Duration refreshInterval;

  Timer? _timer;
  bool _refreshInFlight = false;
  String? _routeId;

  Future<void> start(String routeId) async {
    _routeId = routeId;
    _timer?.cancel();

    if (state.snapshot == null) {
      emit(state.copyWith(
        status: RouteVehiclesStatus.loading,
        clearError: true,
      ));
    }

    await refresh();
    _timer = Timer.periodic(refreshInterval, (_) => unawaited(refresh()));
  }

  Future<void> refresh() async {
    final routeId = _routeId;
    if (routeId == null || _refreshInFlight) return;

    _refreshInFlight = true;
    try {
      final snapshot = await _repository.getVehicles(routeId: routeId);
      emit(state.copyWith(
        status: snapshot.stale
            ? RouteVehiclesStatus.stale
            : RouteVehiclesStatus.ready,
        snapshot: snapshot,
        clearError: true,
      ));
    } on Object catch (error) {
      emit(state.copyWith(
        status: state.snapshot == null
            ? RouteVehiclesStatus.failure
            : RouteVehiclesStatus.stale,
        error: error,
      ));
    } finally {
      _refreshInFlight = false;
    }
  }

  void selectVehicle(String vehicleId) {
    emit(state.copyWith(selectedVehicleId: vehicleId));
  }

  void clearSelection() {
    emit(state.copyWith(clearSelection: true));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
