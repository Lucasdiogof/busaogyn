abstract final class MapConfig {
  static const tileUrlTemplate = String.fromEnvironment(
    'MAP_TILE_URL_TEMPLATE',
    defaultValue: '',
  );

  static const attribution = String.fromEnvironment(
    'MAP_TILE_ATTRIBUTION',
    defaultValue: '',
  );

  static const userAgentPackageName = String.fromEnvironment(
    'MAP_TILE_USER_AGENT_PACKAGE',
    defaultValue: 'com.busaogyn.app',
  );

  static bool get hasTiles => tileUrlTemplate.trim().isNotEmpty;
}
