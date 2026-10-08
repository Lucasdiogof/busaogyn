import 'json_fields.dart';

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

  /// `null` quando falta coordenada ou ela está fora do intervalo válido:
  /// sem posição não há marcador, nunca um ponto inventado.
  static GeoPosition? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    if (latitude is! num || longitude is! num) return null;
    if (!latitude.isFinite || !longitude.isFinite) return null;
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;
    return GeoPosition(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
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

  /// Sem `id` ou número de veículo: [FormatException].
  factory TrackedVehicle.fromJson(Map<String, dynamic> json) {
    final id = jsonString(json['id']);
    final vehicleNumber = jsonVehicleNumber(json['vehicleNumber']);
    if (id == null || vehicleNumber == null) {
      throw const FormatException('Tracked vehicle without id or number.');
    }
    final punctuality = json['punctuality'];
    final accessible = json['accessible'];

    return TrackedVehicle(
      id: id,
      vehicleNumber: vehicleNumber,
      routeId: jsonString(json['routeId']),
      routeName: jsonString(json['routeName']),
      destination: jsonString(json['destination']),
      position: GeoPosition.tryFromJson(json['position']),
      accessible: accessible is bool ? accessible : null,
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
