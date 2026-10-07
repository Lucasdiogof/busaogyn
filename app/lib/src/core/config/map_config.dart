import 'package:flutter/material.dart';

abstract final class MapConfig {
  static const defaultStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

  /// Liberty noturno pré-derivado (ver `tool/build_night_style.dart`). Usa as
  /// mesmas sources, fontes e sprites do Liberty; a atribuição continua vindo
  /// das sources e é exibida pelo controle nativo do MapLibre.
  static const nightStyleAsset = 'assets/map/liberty-night.json';

  static const styleUrl = String.fromEnvironment(
    'MAP_STYLE_URL',
    defaultValue: defaultStyleUrl,
  );

  /// Estilo noturno opcional para quem configurar um MAP_STYLE_URL próprio.
  static const darkStyleUrl = String.fromEnvironment('MAP_STYLE_DARK_URL');

  static MapStyles get styles =>
      MapStyles.resolve(styleUrl: styleUrl, darkStyleUrl: darkStyleUrl);
}

/// Estilos do mapa por tema, com o estilo de segurança para o noturno.
@immutable
class MapStyles {
  const MapStyles({
    required this.light,
    required this.dark,
    required this.fallback,
  });

  /// - Padrão: Liberty de dia, Liberty noturno empacotado à noite.
  /// - MAP_STYLE_URL próprio: ele vale para os dois temas, a menos que
  ///   MAP_STYLE_DARK_URL também seja informado (o derivado do Liberty não
  ///   combina com outro estilo).
  /// - Se o estilo noturno não carregar, volta para o estilo diurno.
  factory MapStyles.resolve({
    required String styleUrl,
    String darkStyleUrl = '',
  }) {
    final light = styleUrl.trim().isEmpty
        ? MapConfig.defaultStyleUrl
        : styleUrl.trim();
    final String dark;
    if (darkStyleUrl.trim().isNotEmpty) {
      dark = darkStyleUrl.trim();
    } else if (light == MapConfig.defaultStyleUrl) {
      dark = MapConfig.nightStyleAsset;
    } else {
      dark = light;
    }
    return MapStyles(light: light, dark: dark, fallback: light);
  }

  final String light;
  final String dark;
  final String fallback;

  String forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  @override
  bool operator ==(Object other) =>
      other is MapStyles &&
      other.light == light &&
      other.dark == dark &&
      other.fallback == fallback;

  @override
  int get hashCode => Object.hash(light, dark, fallback);
}
