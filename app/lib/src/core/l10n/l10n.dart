import 'dart:ui' show Locale;

import '../../../l10n/app_localizations.dart';

export '../../../l10n/app_localizations.dart';

/// Idiomas do app. O primeiro é o padrão quando o do aparelho não é atendido.
const supportedAppLocales = [Locale('pt'), Locale('en'), Locale('es')];

AppLocalizations _current = lookupAppLocalizations(const Locale('pt'));

/// Textos no idioma em uso. Formatadores e cubits não têm [BuildContext];
/// o app troca este valor quando o idioma resolvido muda (ver [useLocale]).
AppLocalizations get l10n => _current;

/// Idioma do aparelho entre os atendidos (pt, en, es); senão, português.
Locale resolveAppLocale(Locale? device) {
  for (final locale in supportedAppLocales) {
    if (locale.languageCode == device?.languageCode) return locale;
  }
  return supportedAppLocales.first;
}

void useLocale(Locale locale) {
  _current = lookupAppLocalizations(resolveAppLocale(locale));
}
