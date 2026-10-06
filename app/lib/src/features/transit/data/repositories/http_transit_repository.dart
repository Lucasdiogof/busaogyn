import '../../../../core/network/api_client.dart';
import '../../domain/entities/arrival.dart';
import '../../domain/entities/tracked_vehicle.dart';
import '../../domain/repositories/transit_repository.dart';

class HttpTransitRepository implements TransitRepository {
  const HttpTransitRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<ArrivalGroup>> getArrivals(String stopId) async {
    final response = await _apiClient.getJson('/v1/stops/$stopId/arrivals');
    final data = response['data'];

    if (data is! List) {
      throw const FormatException('Expected arrival list.');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(ArrivalGroup.fromJson)
        .toList(growable: false);
  }

  @override
  Future<TrackedVehicle?> getVehiclePosition({
    required String vehicleNumber,
    required String stopId,
  }) async {
    final response = await _apiClient.getJson(
      '/v1/vehicles/$vehicleNumber/position',
      queryParameters: {'stopId': stopId},
    );

    final data = response['data'];
    if (data == null) return null;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected tracked vehicle object.');
    }
    return TrackedVehicle.fromJson(data);
  }
}
