import '../entities/arrival.dart';
import '../entities/vehicle.dart';

abstract interface class TransitRepository {
  Future<VehicleSnapshot> getVehicles({String? routeId});

  Future<ArrivalSnapshot> getArrivals(String stopId);
}
