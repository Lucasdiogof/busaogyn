import '../entities/arrival.dart';
import '../entities/tracked_vehicle.dart';
import '../models/transit_snapshot.dart';

abstract interface class TransitRepository {
  Future<TransitSnapshot<List<ArrivalGroup>>> getArrivals(String stopId);

  Future<TransitSnapshot<TrackedVehicle?>> getVehiclePosition({
    required String vehicleNumber,
    required String stopId,
  });
}

/// Posições de vários ônibus de um ponto num só pedido. Opcional: sem ela,
/// cada ônibus é consultado com [TransitRepository.getVehiclePosition].
abstract interface class BatchVehiclePositions {
  /// Uma entrada por ônibus respondido; o que falhou na fonte fica de fora.
  /// Lança [BatchUnsupported] se a API ainda não tiver o lote.
  Future<Map<String, TransitSnapshot<TrackedVehicle?>>> getVehiclePositions({
    required String stopId,
    required List<String> vehicleNumbers,
  });
}

/// A API publicada não tem o endpoint em lote (Worker anterior).
class BatchUnsupported implements Exception {
  const BatchUnsupported();
}
