import 'dart:async';

import 'package:busaogyn/src/features/saved_stops/domain/saved_stop.dart';
import 'package:busaogyn/src/features/saved_stops/domain/saved_stops_store.dart';

/// Armazenamento controlável: pausa a leitura, falha a leitura ou a gravação
/// e registra tudo o que foi gravado.
class FakeStore implements SavedStopsStore {
  FakeStore({
    SavedStopsData? initial,
    this.unreadable = false,
    this.isPersistent = true,
  }) : data = initial ?? SavedStopsData.empty;

  SavedStopsData data;
  final bool unreadable;
  final bool isPersistent;

  /// Enquanto houver um gate, `load` espera por ele.
  Completer<void>? loadGate;
  Object? loadError;
  Object? saveError;
  Completer<void>? saveGate;

  var loads = 0;
  final saves = <SavedStopsData>[];

  @override
  bool get persistent => isPersistent;

  @override
  Future<SavedStopsLoad> load() async {
    loads++;
    final gate = loadGate;
    if (gate != null) await gate.future;
    final error = loadError;
    if (error != null) throw error;
    return SavedStopsLoad(data, unreadable: unreadable);
  }

  @override
  Future<void> save(SavedStopsData next) async {
    final gate = saveGate;
    if (gate != null) await gate.future;
    final error = saveError;
    if (error != null) throw error;
    saves.add(next);
    data = next;
  }
}

/// Relógio que anda um segundo a cada leitura, para ordenar sem dormir.
class TickClock {
  var _now = DateTime.utc(2026, 10, 17, 12);

  DateTime call() {
    _now = _now.add(const Duration(seconds: 1));
    return _now;
  }
}

SavedStop stop(String code, {String? name, int second = 0}) => SavedStop(
  code: code,
  name: name,
  at: DateTime.utc(2026, 10, 17, 12, 0, second),
);

List<String> codes(List<SavedStop> stops) => [for (final s in stops) s.code];
