import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
import '../cubit/stop_arrivals_cubit.dart';
import '../formatters/transit_labels.dart';

/// Meu ônibus contextual: barra compacta acima da navegação enquanto um
/// ônibus é acompanhado, em qualquer área. Tocar abre o acompanhamento;
/// o × encerra. O estado do acompanhamento não depende da área aberta.
class TrackingBar extends StatelessWidget {
  const TrackingBar({
    required this.state,
    required this.tracking,
    required this.onOpen,
    required this.onStop,
    super.key,
  });

  final StopArrivalsLoaded state;
  final TrackingInfo tracking;
  final VoidCallback onOpen;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final snapshot = tracking.vehicle;
    final vehicle = snapshot?.data;
    final match = trackedArrival(state.arrivals.data, tracking.vehicleNumber);
    final routeId = vehicle?.routeId ?? match?.group.routeId;
    final destination = vehicle?.destination ?? match?.group.destination;
    final stale =
        (snapshot?.stale ?? false) || tracking.phase != TrackingPhase.active;
    final heading = headingToLabel(destination);
    // Barra compacta de altura fixa: o texto escala até 130%; a ficha
    // completa (Meu ônibus) acompanha a fonte do sistema sem limite.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: Chrome.headerMaxTextScale,
      child: Semantics(
        container: true,
        label: l10n.trackingBarSemantics(tracking.vehicleNumber, heading),
        child: GlassSurface(
          key: const ValueKey('tracking-bar'),
          radius: Radii.card,
          solid: true,
          child: InkWell(
            onTap: onOpen,
            child: SizedBox(
              height: Chrome.trackingBar,
              child: Row(
                children: [
                  const SizedBox(width: Space.sm),
                  if (routeId != null)
                    IntrinsicWidth(child: RoutePlate(routeId, filled: true))
                  else
                    Icon(
                      Icons.directions_bus_rounded,
                      color: tokens.accentText,
                    ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.busNumber(tracking.vehicleNumber),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: tokens.strongText,
                          ),
                        ),
                        Text(
                          heading,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: tokens.softText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Estado sem depender só de cor: ponto pulsando = ao vivo;
                  // triângulo = posição antiga ou sem sinal.
                  if (stale)
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: tokens.unconfirmed,
                      semanticLabel: l10n.trackingBarStale,
                    )
                  else
                    StatusDot(color: tokens.realtime, pulsing: true),
                  IconButton(
                    key: const ValueKey('tracking-bar-open'),
                    tooltip: l10n.trackingBarOpen,
                    onPressed: onOpen,
                    icon: const Icon(Icons.expand_less_rounded),
                  ),
                  IconButton(
                    key: const ValueKey('tracking-bar-stop'),
                    tooltip: l10n.stopTracking,
                    onPressed: onStop,
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const SizedBox(width: Space.xxs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
