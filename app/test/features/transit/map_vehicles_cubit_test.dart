import 'dart:async';

import 'package:busaogyn/src/features/transit/domain/entities/arrival.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/domain/models/transit_snapshot.dart';
import 'package:busaogyn/src/features/transit/domain/repositories/transit_repository.dart';
import 'package:busaogyn/src/features/transit/presentation/cubit/map_vehicles_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

TransitSnapshot<TrackedVehicle?> _snapshot(
  String number, {
  double lat = -16.68,
  double lon = -49.25,
  bool stale = false,
  bool withPosition = true,
}) {
  return TransitSnapshot(
    data: TrackedVehicle(
      id: 'rmtc:$number',
      vehicleNumber: number,
      routeId: '003',
      routeName: null,
      destination: 'T MARANATA',
      position: withPosition
          ? GeoPosition(latitude: lat, longitude: lon)
          : null,
      accessible: true,
      punctuality: VehiclePunctuality.unknown,
    ),
    fetchedAt: DateTime(2026, 10, 7, 12),
    stale: stale,
    ageSeconds: 4,
  );
}

class _FakeRepository implements TransitRepository {
  final calls = <String>[];
  final pending = <String, Completer<TransitSnapshot<TrackedVehicle?>>>{};
  final failing = <String>{};
  var inFlight = 0;
  var maxInFlight = 0;

  /// Respostas imediatas por veículo; o resto fica pendente em [pending].
  final instant = <String, TransitSnapshot<TrackedVehicle?>>{};

  @override
  Future<TransitSnapshot<List<ArrivalGroup>>> getArrivals(String stopId) =>
      throw UnimplementedError();

  @override
  Future<TransitSnapshot<TrackedVehicle?>> getVehiclePosition({
    required String vehicleNumber,
    required String stopId,
  }) async {
    calls.add(vehicleNumber);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      if (failing.contains(vehicleNumber)) throw Exception('falha');
      final ready = instant[vehicleNumber];
      if (ready != null) {
        await Future<void>.delayed(Duration.zero);
        return ready;
      }
      final completer = pending.putIfAbsent(
        vehicleNumber,
        Completer<TransitSnapshot<TrackedVehicle?>>.new,
      );
      return await completer.future;
    } finally {
      inFlight--;
    }
  }
}

Arrival _arrival(
  String? number, {
  int minutes = 5,
  ArrivalQuality quality = ArrivalQuality.realtime,
}) {
  return Arrival(
    vehicleId: number == null ? null : 'rmtc:$number',
    vehicleNumber: number,
    minutes: minutes,
    plannedArrival: null,
    predictedArrival: null,
    realtime: quality == ArrivalQuality.realtime,
    quality: quality,
  );
}

ArrivalGroup _group(String route, Arrival next, [Arrival? following]) {
  return ArrivalGroup(
    routeId: route,
    destination: 'DESTINO $route',
    next: next,
    following: following,
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

List<String> _numbers(MapVehiclesCubit cubit) =>
    cubit.state.secondaries.map((v) => v.vehicleNumber).toList()..sort();

void main() {
  late _FakeRepository repository;
  late DateTime now;
  late MapVehiclesCubit cubit;

  MapVehiclesCubit build({int limit = 6, int maxConcurrent = 3}) {
    return MapVehiclesCubit(
      repository,
      refreshInterval: null,
      limit: limit,
      maxConcurrent: maxConcurrent,
      maxStaleAge: const Duration(seconds: 90),
      retryAfter: const Duration(seconds: 10),
      clock: () => now,
    );
  }

  setUp(() {
    repository = _FakeRepository();
    now = DateTime(2026, 10, 7, 12);
    cubit = build();
  });

  tearDown(() => cubit.close());

  test('busca cada veículo realtime uma vez e mostra a posição real', () async {
    repository.instant['20051'] = _snapshot('20051', lat: -16.61);
    repository.instant['20064'] = _snapshot('20064', lat: -16.62);
    repository.instant['50462'] = _snapshot('50462', lat: -16.63);

    cubit.sync(
      stopId: '30402',
      groups: [
        _group('003', _arrival('20051'), _arrival('20064')),
        _group('020', _arrival('50462')),
        // Duplicado em outra linha: não gera segunda chamada nem segundo marcador.
        _group('021', _arrival('20051', minutes: 40)),
      ],
    );
    await _settle();

    expect(repository.calls.toSet(), {'20051', '20064', '50462'});
    expect(repository.calls, hasLength(3));
    expect(_numbers(cubit), ['20051', '20064', '50462']);
    final first = cubit.state.byNumber('20051')!;
    expect(first.position.latitude, -16.61);
    expect(first.isTracked, isFalse);
    expect(first.routeId, '003');
  });

  test('ignora programado e veículo sem número: nenhuma chamada', () async {
    cubit.sync(
      stopId: '30402',
      groups: [
        _group(
          '003',
          _arrival('20051', quality: ArrivalQuality.scheduled),
          _arrival(null),
        ),
        _group('020', _arrival('50462', quality: ArrivalQuality.unknown)),
      ],
    );
    await _settle();

    expect(repository.calls, isEmpty);
    expect(cubit.state.secondaries, isEmpty);
  });

  test('o acompanhado não vira marcador secundário', () async {
    repository.instant['20064'] = _snapshot('20064');

    cubit.sync(
      stopId: '30402',
      groups: [_group('003', _arrival('20051'), _arrival('20064'))],
      trackedVehicleNumber: '20051',
      trackedVehicle: _snapshot('20051').data,
    );
    await _settle();

    expect(repository.calls, ['20064']);
    expect(_numbers(cubit), ['20064']);
  });

  test('respeita o limite e prioriza o menor ETA', () async {
    cubit = build(limit: 3);
    for (var i = 0; i < 8; i++) {
      repository.instant['2000$i'] = _snapshot('2000$i');
    }

    cubit.sync(
      stopId: '30402',
      groups: [
        for (var i = 0; i < 8; i++)
          _group('L$i', _arrival('2000$i', minutes: 30 - i)),
      ],
    );
    await _settle();

    // ETAs 23, 24 e 25 (veículos 20007, 20006 e 20005).
    expect(_numbers(cubit), ['20005', '20006', '20007']);
    expect(repository.calls.toSet(), {'20005', '20006', '20007'});
  });

  test('limita a concorrência das requisições', () async {
    cubit = build(maxConcurrent: 2);
    for (var i = 0; i < 6; i++) {
      repository.instant['3000$i'] = _snapshot('3000$i');
    }

    cubit.sync(
      stopId: '30402',
      groups: [for (var i = 0; i < 6; i++) _group('L$i', _arrival('3000$i'))],
    );
    await _settle();

    expect(repository.calls, hasLength(6));
    expect(repository.maxInFlight, lessThanOrEqualTo(2));
  });

  test('trocar de ponto descarta o conjunto anterior', () async {
    repository.instant['20051'] = _snapshot('20051');
    repository.instant['50462'] = _snapshot('50462');

    cubit.sync(stopId: 'A', groups: [_group('003', _arrival('20051'))]);
    await _settle();
    expect(_numbers(cubit), ['20051']);

    cubit.sync(stopId: 'B', groups: [_group('020', _arrival('50462'))]);
    expect(cubit.state.secondaries, isEmpty);
    expect(cubit.state.stopId, 'B');
    await _settle();
    expect(_numbers(cubit), ['50462']);

    cubit.sync(stopId: null, groups: const []);
    expect(cubit.state.secondaries, isEmpty);
  });

  test('resposta atrasada de ponto anterior é ignorada', () async {
    cubit.sync(stopId: 'A', groups: [_group('003', _arrival('20051'))]);
    await _settle();
    expect(repository.pending, contains('20051'));

    repository.instant['50462'] = _snapshot('50462');
    cubit.sync(stopId: 'B', groups: [_group('020', _arrival('50462'))]);
    await _settle();

    // A resposta de A chega depois de B já estar na tela.
    repository.pending['20051']!.complete(_snapshot('20051'));
    await _settle();

    expect(_numbers(cubit), ['50462']);
    expect(cubit.state.stopId, 'B');
  });

  test('resposta de veículo que saiu do conjunto é ignorada', () async {
    cubit.sync(stopId: 'A', groups: [_group('003', _arrival('20051'))]);
    await _settle();

    // As chegadas mudaram: 20051 não está mais entre os candidatos.
    repository.instant['50462'] = _snapshot('50462');
    cubit.sync(stopId: 'A', groups: [_group('020', _arrival('50462'))]);
    await _settle();
    repository.pending['20051']!.complete(_snapshot('20051'));
    await _settle();

    expect(_numbers(cubit), ['50462']);
  });

  test('falha mantém a última posição como antiga e depois remove', () async {
    repository.instant['20051'] = _snapshot('20051', lat: -16.61);
    cubit.sync(stopId: 'A', groups: [_group('003', _arrival('20051'))]);
    await _settle();
    expect(cubit.state.byNumber('20051')!.stale, isFalse);

    repository.instant.remove('20051');
    repository.failing.add('20051');

    now = now.add(const Duration(seconds: 30));
    await cubit.refreshNow();
    final kept = cubit.state.byNumber('20051')!;
    expect(kept.stale, isTrue);
    expect(kept.position.latitude, -16.61);
    expect(kept.visual.markerVariant.name, 'stale');

    // Passada a janela, a posição velha some em vez de parecer atual.
    now = now.add(const Duration(seconds: 120));
    await cubit.refreshNow();
    expect(cubit.state.secondaries, isEmpty);
  });

  test('snapshot marcado como antigo pela API aparece como antigo', () async {
    repository.instant['20051'] = _snapshot('20051', stale: true);
    cubit.sync(stopId: 'A', groups: [_group('003', _arrival('20051'))]);
    await _settle();

    expect(cubit.state.byNumber('20051')!.stale, isTrue);
  });

  test('sem posição na resposta não cria marcador', () async {
    repository.instant['20051'] = _snapshot('20051', withPosition: false);
    cubit.sync(stopId: 'A', groups: [_group('003', _arrival('20051'))]);
    await _settle();

    expect(cubit.state.secondaries, isEmpty);
  });

  test('veículo que falha não é rebuscado a cada mudança de estado', () async {
    repository.failing.add('20051');
    final groups = [_group('003', _arrival('20051'))];

    cubit.sync(stopId: 'A', groups: groups);
    await _settle();
    expect(repository.calls, hasLength(1));

    cubit.sync(stopId: 'A', groups: groups);
    cubit.sync(stopId: 'A', groups: groups);
    await _settle();
    expect(repository.calls, hasLength(1));

    now = now.add(const Duration(seconds: 11));
    cubit.sync(stopId: 'A', groups: groups);
    await _settle();
    expect(repository.calls, hasLength(2));
  });

  test(
    'ao trocar o acompanhado, o anterior vira secundário na posição que tinha',
    () async {
      final groups = [_group('003', _arrival('20051'), _arrival('20064'))];
      repository.instant['20064'] = _snapshot('20064', lat: -16.64);

      cubit.sync(
        stopId: 'A',
        groups: groups,
        trackedVehicleNumber: '20051',
        trackedVehicle: _snapshot('20051', lat: -16.61).data,
      );
      await _settle();
      expect(_numbers(cubit), ['20064']);

      cubit.sync(
        stopId: 'A',
        groups: groups,
        trackedVehicleNumber: '20064',
        trackedVehicle: _snapshot('20064', lat: -16.64).data,
      );

      // 20051 aparece na hora, sem nova chamada, com a última posição real.
      expect(_numbers(cubit), ['20051']);
      expect(cubit.state.byNumber('20051')!.position.latitude, -16.61);
      expect(cubit.state.byNumber('20051')!.isTracked, isFalse);
      expect(repository.calls, ['20064']);
    },
  );
}
