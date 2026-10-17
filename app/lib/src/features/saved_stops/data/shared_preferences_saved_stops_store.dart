import 'package:shared_preferences/shared_preferences.dart';

import '../domain/saved_stop.dart';
import '../domain/saved_stops_store.dart';
import 'saved_stops_codec.dart';

/// Favoritos e recentes em `shared_preferences` (a mesma API que já guarda o
/// tema), como um único JSON versionado na chave [key].
class SharedPreferencesSavedStopsStore implements SavedStopsStore {
  SharedPreferencesSavedStopsStore(
    this._preferences, {
    this.favoriteLimit = defaultFavoriteStopsLimit,
    this.recentLimit = defaultRecentStopsLimit,
  });

  static const key = 'busaogyn.saved_stops.v1';

  final SharedPreferences _preferences;
  final int favoriteLimit;
  final int recentLimit;

  @override
  bool get persistent => true;

  @override
  Future<SavedStopsLoad> load() async {
    // `getString` lança se a chave guarda outro tipo; isso é dado ilegível.
    String? raw;
    try {
      raw = _preferences.getString(key);
    } catch (_) {
      return const SavedStopsLoad(SavedStopsData.empty, unreadable: true);
    }
    return decodeSavedStops(
      raw,
      favoriteLimit: favoriteLimit,
      recentLimit: recentLimit,
    );
  }

  @override
  Future<void> save(SavedStopsData data) async {
    final ok = await _preferences.setString(key, encodeSavedStops(data));
    if (!ok) throw StateError('shared_preferences não gravou $key');
  }
}
