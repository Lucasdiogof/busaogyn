abstract final class MapConfig {
  static const defaultStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

  /// A atribuição OpenFreeMap/OpenMapTiles/OSM vem do próprio estilo e é
  /// exibida pelo controle de atribuição nativo do MapLibre.
  static const styleUrl = String.fromEnvironment(
    'MAP_STYLE_URL',
    defaultValue: defaultStyleUrl,
  );
}
