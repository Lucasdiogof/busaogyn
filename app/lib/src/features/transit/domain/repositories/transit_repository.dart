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
