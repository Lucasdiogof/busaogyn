import 'package:busaogyn/src/features/transit/domain/entities/arrival.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses realtime arrival without losing vehicle identity', () {
    final group = ArrivalGroup.fromJson({
      'routeId': '020',
      'destination': 'T. BIBLIA',
      'next': {
        'vehicleId': 'rmtc:20529',
        'vehicleNumber': '20529',
        'minutes': 0,
        'plannedArrival': '14:02',
        'predictedArrival': '14:03',
        'realtime': true,
        'quality': 'realtime',
      },
      'following': null,
    });

    expect(group.routeId, '020');
    expect(group.next.vehicleNumber, '20529');
    expect(group.next.minutes, 0);
    expect(group.next.realtime, isTrue);
    expect(group.next.quality, ArrivalQuality.realtime);
    expect(group.following, isNull);
  });

  test('parses tracked vehicle position and punctuality', () {
    final vehicle = TrackedVehicle.fromJson({
      'id': 'rmtc:50614',
      'vehicleNumber': '50614',
      'routeId': '008',
      'routeName': 'T. Veiga Jardim / Eixo 85 / T. Paulo Garcia',
      'destination': 'T VEIGA JARDIM',
      'position': {
        'latitude': -16.7071,
        'longitude': -49.2640,
      },
      'accessible': true,
      'punctuality': {
        'status': 'delayed',
        'sourceStatus': 'Atrasado',
      },
    });

    expect(vehicle.id, 'rmtc:50614');
    expect(vehicle.position?.latitude, closeTo(-16.7071, 0.00001));
    expect(vehicle.punctuality, VehiclePunctuality.delayed);
    expect(vehicle.accessible, isTrue);
  });
}
