import 'package:busaogyn/src/features/transit/domain/entities/arrival.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/domain/models/transit_snapshot.dart';
import 'package:busaogyn/src/features/transit/domain/repositories/transit_repository.dart';
import 'package:busaogyn/src/features/transit/presentation/cubit/map_vehicles_cubit.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositório que responde na hora (só microtasks, compatível com
/// `fakeAsync`) e conta as chamadas.
class _Repository implements TransitRepository {
  final ages = <String, int>{};
  final calls = <String>[];

  @override
  Future<TransitSnapshot<List<ArrivalGroup>>> getArrivals(String stopId) =>
      throw UnimplementedError();

  @override
  Future<TransitSnapshot<TrackedVehicle?>> getVehiclePosition({
    required String vehicleNumber,
    required String stopId,
  }) async {
    calls.add(vehicleNumber);
    return TransitSnapshot(
      data: TrackedVehicle(
        id: 'rmtc:$vehicleNumber',
        vehicleNumber: vehicleNumber,
        routeId: '003',
        routeName: null,
        destination: 'T MARANATA',
        position: GeoPosition(latitude: -16.68, longitude: -49.25),
        accessible: true,
        punctuality: VehiclePunctuality.unknown,
      ),
      fetchedAt: DateTime(2026, 10, 7, 12),
      stale: false,
      ageSeconds: ages[vehicleNumber] ?? 0,
    );
  }
}

ArrivalGroup _group(List<String> numbers) {
  Arrival arrival(String number) => Arrival(
    vehicleId: 'rmtc:$number',
    vehicleNumber: number,
    minutes: 5,
    plannedArrival: null,
    predictedArrival: null,
    realtime: true,
    quality: ArrivalQuality.realtime,
  );
  return ArrivalGroup(
    routeId: '003',
    destination: 'DESTINO',
    next: arrival(numbers.first),
    following: numbers.length > 1 ? arrival(numbers[1]) : null,
  );
}

/// Cubit + relógio simulado: `elapse` avança o relógio do cubit e o tempo
/// do `fakeAsync` juntos, sem dormir de verdade.
class _Rig {
  _Rig(this.async, {Duration? refreshInterval = const Duration(seconds: 30)}) {
    cubit = MapVehiclesCubit(
      repository,
      refreshInterval: refreshInterval,
      clock: () => now,
    );
  }

  final FakeAsync async;
  final repository = _Repository();
  var now = DateTime(2026, 10, 7, 12);
  late final MapVehiclesCubit cubit;

  void elapse(Duration d) {
    now = now.add(d);
    async.elapse(d);
  }

  void sync(List<String> numbers, {String stop = 'A'}) {
    cubit.sync(stopId: stop, groups: [_group(numbers)]);
    async.flushMicrotasks();
  }

  List<String> get numbers =>
      cubit.state.secondaries.map((v) => v.vehicleNumber).toList()..sort();

  /// Timers pendentes além do polling periódico (se houver).
  int get expiryTimers => async.nonPeriodicTimerCount;
}

const _s = Duration(seconds: 1);

void main() {
  test('1. 89 s: o secundário continua no mapa', () {
    fakeAsync((async) {
      final rig = _Rig(async, refreshInterval: null)..sync(['1']);
      rig.elapse(const Duration(seconds: 89));
      expect(rig.numbers, ['1']);
    });
  });

  test('2. 90 s exatos: ainda aparece (fronteira não virou >=)', () {
    fakeAsync((async) {
      final rig = _Rig(async, refreshInterval: null)..sync(['1']);
      rig.elapse(const Duration(seconds: 90));
      expect(rig.numbers, ['1']);
    });
  });

  test('3. logo depois de 90 s some, sem esperar o polling', () {
    fakeAsync((async) {
      // Próximo polling só em 120 s: a saída em 91 s não espera por ele.
      final rig = _Rig(async, refreshInterval: const Duration(seconds: 120))
        ..sync(['1']);
      rig.elapse(const Duration(seconds: 90));
      expect(rig.numbers, ['1']);
      rig.elapse(_s);
      expect(rig.numbers, isEmpty);
      expect(rig.repository.calls, hasLength(1));
    });
  });

  test('3b. a idade do Worker na chegada antecipa o prazo', () {
    fakeAsync((async) {
      final rig = _Rig(async, refreshInterval: null);
      rig.repository.ages['1'] = 40;
      rig.sync(['1']);
      rig.elapse(const Duration(seconds: 50));
      expect(rig.numbers, ['1']); // 40 + 50 = 90
      rig.elapse(_s);
      expect(rig.numbers, isEmpty); // 91
    });
  });

  test('4. a expiração não faz requisição', () {
    fakeAsync((async) {
      final rig = _Rig(async, refreshInterval: null)..sync(['1', '2']);
      expect(rig.repository.calls, hasLength(2));
      rig.elapse(const Duration(seconds: 200));
      expect(rig.numbers, isEmpty);
      expect(rig.repository.calls, hasLength(2));
    });
  });

  test('5. dois veículos, cada um no seu prazo', () {
    fakeAsync((async) {
      final rig = _Rig(async, refreshInterval: null);
      rig.repository.ages['1'] = 30; // prazo: 61 s
      rig.repository.ages['2'] = 0; // prazo: 91 s
      rig.sync(['1', '2']);
      rig.elapse(const Duration(seconds: 60));
      expect(rig.numbers, ['1', '2']);
      rig.elapse(_s);
      expect(rig.numbers, ['2']);
      rig.elapse(const Duration(seconds: 29));
      expect(rig.numbers, ['2']);
      rig.elapse(_s);
      expect(rig.numbers, isEmpty);
    });
  });

  test('6. posição nova antes do prazo reagenda a expiração', () {
    fakeAsync((async) {
      final rig = _Rig(async)..sync(['1']);
      // O tique de 30 s traz posição nova (idade 0) e renova o prazo.
      rig.elapse(const Duration(seconds: 30));
      rig.elapse(const Duration(seconds: 30));
      rig.elapse(const Duration(seconds: 30));
      rig.elapse(const Duration(seconds: 30));
      expect(rig.numbers, ['1']); // 120 s depois, mas sempre renovado
      expect(rig.repository.calls.length, greaterThan(1));
      expect(rig.expiryTimers, 1);
    });
  });

  test('7. mudança de ponto: o prazo antigo não afeta o novo', () {
    fakeAsync((async) {
      final rig = _Rig(async, refreshInterval: null)..sync(['1'], stop: 'A');
      rig.elapse(const Duration(seconds: 60));
      rig.sync(['2'], stop: 'B'); // prazo do 2: 91 s a partir de agora
      expect(rig.numbers, ['2']);
      rig.elapse(const Duration(seconds: 31)); // passa do prazo do ponto A
      expect(rig.numbers, ['2']);
      rig.elapse(const Duration(seconds: 60));
      expect(rig.numbers, isEmpty);
    });
  });

  test('8. geração antiga não ressuscita nem remove', () {
    fakeAsync((async) {
      final rig = _Rig(async, refreshInterval: null)..sync(['1'], stop: 'A');
      rig.sync(['1'], stop: 'B');
      rig.sync(['1'], stop: 'A'); // volta: busca de novo, estado novo
      expect(rig.numbers, ['1']);
      final calls = rig.repository.calls.length;
      rig.elapse(const Duration(seconds: 91));
      expect(rig.numbers, isEmpty);
      // Nada reapareceu e nenhuma busca foi disparada pela expiração.
      rig.elapse(const Duration(seconds: 120));
      expect(rig.numbers, isEmpty);
      expect(rig.repository.calls.length, calls);
    });
  });

  test('9. polling e expiração próximos: sem duplicação nem corrida', () {
    fakeAsync((async) {
      final rig = _Rig(async)..sync(['1']);
      rig.repository.ages['1'] = 1; // tique renova com idade 1
      // Chegada em 0 s; prazo em 91 s; tiques em 30, 60, 90 s renovam antes.
      rig.elapse(const Duration(seconds: 90));
      expect(rig.numbers, ['1']);
      rig.elapse(const Duration(seconds: 1));
      expect(rig.numbers, ['1']);
      // Uma única entrada, e só um timer de expiração armado.
      expect(rig.cubit.state.secondaries, hasLength(1));
      expect(rig.expiryTimers, 1);
    });
  });

  test('10. close cancela o timer de expiração', () {
    fakeAsync((async) {
      final rig = _Rig(async, refreshInterval: null)..sync(['1']);
      expect(rig.expiryTimers, 1);
      rig.cubit.close();
      async.flushMicrotasks();
      expect(rig.expiryTimers, 0);
      rig.elapse(const Duration(seconds: 200)); // não deve lançar
    });
  });

  test('11. vários ciclos mantêm no máximo um timer de expiração', () {
    fakeAsync((async) {
      final rig = _Rig(async, refreshInterval: null);
      for (var i = 0; i < 5; i++) {
        rig.sync(['1', '2']);
        rig.sync(['1', '2', '3']);
        rig.cubit.pause();
        rig.async.flushMicrotasks();
        expect(rig.expiryTimers, lessThanOrEqualTo(1));
        rig.cubit.resume();
        rig.async.flushMicrotasks();
        expect(rig.expiryTimers, lessThanOrEqualTo(1));
        rig.elapse(const Duration(seconds: 100));
        expect(rig.expiryTimers, lessThanOrEqualTo(1));
      }
      rig.elapse(const Duration(seconds: 200));
      expect(rig.expiryTimers, 0);
    });
  });
}
