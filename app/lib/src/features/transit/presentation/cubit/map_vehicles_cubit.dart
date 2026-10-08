import 'dart:async';
import 'dart:collection';

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
///   requisições em paralelo no total: timer, `sync` e `resume` dividem a
///   mesma fila.
/// - Conjunto deduplicado por número de veículo; trocar de ponto descarta o
///   conjunto anterior e invalida respostas em voo.
/// - Falha de um secundário não aparece na UI: mantém a última posição
///   válida, marcada como antiga, por até [maxStaleAge]; depois some.
/// - A expiração não espera o polling: um único `Timer` de expiração,
///   armado para o próximo prazo entre os secundários, remove quem passou do
///   limite e se rearma para o seguinte (ver [_scheduleExpiry]). Ele só relê
///   o estado local: nunca faz requisição, e o polling segue como estava.
/// - Usa só o endpoint de posição existente da API BusãoGyn.
///
/// Fronteira do limite: a idade total é `ageAtReceipt` (segundos do Worker)
/// mais os **segundos inteiros** locais desde a chegada, como sempre foi
/// mostrado na UI. Idade total <= [maxStaleAge] permanece; > [maxStaleAge]
/// some. Com limite de 90 s: 89 s e 90 s aparecem; o marcador sai quando o
/// contador chega a 91 s.
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

  /// Único timer de expiração (não há um por veículo). Fica ativo mesmo com
  /// o polling pausado: só relê o estado local, não consulta a rede.
  Timer? _expiryTimer;
  bool _paused = false;
  String? _stopId;
  List<SecondaryCandidate> _candidates = const [];
  final _entries = <String, _Entry>{};
  final _inFlight = <String>{};

  /// Fila única de consultas e quantos consumidores dela estão ativos.
  final _queue = Queue<SecondaryCandidate>();
  int _workers = 0;

  /// Completa quando a fila do ponto atual esvazia.
  Completer<void>? _drained;

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

  /// Retoma o timer e consulta na hora só quem não foi tentado nos últimos
  /// [retryAfter]: alternar janelas rapidamente não vira rajada.
  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    _armTimer();
    final now = _clock();
    await _fetch([
      for (final candidate in _candidates)
        if (_entries[candidate.vehicleNumber]?.lastAttemptAt case final last
            when last == null || now.difference(last) >= retryAfter)
          candidate,
    ]);
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
    // Consultas do ponto anterior ainda em voo são descartadas pela geração
    // e não ocupam vagas do ponto novo.
    _queue.clear();
    _workers = 0;
    _completeDrained();
    _candidates = const [];
    _trackedNumber = null;
    _trackedEntry = null;
    _timer?.cancel();
    _timer = null;
    // O prazo do ponto anterior não vale para o novo.
    _expiryTimer?.cancel();
    _expiryTimer = null;
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

  /// Põe [targets] na fila única e completa quando ela esvazia.
  Future<void> _fetch(List<SecondaryCandidate> targets) {
    final stopId = _stopId;
    if (stopId == null || isClosed) return Future.value();
    final queued = {for (final candidate in _queue) candidate.vehicleNumber};
    for (final candidate in targets) {
      final number = candidate.vehicleNumber;
      if (_inFlight.contains(number) || !queued.add(number)) continue;
      _queue.add(candidate);
    }
    if (_queue.isEmpty && _workers == 0) return Future.value();

    final drained = _drained ??= Completer<void>();
    while (_workers < maxConcurrent && _queue.isNotEmpty) {
      _workers++;
      unawaited(_work(stopId, _generation));
    }
    return drained.future;
  }

  Future<void> _work(String stopId, int generation) async {
    try {
      while (generation == _generation && _queue.isNotEmpty) {
        final candidate = _queue.removeFirst();
        final number = candidate.vehicleNumber;
        // Saiu do conjunto enquanto esperava na fila: nada a consultar.
        if (!_entries.containsKey(number) || !_inFlight.add(number)) continue;
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
            _entries[number]
              ?..position = position
              ..receivedAt = _clock()
              ..ageAtReceipt = snapshot.ageSeconds
              ..snapshotStale = snapshot.stale
              ..failing = false;
          }
        } catch (_) {
          if (generation != _generation) return;
          _markFailing(number);
        } finally {
          if (generation == _generation) _inFlight.remove(number);
        }
      }
    } finally {
      if (generation == _generation && --_workers == 0) {
        _emitState();
        _completeDrained();
      }
    }
  }

  void _completeDrained() {
    final drained = _drained;
    _drained = null;
    drained?.complete();
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
      // Idade real da posição: o que ela já tinha no Worker ao chegar mais o
      // tempo local desde então. Um snapshot que chega velho não ganha uma
      // janela nova inteira.
      final totalAgeSeconds = _totalAgeSeconds(entry, receivedAt, now);
      if (totalAgeSeconds > maxStaleAge.inSeconds) {
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
          ageSeconds: totalAgeSeconds,
        ),
      );
    }
    emit(MapVehiclesState(stopId: _stopId, secondaries: vehicles));
    _scheduleExpiry(now);
  }

  /// Idade total em segundos inteiros: o do Worker na chegada mais o tempo
  /// local desde então.
  int _totalAgeSeconds(_Entry entry, DateTime receivedAt, DateTime now) =>
      entry.ageAtReceipt + now.difference(receivedAt).inSeconds;

  /// Arma o único timer de expiração para o primeiro prazo entre os
  /// secundários visíveis; o disparo recalcula tudo em [_emitState], que
  /// remove quem passou do limite e chama este método de novo (próximo
  /// prazo, se houver).
  ///
  /// Cada [_emitState] (posição nova, sync, troca de ponto, expiração) cancela
  /// o timer anterior antes de armar outro: há no máximo um, e um prazo velho
  /// nunca sobrevive a uma posição mais nova. O prazo de um veículo é o
  /// instante em que sua idade total (segundos inteiros) chega a
  /// `maxStaleAge + 1`: `receivedAt + (maxStaleAge + 1 - ageAtReceipt)`.
  void _scheduleExpiry(DateTime now) {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    if (isClosed) return;
    DateTime? first;
    for (final candidate in _candidates) {
      final entry = _entries[candidate.vehicleNumber];
      final receivedAt = entry?.receivedAt;
      if (entry == null || entry.position == null || receivedAt == null) {
        continue;
      }
      final deadline = receivedAt.add(
        Duration(seconds: maxStaleAge.inSeconds + 1 - entry.ageAtReceipt),
      );
      if (first == null || deadline.isBefore(first)) first = deadline;
    }
    if (first == null) return;
    // Quem já passou do prazo saiu no `_emitState` que chamou este método;
    // o piso evita um disparo imediato em laço se o relógio recuar.
    final wait = first.difference(now);
    _expiryTimer = Timer(
      wait < const Duration(milliseconds: 1)
          ? const Duration(milliseconds: 1)
          : wait,
      _onExpiry,
    );
  }

  void _onExpiry() {
    _expiryTimer = null;
    if (!isClosed) _emitState();
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _generation++;
    _queue.clear();
    _completeDrained();
    return super.close();
  }
}
