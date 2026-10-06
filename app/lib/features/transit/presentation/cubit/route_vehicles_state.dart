import '../../domain/entities/vehicle.dart';

enum RouteVehiclesStatus {
  initial,
  loading,
  ready,
  stale,
  failure,
}

final class RouteVehiclesState {
  const RouteVehiclesState({
    this.status = RouteVehiclesStatus.initial,
    this.snapshot,
    this.selectedVehicleId,
    this.error,
  });

  final RouteVehiclesStatus status;
  final VehicleSnapshot? snapshot;
  final String? selectedVehicleId;
  final Object? error;

  Vehicle? get selectedVehicle {
    final id = selectedVehicleId;
    final current = snapshot;
    if (id == null || current == null) return null;

    for (final vehicle in current.vehicles) {
      if (vehicle.id == id) return vehicle;
    }
    return null;
  }

  RouteVehiclesState copyWith({
    RouteVehiclesStatus? status,
    VehicleSnapshot? snapshot,
    String? selectedVehicleId,
    bool clearSelection = false,
    Object? error,
    bool clearError = false,
  }) {
    return RouteVehiclesState(
      status: status ?? this.status,
      snapshot: snapshot ?? this.snapshot,
      selectedVehicleId: clearSelection
          ? null
          : selectedVehicleId ?? this.selectedVehicleId,
      error: clearError ? null : error ?? this.error,
    );
  }
}
