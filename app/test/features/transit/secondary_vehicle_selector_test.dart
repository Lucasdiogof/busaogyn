import 'package:busaogyn/src/features/transit/domain/entities/arrival.dart';
import 'package:busaogyn/src/features/transit/presentation/map_vehicles/secondary_vehicle_selector.dart';
import 'package:flutter_test/flutter_test.dart';

Arrival _arrival(
  String? vehicleNumber, {
  int? minutes = 5,
  ArrivalQuality quality = ArrivalQuality.realtime,
}) {
  return Arrival(
    vehicleId: vehicleNumber == null ? null : 'rmtc:$vehicleNumber',
    vehicleNumber: vehicleNumber,
    minutes: minutes,
    plannedArrival: null,
    predictedArrival: null,
    realtime: quality == ArrivalQuality.realtime,
    quality: quality,
  );
}

ArrivalGroup _group(String routeId, Arrival next, [Arrival? following]) {
  return ArrivalGroup(
    routeId: routeId,
    destination: 'DESTINO $routeId',
    next: next,
    following: following,
  );
}

List<String> _numbers(List<SecondaryCandidate> candidates) =>
    candidates.map((c) => c.vehicleNumber).toList();

void main() {
  group('selectSecondaryCandidates', () {
    test('junta next e following de cada linha, sem duplicar o veículo', () {
      final result = selectSecondaryCandidates([
        _group(
          '003',
          _arrival('20051', minutes: 2),
          _arrival('20064', minutes: 9),
        ),
        _group('020', _arrival('50462', minutes: 4)),
        // Mesmo veículo aparecendo em outra linha/posição: um só marcador.
        _group('021', _arrival('20051', minutes: 30)),
      ]);

      expect(_numbers(result), ['20051', '50462', '20064']);
      // Fica o registro de menor ETA do veículo repetido.
      expect(result.first.minutes, 2);
    });

    test('ignora previsão programada e desconhecida', () {
      final result = selectSecondaryCandidates([
        _group(
          '003',
          _arrival('20051', quality: ArrivalQuality.scheduled),
          _arrival('20064', quality: ArrivalQuality.unknown),
        ),
        _group('020', _arrival('50462')),
      ]);

      expect(_numbers(result), ['50462']);
    });

    test('ignora veículo sem número ou com número vazio', () {
      final result = selectSecondaryCandidates([
        _group('003', _arrival(null), _arrival('  ')),
        _group('020', _arrival('50462')),
      ]);

      expect(_numbers(result), ['50462']);
    });

    test('exclui o ônibus acompanhado', () {
      final result = selectSecondaryCandidates([
        _group('003', _arrival('20051'), _arrival('20064')),
      ], trackedVehicleNumber: '20051');

      expect(_numbers(result), ['20064']);
    });

    test('respeita o limite e prioriza o menor ETA', () {
      final groups = [
        for (var i = 0; i < 9; i++)
          _group('L$i', _arrival('2000$i', minutes: 20 - i)),
      ];

      final result = selectSecondaryCandidates(groups, limit: 6);

      expect(result, hasLength(6));
      // ETAs 12..17 (veículos 20008 a 20003), do menor para o maior.
      expect(_numbers(result), [
        '20008',
        '20007',
        '20006',
        '20005',
        '20004',
        '20003',
      ]);
    });

    test('sem ETA fica por último, e o desempate é estável', () {
      final result = selectSecondaryCandidates([
        _group('A', _arrival('20090', minutes: null)),
        _group('B', _arrival('20002', minutes: 3)),
        _group('C', _arrival('20001', minutes: 3)),
      ]);

      expect(_numbers(result), ['20001', '20002', '20090']);
    });

    test('limite padrão é 6', () {
      expect(defaultSecondaryVehicleLimit, 6);
      final groups = [
        for (var i = 0; i < 10; i++) _group('L$i', _arrival('3000$i')),
      ];
      expect(selectSecondaryCandidates(groups), hasLength(6));
    });
  });
}
