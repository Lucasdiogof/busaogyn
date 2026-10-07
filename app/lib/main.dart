import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/core/config/api_config.dart';
import 'src/core/network/api_client.dart';
import 'src/core/settings/theme_mode_cubit.dart';
import 'src/features/transit/data/repositories/http_transit_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicense();

  final apiClient = ApiClient(baseUrl: ApiConfig.baseUrl);
  final repository = HttpTransitRepository(apiClient);

  runApp(BusaoGynApp(repository: repository, themeStore: await _themeStore()));
}

Future<ThemePreferenceStore> _themeStore() async {
  try {
    return SharedPreferencesThemeStore(await SharedPreferences.getInstance());
  } catch (_) {
    return MemoryThemePreferenceStore();
  }
}

/// Geist e Geist Mono são distribuídas sob a SIL Open Font License 1.1; o
/// texto da licença acompanha o app e aparece em Ajustes > Licenças.
void _registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/geist/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Geist', 'Geist Mono'], text);
  });
}
