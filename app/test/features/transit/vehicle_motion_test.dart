import 'package:busaogyn/src/features/transit/domain/entities/map_vehicle.dart';
import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/vehicle_motion.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = GeoPosition(latitude: -16.6800, longitude: -49.2500);
// ~111 m ao norte de _a.
const _b = GeoPosition(latitude: -16.6790, longitude: -49.2500);
const _c = GeoPosition(latitude: -16.6780, longitude: -49.2500);

void main() {
  group('interpolatePosition', () {
    test('termina exatamente em B', () {
      final end = interpolatePosition(_a, _b, 1);
      expect(end.latitude, _b.latitude);
      expect(end.longitude, _b.longitude);
    });

    test('nunca extrapola além de B', () {
      for (final t in [1.0, 1.01, 1.5, 4.0]) {
        final p = interpolatePosition(_a, _b, t);
        expect(p.latitude, _b.latitude);
        expect(p.longitude, _b.longitude);
      }
      for (final t in [0.0, -0.5]) {
        expect(interpolatePosition(_a, _b, t).latitude, _a.latitude);
      }
    });

    test('fica entre A e B durante a transição', () {
      final mid = interpolatePosition(_a, _b, 0.5);
      expect(mid.latitude, inInclusiveRange(_a.latitude, _b.latitude));
      expect(mid.latitude, isNot(_a.latitude));
      expect(mid.latitude, isNot(_b.latitude));
    });
  });

  group('shouldAnimateMove', () {
    test('anima deslocamento normal de ônibus', () {
      expect(distanceMeters(_a, _b), closeTo(111, 2));
      expect(shouldAnimateMove(_a, _b), isTrue);
    });

    test('não anima ruído de GPS', () {
      const noise = GeoPosition(latitude: -16.68000001, longitude: -49.25);
      expect(shouldAnimateMove(_a, noise), isFalse);
    });

    test('salto absurdo troca direto, sem percorrer o mapa', () {
      const far = GeoPosition(latitude: -16.6500, longitude: -49.2500);
      expect(distanceMeters(_a, far), greaterThan(maxAnimatedJumpMeters));
      expect(shouldAnimateMove(_a, far), isFalse);
    });

    test('duração e limites documentados', () {
      expect(
        markerTransitionDuration.inMilliseconds,
        inInclusiveRange(500, 1000),
      );
      expect(maxAnimatedJumpMeters, 1000);
    });
  });

  group('VehicleMotion', () {
    test('primeira posição aparece direto, sem animação', () {
      final motion = VehicleMotion();
      motion.setTarget('a', _a, Duration.zero);
      expect(motion.shown('a'), _a);
      expect(motion.animating, isFalse);
    });

    test('A → B anima e fica parado em B, sem prever além', () {
      final motion = VehicleMotion();
      motion.setTarget('a', _a, Duration.zero);
      motion.setTarget('a', _b, const Duration(seconds: 10));
      expect(motion.animating, isTrue);

      // Começo: ainda em A.
      motion.tick(const Duration(seconds: 10));
      expect(motion.shown('a')!.latitude, _a.latitude);

      // Meio: entre A e B.
      expect(
        motion.tick(const Duration(seconds: 10, milliseconds: 350)),
        isTrue,
      );
      expect(
        motion.shown('a')!.latitude,
        inExclusiveRange(_a.latitude, _b.latitude),
      );

      // Fim: exatamente em B e a animação acaba.
      expect(
        motion.tick(const Duration(seconds: 10, milliseconds: 700)),
        isFalse,
      );
      expect(motion.shown('a')!.latitude, _b.latitude);
      expect(motion.animating, isFalse);

      // Muito depois, sem nova amostra: continua em B.
      motion.tick(const Duration(minutes: 5));
      expect(motion.shown('a')!.latitude, _b.latitude);
      expect(motion.shown('a')!.longitude, _b.longitude);
    });

    test('mesma amostra repetida não reinicia a transição', () {
      final motion = VehicleMotion();
      motion.setTarget('a', _a, Duration.zero);
      motion.setTarget('a', _b, const Duration(seconds: 1));
      motion.tick(const Duration(seconds: 1, milliseconds: 600));
      motion.setTarget('a', _b, const Duration(seconds: 1, milliseconds: 600));
      motion.tick(const Duration(seconds: 1, milliseconds: 700));
      expect(motion.shown('a')!.latitude, _b.latitude);
      expect(motion.animating, isFalse);
    });

    test('nova amostra no meio da transição parte de onde o marcador está', () {
      final motion = VehicleMotion();
      motion.setTarget('a', _a, Duration.zero);
      motion.setTarget('a', _b, Duration.zero);
      motion.tick(const Duration(milliseconds: 350));
      final partial = motion.shown('a')!;

      motion.setTarget('a', _c, const Duration(milliseconds: 350));
      motion.tick(const Duration(milliseconds: 350));
      expect(motion.shown('a')!.latitude, partial.latitude);

      motion.tick(const Duration(milliseconds: 1050));
      expect(motion.shown('a')!.latitude, _c.latitude);
    });

    test('salto grande troca direto', () {
      final motion = VehicleMotion();
      const far = GeoPosition(latitude: -16.6000, longitude: -49.2500);
      motion.setTarget('a', _a, Duration.zero);
      motion.setTarget('a', far, const Duration(seconds: 1));
      expect(motion.shown('a'), far);
      expect(motion.animating, isFalse);
    });

    test('posição nula remove o marcador; retainOnly descarta os demais', () {
      final motion = VehicleMotion();
      motion.setTarget('a', _a, Duration.zero);
      motion.setTarget('b', _b, Duration.zero);
      motion.setTarget('a', null, Duration.zero);
      expect(motion.shown('a'), isNull);

      motion.retainOnly({});
      expect(motion.shown('b'), isNull);
    });
  });

  group('MapVehicle', () {
    MapVehicle vehicle({bool tracked = false, bool stale = false}) {
      return MapVehicle(
        vehicleNumber: '20051',
        position: _a,
        isTracked: tracked,
        stale: stale,
        ageSeconds: 3,
      );
    }

    test('o acompanhado tem prioridade visual sobre os secundários', () {
      expect(
        vehicle(tracked: true).visual.markerVariant,
        MarkerVariant.tracked,
      );
      expect(vehicle().visual.markerVariant, MarkerVariant.secondary);
    });

    test('posição antiga vira stale, acompanhado ou não', () {
      expect(
        vehicle(tracked: true, stale: true).visual.markerVariant,
        MarkerVariant.stale,
      );
      expect(vehicle(stale: true).visual.markerVariant, MarkerVariant.stale);
    });

    test(
      'operadora, família e classe da rede ficam nulas sem fonte oficial',
      () {
        final visual = vehicle().visual;
        expect(visual.operator, isNull);
        expect(visual.vehicleFamily, isNull);
        expect(visual.networkClass, isNull);
      },
    );
  });
}
