import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/theme/busao_tokens.dart';
import '../../../catalog/domain/network_geojson.dart';

/// Camadas da rede (pontos, trajetos) no MapLibre, todas nativas: nenhuma
/// widget Flutter por ponto. Só existem com o catálogo de desenvolvimento.
const netRouteSourceId = 'busao-net-route';
const netRouteEndsSourceId = 'busao-net-route-ends';
const netRouteStopsSourceId = 'busao-net-route-stops';
const netStopsSourceId = 'busao-net-stops';
const netSelectedSourceId = 'busao-net-selected';
const netTrackSourceId = 'busao-net-track';

const netRouteFadedLayerId = 'busao-net-route-faded';
const netRouteOutboundLayerId = 'busao-net-route-ida';
const netRouteInboundLayerId = 'busao-net-route-volta';
const netTrackOfficialLayerId = 'busao-net-track-official';
const netTrackFutureLayerId = 'busao-net-track-future';
const netRouteStopsLayerId = 'busao-net-route-stops-layer';
const netClusterLayerId = 'busao-net-clusters';
const netClusterCountLayerId = 'busao-net-cluster-count';
const netStopsLayerId = 'busao-net-stops-layer';
const netRouteEndsLayerId = 'busao-net-route-ends-layer';
const netSelectedLayerId = 'busao-net-selected-layer';

const netSourceIds = {
  netRouteSourceId,
  netRouteEndsSourceId,
  netRouteStopsSourceId,
  netStopsSourceId,
  netSelectedSourceId,
  netTrackSourceId,
};

const netLayerIds = {
  netRouteFadedLayerId,
  netRouteOutboundLayerId,
  netRouteInboundLayerId,
  netTrackOfficialLayerId,
  netTrackFutureLayerId,
  netRouteStopsLayerId,
  netClusterLayerId,
  netClusterCountLayerId,
  netStopsLayerId,
  netRouteEndsLayerId,
  netSelectedLayerId,
};

/// Acima deste zoom os pontos aparecem um a um; abaixo, agrupados.
const netClusterMaxZoom = 13.0;

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Cria sources e layers da rede, abaixo do rastro e dos ônibus. [step]
/// executa cada chamada nativa só se a carga de estilo ainda vale.
Future<bool> addNetworkLayers({
  required MapLibreMapController controller,
  required NetworkOverlay overlay,
  required BusaoTokens tokens,
  required Brightness brightness,
  required Future<bool> Function(Future<void> Function() call) step,
}) async {
  final dark = brightness == Brightness.dark;
  final accent = _hex(tokens.accent);
  final strong = _hex(tokens.strongText);
  final muted = _hex(tokens.mutedText);
  final neutral = _hex(tokens.scheduled);
  final panel = _hex(tokens.panel);
  final onAccent = _hex(tokens.onAccent);
  const isActive = [
    '==',
    ['get', 'active'],
    true,
  ];

  final calls = <Future<void> Function()>[
    () => controller.addGeoJsonSource(netRouteSourceId, overlay.route),
    () => controller.addGeoJsonSource(netTrackSourceId, overlay.trackRoute),
    () => controller.addGeoJsonSource(
      netRouteStopsSourceId,
      overlay.routeStops,
      promoteId: 'id',
    ),
    () => controller.addSource(
      netStopsSourceId,
      GeojsonSourceProperties(
        data: overlay.stops,
        cluster: true,
        clusterMaxZoom: netClusterMaxZoom,
        clusterRadius: 46,
        promoteId: 'id',
      ),
    ),
    () => controller.addGeoJsonSource(netRouteEndsSourceId, overlay.routeEnds),
    () =>
        controller.addGeoJsonSource(netSelectedSourceId, overlay.selectedStop),

    // Trajetos: outras variantes/sentidos esmaecidos; ida em âmbar contínuo,
    // volta em traço tracejado da cor do texto (forma, não só cor).
    () => controller.addLineLayer(
      netRouteSourceId,
      netRouteFadedLayerId,
      LineLayerProperties(
        lineColor: muted,
        lineWidth: 3,
        lineOpacity: dark ? 0.35 : 0.3,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        '==',
        ['get', 'active'],
        false,
      ],
      enableInteraction: false,
    ),
    () => controller.addLineLayer(
      netRouteSourceId,
      netRouteOutboundLayerId,
      LineLayerProperties(
        lineColor: accent,
        lineWidth: 5,
        lineOpacity: 0.95,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        'all',
        isActive,
        [
          '!=',
          ['get', 'dir'],
          'v',
        ],
      ],
      enableInteraction: false,
    ),
    () => controller.addLineLayer(
      netRouteSourceId,
      netRouteInboundLayerId,
      LineLayerProperties(
        lineColor: strong,
        lineWidth: 4.5,
        lineOpacity: 0.9,
        lineDasharray: const [2, 1.4],
        lineJoin: 'round',
      ),
      filter: [
        'all',
        isActive,
        [
          '==',
          ['get', 'dir'],
          'v',
        ],
      ],
      enableInteraction: false,
    ),

    // Ônibus acompanhado: percurso oficial total em neutro, futuro estimado
    // em âmbar tracejado (o rastro observado é âmbar fino e contínuo).
    () => controller.addLineLayer(
      netTrackSourceId,
      netTrackOfficialLayerId,
      LineLayerProperties(
        lineColor: neutral,
        lineWidth: 4,
        lineOpacity: 0.55,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        '==',
        ['get', 'kind'],
        'official',
      ],
      enableInteraction: false,
    ),
    () => controller.addLineLayer(
      netTrackSourceId,
      netTrackFutureLayerId,
      LineLayerProperties(
        lineColor: accent,
        lineWidth: 5,
        lineOpacity: 0.95,
        lineDasharray: const [1.2, 1.2],
        lineJoin: 'round',
      ),
      filter: [
        '==',
        ['get', 'kind'],
        'future',
      ],
      enableInteraction: false,
    ),

    // Pontos da linha (cadastro, sem ordem): anel âmbar. Tocáveis: com o
    // trajeto aberto, os pontos gerais saem do mapa.
    () => controller.addCircleLayer(
      netRouteStopsSourceId,
      netRouteStopsLayerId,
      CircleLayerProperties(
        // Pequenos de longe para não esconder o traço (ida/volta).
        circleRadius: const [
          'interpolate',
          ['linear'],
          ['zoom'],
          11,
          1.5,
          15,
          5,
        ],
        circleColor: panel,
        circleStrokeColor: accent,
        circleStrokeWidth: const [
          'interpolate',
          ['linear'],
          ['zoom'],
          11,
          1,
          15,
          2.5,
        ],
      ),
    ),

    // Todos os pontos: agrupados em zoom baixo, um a um em zoom alto.
    () => controller.addCircleLayer(
      netStopsSourceId,
      netClusterLayerId,
      CircleLayerProperties(
        circleColor: accent,
        circleOpacity: 0.82,
        circleRadius: const [
          'step',
          ['get', 'point_count'],
          13,
          25,
          16,
          100,
          20,
          400,
          25,
        ],
        circleStrokeColor: panel,
        circleStrokeWidth: 2,
      ),
      filter: ['has', 'point_count'],
    ),
    () => controller.addSymbolLayer(
      netStopsSourceId,
      netClusterCountLayerId,
      SymbolLayerProperties(
        textField: const ['get', 'point_count_abbreviated'],
        textFont: const ['Noto Sans Bold'],
        textSize: 12,
        textColor: onAccent,
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
      filter: ['has', 'point_count'],
      enableInteraction: false,
    ),
    () => controller.addCircleLayer(
      netStopsSourceId,
      netStopsLayerId,
      CircleLayerProperties(
        circleColor: panel,
        circleRadius: const [
          'interpolate',
          ['linear'],
          ['zoom'],
          13,
          3,
          17,
          6.5,
        ],
        circleStrokeColor: accent,
        circleStrokeWidth: 1.6,
      ),
      filter: [
        '!',
        ['has', 'point_count'],
      ],
    ),
    () => controller.addCircleLayer(
      netRouteEndsSourceId,
      netRouteEndsLayerId,
      CircleLayerProperties(
        circleRadius: 7,
        circleColor: accent,
        circleStrokeColor: strong,
        circleStrokeWidth: 2.5,
      ),
      enableInteraction: false,
    ),
    () => controller.addCircleLayer(
      netSelectedSourceId,
      netSelectedLayerId,
      CircleLayerProperties(
        circleRadius: 12,
        circleColor: accent,
        circleOpacity: 0.28,
        circleStrokeColor: accent,
        circleStrokeWidth: 3,
      ),
      enableInteraction: false,
    ),
  ];
  for (final call in calls) {
    if (!await step(call)) return false;
  }
  return true;
}
