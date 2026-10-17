import '../domain/saved_stop.dart';
import '../domain/saved_stops_store.dart';

/// Guarda em memória: testes, e o app quando o armazenamento do aparelho não
/// está disponível (nesse caso [volatile] é `true` e a tela avisa).
class MemorySavedStopsStore implements SavedStopsStore {
  MemorySavedStopsStore({SavedStopsData? initial, this.volatile = false})
    : _data = initial ?? SavedStopsData.empty;

  final bool volatile;
  SavedStopsData _data;

  @override
  bool get persistent => !volatile;

  @override
  Future<SavedStopsLoad> load() async => SavedStopsLoad(_data);

  @override
  Future<void> save(SavedStopsData data) async => _data = data;
}
