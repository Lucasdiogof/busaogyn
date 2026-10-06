import 'dart:convert';

import 'package:busaogyn/features/transit/data/repositories/api_transit_repository.dart';
import 'package:busaogyn/features/transit/domain/entities/arrival.dart';
import 'package:busaogyn/features/transit/domain/entities/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiTransitRepository', () {
    test('parses the line 020 vehicle snapshot without inventing data', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/routes/020/vehicles');

        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'data': [
              {
                'id': 'rmtc:20529',
                'vehicleNumber': '20529',
                'routeId': '020',
                'destination': 'T. BIBLIA',
                'position': {
                  'latitude': -16.7123,
                  'longitude': -49.2567,
                },
                'accessible': true,
                'status': 'unknown',
              },
              {
                'id': 'rmtc:20530',
                'vehicleNumber': '20530',
                'routeId': '020',
                'destination': null,
                'position': null,
                'accessible': null,
                'status': 'unknown',
              },
            ],
            'meta': {
              'routeId': '020',
              'count': 2,
              'fetchedAt': '2026-10-06T17:30:00.000Z',
              'stale': false,
              'ageSeconds': 4,
            },
          })),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repository = ApiTransitRepository(
        baseUri: Uri.parse('https://api.example.test'),
        client: client,
      );

      final snapshot = await repository.getVehicles(routeId: '020');

      expect(snapshot.vehicles, hasLength(2));
      expect(snapshot.stale, isFalse);
      expect(snapshot.ageSeconds, 4);
      expect(snapshot.vehicles.first.vehicleNumber, '20529');
      expect(snapshot.vehicles.first.position?.latitude, -16.7123);
      expect(snapshot.vehicles.first.accessible, isTrue);
      expect(snapshot.vehicles.first.status, VehicleStatus.unknown);
      expect(snapshot.vehicles.last.destination, isNull);
      expect(snapshot.vehicles.last.position, isNull);
      expect(snapshot.vehicles.last.accessible, isNull);
    });

    test('keeps zero-minute realtime arrival for the < 1 min UI', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/stops/01286/arrivals');

        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'data': [
              {
                'routeId': '020',
                'destination': 'T. BIBLIA',
                'next': {
                  'vehicleId': 'rmtc:20529',
                  'vehicleNumber': '20529',
                  'minutes': 0,
                  'plannedArrival': '14:02',
                  'predictedArrival': '14:01',
                  'realtime': true,
                  'quality': 'realtime',
                },
                'following': null,
              },
            ],
            'meta': {
              'stopId': '01286',
              'count': 1,
              'fetchedAt': '2026-10-06T17:30:00.000Z',
              'stale': false,
              'ageSeconds': 2,
            },
          })),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repository = ApiTransitRepository(
        baseUri: Uri.parse('https://api.example.test'),
        client: client,
      );

      final snapshot = await repository.getArrivals('01286');

      expect(snapshot.stopId, '01286');
      expect(snapshot.groups.single.next.minutes, 0);
      expect(snapshot.groups.single.next.realtime, isTrue);
      expect(snapshot.groups.single.next.quality, ArrivalQuality.realtime);
      expect(snapshot.groups.single.following, isNull);
    });

    test('rejects malformed success payloads instead of fabricating defaults',
        () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': [],
            'meta': {
              'stale': false,
              'ageSeconds': 0,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final repository = ApiTransitRepository(
        baseUri: Uri.parse('https://api.example.test'),
        client: client,
      );

      expect(
        () => repository.getVehicles(routeId: '020'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
