import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onde a escolha de tema fica guardada entre aberturas do app.
abstract interface class ThemePreferenceStore {
  ThemeMode? read();
  Future<void> write(ThemeMode mode);
}

/// Guarda em memória; usado em testes e quando o armazenamento falha.
class MemoryThemePreferenceStore implements ThemePreferenceStore {
  MemoryThemePreferenceStore([this._mode]);

  ThemeMode? _mode;

  @override
  ThemeMode? read() => _mode;

  @override
  Future<void> write(ThemeMode mode) async => _mode = mode;
}

class SharedPreferencesThemeStore implements ThemePreferenceStore {
  SharedPreferencesThemeStore(this._preferences);

  static const _key = 'theme_mode';

  final SharedPreferences _preferences;

  @override
  ThemeMode? read() {
    final value = _preferences.getString(_key);
    for (final mode in ThemeMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }

  @override
  Future<void> write(ThemeMode mode) => _preferences.setString(_key, mode.name);
}

/// Tema escolhido em Ajustes (sistema, noturno ou claro). O mapa acompanha.
class ThemeModeCubit extends Cubit<ThemeMode> {
  ThemeModeCubit(this._store) : super(_store.read() ?? ThemeMode.system);

  final ThemePreferenceStore _store;

  Future<void> select(ThemeMode mode) async {
    if (mode == state) return;
    emit(mode);
    try {
      await _store.write(mode);
    } catch (_) {
      // Sem persistência a escolha vale até fechar o app.
    }
  }
}
