import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/arrival.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/repositories/transit_repository.dart';

final class ApiTransitRepository implements TransitRepository {
  ApiTransitRepository({
    required this.baseUri,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri baseUri;
  final http.Client _client;

  @override
  Future<VehicleSnapshot> getVehicles({String? routeId}) async {
    final path = routeId == null
        ? '/v1/vehicles'
        : '/v1/routes/${Uri.encodeComponent(routeId)}/vehicles';
    final payload = await _getJson(baseUri.resolve(path));

    final data = _asList(payload['data'], 'data');
    final meta = _asMap(payload['meta'], 'meta');

    return VehicleSnapshot(
      vehicles: data.map(_parseVehicle).toList(growable: false),
      fetchedAt: _parseDate(meta['fetchedAt'], 'meta.fetchedAt'),
      stale: _readBool(meta['stale'], 'meta.stale'),
      ageSeconds: _readInt(meta['ageSeconds'], 'meta.ageSeconds'),
    );
  }

  @override
  Future<ArrivalSnapshot> getArrivals(String stopId) async {
    final payload = await _getJson(
      baseUri.resolve('/v1/stops/${Uri.encodeComponent(stopId)}/arrivals'),
    );

    final data = _asList(payload['data'], 'data');
    final meta = _asMap(payload['meta'], 'meta');

    return ArrivalSnapshot(
      groups: data.map(_parseArrivalGroup).toList(growable: false),
      stopId: _readString(meta['stopId'], 'meta.stopId'),
      fetchedAt: _parseDate(meta['fetchedAt'], 'meta.fetchedAt'),
      stale: _readBool(meta['stale'], 'meta.stale'),
      ageSeconds: _readInt(meta['ageSeconds'], 'meta.ageSeconds'),
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    late final http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );
    } on Exception {
      throw const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Não foi possível acessar a API do BusãoGyn.',
        retryable: true,
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(
        code: 'INVALID_RESPONSE',
        message: 'A API retornou uma resposta inválida.',
        retryable: true,
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded is Map<String, dynamic>
          ? decoded['error']
          : null;
      final errorMap = error is Map<String, dynamic> ? error : null;
      throw ApiException(
        code: errorMap?['code'] is String
            ? errorMap!['code'] as String
            : 'HTTP_${response.statusCode}',
        message: errorMap?['message'] is String
            ? errorMap!['message'] as String
            : 'A API do BusãoGyn está temporariamente indisponível.',
        retryable: errorMap?['retryable'] is bool
            ? errorMap!['retryable'] as bool
            : response.statusCode >= 500,
        statusCode: response.statusCode,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        code: 'INVALID_RESPONSE',
        message: 'A API retornou um payload inesperado.',
        retryable: true,
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }

  Vehicle _parseVehicle(dynamic value) {
    final map = _asMap(value, 'vehicle');
    final positionValue = map['position'];
    VehiclePosition? position;

    if (positionValue != null) {
      final positionMap = _asMap(positionValue, 'vehicle.position');
      position = VehiclePosition(
        latitude: _readDouble(
          positionMap['latitude'],
          'vehicle.position.latitude',
        ),
        longitude: _readDouble(
          positionMap['longitude'],
          'vehicle.position.longitude',
        ),
      );
    }

    return Vehicle(
      id: _readString(map['id'], 'vehicle.id'),
      vehicleNumber: _readString(
        map['vehicleNumber'],
        'vehicle.vehicleNumber',
      ),
      routeId: _readNullableString(map['routeId']),
      destination: _readNullableString(map['destination']),
      position: position,
      accessible: _readNullableBool(map['accessible']),
      status: _parseVehicleStatus(map['status']),
    );
  }

  ArrivalGroup _parseArrivalGroup(dynamic value) {
    final map = _asMap(value, 'arrivalGroup');
    return ArrivalGroup(
      routeId: _readString(map['routeId'], 'arrivalGroup.routeId'),
      destination: _readNullableString(map['destination']),
      next: _parseArrival(map['next']),
      following: map['following'] == null
          ? null
          : _parseArrival(map['following']),
    );
  }

  Arrival _parseArrival(dynamic value) {
    final map = _asMap(value, 'arrival');
    return Arrival(
      vehicleId: _readNullableString(map['vehicleId']),
      vehicleNumber: _readNullableString(map['vehicleNumber']),
      minutes: _readNullableInt(map['minutes']),
      plannedArrival: _readNullableString(map['plannedArrival']),
      predictedArrival: _readNullableString(map['predictedArrival']),
      realtime: _readBool(map['realtime'], 'arrival.realtime'),
      quality: _parseArrivalQuality(map['quality']),
    );
  }

  VehicleStatus _parseVehicleStatus(dynamic value) {
    return switch (value) {
      'in_service' => VehicleStatus.inService,
      'interval' => VehicleStatus.interval,
      'out_of_service' => VehicleStatus.outOfService,
      _ => VehicleStatus.unknown,
    };
  }

  ArrivalQuality _parseArrivalQuality(dynamic value) {
    return switch (value) {
      'realtime' => ArrivalQuality.realtime,
      'scheduled' => ArrivalQuality.scheduled,
      _ => ArrivalQuality.unknown,
    };
  }

  Map<String, dynamic> _asMap(dynamic value, String field) {
    if (value is Map<String, dynamic>) return value;
    throw _invalid(field);
  }

  List<dynamic> _asList(dynamic value, String field) {
    if (value is List<dynamic>) return value;
    throw _invalid(field);
  }

  String _readString(dynamic value, String field) {
    if (value is String && value.isNotEmpty) return value;
    throw _invalid(field);
  }

  String? _readNullableString(dynamic value) {
    return value is String && value.isNotEmpty ? value : null;
  }

  bool _readBool(dynamic value, String field) {
    if (value is bool) return value;
    throw _invalid(field);
  }

  bool? _readNullableBool(dynamic value) {
    return value is bool ? value : null;
  }

  int _readInt(dynamic value, String field) {
    if (value is int) return value;
    throw _invalid(field);
  }

  int? _readNullableInt(dynamic value) {
    return value is int ? value : null;
  }

  double _readDouble(dynamic value, String field) {
    if (value is num) return value.toDouble();
    throw _invalid(field);
  }

  DateTime _parseDate(dynamic value, String field) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw _invalid(field);
  }

  ApiException _invalid(String field) {
    return ApiException(
      code: 'INVALID_RESPONSE',
      message: 'Campo inválido na resposta: $field.',
      retryable: true,
    );
  }
}
