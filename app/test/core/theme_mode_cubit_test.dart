import 'package:busaogyn/src/core/settings/theme_mode_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('começa no tema salvo ou em Sistema', () {
    expect(
      ThemeModeCubit(MemoryThemePreferenceStore()).state,
      ThemeMode.system,
    );
    expect(
      ThemeModeCubit(MemoryThemePreferenceStore(ThemeMode.dark)).state,
      ThemeMode.dark,
    );
  });

  test('salva a escolha', () async {
    final store = MemoryThemePreferenceStore();
    final cubit = ThemeModeCubit(store);
    await cubit.select(ThemeMode.light);
    expect(cubit.state, ThemeMode.light);
    expect(store.read(), ThemeMode.light);
  });

  test('SharedPreferences guarda e lê o nome do modo', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesThemeStore(
      await SharedPreferences.getInstance(),
    );
    expect(store.read(), isNull);
    await store.write(ThemeMode.dark);
    expect(store.read(), ThemeMode.dark);
  });

  test('valor salvo inválido volta para Sistema', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'roxo'});
    final store = SharedPreferencesThemeStore(
      await SharedPreferences.getInstance(),
    );
    expect(store.read(), isNull);
    expect(ThemeModeCubit(store).state, ThemeMode.system);
  });

  test('falha ao salvar não desfaz a troca de tema', () async {
    final cubit = ThemeModeCubit(_FailingStore());
    await cubit.select(ThemeMode.dark);
    expect(cubit.state, ThemeMode.dark);
  });
}

class _FailingStore implements ThemePreferenceStore {
  @override
  ThemeMode? read() => null;

  @override
  Future<void> write(ThemeMode mode) async => throw Exception('disco cheio');
}
