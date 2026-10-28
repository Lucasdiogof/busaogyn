import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/api_config.dart';
import 'core/network/api_client.dart';
import 'core/settings/theme_mode_cubit.dart';
import 'features/catalog/data/catalog_codec.dart';
import 'features/catalog/domain/transit_catalog.dart';
import 'features/saved_stops/data/memory_saved_stops_store.dart';
import 'features/saved_stops/data/shared_preferences_saved_stops_store.dart';
import 'features/saved_stops/domain/saved_stops_store.dart';
import 'features/transit/data/repositories/http_transit_repository.dart';

/// Inicia o app. Produção (`lib/main.dart`) chama sem argumentos: sem
/// catálogo, comportamento idêntico ao de antes da v2.
///
/// [devCatalogJson] só é passado pelo entrypoint gerado localmente em
/// `dev_catalog/main.dart` (fora do Git). Os dados oficiais da CMTC ainda não
/// podem ser redistribuídos, então o catálogo é recusado em build release
/// mesmo que alguém aponte o entrypoint de desenvolvimento para ele.
Future<void> runBusaoGyn({String? devCatalogJson}) async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicense();

  final apiClient = ApiClient(baseUrl: ApiConfig.baseUrl);
  final repository = HttpTransitRepository(apiClient);

  final preferences = await _preferences();
  runApp(
    BusaoGynApp(
      repository: repository,
      themeStore: preferences == null
          ? MemoryThemePreferenceStore()
          : SharedPreferencesThemeStore(preferences),
      savedStopsStore: _savedStopsStore(preferences),
      catalog: loadDevCatalog(devCatalogJson, releaseMode: kReleaseMode),
    ),
  );
}

/// Catálogo de desenvolvimento, ou `null` (desligado). Nunca em release;
/// formato inválido também desliga (o app segue como antes).
TransitCatalog? loadDevCatalog(String? json, {required bool releaseMode}) {
  if (json == null || releaseMode) return null;
  try {
    return decodeCatalog(json);
  } on CatalogFormatException catch (error) {
    debugPrint('Catálogo de desenvolvimento ignorado: $error');
    return null;
  }
}

Future<SharedPreferences?> _preferences() async {
  try {
    return await SharedPreferences.getInstance();
  } catch (_) {
    return null;
  }
}

/// Sem armazenamento do aparelho, favoritos e recentes valem só na sessão (e a
/// tela avisa).
SavedStopsStore _savedStopsStore(SharedPreferences? preferences) =>
    preferences == null
    ? MemorySavedStopsStore(volatile: true)
    : SharedPreferencesSavedStopsStore(preferences);

/// Geist e Geist Mono são distribuídas sob a SIL Open Font License 1.1; o
/// texto da licença acompanha o app e aparece em Ajustes > Licenças.
void _registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/geist/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Geist', 'Geist Mono'], text);
  });
}
