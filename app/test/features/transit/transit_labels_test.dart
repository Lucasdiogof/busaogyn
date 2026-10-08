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
  destinationLabelTests();
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
    expect(minutesSemantics(null), 'tempo não informado');
    expect(minutesSemantics(-2), 'menos de 1 minuto');
    expect(minutesSemantics(0), 'menos de 1 minuto');
    expect(minutesSemantics(1), '1 minuto');
    expect(minutesSemantics(8), '8 minutos');
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

  group('status ao vivo', () {
    final now = DateTime(2026, 10, 7, 14);

    StopArrivalsLoaded loaded(
      List<ArrivalGroup> groups, {
      bool stale = false,
      int ageSeconds = 0,
      DateTime? receivedAt,
      TrackingInfo? tracking,
      String? refreshError,
    }) {
      return StopArrivalsLoaded(
        stopId: '30402',
        arrivals: TransitSnapshot(
          data: groups,
          fetchedAt: null,
          stale: stale,
          ageSeconds: ageSeconds,
        ),
        arrivalsReceivedAt: receivedAt ?? now,
        tracking: tracking,
        refreshError: refreshError,
      );
    }

    ArrivalGroup group(Arrival next, {Arrival? following}) => ArrivalGroup(
      routeId: '020',
      destination: null,
      next: next,
      following: following,
    );

    final realtime = group(
      _arrival(realtime: true, quality: ArrivalQuality.realtime),
    );
    final scheduled = group(
      _arrival(
        realtime: false,
        quality: ArrivalQuality.scheduled,
        vehicleNumber: null,
      ),
    );
    final unknown = group(
      _arrival(realtime: true, quality: ArrivalQuality.unknown),
    );

    test('sem consulta não há status', () {
      expect(liveStatus(const StopArrivalsInitial(), now), isNull);
      expect(liveStatus(const StopArrivalsLoading(stopId: '1'), now), isNull);
      expect(
        liveStatus(
          const StopArrivalsInitial(searchError: SearchFeedback.invalidCode),
          now,
        ),
        isNull,
      );
    });

    test('ao vivo só com tempo real recente', () {
      final status = liveStatus(loaded([realtime]), now)!;
      expect(status.label, 'Ao vivo');
      expect(status.detail, 'agora');
      expect(status.tone, LiveTone.live);

      final older = liveStatus(
        loaded([realtime], ageSeconds: 10, receivedAt: now),
        now,
      )!;
      expect(older.label, 'Ao vivo');
      expect(older.detail, 'há 10 s');
    });

    test('a API respondeu, mas só com horário programado', () {
      final status = liveStatus(loaded([scheduled]), now)!;
      expect(status.label, 'Programado');
      expect(status.tone, LiveTone.scheduled);
    });

    test('qualidade desconhecida não conta como tempo real', () {
      expect(liveStatus(loaded([unknown]), now)!.label, 'Programado');
    });

    test('seguinte em tempo real conta', () {
      final status = liveStatus(
        loaded([
          group(
            scheduled.next,
            following: _arrival(
              realtime: true,
              quality: ArrivalQuality.realtime,
            ),
          ),
        ]),
        now,
      )!;
      expect(status.tone, LiveTone.live);
    });

    test('sem chegadas', () {
      expect(liveStatus(loaded([]), now)!.label, 'Sem previsão');
    });

    test('tempo real envelhecido deixa de ser ao vivo', () {
      final status = liveStatus(
        loaded([
          realtime,
        ], receivedAt: now.subtract(const Duration(minutes: 2))),
        now,
      )!;
      expect(status.label, 'Previsão');
      expect(status.detail, 'há 2 min');
      expect(status.tone, LiveTone.aging);
    });

    test('stale ou falha de atualização ficam desatualizados', () {
      expect(
        liveStatus(loaded([realtime], stale: true), now)!.tone,
        LiveTone.stale,
      );
      expect(
        liveStatus(loaded([realtime], refreshError: 'x'), now)!.label,
        'Desatualizado',
      );
    });

    test('acompanhamento usa a idade da posição', () {
      expect(
        liveStatus(
          loaded([
            realtime,
          ], tracking: _tracking(phase: TrackingPhase.active, receivedAt: now)),
          now,
        )!.label,
        'Ao vivo',
      );
      expect(
        liveStatus(
          loaded(
            [realtime],
            tracking: _tracking(
              phase: TrackingPhase.active,
              ageSeconds: 50,
              receivedAt: now,
            ),
          ),
          now,
        )!.tone,
        LiveTone.aging,
      );
      expect(
        liveStatus(
          loaded(
            [realtime],
            tracking: _tracking(phase: TrackingPhase.failing, receivedAt: now),
          ),
          now,
        )!.label,
        'Desatualizado',
      );
      expect(
        liveStatus(
          loaded(
            [realtime],
            tracking: _tracking(
              phase: TrackingPhase.unavailable,
              withPosition: false,
            ),
          ),
          now,
        )!.label,
        'Sem posição',
      );
      expect(
        liveStatus(
          loaded(
            [realtime],
            tracking: _tracking(
              phase: TrackingPhase.searching,
              withPosition: false,
            ),
          ),
          now,
        )!.tone,
        LiveTone.scheduled,
      );
    });

    test('chegada do ônibus acompanhado', () {
      final groups = [
        realtime,
        group(
          scheduled.next,
          following: _arrival(
            realtime: true,
            quality: ArrivalQuality.realtime,
            vehicleNumber: '777',
          ),
        ),
      ];
      expect(trackedArrival(groups, '20529')!.arrival, same(realtime.next));
      expect(trackedArrival(groups, '777')!.group, same(groups[1]));
      expect(trackedArrival(groups, '999'), isNull);
    });
  });
}

void destinationLabelTests() {
  test('destinationLabel cola prefixo curto à próxima palavra', () {
    expect(destinationLabel('T MARANATA'), 'T MARANATA');
    expect(destinationLabel('PQ INDUSTRIAL'), 'PQ INDUSTRIAL');
    expect(
      destinationLabel('GARAVELO - VEIGA JARDIM'),
      'GARAVELO - VEIGA JARDIM',
    );
  });
}
