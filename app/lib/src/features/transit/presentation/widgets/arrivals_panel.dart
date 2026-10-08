import 'package:flutter/material.dart';

import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
import '../cubit/stop_arrivals_cubit.dart';
import 'arrival_card.dart';

/// Exemplo da intro; é um ponto real da RMTC, não um favorito.
const exampleStopId = '30402';

/// Conteúdo da aba Ponto: intro, carregamento ou chegadas do ponto. Erros de
/// busca aparecem junto do campo (ver `SearchHeader`), não aqui.
class ArrivalsPanel extends StatelessWidget {
  const ArrivalsPanel({
    required this.state,
    required this.onRefresh,
    required this.onTrack,
    required this.onOpenTracking,
    required this.onExample,
    super.key,
  });

  final StopArrivalsState state;
  final VoidCallback onRefresh;
  final ValueChanged<String> onTrack;
  final VoidCallback onOpenTracking;
  final ValueChanged<String> onExample;

  @override
  Widget build(BuildContext context) {
    final children = switch (state) {
      StopArrivalsInitial() => [_Intro(onExample: onExample)],
      StopArrivalsLoading(:final stopId) => [_LoadingView(stopId: stopId)],
      final StopArrivalsLoaded loaded => _loaded(context, loaded),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  List<Widget> _loaded(BuildContext context, StopArrivalsLoaded state) {
    final tokens = context.tokens;
    final arrivals = state.arrivals.data;
    final tracking = state.tracking;

    return [
      if (tracking != null) ...[
        _TrackingBanner(tracking: tracking, onOpen: onOpenTracking),
        const SizedBox(height: Space.sm),
      ],
      SectionLabel(
        icon: Icons.schedule_rounded,
        label: 'Próximos ônibus',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              arrivals.length == 1 ? '1 linha' : '${arrivals.length} linhas',
              style: monoStyle(
                TextStyle(fontSize: 12, color: tokens.mutedText),
              ),
            ),
            const SizedBox(width: Space.xxs),
            SizedBox.square(
              dimension: 44,
              child: IconButton(
                onPressed: state.refreshing ? null : onRefresh,
                tooltip: 'Atualizar chegadas',
                padding: EdgeInsets.zero,
                iconSize: 20,
                icon: state.refreshing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ),
          ],
        ),
      ),
      if (state.refreshError != null) ...[
        const SizedBox(height: Space.xs),
        _InlineNotice(
          icon: Icons.sync_problem_rounded,
          text:
              'Não foi possível atualizar agora. Mostrando a consulta '
              'anterior. ${state.refreshError}',
        ),
      ],
      if (state.arrivals.stale) ...[
        const SizedBox(height: Space.xs),
        const _InlineNotice(
          icon: Icons.warning_amber_rounded,
          text: 'A fonte está instável. Mostrando o último dado válido.',
        ),
      ],
      const SizedBox(height: Space.xs),
      if (arrivals.isEmpty)
        MessageView(
          icon: Icons.departure_board_rounded,
          title: 'Nenhuma chegada prevista agora',
          body:
              'A fonte não informou ônibus para este ponto neste momento. '
              'Tente atualizar em alguns minutos.',
          action: OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Atualizar'),
          ),
        )
      else
        for (final group in arrivals) ...[
          ArrivalCard(group: group, tracking: tracking, onTrack: onTrack),
          const SizedBox(height: Space.xs),
        ],
      const SizedBox(height: Space.xxs),
      const FootNote(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Tempo real',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: ': posição informada pela RMTC, pode ser acompanhada. ',
              ),
              TextSpan(
                text: 'Programado',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: ': horário de tabela, sem GPS.'),
            ],
          ),
        ),
      ),
    ];
  }
}

/// Lembra que há um ônibus acompanhado e leva à aba Acompanhando.
class _TrackingBanner extends StatelessWidget {
  const _TrackingBanner({required this.tracking, required this.onOpen});

  final TrackingInfo tracking;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      container: true,
      button: true,
      label:
          'Ônibus ${tracking.vehicleNumber} sendo acompanhado. '
          'Ver em Meu ônibus',
      excludeSemantics: true,
      child: Material(
        color: tokens.accentSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: tokens.accent),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.sm, 10, Space.xs, 10),
            child: Row(
              children: [
                Icon(
                  Icons.directions_bus_rounded,
                  size: 20,
                  color: tokens.accentText,
                ),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Meu ônibus · '),
                        TextSpan(
                          text: tracking.vehicleNumber,
                          style: monoStyle(
                            const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: tokens.strongText,
                    ),
                  ),
                ),
                Text(
                  'Ver',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.strongText,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: tokens.strongText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: tokens.unconfirmedContainer,
        borderRadius: BorderRadius.circular(Radii.plate),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tokens.unconfirmed),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.unconfirmed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onExample});

  final ValueChanged<String> onExample;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MessageView(
          icon: Icons.location_on_outlined,
          title: 'Digite o código do ponto',
          body:
              'Você vê as próximas chegadas de cada linha e acompanha o '
              'ônibus no mapa.',
          action: Semantics(
            button: true,
            label: 'Consultar o ponto de exemplo $exampleStopId',
            excludeSemantics: true,
            child: ActionChip(
              onPressed: () => onExample(exampleStopId),
              avatar: Icon(
                Icons.north_east_rounded,
                size: 16,
                color: tokens.accentText,
              ),
              label: Text(
                'Exemplo: $exampleStopId',
                style: monoStyle(
                  TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.strongText,
                  ),
                ),
              ),
              backgroundColor: tokens.card,
              side: BorderSide(color: tokens.hairline),
              shape: const StadiumBorder(),
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        const FootNote(
          child: Text(
            'O código fica na placa do ponto. Só ônibus com GPS informado '
            'pela fonte podem ser acompanhados.',
          ),
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.stopId});

  final String? stopId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    Widget row() => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: tokens.hairline),
      ),
      child: const Row(
        children: [
          SkeletonBlock(height: 44, width: 52, radius: Radii.plate),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBlock(height: 14),
                SizedBox(height: 6),
                SkeletonBlock(height: 10, width: 80),
              ],
            ),
          ),
          SizedBox(width: Space.sm),
          SkeletonBlock(height: 48, width: 58, radius: Radii.plate),
        ],
      ),
    );

    return Semantics(
      liveRegion: true,
      label: 'Consultando chegadas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            icon: Icons.schedule_rounded,
            label: stopId == null
                ? 'Consultando…'
                : 'Consultando o ponto $stopId',
          ),
          const SizedBox(height: Space.sm),
          row(),
          const SizedBox(height: Space.xs),
          row(),
          const SizedBox(height: Space.xs),
          row(),
        ],
      ),
    );
  }
}
