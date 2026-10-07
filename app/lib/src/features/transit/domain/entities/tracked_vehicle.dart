enum VehiclePunctuality {
  onTime,
  delayed,
  early,
  unknown;

  static VehiclePunctuality fromJson(Object? value) {
    return switch (value) {
      'on_time' => VehiclePunctuality.onTime,
      'delayed' => VehiclePunctuality.delayed,
      'early' => VehiclePunctuality.early,
      _ => VehiclePunctuality.unknown,
    };
  }
}

class GeoPosition {
  const GeoPosition({required this.latitude, required this.longitude});

  factory GeoPosition.fromJson(Map<String, dynamic> json) {
    return GeoPosition(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  final double latitude;
  final double longitude;
}

class TrackedVehicle {
  const TrackedVehicle({
    required this.id,
    required this.vehicleNumber,
    required this.routeId,
    required this.routeName,
    required this.destination,
    required this.position,
    required this.accessible,
    required this.punctuality,
  });

  factory TrackedVehicle.fromJson(Map<String, dynamic> json) {
    final position = json['position'];
    final punctuality = json['punctuality'];

    return TrackedVehicle(
      id: json['id'] as String,
      vehicleNumber: json['vehicleNumber'] as String,
      routeId: json['routeId'] as String?,
      routeName: json['routeName'] as String?,
      destination: json['destination'] as String?,
      position: position is Map<String, dynamic>
          ? GeoPosition.fromJson(position)
          : null,
      accessible: json['accessible'] as bool?,
      punctuality: punctuality is Map<String, dynamic>
          ? VehiclePunctuality.fromJson(punctuality['status'])
          : VehiclePunctuality.unknown,
    );
  }

  final String id;
  final String vehicleNumber;
  final String? routeId;
  final String? routeName;
  final String? destination;
  final GeoPosition? position;
  final bool? accessible;
  final VehiclePunctuality punctuality;
}
