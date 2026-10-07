import 'package:flutter/material.dart';

import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
import '../../domain/entities/arrival.dart';
import '../cubit/stop_arrivals_cubit.dart';
import '../formatters/transit_labels.dart';

class QualityBadge extends StatelessWidget {
  const QualityBadge(this.quality, {this.dense = false, super.key});

  final ArrivalQuality quality;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = switch (quality) {
      ArrivalQuality.realtime => (Icons.sensors_rounded, PillTone.positive),
      ArrivalQuality.scheduled => (Icons.schedule_rounded, PillTone.neutral),
      ArrivalQuality.unknown => (Icons.help_outline_rounded, PillTone.caution),
    };
    return StatusPill(
      icon: icon,
      label: qualityLabel(quality),
      tone: tone,
      dense: dense,
    );
  }
}

class ArrivalCard extends StatelessWidget {
  const ArrivalCard({
    required this.group,
    required this.tracking,
    required this.onTrack,
    super.key,
  });

  final ArrivalGroup group;
  final TrackingInfo? tracking;
  final ValueChanged<String> onTrack;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final following = group.following;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RoutePlate(group.routeId),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    group.destination ?? 'Destino não informado',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            _ArrivalSlot(
              label: 'Próximo',
              arrival: group.next,
              emphasized: true,
              tracking: tracking,
              onTrack: onTrack,
            ),
            if (following != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: tokens.hairline),
              ),
              _ArrivalSlot(
                label: 'Seguinte',
                arrival: following,
                emphasized: false,
                tracking: tracking,
                onTrack: onTrack,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ArrivalSlot extends StatelessWidget {
  const _ArrivalSlot({
    required this.label,
    required this.arrival,
    required this.emphasized,
    required this.tracking,
    required this.onTrack,
  });

  final String label;
  final Arrival arrival;
  final bool emphasized;
  final TrackingInfo? tracking;
  final ValueChanged<String> onTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final quality = displayQuality(arrival);
    final vehicleNumber = arrival.vehicleNumber;
    final showVehicle =
        quality == ArrivalQuality.realtime && vehicleNumber != null;
    final isTracked =
        vehicleNumber != null && tracking?.vehicleNumber == vehicleNumber;

    final minutesStyle =
        (emphasized
                ? theme.textTheme.headlineSmall
                : theme.textTheme.titleLarge)
            ?.copyWith(fontWeight: FontWeight.w800);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Semantics(
            label:
                '$label: ${minutesSemantics(arrival.minutes)}, '
                '${qualityLabel(quality)}'
                '${showVehicle ? ', ônibus $vehicleNumber' : ''}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tokens.mutedText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(minutesLabel(arrival.minutes), style: minutesStyle),
                const SizedBox(height: Space.xxs),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    QualityBadge(quality, dense: true),
                    if (showVehicle)
                      Text(
                        'Ônibus $vehicleNumber',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.mutedText,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (canTrack(arrival)) ...[
          const SizedBox(width: Space.xs),
          TrackButton(
            phase: isTracked ? tracking!.phase : null,
            onPressed: () => onTrack(vehicleNumber!),
          ),
        ],
      ],
    );
  }
}

/// Botão de acompanhar com fase explícita; só gira enquanto a primeira
/// posição está realmente pendente.
class TrackButton extends StatelessWidget {
  const TrackButton({required this.phase, required this.onPressed, super.key});

  /// `null` quando este ônibus não é o acompanhado.
  final TrackingPhase? phase;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final phase = this.phase;
    if (phase == null) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.gps_fixed_rounded, size: 18),
        label: const Text('Acompanhar'),
      );
    }

    final (Widget icon, String label) = switch (phase) {
      TrackingPhase.searching => (
        const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        'Buscando…',
      ),
      TrackingPhase.active => (
        const Icon(Icons.check_circle_rounded, size: 18),
        'Acompanhando',
      ),
      TrackingPhase.unavailable => (
        const Icon(Icons.location_disabled_rounded, size: 18),
        'Sem posição',
      ),
      TrackingPhase.failing => (
        const Icon(Icons.sync_problem_rounded, size: 18),
        'Reconectando',
      ),
    };
    // Já acompanhado: tocar de novo força uma nova consulta (sem trocar de
    // ônibus), útil depois de uma falha.
    return FilledButton.tonalIcon(
      onPressed: phase == TrackingPhase.searching ? null : onPressed,
      icon: icon,
      label: Text(label),
    );
  }
}
