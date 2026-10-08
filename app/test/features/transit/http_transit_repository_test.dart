import 'dart:convert';

import 'package:busaogyn/src/core/network/api_client.dart';
import 'package:busaogyn/src/features/transit/data/repositories/http_transit_repository.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Contrato da API BusãoGyn com dados incompletos ou fora do tipo: nada
/// pode virar `TypeError` nem conteúdo inventado.
void main() {
  late List<Uri> requests;

  HttpTransitRepository repositoryReturning(Object? body) {
    requests = [];
    return HttpTransitRepository(
      ApiClient(
        baseUrl: 'https://api.example.test',
        client: MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );
  }

  Map<String, Object?> arrival({
    Object? vehicleNumber = '20529',
    Object? minutes = 4,
    Object? quality = 'realtime',
    Object? realtime = true,
  }) => {
    'vehicleId': 'rmtc:20529',
    'vehicleNumber': vehicleNumber,
    'minutes': minutes,
    'plannedArrival': null,
    'predictedArrival': null,
    'realtime': realtime,
    'quality': quality,
    'sourceQuality': 'x',
  };

  group('chegadas', () {
    test('código com zeros à esquerda vai igual para a API', () async {
      final repository = repositoryReturning({'data': <Object>[]});
      await repository.getArrivals('00001');
      expect(requests.single.path, '/v1/stops/00001/arrivals');
    });

    test('lista vazia e meta ausente', () async {
      final snapshot = await repositoryReturning({
        'data': <Object>[],
      }).getArrivals('30402');
      expect(snapshot.data, isEmpty);
      expect(snapshot.ageSeconds, 0);
      expect(snapshot.fetchedAt, isNull);
      expect(snapshot.stale, isFalse);
    });

    test('grupo malformado é descartado sem derrubar os outros', () async {
      final snapshot = await repositoryReturning({
        'data': [
          {'routeId': null, 'next': arrival()},
          {'routeId': '020', 'next': null},
          {'routeId': 20, 'next': arrival()},
          'lixo',
          {
            'routeId': '003',
            'destination': null,
            'next': arrival(),
            'following': 'não é objeto',
            'campoNovo': {'qualquer': true},
          },
        ],
        'meta': {'fetchedAt': '2026-10-08T12:00:00Z', 'ageSeconds': 3},
      }).getArrivals('30402');

      final group = snapshot.data.single;
      expect(group.routeId, '003');
      expect(group.destination, isNull);
      expect(group.following, isNull);
      expect(group.next.vehicleNumber, '20529');
      expect(snapshot.ageSeconds, 3);
    });

    test('veículo vazio, só zeros ou fora do tipo vira ausente', () async {
      final snapshot = await repositoryReturning({
        'data': [
          for (final number in ['0', '0000', '', '   ', 20529, null])
            {'routeId': '020', 'next': arrival(vehicleNumber: number)},
          {'routeId': '021', 'next': arrival(vehicleNumber: ' 20777 ')},
        ],
      }).getArrivals('30402');

      expect(snapshot.data.map((group) => group.next.vehicleNumber).toList(), [
        null,
        null,
        null,
        null,
        null,
        null,
        '20777',
      ]);
    });

    test('minutos e qualidade fora do tipo não quebram nem viram tempo '
        'real', () async {
      final snapshot = await repositoryReturning({
        'data': [
          {
            'routeId': '020',
            'next': arrival(minutes: '4', quality: 'REALTIME'),
          },
          {'routeId': '021', 'next': arrival(minutes: 99999, realtime: 'true')},
          {'routeId': '022', 'next': arrival(minutes: -2)},
        ],
      }).getArrivals('30402');

      final [first, second, third] = snapshot.data;
      expect(first.next.minutes, isNull);
      expect(first.next.isConfirmedRealtime, isFalse);
      expect(second.next.minutes, 99999);
      expect(second.next.isConfirmedRealtime, isFalse);
      expect(third.next.minutes, -2);
    });

    test('idade negativa ou fora do tipo vira zero', () async {
      final negative = await repositoryReturning({
        'data': <Object>[],
        'meta': {'ageSeconds': -5},
      }).getArrivals('30402');
      final text = await repositoryReturning({
        'data': <Object>[],
        'meta': {'ageSeconds': '40', 'stale': 'true'},
      }).getArrivals('30402');

      expect(negative.ageSeconds, 0);
      expect(text.ageSeconds, 0);
      expect(text.stale, isFalse);
    });

    test('data que não é lista é formato inesperado', () async {
      await expectLater(
        repositoryReturning({'data': {}}).getArrivals('30402'),
        throwsFormatException,
      );
    });
  });

  group('posição do ônibus', () {
    Map<String, Object?> vehicle({Object? position, Object? id = 'rmtc:1'}) => {
      'id': id,
      'vehicleNumber': '20529',
      'routeId': null,
      'routeName': null,
      'destination': null,
      'position': position,
      'accessible': null,
      'punctuality': null,
      'referenceStop': null,
      'prediction': null,
    };

    test('data null é ônibus sem posição', () async {
      final snapshot = await repositoryReturning({
        'data': null,
      }).getVehiclePosition(vehicleNumber: '20529', stopId: '00001');
      expect(snapshot.data, isNull);
      expect(requests.single.queryParameters, {'stopId': '00001'});
    });

    test('campos nulos não inventam conteúdo', () async {
      final snapshot = await repositoryReturning({
        'data': vehicle(position: {'latitude': -16.7, 'longitude': -49.2}),
      }).getVehiclePosition(vehicleNumber: '20529', stopId: '30402');

      final data = snapshot.data!;
      expect(data.routeId, isNull);
      expect(data.destination, isNull);
      expect(data.accessible, isNull);
      expect(data.punctuality, VehiclePunctuality.unknown);
      expect(data.position?.latitude, -16.7);
    });

    test('coordenada ausente, fora do tipo ou fora do intervalo vira sem '
        'posição', () async {
      for (final position in [
        {'latitude': -16.7},
        {'latitude': '-16.7', 'longitude': '-49.2'},
        {'latitude': 91, 'longitude': -49.2},
        {'latitude': -16.7, 'longitude': 181},
        'não é objeto',
      ]) {
        final snapshot = await repositoryReturning({
          'data': vehicle(position: position),
        }).getVehiclePosition(vehicleNumber: '20529', stopId: '30402');
        expect(snapshot.data?.position, isNull, reason: '$position');
      }
    });

    test('sem id é formato inesperado, não TypeError', () async {
      await expectLater(
        repositoryReturning({
          'data': vehicle(id: null),
        }).getVehiclePosition(vehicleNumber: '20529', stopId: '30402'),
        throwsFormatException,
      );
    });
  });
}
