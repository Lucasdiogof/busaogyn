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
    // Sem intervalo mínimo: aqui resumeTracking serve de gatilho de consulta.
    cubit = StopArrivalsCubit(
      repository,
      trackingRefreshInterval: null,
      resumeRefreshAfter: Duration.zero,
    );
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

  group('fases e refresh', () {
    late _FlexibleRepository flex;
    late StopArrivalsCubit flexCubit;

    StopArrivalsLoaded flexLoaded() => flexCubit.state as StopArrivalsLoaded;

    Future<void> loadStop(String stopId) async {
      final loading = flexCubit.load(stopId);
      flex.arrivalRequests.last.reply.complete(_groups('020'));
      await loading;
    }

    setUp(() {
      flex = _FlexibleRepository();
      flexCubit = StopArrivalsCubit(flex, trackingRefreshInterval: null);
    });

    tearDown(() => flexCubit.close());

    test('tracking sem posição sai de buscando para indisponível', () async {
      await loadStop('30402');
      final tracking = flexCubit.track('20529');
      expect(flexLoaded().trackingPhase, TrackingPhase.searching);

      flex.positionRequests.single.reply.complete(null);
      await tracking;

      expect(flexLoaded().trackingPhase, TrackingPhase.unavailable);
      expect(flexLoaded().trackingVehicleNumber, '20529');
      expect(flexLoaded().trackedVehicle, isNull);
    });

    test('falha inicial sem posição não deixa a fase em buscando', () async {
      await loadStop('30402');
      final tracking = flexCubit.track('20529');
      flex.positionRequests.single.reply.completeError(_transientError);
      await tracking;

      expect(flexLoaded().trackingPhase, TrackingPhase.failing);
      // Mensagem técnica da API nunca vai direto para a tela.
      expect(
        flexLoaded().trackingError,
        'O serviço está instável agora. Tente novamente em instantes.',
      );
    });

    test('refresh das chegadas preserva o tracking', () async {
      await loadStop('30402');
      final tracking = flexCubit.track('20529');
      flex.positionRequests.single.reply.complete(_vehicle('20529', -16.7));
      await tracking;

      final refresh = flexCubit.refresh();
      expect(flexLoaded().refreshing, isTrue);
      flex.arrivalRequests.last.reply.complete(_groups('020', '003'));
      await refresh;

      expect(flexLoaded().refreshing, isFalse);
      expect(flexLoaded().arrivals.data, hasLength(2));
      expect(flexLoaded().trackingVehicleNumber, '20529');
      expect(flexLoaded().trackingPhase, TrackingPhase.active);
    });

    test('buscar o mesmo ponto equivale a refresh', () async {
      await loadStop('30402');
      final tracking = flexCubit.track('20529');
      flex.positionRequests.single.reply.complete(_vehicle('20529', -16.7));
      await tracking;

      final again = flexCubit.load('30402');
      flex.arrivalRequests.last.reply.complete(_groups('020'));
      await again;

      expect(flexLoaded().trackingVehicleNumber, '20529');
    });

    test('falha no refresh mantém chegadas anteriores', () async {
      await loadStop('30402');
      final refresh = flexCubit.refresh();
      flex.arrivalRequests.last.reply.completeError(_transientError);
      await refresh;

      expect(flexLoaded().arrivals.data, hasLength(1));
      expect(flexLoaded().refreshError, isNotNull);
    });

    test('buscar outro ponto encerra o tracking', () async {
      await loadStop('30402');
      final tracking = flexCubit.track('20529');
      flex.positionRequests.single.reply.complete(_vehicle('20529', -16.7));
      await tracking;

      await loadStop('10001');

      expect(flexLoaded().stopId, '10001');
      expect(flexLoaded().tracking, isNull);
    });

    test('resposta atrasada de um ponto anterior é descartada', () async {
      final first = flexCubit.load('30402');
      final second = flexCubit.load('10001');

      flex.arrivalRequests.last.reply.complete(_groups('003'));
      await second;
      flex.arrivalRequests.first.reply.complete(_groups('020'));
      await first;

      expect(flexLoaded().stopId, '10001');
      expect(flexLoaded().arrivals.data.single.routeId, '003');
    });

    test('retomar logo depois não reconsulta a posição', () async {
      var clockNow = DateTime(2026, 10, 7, 12);
      final timed = StopArrivalsCubit(
        flex,
        trackingRefreshInterval: null,
        clock: () => clockNow,
      );
      addTearDown(timed.close);
      final loading = timed.load('30402');
      flex.arrivalRequests.last.reply.complete(_groups('020'));
      await loading;
      final tracking = timed.track('20529');
      flex.positionRequests.single.reply.complete(_vehicle('20529', -16.7));
      await tracking;

      clockNow = clockNow.add(const Duration(seconds: 3));
      timed.pauseTracking();
      await timed.resumeTracking();
      expect(flex.positionRequests, hasLength(1));

      clockNow = clockNow.add(const Duration(seconds: 10));
      timed.pauseTracking();
      final resumed = timed.resumeTracking();
      expect(flex.positionRequests, hasLength(2));
      flex.positionRequests.last.reply.complete(_vehicle('20529', -16.6));
      await resumed;
    });

    test('parar de acompanhar limpa o tracking', () async {
      await loadStop('30402');
      final tracking = flexCubit.track('20529');
      flex.positionRequests.single.reply.complete(_vehicle('20529', -16.7));
      await tracking;

      flexCubit.stopTracking();

      expect(flexLoaded().tracking, isNull);
    });
  });

  group('busca de ponto', () {
    late _FlexibleRepository flex;
    late StopArrivalsCubit searchCubit;

    const notFound = ApiException(
      code: 'SOURCE_INVALID_RESPONSE',
      message: 'RMTC arrivals payload has an unexpected shape.',
      retryable: true,
      statusCode: 502,
    );

    setUp(() {
      flex = _FlexibleRepository();
      searchCubit = StopArrivalsCubit(flex, trackingRefreshInterval: null);
    });

    tearDown(() => searchCubit.close());

    Future<void> loadOk(String stopId) async {
      final loading = searchCubit.load(stopId);
      flex.arrivalRequests.last.reply.complete(_groups('020'));
      await loading;
    }

    Future<void> loadFailing(String stopId, Object error) async {
      final loading = searchCubit.load(stopId);
      flex.arrivalRequests.last.reply.completeError(error);
      await loading;
    }

    test('erro sem ponto anterior não vira tela de conteúdo', () async {
      await loadFailing('99999', notFound);

      final state = searchCubit.state;
      expect(state, isA<StopArrivalsInitial>());
      final feedback = (state as StopArrivalsInitial).searchError!;
      expect(feedback.kind, SearchFeedbackKind.notFound);
      expect(feedback.title, 'Ponto não encontrado');
      // A mensagem técnica do Worker não chega na UI.
      expect(feedback.message, isNot(contains('RMTC')));
      expect(feedback.title, isNot(contains('payload')));
    });

    test('erro mantém o ponto válido anterior e o tracking', () async {
      await loadOk('30402');
      final tracking = searchCubit.track('20529');
      flex.positionRequests.single.reply.complete(_vehicle('20529', -16.7));
      await tracking;

      final searching = searchCubit.load('99999');
      final during = searchCubit.state as StopArrivalsLoaded;
      expect(during.stopId, '30402');
      expect(during.searchingStopId, '99999');
      flex.arrivalRequests.last.reply.completeError(notFound);
      await searching;

      final after = searchCubit.state as StopArrivalsLoaded;
      expect(after.stopId, '30402');
      expect(after.arrivals.data, hasLength(1));
      expect(after.trackingVehicleNumber, '20529');
      expect(after.searchingStopId, isNull);
      expect(after.searchError?.kind, SearchFeedbackKind.notFound);
    });

    test('nova busca válida limpa o erro e substitui o ponto', () async {
      await loadOk('30402');
      await loadFailing('99999', notFound);
      await loadOk('30100');

      final state = searchCubit.state as StopArrivalsLoaded;
      expect(state.stopId, '30100');
      expect(state.searchError, isNull);
    });

    test('separa timeout, sem conexão e indisponível', () async {
      await loadFailing(
        '1',
        const ApiException(
          code: 'CLIENT_TIMEOUT',
          message: 'x',
          retryable: true,
        ),
      );
      expect(
        (searchCubit.state as StopArrivalsInitial).searchError!.kind,
        SearchFeedbackKind.timeout,
      );

      await loadFailing(
        '2',
        const ApiException(
          code: 'NETWORK_ERROR',
          message: 'x',
          retryable: true,
        ),
      );
      expect(
        (searchCubit.state as StopArrivalsInitial).searchError!.title,
        'Sem conexão',
      );

      await loadFailing(
        '3',
        const ApiException(
          code: 'SOURCE_UNAVAILABLE',
          message: 'Upstream source is unavailable.',
          retryable: true,
          statusCode: 503,
        ),
      );
      expect(
        (searchCubit.state as StopArrivalsInitial).searchError!.title,
        'Serviço temporariamente indisponível',
      );
    });

    test('código vazio é aviso compacto e não apaga o ponto', () async {
      await loadOk('30402');
      await searchCubit.load('');

      final state = searchCubit.state as StopArrivalsLoaded;
      expect(state.stopId, '30402');
      expect(state.searchError?.kind, SearchFeedbackKind.invalidCode);
    });

    test('erro atrasado de busca antiga não sobrescreve a nova', () async {
      final old = searchCubit.load('99999');
      final fresh = searchCubit.load('30100');
      flex.arrivalRequests.last.reply.complete(_groups('020'));
      await fresh;
      flex.arrivalRequests.first.reply.completeError(notFound);
      await old;

      final state = searchCubit.state as StopArrivalsLoaded;
      expect(state.stopId, '30100');
      expect(state.searchError, isNull);
    });
  });
}

TransitSnapshot<List<ArrivalGroup>> _groups(String first, [String? second]) {
  ArrivalGroup group(String routeId) => ArrivalGroup(
    routeId: routeId,
    destination: null,
    next: const Arrival(
      vehicleId: 'rmtc:20529',
      vehicleNumber: '20529',
      minutes: 3,
      plannedArrival: null,
      predictedArrival: null,
      realtime: true,
      quality: ArrivalQuality.realtime,
    ),
    following: null,
  );
  return _snapshot([group(first), if (second != null) group(second)]);
}

/// Chegadas e posições pendentes até o teste completá-las; posição pode ser
/// `null` (fonte sem posição).
class _FlexibleRepository implements TransitRepository {
  final arrivalRequests =
      <
        ({String stopId, Completer<TransitSnapshot<List<ArrivalGroup>>> reply})
      >[];
  final positionRequests =
      <({String vehicleNumber, Completer<TrackedVehicle?> reply})>[];

  @override
  Future<TransitSnapshot<List<ArrivalGroup>>> getArrivals(String stopId) {
    final reply = Completer<TransitSnapshot<List<ArrivalGroup>>>();
    arrivalRequests.add((stopId: stopId, reply: reply));
    return reply.future;
  }

  @override
  Future<TransitSnapshot<TrackedVehicle?>> getVehiclePosition({
    required String vehicleNumber,
    required String stopId,
  }) async {
    final reply = Completer<TrackedVehicle?>();
    positionRequests.add((vehicleNumber: vehicleNumber, reply: reply));
    return _snapshot(await reply.future);
  }
}
