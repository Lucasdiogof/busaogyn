import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/map_config.dart';
import '../../domain/entities/tracked_vehicle.dart';

class TrackedVehicleMap extends StatelessWidget {
  const TrackedVehicleMap({
    required this.vehicle,
    super.key,
  });

  final TrackedVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final position = vehicle.position;
    if (position == null) {
      return const SizedBox.shrink();
    }

    final center = LatLng(position.latitude, position.longitude);
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 16,
                minZoom: 3,
                maxZoom: 19,
              ),
              children: [
                if (MapConfig.hasTiles)
                  TileLayer(
                    urlTemplate: MapConfig.tileUrlTemplate,
                    userAgentPackageName: MapConfig.userAgentPackageName,
                  )
                else
                  ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: const SizedBox.expand(),
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      child: Semantics(
                        label: 'Ônibus ${vehicle.vehicleNumber}',
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: scheme.onPrimary,
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.directions_bus_rounded,
                            color: scheme.onPrimary,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (!MapConfig.hasTiles)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      'Mapa-base ainda não configurado. '
                      'A posição do ônibus continua disponível.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            if (MapConfig.hasTiles && MapConfig.attribution.isNotEmpty)
              Positioned(
                left: 8,
                bottom: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Text(
                      MapConfig.attribution,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
