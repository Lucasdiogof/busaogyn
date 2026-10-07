import 'dart:async';

import 'package:busaogyn/src/core/network/api_exception.dart';
import 'package:busaogyn/src/features/transit/domain/entities/arrival.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/domain/models/transit_snapshot.dart';
import 'package:busaogyn/src/features/transit/domain/repositories/transit_repository.dart';
import 'package:busaogyn/src/features/transit/presentation/cubit/stop_arrivals_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

TransitSnapshot<T> _snapshot<T>(T data) => TransitSnapshot(
  data: data,
  fetchedAt: DateTime(2026, 10, 6, 17),
  stale: false,
  ageSeconds: 0,
);

TrackedVehicle _vehicle(String number, double latitude) => TrackedVehicle(
  id: 'rmtc:$number',
  vehicleNumber: number,
  routeId: '020',
  routeName: 'Linha 020',
  destination: 'T. BIBLIA',
  position: GeoPosition(latitude: latitude, longitude: -49.2),
  accessible: true,
  punctuality: VehiclePunctuality.onTime,
);

/// Cada chamada de posição fica pendente até o teste completá-la.
class _ControlledRepository implements TransitRepository {
  final requests =
      <({String vehicleNumber, Completer<TrackedVehicle> reply})>[];

  @override
  Future<TransitSnapshot<List<ArrivalGroup>>> getArrivals(String stopId) async {
    return _snapshot(const <ArrivalGroup>[]);
  }

  @override
  Future<TransitSnapshot<TrackedVehicle?>> getVehiclePosition({
    required String vehicleNumber,
    required String stopId,
  }) async {
    final reply = Completer<TrackedVehicle>();
    requests.add((vehicleNumber: vehicleNumber, reply: reply));
    return _snapshot(await reply.future);
  }
}

const _transientError = ApiException(
  code: 'upstream_unavailable',
  message: 'Fonte indisponível.',
  retryable: true,
);

void main() {
  late _ControlledRepository repository;
  late StopArrivalsCubit cubit;

  StopArrivalsLoaded loaded() => cubit.state as StopArrivalsLoaded;

  setUp(() async {
    repository = _ControlledRepository();
    cubit = StopArrivalsCubit(repository, trackingRefreshInterval: null);
    await cubit.load('30402');
  });

  tearDown(() => cubit.close());

  test('mantém trackingVehicleNumber após a posição chegar', () async {
    final tracking = cubit.track('20529');
    expect(loaded().trackingVehicleNumber, '20529');
    expect(loaded().trackedVehicle, isNull);

    repository.requests.single.reply.complete(_vehicle('20529', -16.7));
    await tracking;

    expect(loaded().trackingVehicleNumber, '20529');
    expect(loaded().trackedVehicle?.data?.vehicleNumber, '20529');
    expect(loaded().trackingError, isNull);
  });

  test('erro temporário preserva o ônibus e a última posição', () async {
    final tracking = cubit.track('20529');
    repository.requests.single.reply.complete(_vehicle('20529', -16.7));
    await tracking;

    final refresh = cubit.resumeTracking();
    repository.requests.last.reply.completeError(_transientError);
    await refresh;

    expect(loaded().trackingVehicleNumber, '20529');
    expect(loaded().trackedVehicle?.data?.position?.latitude, -16.7);
    expect(loaded().trackingError, 'Posição temporariamente indisponível.');
  });

  test('trocar de ônibus não exibe a posição do anterior', () async {
    final first = cubit.track('20529');
    repository.requests.single.reply.complete(_vehicle('20529', -16.7));
    await first;

    final second = cubit.track('20777');
    expect(loaded().trackingVehicleNumber, '20777');
    expect(loaded().trackedVehicle, isNull);

    repository.requests.last.reply.complete(_vehicle('20777', -16.8));
    await second;

    expect(loaded().trackingVehicleNumber, '20777');
    expect(loaded().trackedVehicle?.data?.vehicleNumber, '20777');
  });

  test('resposta atrasada do ônibus anterior é descartada', () async {
    final first = cubit.track('20529');
    final second = cubit.track('20777');

    // A requisição pendente do primeiro não bloqueia a do segundo.
    expect(repository.requests.map((r) => r.vehicleNumber), ['20529', '20777']);

    repository.requests.last.reply.complete(_vehicle('20777', -16.8));
    await second;
    repository.requests.first.reply.complete(_vehicle('20529', -16.7));
    await first;

    expect(loaded().trackingVehicleNumber, '20777');
    expect(loaded().trackedVehicle?.data?.vehicleNumber, '20777');
  });

  // testWidgets roda em tempo simulado: tester.pump avança o Timer.periodic.
  testWidgets('timer segue atualizando o mesmo ônibus', (tester) async {
    final timed = _ControlledRepository();
    final timedCubit = StopArrivalsCubit(
      timed,
      trackingRefreshInterval: const Duration(seconds: 15),
    );
    await timedCubit.load('30402');

    final tracking = timedCubit.track('20529');
    timed.requests.single.reply.complete(_vehicle('20529', -16.7));
    await tracking;

    await tester.pump(const Duration(seconds: 15));
    expect(timed.requests, hasLength(2));
    timed.requests.last.reply.completeError(_transientError);
    await tester.pump();

    var state = timedCubit.state as StopArrivalsLoaded;
    expect(state.trackingVehicleNumber, '20529');
    expect(state.trackingError, 'Posição temporariamente indisponível.');

    await tester.pump(const Duration(seconds: 15));
    expect(timed.requests, hasLength(3));
    expect(timed.requests.every((r) => r.vehicleNumber == '20529'), isTrue);
    timed.requests.last.reply.complete(_vehicle('20529', -16.6));
    await tester.pump();

    state = timedCubit.state as StopArrivalsLoaded;
    expect(state.trackingVehicleNumber, '20529');
    expect(state.trackedVehicle?.data?.position?.latitude, -16.6);
    expect(state.trackingError, isNull);

    await timedCubit.close();
  });
}
