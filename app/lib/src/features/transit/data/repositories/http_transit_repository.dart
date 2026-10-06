import '../../../../core/network/api_client.dart';
import '../../domain/entities/arrival.dart';
import '../../domain/entities/tracked_vehicle.dart';
import '../../domain/models/transit_snapshot.dart';
import '../../domain/repositories/transit_repository.dart';

class HttpTransitRepository implements TransitRepository {
  const HttpTransitRepository(this._apiClient);

  final ApiClient _apiClient;

  TransitSnapshot<T> _snapshot<T>(
    Map<String, dynamic> response,
    T data,
  ) {
    final meta = response['meta'];
    final metadata = meta is Map<String, dynamic> ? meta : const <String, dynamic>{};

    return TransitSnapshot<T>(
      data: data,
      fetchedAt: DateTime.tryParse(metadata['fetchedAt']?.toString() ?? ''),
      stale: metadata['stale'] == true,
      ageSeconds: (metadata['ageSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<TransitSnapshot<List<ArrivalGroup>>> getArrivals(String stopId) async {
    final response = await _apiClient.getJson('/v1/stops/$stopId/arrivals');
    final data = response['data'];

    if (data is! List) {
      throw const FormatException('Expected arrival list.');
    }

    final arrivals = data
        .whereType<Map<String, dynamic>>()
        .map(ArrivalGroup.fromJson)
        .toList(growable: false);

    return _snapshot(response, arrivals);
  }

  @override
  Future<TransitSnapshot<TrackedVehicle?>> getVehiclePosition({
    required String vehicleNumber,
    required String stopId,
  }) async {
    final response = await _apiClient.getJson(
      '/v1/vehicles/$vehicleNumber/position',
      queryParameters: {'stopId': stopId},
    );

    final data = response['data'];
    if (data == null) return _snapshot<TrackedVehicle?>(response, null);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected tracked vehicle object.');
    }
    return _snapshot<TrackedVehicle?>(
      response,
      TrackedVehicle.fromJson(data),
    );
  }
}
