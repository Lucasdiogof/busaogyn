import 'dart:math' as math;

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/arrival.dart';
import '../../domain/entities/json_fields.dart';
import '../../domain/entities/tracked_vehicle.dart';
import '../../domain/models/transit_snapshot.dart';
import '../../domain/repositories/transit_repository.dart';

class HttpTransitRepository
    implements TransitRepository, BatchVehiclePositions {
  const HttpTransitRepository(this._apiClient);

  final ApiClient _apiClient;

  TransitSnapshot<T> _snapshot<T>(Map<String, dynamic> response, T data) {
    final meta = response['meta'];
    final metadata = meta is Map<String, dynamic>
        ? meta
        : const <String, dynamic>{};

    return TransitSnapshot<T>(
      data: data,
      fetchedAt: DateTime.tryParse(metadata['fetchedAt']?.toString() ?? ''),
      stale: metadata['stale'] == true,
      ageSeconds: math.max(0, jsonInt(metadata['ageSeconds']) ?? 0),
    );
  }

  @override
  Future<TransitSnapshot<List<ArrivalGroup>>> getArrivals(String stopId) async {
    final response = await _apiClient.getJson('/v1/stops/$stopId/arrivals');
    final data = response['data'];

    if (data is! List) {
      throw const FormatException('Expected arrival list.');
    }

    // Um grupo malformado é descartado sem derrubar as outras linhas.
    final arrivals = <ArrivalGroup>[
      for (final item in data.whereType<Map<String, dynamic>>())
        ?_tryGroup(item),
    ];

    return _snapshot(response, arrivals);
  }

  static ArrivalGroup? _tryGroup(Map<String, dynamic> json) {
    try {
      return ArrivalGroup.fromJson(json);
    } on FormatException {
      return null;
    }
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
    return _snapshot<TrackedVehicle?>(response, TrackedVehicle.fromJson(data));
  }

  @override
  Future<Map<String, TransitSnapshot<TrackedVehicle?>>> getVehiclePositions({
    required String stopId,
    required List<String> vehicleNumbers,
  }) async {
    final Map<String, dynamic> response;
    try {
      response = await _apiClient.getJson(
        '/v1/stops/$stopId/vehicle-positions',
        queryParameters: {'vehicles': vehicleNumbers.join(',')},
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404 && error.code == 'NOT_FOUND') {
        throw const BatchUnsupported();
      }
      rethrow;
    }
    final data = response['data'];
    if (data is! List) {
      throw const FormatException('Expected vehicle position list.');
    }
    final results = <String, TransitSnapshot<TrackedVehicle?>>{};
    for (final item in data.whereType<Map<String, dynamic>>()) {
      final number = jsonString(item['vehicleNumber']);
      // Ônibus que falhou na fonte: fica de fora (o cubit marca a falha).
      if (number == null || item['error'] != null) continue;
      final vehicle = item['data'];
      results[number] = _snapshot<TrackedVehicle?>(
        item,
        vehicle is Map<String, dynamic>
            ? TrackedVehicle.fromJson(vehicle)
            : null,
      );
    }
    return results;
  }
}
