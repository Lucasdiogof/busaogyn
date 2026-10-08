import 'package:flutter/material.dart';

abstract final class MapConfig {
  static const defaultStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

  /// Estilos cartográficos do BusãoGyn, pré-gerados a partir do Liberty (ver
  /// `tool/build_map_styles.dart`). Usam as mesmas sources, fontes e sprites do
  /// Liberty; a atribuição continua vindo das sources e é exibida pelo
  /// controle nativo do MapLibre.
  static const lightStyleAsset = 'assets/map/busao-light.json';
  static const nightStyleAsset = 'assets/map/busao-dark.json';

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

  /// - Padrão: estilos BusãoGyn empacotados (claro e escuro); se um deles não
  ///   carregar, volta para o Liberty por URL.
  /// - MAP_STYLE_URL próprio: ele vale para os dois temas, a menos que
  ///   MAP_STYLE_DARK_URL também seja informado (os estilos empacotados não
  ///   combinam com outro estilo) e é o próprio fallback.
  factory MapStyles.resolve({
    required String styleUrl,
    String darkStyleUrl = '',
  }) {
    final custom = styleUrl.trim().isEmpty
        ? MapConfig.defaultStyleUrl
        : styleUrl.trim();
    final bundled = custom == MapConfig.defaultStyleUrl;
    final String dark;
    if (darkStyleUrl.trim().isNotEmpty) {
      dark = darkStyleUrl.trim();
    } else if (bundled) {
      dark = MapConfig.nightStyleAsset;
    } else {
      dark = custom;
    }
    return MapStyles(
      light: bundled ? MapConfig.lightStyleAsset : custom,
      dark: dark,
      fallback: custom,
    );
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
