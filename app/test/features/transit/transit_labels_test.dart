import 'package:busaogyn/src/features/transit/domain/entities/arrival.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/domain/models/transit_snapshot.dart';
import 'package:busaogyn/src/features/transit/presentation/cubit/stop_arrivals_cubit.dart';
import 'package:busaogyn/src/features/transit/presentation/formatters/transit_labels.dart';
import 'package:flutter_test/flutter_test.dart';

Arrival _arrival({
  required bool realtime,
  required ArrivalQuality quality,
  String? vehicleNumber = '20529',
}) {
  return Arrival(
    vehicleId: null,
    vehicleNumber: vehicleNumber,
    minutes: 5,
    plannedArrival: null,
    predictedArrival: null,
    realtime: realtime,
    quality: quality,
  );
}

TrackingInfo _tracking({
  required TrackingPhase phase,
  bool withPosition = true,
  bool stale = false,
  int ageSeconds = 0,
  DateTime? receivedAt,
}) {
  return TrackingInfo(
    vehicleNumber: '20529',
    phase: phase,
    receivedAt: receivedAt,
    vehicle: withPosition
        ? TransitSnapshot(
            data: const TrackedVehicle(
              id: 'rmtc:20529',
              vehicleNumber: '20529',
              routeId: '020',
              routeName: null,
              destination: null,
              position: GeoPosition(latitude: -16.7, longitude: -49.2),
              accessible: null,
              punctuality: VehiclePunctuality.unknown,
            ),
            fetchedAt: null,
            stale: stale,
            ageSeconds: ageSeconds,
          )
        : null,
  );
}

void main() {
  group('qualidade da previsão', () {
    test('realtime só quando flag e qualidade concordam', () {
      expect(
        displayQuality(
          _arrival(realtime: true, quality: ArrivalQuality.realtime),
        ),
        ArrivalQuality.realtime,
      );
      expect(
        displayQuality(
          _arrival(realtime: false, quality: ArrivalQuality.realtime),
        ),
        ArrivalQuality.unknown,
      );
    });

    test('unknown nunca vira realtime nem permite acompanhar', () {
      final arrival = _arrival(realtime: true, quality: ArrivalQuality.unknown);
      expect(displayQuality(arrival), ArrivalQuality.unknown);
      expect(
        qualityLabel(displayQuality(arrival)),
        'Informação não confirmada',
      );
      expect(canTrack(arrival), isFalse);
    });

    test('programado é programado e não permite acompanhar', () {
      final arrival = _arrival(
        realtime: false,
        quality: ArrivalQuality.scheduled,
      );
      expect(qualityLabel(displayQuality(arrival)), 'Programado');
      expect(canTrack(arrival), isFalse);
    });

    test('realtime sem veículo não permite acompanhar', () {
      expect(
        canTrack(
          _arrival(
            realtime: true,
            quality: ArrivalQuality.realtime,
            vehicleNumber: null,
          ),
        ),
        isFalse,
      );
    });
  });

  test('minutos', () {
    expect(minutesLabel(null), '—');
    expect(minutesLabel(0), '< 1 min');
    expect(minutesLabel(8), '8 min');
  });

  group('frescor da posição', () {
    final now = DateTime(2026, 10, 7, 8);

    test('recente', () {
      final text = positionFreshness(
        _tracking(phase: TrackingPhase.active, receivedAt: now),
        now,
      ).text;
      expect(text, 'Dados atualizados recentemente');
    });

    test('envelhece com ageSeconds da API + tempo local', () {
      final freshness = positionFreshness(
        _tracking(
          phase: TrackingPhase.active,
          ageSeconds: 20,
          receivedAt: now.subtract(const Duration(seconds: 20)),
        ),
        now,
      );
      expect(freshness.text, 'Última posição consultada há 40 s');
      expect(freshness.tone, FreshnessTone.aging);
    });

    test('stale da API ou falha mostram desatualizada', () {
      expect(
        positionFreshness(
          _tracking(phase: TrackingPhase.active, stale: true, receivedAt: now),
          now,
        ).tone,
        FreshnessTone.stale,
      );
      expect(
        positionFreshness(
          _tracking(phase: TrackingPhase.failing, receivedAt: now),
          now,
        ).text,
        startsWith('Posição temporariamente desatualizada'),
      );
    });

    test('sem posição', () {
      expect(
        positionFreshness(
          _tracking(phase: TrackingPhase.unavailable, withPosition: false),
          now,
        ).text,
        'Posição indisponível',
      );
      expect(
        positionFreshness(
          _tracking(phase: TrackingPhase.searching, withPosition: false),
          now,
        ).text,
        'Buscando posição',
      );
    });
  });
}
