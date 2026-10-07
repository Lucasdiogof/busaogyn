import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/arrival.dart';
import '../../domain/entities/map_vehicle.dart';
import '../../domain/entities/tracked_vehicle.dart';
import '../../domain/repositories/transit_repository.dart';
import '../map_vehicles/secondary_vehicle_selector.dart';

/// Outros ônibus em tempo real do ponto consultado, com a última posição
/// real de cada um. O ônibus acompanhado não entra: ele segue no
/// `StopArrivalsCubit`.
final class MapVehiclesState {
  const MapVehiclesState({this.stopId, this.secondaries = const []});

  final String? stopId;
  final List<MapVehicle> secondaries;

  MapVehicle? byNumber(String vehicleNumber) {
    for (final vehicle in secondaries) {
      if (vehicle.vehicleNumber == vehicleNumber) return vehicle;
    }
    return null;
  }
}

class _Entry {
  _Entry({required this.candidate});

  SecondaryCandidate candidate;
  GeoPosition? position;
  DateTime? receivedAt;
  int ageAtReceipt = 0;
  bool snapshotStale = false;
  bool failing = false;

  /// Última tentativa de consulta; evita repetir o que acabou de falhar.
  DateTime? lastAttemptAt;
}

/// Único coordenador de posição dos ônibus secundários.
///
/// - Um só `Timer` (não há timer por marcador), com intervalo de
///   [refreshInterval] (~30 s; o acompanhado segue em ~15 s).
/// - No máximo [limit] veículos (menor ETA primeiro) e [maxConcurrent]
///   requisições em paralelo.
/// - Conjunto deduplicado por número de veículo; trocar de ponto descarta o
///   conjunto anterior e invalida respostas em voo.
/// - Falha de um secundário não aparece na UI: mantém a última posição
///   válida, marcada como antiga, por até [maxStaleAge]; depois some.
/// - Usa só o endpoint de posição existente da API BusãoGyn.
class MapVehiclesCubit extends Cubit<MapVehiclesState> {
  MapVehiclesCubit(
    this._repository, {
    this.refreshInterval = const Duration(seconds: 30),
    this.limit = defaultSecondaryVehicleLimit,
    this.maxConcurrent = 3,
    this.maxStaleAge = const Duration(seconds: 90),
    this.retryAfter = const Duration(seconds: 10),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const MapVehiclesState());

  final TransitRepository _repository;
  final Duration? refreshInterval;
  final int limit;
  final int maxConcurrent;
  final Duration maxStaleAge;

  /// Intervalo mínimo entre tentativas de um veículo ainda sem posição.
  final Duration retryAfter;
  final DateTime Function() _clock;

  Timer? _timer;
  bool _paused = false;
  String? _stopId;
  List<SecondaryCandidate> _candidates = const [];
  final _entries = <String, _Entry>{};
  final _inFlight = <String>{};

  /// Invalida respostas de um ponto anterior.
  int _generation = 0;

  /// Último ônibus acompanhado e sua posição: ao trocar de acompanhado, o
  /// anterior vira secundário já com a posição que tinha.
  String? _trackedNumber;
  _Entry? _trackedEntry;

  /// Chamado a cada mudança do `StopArrivalsCubit`; barato quando nada
  /// relevante mudou.
  void sync({
    required String? stopId,
    required List<ArrivalGroup> groups,
    String? trackedVehicleNumber,
    TrackedVehicle? trackedVehicle,
    int trackedAgeSeconds = 0,
    bool trackedStale = false,
  }) {
    if (stopId != _stopId) _reset(stopId);
    if (stopId == null) return;

    _syncTracked(
      trackedVehicleNumber,
      trackedVehicle,
      trackedAgeSeconds,
      trackedStale,
    );

    final next = selectSecondaryCandidates(
      groups,
      trackedVehicleNumber: trackedVehicleNumber,
      limit: limit,
    );
    final keep = {for (final candidate in next) candidate.vehicleNumber};
    _entries.removeWhere((number, _) => !keep.contains(number));
    for (final candidate in next) {
      final entry = _entries.putIfAbsent(
        candidate.vehicleNumber,
        () => _Entry(candidate: candidate),
      );
      entry.candidate = candidate;
    }
    _candidates = next;

    _armTimer();
    _emitState();

    final now = _clock();
    final missing = next.where((candidate) {
      final entry = _entries[candidate.vehicleNumber]!;
      final attempt = entry.lastAttemptAt;
      return entry.position == null &&
          (attempt == null || now.difference(attempt) >= retryAfter);
    }).toList();
    if (missing.isNotEmpty && !_paused) unawaited(_fetch(missing));
  }

  /// Mesma atualização do timer, disparada à mão (testes).
  @visibleForTesting
  Future<void> refreshNow() => _fetch(_candidates);

  void pause() {
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    _armTimer();
    await _fetch(_candidates);
  }

  void _syncTracked(
    String? number,
    TrackedVehicle? vehicle,
    int ageSeconds,
    bool stale,
  ) {
    if (_trackedNumber != number) {
      final previous = _trackedNumber;
      final previousEntry = _trackedEntry;
      if (previous != null &&
          previousEntry != null &&
          previousEntry.position != null) {
        _entries[previous] = previousEntry;
      }
      _trackedNumber = number;
      _trackedEntry = null;
    }
    final position = vehicle?.position;
    if (number == null || position == null) return;
    final entry = _trackedEntry ??= _Entry(
      candidate: SecondaryCandidate(
        vehicleNumber: number,
        routeId: vehicle?.routeId ?? '',
        destination: vehicle?.destination,
        minutes: null,
      ),
    );
    entry
      ..position = position
      ..receivedAt = _clock()
      ..ageAtReceipt = ageSeconds
      ..snapshotStale = stale
      ..failing = false;
  }

  void _reset(String? stopId) {
    _generation++;
    _stopId = stopId;
    _entries.clear();
    _inFlight.clear();
    _candidates = const [];
    _trackedNumber = null;
    _trackedEntry = null;
    _timer?.cancel();
    _timer = null;
    emit(MapVehiclesState(stopId: stopId));
  }

  void _armTimer() {
    final interval = refreshInterval;
    if (interval == null || _paused || _candidates.isEmpty) {
      if (_candidates.isEmpty) {
        _timer?.cancel();
        _timer = null;
      }
      return;
    }
    _timer ??= Timer.periodic(interval, (_) {
      unawaited(_fetch(_candidates));
    });
  }

  Future<void> _fetch(List<SecondaryCandidate> targets) async {
    final stopId = _stopId;
    if (stopId == null) return;
    final generation = _generation;
    final queue = Queue<SecondaryCandidate>.of(
      targets.where((c) => !_inFlight.contains(c.vehicleNumber)),
    );
    if (queue.isEmpty) return;

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final candidate = queue.removeFirst();
        final number = candidate.vehicleNumber;
        if (!_inFlight.add(number)) continue;
        _entries[number]?.lastAttemptAt = _clock();
        try {
          final snapshot = await _repository.getVehiclePosition(
            vehicleNumber: number,
            stopId: stopId,
          );
          if (generation != _generation) return;
          final position = snapshot.data?.position;
          if (position == null) {
            _markFailing(number);
          } else {
            final entry = _entries[number];
            if (entry != null) {
              entry
                ..position = position
                ..receivedAt = _clock()
                ..ageAtReceipt = snapshot.ageSeconds
                ..snapshotStale = snapshot.stale
                ..failing = false;
            }
          }
        } catch (_) {
          if (generation != _generation) return;
          _markFailing(number);
        } finally {
          if (generation == _generation) _inFlight.remove(number);
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < math.min(maxConcurrent, queue.length); i++) worker(),
    ]);
    if (generation == _generation && !isClosed) _emitState();
  }

  void _markFailing(String number) {
    final entry = _entries[number];
    if (entry != null && entry.position != null) entry.failing = true;
  }

  void _emitState() {
    if (isClosed) return;
    final now = _clock();
    final vehicles = <MapVehicle>[];
    for (final candidate in _candidates) {
      final entry = _entries[candidate.vehicleNumber];
      final position = entry?.position;
      final receivedAt = entry?.receivedAt;
      if (entry == null || position == null || receivedAt == null) continue;
      final since = now.difference(receivedAt);
      if (since > maxStaleAge) {
        // Posição velha demais para ser mostrada como se fosse atual.
        entry
          ..position = null
          ..receivedAt = null;
        continue;
      }
      vehicles.add(
        MapVehicle(
          vehicleNumber: candidate.vehicleNumber,
          routeId: candidate.routeId.isEmpty ? null : candidate.routeId,
          destination: candidate.destination,
          position: position,
          isTracked: false,
          stale: entry.failing || entry.snapshotStale,
          ageSeconds: entry.ageAtReceipt + since.inSeconds,
        ),
      );
    }
    emit(MapVehiclesState(stopId: _stopId, secondaries: vehicles));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _generation++;
    return super.close();
  }
}
