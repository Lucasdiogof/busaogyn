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
const netPlanSourceId = 'busao-net-plan';
const netMeSourceId = 'busao-net-me';

const netRouteFadedLayerId = 'busao-net-route-faded';
const netRouteOutboundLayerId = 'busao-net-route-ida';
const netRouteInboundLayerId = 'busao-net-route-volta';
const netRouteArrowsLayerId = 'busao-net-route-arrows';
const netTrackOfficialLayerId = 'busao-net-track-official';
const netTrackFutureLayerId = 'busao-net-track-future';
const netRouteStopsLayerId = 'busao-net-route-stops-layer';
const netClusterLayerId = 'busao-net-clusters';
const netClusterCountLayerId = 'busao-net-cluster-count';
const netStopsLayerId = 'busao-net-stops-layer';
const netRouteEndsLayerId = 'busao-net-route-ends-layer';
const netSelectedLayerId = 'busao-net-selected-layer';
const netPlanWalkLayerId = 'busao-net-plan-walk';
const netPlanLeg1LayerId = 'busao-net-plan-leg1';
const netPlanLeg2LayerId = 'busao-net-plan-leg2';
const netPlanArrowsLayerId = 'busao-net-plan-arrows';
const netPlanPointsLayerId = 'busao-net-plan-points';
const netMeLayerId = 'busao-net-me-layer';

const netSourceIds = {
  netRouteSourceId,
  netRouteEndsSourceId,
  netRouteStopsSourceId,
  netStopsSourceId,
  netSelectedSourceId,
  netTrackSourceId,
  netPlanSourceId,
  netMeSourceId,
};

const netLayerIds = {
  netRouteFadedLayerId,
  netRouteOutboundLayerId,
  netRouteInboundLayerId,
  netRouteArrowsLayerId,
  netTrackOfficialLayerId,
  netTrackFutureLayerId,
  netRouteStopsLayerId,
  netClusterLayerId,
  netClusterCountLayerId,
  netStopsLayerId,
  netRouteEndsLayerId,
  netSelectedLayerId,
  netPlanWalkLayerId,
  netPlanLeg1LayerId,
  netPlanLeg2LayerId,
  netPlanArrowsLayerId,
  netPlanPointsLayerId,
  netMeLayerId,
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
    () => controller.addGeoJsonSource(
      netPlanSourceId,
      overlay.plan,
      promoteId: 'id',
    ),
    () => controller.addGeoJsonSource(netMeSourceId, overlay.me),

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

    // Setas no sentido do percurso, como na viagem planejada: o sentido
    // não depende de saber qual cor é ida e qual é volta.
    () => controller.addSymbolLayer(
      netRouteSourceId,
      netRouteArrowsLayerId,
      SymbolLayerProperties(
        symbolPlacement: 'line',
        symbolSpacing: 110,
        textField: '›',
        textFont: const ['Noto Sans Bold'],
        textSize: 16,
        textColor: dark ? onAccent : panel,
        textHaloColor: strong,
        textHaloWidth: 1.2,
        textKeepUpright: false,
        textAllowOverlap: true,
      ),
      filter: isActive,
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
    // Viagem planejada: 1º ônibus âmbar, 2º na cor do texto (larguras e
    // cores diferentes do trajeto da linha e do rastro do ônibus real),
    // caminhada pontilhada, setas no sentido do percurso.
    () => controller.addLineLayer(
      netPlanSourceId,
      netPlanWalkLayerId,
      LineLayerProperties(
        lineColor: muted,
        lineWidth: 3,
        lineDasharray: const [0.4, 1.6],
        lineCap: 'round',
      ),
      filter: [
        '==',
        ['get', 'kind'],
        'walk',
      ],
      enableInteraction: false,
    ),
    () => controller.addLineLayer(
      netPlanSourceId,
      netPlanLeg1LayerId,
      LineLayerProperties(
        lineColor: accent,
        lineWidth: 7,
        lineOpacity: 0.95,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      // 1º e 3º ônibus no mesmo estilo; o 2º contrasta entre eles.
      filter: [
        'in',
        ['get', 'kind'],
        [
          'literal',
          ['leg1', 'leg3'],
        ],
      ],
      enableInteraction: false,
    ),
    () => controller.addLineLayer(
      netPlanSourceId,
      netPlanLeg2LayerId,
      LineLayerProperties(
        lineColor: strong,
        lineWidth: 7,
        lineOpacity: 0.9,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        '==',
        ['get', 'kind'],
        'leg2',
      ],
      enableInteraction: false,
    ),
    () => controller.addSymbolLayer(
      netPlanSourceId,
      netPlanArrowsLayerId,
      SymbolLayerProperties(
        symbolPlacement: 'line',
        symbolSpacing: 90,
        textField: '›',
        textFont: const ['Noto Sans Bold'],
        textSize: 18,
        // Seta e halo em contraste entre si (clara/halo escuro no tema
        // claro, escura/halo claro no escuro): legível no âmbar e no traço.
        textColor: dark ? onAccent : panel,
        textHaloColor: strong,
        textHaloWidth: 1.2,
        textKeepUpright: false,
        textAllowOverlap: true,
      ),
      filter: [
        'in',
        ['get', 'kind'],
        [
          'literal',
          ['leg1', 'leg2', 'leg3'],
        ],
      ],
      enableInteraction: false,
    ),
    () => controller.addCircleLayer(
      netPlanSourceId,
      netPlanPointsLayerId,
      CircleLayerProperties(
        circleRadius: [
          'match',
          ['get', 'kind'],
          'transfer',
          7,
          8,
        ],
        circleColor: [
          'match',
          ['get', 'kind'],
          'origin',
          panel,
          'destination',
          accent,
          panel,
        ],
        circleStrokeColor: [
          'match',
          ['get', 'kind'],
          'transfer',
          accent,
          strong,
        ],
        circleStrokeWidth: 3,
      ),
      filter: [
        '==',
        ['geometry-type'],
        'Point',
      ],
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
    // Você ("Perto de mim"): disco na cor do texto com borda do painel e
    // forma diferente dos pontos (anéis) e das paradas da viagem.
    () => controller.addCircleLayer(
      netMeSourceId,
      netMeLayerId,
      CircleLayerProperties(
        circleRadius: 7,
        circleColor: strong,
        circleStrokeColor: panel,
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
