import '../entities/arrival.dart';
import '../entities/tracked_vehicle.dart';

abstract interface class TransitRepository {
  Future<List<ArrivalGroup>> getArrivals(String stopId);

  Future<TrackedVehicle?> getVehiclePosition({
    required String vehicleNumber,
    required String stopId,
  });
}
