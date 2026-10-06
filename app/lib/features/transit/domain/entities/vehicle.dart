enum VehicleStatus {
  inService,
  interval,
  outOfService,
  unknown,
}

final class VehiclePosition {
  const VehiclePosition({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

final class Vehicle {
  const Vehicle({
    required this.id,
    required this.vehicleNumber,
    required this.routeId,
    required this.destination,
    required this.position,
    required this.accessible,
    required this.status,
  });

  final String id;
  final String vehicleNumber;
  final String? routeId;
  final String? destination;
  final VehiclePosition? position;
  final bool? accessible;
  final VehicleStatus status;
}

final class VehicleSnapshot {
  const VehicleSnapshot({
    required this.vehicles,
    required this.fetchedAt,
    required this.stale,
    required this.ageSeconds,
  });

  final List<Vehicle> vehicles;
  final DateTime fetchedAt;
  final bool stale;
  final int ageSeconds;
}
