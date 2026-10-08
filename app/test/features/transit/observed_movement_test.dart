import 'package:busaogyn/src/features/transit/domain/entities/tracked_vehicle.dart';
import 'package:busaogyn/src/features/transit/domain/models/observed_movement.dart';
import 'package:busaogyn/src/features/transit/presentation/widgets/vehicle_map_data.dart';
import 'package:flutter_test/flutter_test.dart';

const _origin = GeoPosition(latitude: -16.7000, longitude: -49.2500);

/// Desloca [meters] para o norte (+) / sul (-) e leste (+) / oeste (-).
GeoPosition _offset(GeoPosition from, {double north = 0, double east = 0}) {
  const metersPerDegreeLat = 111320.0;
  final metersPerDegreeLon = 111320.0 * 0.9578; // cos(-16.7°)
  return GeoPosition(
    latitude: from.latitude + north / metersPerDegreeLat,
    longitude: from.longitude + east / metersPerDegreeLon,
  );
}

final _t0 = DateTime.utc(2026, 10, 7, 18);
DateTime _t(int seconds) => _t0.add(Duration(seconds: seconds));

void main() {
  group('azimute geodésico', () {
    test('pontos cardeais', () {
      expect(
        initialBearingDegrees(_origin, _offset(_origin, north: 100)),
        closeTo(0, 0.5),
      );
      expect(
        initialBearingDegrees(_origin, _offset(_origin, east: 100)),
        closeTo(90, 0.5),
      );
      expect(
        initialBearingDegrees(_origin, _offset(_origin, north: -100)),
        closeTo(180, 0.5),
      );
      expect(
        initialBearingDegrees(_origin, _offset(_origin, east: -100)),
        closeTo(270, 0.5),
      );
    });

    test('usa a geodésica, não a diferença crua de graus', () {
      // 100 m a leste e 100 m ao norte: 45°. A diferença crua de graus
      // (lon maior por causa da latitude) daria ~43,8°.
      final to = _offset(_origin, north: 100, east: 100);
      expect(initialBearingDegrees(_origin, to), closeTo(45, 0.5));
    });
  });

  group('interpolação angular pelo menor arco', () {
    test('359° → 1° passa por 0°, não gira 358°', () {
      expect(shortestAngleDelta(359, 1), closeTo(2, 1e-9));
      expect(interpolateAngle(359, 1, 0.5), closeTo(0, 1e-9));
      expect(interpolateAngle(1, 359, 0.5), closeTo(0, 1e-9));
    });

    test('termina exatamente no alvo e não passa dele', () {
      expect(interpolateAngle(10, 100, 1), closeTo(100, 1e-9));
      expect(interpolateAngle(10, 100, 2), closeTo(100, 1e-9));
      expect(interpolateAngle(10, 100, 0), closeTo(10, 1e-9));
    });
  });

  group('observedHeading', () {
    test('primeira posição não inventa direção', () {
      final m = ObservedMovement.empty.observe(
        _origin,
        sampledAt: _t(0),
        stale: false,
      );
      expect(m.observedHeading, isNull);
      expect(m.observedTrail, [_origin]);
    });

    test('duas posições reais suficientes geram direção', () {
      final m = ObservedMovement.empty
          .observe(_origin, sampledAt: _t(0), stale: false)
          .observe(_offset(_origin, east: 50), sampledAt: _t(15), stale: false);
      expect(m.observedHeading, closeTo(90, 1));
    });

    test('menos de 8 m mantém a direção anterior', () {
      final moving = ObservedMovement.empty
          .observe(_origin, sampledAt: _t(0), stale: false)
          .observe(_offset(_origin, east: 50), sampledAt: _t(15), stale: false);
      final jitter = moving.observe(
        _offset(_origin, east: 50, north: 5),
        sampledAt: _t(30),
        stale: false,
      );
      expect(jitter.observedHeading, moving.observedHeading);
    });

    test('pequenos passos somam até passar de 8 m', () {
      var m = ObservedMovement.empty.observe(
        _origin,
        sampledAt: _t(0),
        stale: false,
      );
      m = m.observe(
        _offset(_origin, north: 5),
        sampledAt: _t(15),
        stale: false,
      );
      expect(m.observedHeading, isNull);
      m = m.observe(
        _offset(_origin, north: 10),
        sampledAt: _t(30),
        stale: false,
      );
      expect(m.observedHeading, closeTo(0, 1));
    });

    test('salto acima de 1000 m não atualiza a direção', () {
      final moving = ObservedMovement.empty
          .observe(_origin, sampledAt: _t(0), stale: false)
          .observe(_offset(_origin, east: 50), sampledAt: _t(15), stale: false);
      final jumped = moving.observe(
        _offset(_origin, north: -3000),
        sampledAt: _t(30),
        stale: false,
      );
      expect(jumped.observedHeading, moving.observedHeading);
    });

    test('âncora a mais de 1000 m não congela a direção', () {
      // Parado 7 m (abaixo dos 8 m, a âncora fica na origem), depois anda
      // 996 m: do último ponto é movimento normal, da âncora passa de 1000 m.
      final near = _offset(_origin, north: 7);
      final far = _offset(near, north: 996);
      final m = ObservedMovement.empty
          .observe(_origin, sampledAt: _t(0), stale: false)
          .observe(near, sampledAt: _t(15), stale: false)
          .observe(far, sampledAt: _t(30), stale: false)
          .observe(_offset(far, east: 50), sampledAt: _t(45), stale: false);

      expect(m.observedHeading, closeTo(90, 1));
    });

    test('posição stale não cria direção nem rastro', () {
      final first = ObservedMovement.empty.observe(
        _origin,
        sampledAt: _t(0),
        stale: false,
      );
      final stale = first.observe(
        _offset(_origin, east: 50),
        sampledAt: _t(15),
        stale: true,
      );
      expect(stale.observedHeading, isNull);
      expect(stale.observedTrail, [_origin]);
    });

    test('mesma amostra repetida (cache) é ignorada', () {
      final first = ObservedMovement.empty.observe(
        _origin,
        sampledAt: _t(0),
        stale: false,
      );
      final repeated = first.observe(
        _offset(_origin, east: 50),
        sampledAt: _t(0),
        stale: false,
      );
      expect(identical(repeated, first), isTrue);
      expect(
        identical(
          first.observe(
            _offset(_origin, east: 50),
            sampledAt: null,
            stale: false,
          ),
          first,
        ),
        isTrue,
      );
    });
  });

  group('observedTrail', () {
    test('guarda no máximo 20 posições reais, as mais recentes', () {
      var m = ObservedMovement.empty;
      final positions = [
        for (var i = 0; i < 30; i++) _offset(_origin, east: i * 30.0),
      ];
      for (var i = 0; i < positions.length; i++) {
        m = m.observe(positions[i], sampledAt: _t(i * 15), stale: false);
      }
      expect(m.observedTrail, hasLength(observedTrailMaxPoints));
      expect(m.observedTrail.first, positions[10]);
      expect(m.observedTrail.last, positions.last);
      // Só posições recebidas, nenhuma interpolada.
      expect(m.observedTrail.every(positions.contains), isTrue);
    });

    test('menos de 2 m não cria ponto redundante', () {
      final m = ObservedMovement.empty
          .observe(_origin, sampledAt: _t(0), stale: false)
          .observe(_offset(_origin, east: 1), sampledAt: _t(15), stale: false);
      expect(m.observedTrail, [_origin]);
    });

    test('salto acima de 1000 m recomeça o rastro (sem linha gigante)', () {
      final far = _offset(_origin, north: 5000);
      final m = ObservedMovement.empty
          .observe(_origin, sampledAt: _t(0), stale: false)
          .observe(_offset(_origin, east: 40), sampledAt: _t(15), stale: false)
          .observe(far, sampledAt: _t(30), stale: false);
      expect(m.observedTrail, [far]);
      expect(
        observedTrailFeatureCollection(m.observedTrail)['features'],
        isEmpty,
      );
    });

    test('GeoJSON do rastro é uma LineString [lon, lat]', () {
      final b = _offset(_origin, east: 40);
      final geojson = observedTrailFeatureCollection([_origin, b]);
      final feature = (geojson['features'] as List).single as Map;
      expect(feature['geometry']['type'], 'LineString');
      expect(feature['geometry']['coordinates'], [
        [_origin.longitude, _origin.latitude],
        [b.longitude, b.latitude],
      ]);
    });

    test('o ônibus acompanhado leva a direção observada no GeoJSON', () {
      final geojson = vehicleFeatureCollection(_origin, heading: 123);
      final feature = (geojson['features'] as List).single as Map;
      expect(feature['properties']['heading'], 123);
      final neutral = vehicleFeatureCollection(_origin);
      expect(
        ((neutral['features'] as List).single as Map)['properties']['heading'],
        0,
      );
    });
  });
}
