import 'tracked_vehicle.dart';

/// Estado visual de um marcador de ônibus no mapa. Vem só do estado da
/// posição e do acompanhamento, nunca de dado de frota.
enum MarkerVariant {
  /// Ônibus acompanhado: âmbar, maior, com halo.
  tracked,

  /// Outro ônibus em tempo real do ponto consultado: discreto.
  secondary,

  /// Posição antiga ou com falha recente (acompanhado ou não).
  stale,
}

/// Perfil visual de um veículo. Operadora, família do veículo e classe da
/// rede ficam `null` até existir fonte oficial (GTFS ou autorização da
/// RMTC); o prefixo do número do veículo não é usado para inferi-los.
class VehicleVisualProfile {
  const VehicleVisualProfile({
    required this.vehicleNumber,
    required this.markerVariant,
    this.operator,
    this.vehicleFamily,
    this.networkClass,
  });

  final String vehicleNumber;
  final String? operator;
  final String? vehicleFamily;
  final String? networkClass;
  final MarkerVariant markerVariant;
}

/// Um ônibus com posição real recebida da API, pronto para o mapa. Não
/// conhece detalhes da API nem do MapLibre.
class MapVehicle {
  const MapVehicle({
    required this.vehicleNumber,
    required this.position,
    required this.isTracked,
    required this.stale,
    required this.ageSeconds,
    this.routeId,
    this.destination,
  });

  final String vehicleNumber;
  final String? routeId;
  final String? destination;
  final GeoPosition position;
  final bool isTracked;
  final bool stale;
  final int ageSeconds;

  VehicleVisualProfile get visual => VehicleVisualProfile(
    vehicleNumber: vehicleNumber,
    markerVariant: stale
        ? MarkerVariant.stale
        : isTracked
        ? MarkerVariant.tracked
        : MarkerVariant.secondary,
  );
}
