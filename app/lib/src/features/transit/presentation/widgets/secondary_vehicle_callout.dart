import 'package:flutter/material.dart';

import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
import '../../domain/entities/map_vehicle.dart';
import '../formatters/transit_labels.dart';

/// Painel pequeno de um ônibus secundário tocado no mapa. Mostra só o que a
/// API já informou (linha, destino e número do veículo) e oferece acompanhar.
class SecondaryVehicleCallout extends StatelessWidget {
  const SecondaryVehicleCallout({
    required this.vehicle,
    required this.onTrack,
    required this.onClose,
    super.key,
  });

  final MapVehicle vehicle;
  final VoidCallback onTrack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final routeId = vehicle.routeId;
    final destination = vehicle.destination;
    // Com fonte grande o destino não cabe ao lado da placa e do botão de
    // fechar: ele passa para uma linha própria, na largura do painel.
    final stackDestination =
        Chrome.textScale(MediaQuery.textScalerOf(context)) >=
        Chrome.largeTextScale;
    final destinationText = destination == null
        ? null
        : Text(
            destinationLabel(destination),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.softText),
          );

    return GlassSurface(
      radius: Radii.header,
      padding: const EdgeInsets.fromLTRB(
        Space.sm,
        Space.sm,
        Space.xs,
        Space.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (routeId != null) ...[
                RoutePlate(routeId, dense: true),
                const SizedBox(width: Space.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ônibus ${vehicle.vehicleNumber}',
                      style: theme.textTheme.titleSmall,
                    ),
                    if (destinationText != null && !stackDestination)
                      destinationText,
                    if (vehicle.stale)
                      Text(
                        'Posição possivelmente desatualizada',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.unconfirmed,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Fechar',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          if (destinationText != null && stackDestination)
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: destinationText,
            ),
          const SizedBox(height: Space.xs),
          Padding(
            padding: const EdgeInsets.only(right: Space.sm),
            child: FilledButton.icon(
              onPressed: onTrack,
              icon: const Icon(Icons.my_location_rounded, size: 20),
              label: const Text('Acompanhar este ônibus'),
            ),
          ),
        ],
      ),
    );
  }
}
