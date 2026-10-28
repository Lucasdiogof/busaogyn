import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../features/transit/domain/entities/tracked_vehicle.dart';

/// Por que não há posição. A tela explica cada caso uma vez, sem insistir.
enum LocationProblem { denied, deniedForever, serviceOff, timeout, unavailable }

class LocationFailure implements Exception {
  const LocationFailure(this.problem);

  final LocationProblem problem;

  @override
  String toString() => 'LocationFailure($problem)';
}

/// Posição atual com a precisão informada pelo sistema (raio, em metros).
class LocationFix {
  const LocationFix(this.position, this.accuracyM);

  final GeoPosition position;
  final double accuracyM;
}

/// Uma leitura da posição atual, só quando o passageiro pede. Sem histórico,
/// sem segundo plano e sem enviar a posição para lugar nenhum.
abstract interface class LocationService {
  /// Pede permissão se ainda não foi pedida; lança [LocationFailure].
  Future<LocationFix> current();

  /// Abre os ajustes do sistema adequados ao [problem], quando existirem.
  Future<void> openSettings(LocationProblem problem);
}

/// Android, iOS e Web pelo `geolocator` (no Web, a API de geolocalização do
/// navegador, que só funciona em HTTPS ou localhost).
class DeviceLocationService implements LocationService {
  const DeviceLocationService({this.timeLimit = const Duration(seconds: 15)});

  final Duration timeLimit;

  @override
  Future<LocationFix> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationFailure(LocationProblem.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.denied:
          throw const LocationFailure(LocationProblem.denied);
        case LocationPermission.deniedForever:
          throw const LocationFailure(LocationProblem.deniedForever);
        case LocationPermission.whileInUse ||
            LocationPermission.always ||
            LocationPermission.unableToDetermine:
          break;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(timeLimit: timeLimit),
      );
      return LocationFix(
        GeoPosition(latitude: p.latitude, longitude: p.longitude),
        p.accuracy,
      );
    } on LocationFailure {
      rethrow;
    } on TimeoutException {
      throw const LocationFailure(LocationProblem.timeout);
    } on LocationServiceDisabledException {
      throw const LocationFailure(LocationProblem.serviceOff);
    } on PermissionDeniedException {
      throw const LocationFailure(LocationProblem.denied);
    } catch (_) {
      throw const LocationFailure(LocationProblem.unavailable);
    }
  }

  @override
  Future<void> openSettings(LocationProblem problem) async {
    try {
      if (problem == LocationProblem.serviceOff) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    } catch (_) {
      // Web e plataformas sem tela de ajustes: a mensagem já diz o que fazer.
    }
  }
}
