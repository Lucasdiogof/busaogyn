import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
import '../../../transit/domain/entities/arrival.dart';
import '../../../transit/presentation/formatters/transit_labels.dart';
import '../../domain/saved_stop.dart';
import '../cubit/favorite_arrivals_cubit.dart';
import '../cubit/saved_stops_cubit.dart';

/// Estrela do cabeçalho do ponto: preenchida quando o ponto é favorito. O
/// estado muda de forma (estrela cheia ou só contorno), não só de cor.
class FavoriteToggleButton extends StatelessWidget {
  const FavoriteToggleButton({
    required this.code,
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final String code;

  /// Só há o que favoritar com um ponto já consultado.
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SavedStopsCubit, SavedStopsState, bool>(
      selector: (state) => state.isFavorite(code),
      builder: (context, favorite) {
        final tooltip = favorite
            ? 'Remover o ponto $code dos favoritos'
            : 'Favoritar o ponto $code';
        // Alvo de toque de 48 dp (o tema padrão dos botões de ícone é 44).
        return SizedBox.square(
          dimension: 48,
          child: IconButton(
            tooltip: tooltip,
            isSelected: favorite,
            onPressed: enabled ? onPressed : null,
            icon: const Icon(Icons.star_outline_rounded),
            selectedIcon: Icon(
              Icons.star_rounded,
              color: context.tokens.accentText,
            ),
          ),
        );
      },
    );
  }
}

/// Favoritar a linha **neste ponto** (par ponto + linha). Fica no pé do
/// cartão da linha; estado cheio ou vazio, não só cor. Alvo de 48 dp.
class LineFavoriteButton extends StatelessWidget {
  const LineFavoriteButton({
    required this.stopCode,
    required this.routeId,
    super.key,
  });

  final String stopCode;
  final String routeId;

  Future<void> _toggle(BuildContext context) async {
    final result = await context.read<SavedStopsCubit>().toggleFavoriteLine(
      stopCode,
      routeId,
    );
    if (!context.mounted || result != FavoriteResult.limitReached) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Limite de $defaultFavoriteLinesLimit linhas favoritas. Remova '
            'uma para adicionar outra.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return BlocSelector<SavedStopsCubit, SavedStopsState, bool>(
      selector: (state) => state.isFavoriteLine(stopCode, routeId),
      builder: (context, favorite) {
        final label = favorite
            ? 'Remover a linha $routeId do ponto $stopCode dos favoritos'
            : 'Favoritar a linha $routeId neste ponto';
        return Semantics(
          button: true,
          selected: favorite,
          label: label,
          excludeSemantics: true,
          child: Tooltip(
            message: label,
            excludeFromSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.card),
              onTap: () => _toggle(context),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: Space.xs),
                    Icon(
                      favorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 20,
                      color: favorite ? tokens.accentText : tokens.mutedText,
                    ),
                    const SizedBox(width: Space.xs),
                    Flexible(
                      child: Text(
                        favorite ? 'Linha favorita' : 'Favoritar esta linha',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: favorite
                              ? tokens.accentText
                              : tokens.mutedText,
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.xs),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Aviso curto dentro das listas.
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

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

/// Avisos sobre o armazenamento: não guarda, não leu, não gravou.
class _StorageNotices extends StatelessWidget {
  const _StorageNotices({required this.state});

  final SavedStopsState state;

  @override
  Widget build(BuildContext context) {
    final notices = <(IconData, String)>[
      if (!state.persistent)
        (
          Icons.save_outlined,
          'Este aparelho não guardou os pontos. Eles valem só até fechar o app.',
        ),
      if (state.readFailed)
        (
          Icons.sync_problem_rounded,
          'Não foi possível ler os pontos salvos. Começamos com a lista vazia.',
        ),
      if (state.writeFailed)
        (
          Icons.sync_problem_rounded,
          'Não foi possível salvar agora. A lista vale até fechar o app.',
        ),
    ];
    if (notices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (icon, text) in notices) ...[
          _Notice(icon: icon, text: text),
          const SizedBox(height: Space.xs),
        ],
      ],
    );
  }
}

/// Linha de um ponto guardado: toque consulta o ponto; o botão da direita
/// remove. Toda a linha e o botão têm pelo menos 48 dp.
class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.stop,
    required this.icon,
    required this.removeTooltip,
    required this.onOpen,
    required this.onRemove,
    this.summary,
  });

  final SavedStop stop;
  final IconData icon;
  final String removeTooltip;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  /// Próximas chegadas do ponto (só nos favoritos).
  final Widget? summary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final named = stop.name != null;
    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: tokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label:
                      'Consultar as chegadas do ponto ${stop.code}'
                      '${named ? ', ${stop.name}' : ''}',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.card),
                    onTap: onOpen,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.sm,
                          Space.xs,
                          Space.xs,
                          Space.xs,
                        ),
                        child: Row(
                          children: [
                            Icon(icon, size: 20, color: tokens.accentText),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (named)
                                    Text(
                                      stop.name!,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: tokens.strongText,
                                      ),
                                    ),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'Ponto ',
                                          style: TextStyle(
                                            fontWeight: named
                                                ? FontWeight.w400
                                                : FontWeight.w600,
                                            color: named
                                                ? tokens.mutedText
                                                : tokens.strongText,
                                          ),
                                        ),
                                        TextSpan(
                                          text: stop.code,
                                          style: monoStyle(
                                            TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: named
                                                  ? tokens.mutedText
                                                  : tokens.strongText,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox.square(
                dimension: 48,
                child: IconButton(
                  tooltip: removeTooltip,
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ),
            ],
          ),
          ?summary,
        ],
      ),
    );
  }
}

/// Linha favorita num ponto: toque consulta o ponto; o botão remove.
class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.line,
    required this.onOpen,
    required this.onRemove,
    this.summary,
  });

  final SavedLine line;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final Widget? summary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: tokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label:
                      'Consultar as chegadas da linha ${line.routeId} no ponto '
                      '${line.stopCode}',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.card),
                    onTap: onOpen,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.sm,
                          Space.xs,
                          Space.xs,
                          Space.xs,
                        ),
                        child: Row(
                          children: [
                            RoutePlate(line.routeId),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'no ponto ',
                                      style: TextStyle(color: tokens.mutedText),
                                    ),
                                    TextSpan(
                                      text: line.stopCode,
                                      style: monoStyle(
                                        TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: tokens.strongText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox.square(
                dimension: 48,
                child: IconButton(
                  tooltip:
                      'Remover a linha ${line.routeId} do ponto ${line.stopCode} '
                      'dos favoritos',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ),
            ],
          ),
          ?summary,
        ],
      ),
    );
  }
}

const _offlineHint =
    'Toque num ponto para consultar as chegadas. A consulta precisa de '
    'internet e nenhuma previsão fica salva no aparelho.';

/// Aba Favoritos: os pontos favoritos, ou um estado vazio claro. Funciona sem
/// internet; só a consulta de chegadas precisa de conexão.
class FavoritesPanel extends StatelessWidget {
  const FavoritesPanel({
    required this.onOpen,
    required this.onSearchStop,
    this.connectionNotice,
    super.key,
  });

  /// Consulta o ponto (abre Pontos).
  final ValueChanged<String> onOpen;

  /// Leva à busca de pontos.
  final VoidCallback onSearchStop;

  /// Aviso quando a última consulta falhou por conexão ou fonte.
  final String? connectionNotice;

  @override
  Widget build(BuildContext context) {
    return FavoriteArrivalsScope(child: _body());
  }

  Widget _body() {
    return BlocBuilder<SavedStopsCubit, SavedStopsState>(
      builder: (context, state) {
        final children = <Widget>[
          _StorageNotices(state: state),
          if (connectionNotice != null) ...[
            _Notice(icon: Icons.wifi_off_rounded, text: connectionNotice!),
            const SizedBox(height: Space.xs),
          ],
        ];
        if (state.loading) {
          children.add(const _LoadingRows());
        } else if (state.favorites.isEmpty && state.lines.isEmpty) {
          children.add(
            MessageView(
              icon: Icons.star_outline_rounded,
              title: 'Seus pontos favoritos aparecerão aqui.',
              body:
                  'Consulte um ponto e toque na estrela do cabeçalho para '
                  'favoritá-lo.',
              action: FilledButton.icon(
                onPressed: onSearchStop,
                icon: const Icon(Icons.location_on_outlined, size: 20),
                label: const Text('Buscar um ponto'),
              ),
            ),
          );
        } else {
          Widget count(int n) => Text(
            '$n',
            style: monoStyle(
              TextStyle(fontSize: 12, color: context.tokens.mutedText),
            ),
          );
          children.add(const FavoriteArrivalsRefresh());
          if (state.favorites.isNotEmpty) {
            children
              ..add(
                SectionLabel(
                  icon: Icons.star_rounded,
                  label: 'Pontos favoritos',
                  trailing: count(state.favorites.length),
                ),
              )
              ..add(const SizedBox(height: Space.xs));
            for (final stop in state.favorites) {
              children
                ..add(
                  _StopTile(
                    stop: stop,
                    icon: Icons.star_rounded,
                    removeTooltip: 'Remover o ponto ${stop.code} dos favoritos',
                    onOpen: () => onOpen(stop.code),
                    onRemove: () => context
                        .read<SavedStopsCubit>()
                        .removeFavorite(stop.code),
                    summary: FavoriteArrivalsSummary(stopCode: stop.code),
                  ),
                )
                ..add(const SizedBox(height: Space.xs));
            }
          }
          if (state.lines.isNotEmpty) {
            if (state.favorites.isNotEmpty) {
              children.add(const SizedBox(height: Space.xs));
            }
            children
              ..add(
                SectionLabel(
                  icon: Icons.directions_bus_outlined,
                  label: 'Linhas favoritas',
                  trailing: count(state.lines.length),
                ),
              )
              ..add(const SizedBox(height: Space.xs));
            for (final line in state.lines) {
              children
                ..add(
                  _LineTile(
                    line: line,
                    summary: FavoriteArrivalsSummary(
                      stopCode: line.stopCode,
                      routeId: line.routeId,
                    ),
                    onOpen: () => onOpen(line.stopCode),
                    onRemove: () => context
                        .read<SavedStopsCubit>()
                        .removeFavoriteLine(line.stopCode, line.routeId),
                  ),
                )
                ..add(const SizedBox(height: Space.xs));
            }
          }
          children.add(const FootNote(child: Text(_offlineHint)));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}

/// Seção Recentes da aba Pontos: os últimos pontos consultados com sucesso.
class RecentStopsSection extends StatelessWidget {
  const RecentStopsSection({
    required this.onOpen,
    this.excludeCode,
    this.showEmpty = false,
    this.connectionNotice,
    super.key,
  });

  /// Consulta o ponto de novo.
  final ValueChanged<String> onOpen;

  /// Ponto que já está na tela (não repete na lista).
  final String? excludeCode;

  /// Mostra a seção mesmo sem itens (explicando que está vazia).
  final bool showEmpty;
  final String? connectionNotice;

  Future<void> _confirmClear(BuildContext context) async {
    final cubit = context.read<SavedStopsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar recentes?'),
        content: const Text(
          'O histórico de pontos consultados neste aparelho será apagado. '
          'Seus favoritos não mudam.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.clearRecents();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SavedStopsCubit, SavedStopsState>(
      builder: (context, state) {
        final recents = [
          for (final stop in state.recents)
            if (stop.code != excludeCode) stop,
        ];
        if (!state.loading && recents.isEmpty && !showEmpty) {
          return const SizedBox.shrink();
        }
        final tokens = context.tokens;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Space.md),
            SectionLabel(
              icon: Icons.history_rounded,
              label: 'Recentes',
              trailing: recents.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => _confirmClear(context),
                      child: const Text('Limpar'),
                    ),
            ),
            const SizedBox(height: Space.xs),
            _StorageNotices(state: state),
            if (connectionNotice != null) ...[
              _Notice(icon: Icons.wifi_off_rounded, text: connectionNotice!),
              const SizedBox(height: Space.xs),
            ],
            if (state.loading)
              const _LoadingRows(count: 1)
            else if (recents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.xxs,
                  vertical: Space.xs,
                ),
                child: Text(
                  'Os pontos que você consultar aparecerão aqui.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.mutedText),
                ),
              )
            else ...[
              for (final stop in recents) ...[
                _StopTile(
                  stop: stop,
                  icon: Icons.history_rounded,
                  removeTooltip: 'Remover o ponto ${stop.code} dos recentes',
                  onOpen: () => onOpen(stop.code),
                  onRemove: () =>
                      context.read<SavedStopsCubit>().removeRecent(stop.code),
                ),
                const SizedBox(height: Space.xs),
              ],
              const FootNote(child: Text(_offlineHint)),
            ],
          ],
        );
      },
    );
  }
}

class _LoadingRows extends StatelessWidget {
  const _LoadingRows({this.count = 2});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carregando pontos salvos',
      child: Column(
        children: [
          for (var i = 0; i < count; i++) ...[
            const SkeletonBlock(height: 56, width: double.infinity, radius: 16),
            const SizedBox(height: Space.xs),
          ],
        ],
      ),
    );
  }
}

/// Próximas chegadas de um favorito, sempre com a hora da consulta. Só
/// mostra o que a consulta acabou de devolver; sem internet ou com falha,
/// diz isso em vez de repetir a última previsão.
class FavoriteArrivalsSummary extends StatelessWidget {
  const FavoriteArrivalsSummary({
    required this.stopCode,
    this.routeId,
    super.key,
  });

  final String stopCode;

  /// Se informado, mostra só esta linha (linha favorita).
  final String? routeId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoriteArrivalsCubit, FavoriteArrivalsState>(
      buildWhen: (a, b) => a.byStop[stopCode] != b.byStop[stopCode],
      builder: (context, state) {
        final entry = state.byStop[stopCode];
        if (entry == null) return const SizedBox.shrink();
        final style = Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.tokens.mutedText);
        final Widget content = switch (entry.status) {
          FavoriteStopStatus.loading => Text('Consultando…', style: style),
          FavoriteStopStatus.offline => Text(
            'Sem conexão. Toque em Atualizar quando a internet voltar.',
            style: style,
          ),
          FavoriteStopStatus.failed => Text(
            'Não foi possível consultar agora.',
            style: style,
          ),
          FavoriteStopStatus.ready => _ready(context, entry, style),
        };
        return Padding(
          padding: const EdgeInsets.fromLTRB(Space.sm, 0, Space.sm, Space.xs),
          child: Align(alignment: Alignment.centerLeft, child: content),
        );
      },
    );
  }

  Widget _ready(
    BuildContext context,
    FavoriteStopArrivals entry,
    TextStyle? style,
  ) {
    final groups = [
      for (final group in entry.groups)
        if (routeId == null || group.routeId == routeId) group,
    ];
    final time = entry.fetchedAt;
    final hour = time == null
        ? null
        : '${time.hour.toString().padLeft(2, '0')}:'
              '${time.minute.toString().padLeft(2, '0')}';
    final at = hour == null ? '' : ' · consulta das $hour';
    if (groups.isEmpty) {
      return Text('Nenhuma chegada prevista agora$at', style: style);
    }
    const shown = 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: 2,
          children: [
            for (final group in groups.take(shown))
              _ArrivalChip(group: group, color: context.tokens.strongText),
            if (groups.length > shown)
              Text('+${groups.length - shown}', style: style),
          ],
        ),
        Text(
          entry.stale
              ? 'Último dado válido da fonte$at'
              : (hour == null ? 'Consulta feita agora' : 'Consulta das $hour'),
          style: style,
        ),
      ],
    );
  }
}

class _ArrivalChip extends StatelessWidget {
  const _ArrivalChip({required this.group, required this.color});

  final ArrivalGroup group;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final quality = displayQuality(group.next);
    final minutes = group.next.minutes;
    final value = switch (minutes) {
      null => '—',
      <= 0 => '< 1 min',
      final m => '$m min',
    };
    return Semantics(
      container: true,
      label:
          'Linha ${group.routeId}, ${minutesSemantics(minutes)}, '
          '${qualityShortLabel(quality)}',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: group.routeId,
              style: monoStyle(
                TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
            ),
            TextSpan(
              text: ' $value',
              style: TextStyle(color: color),
            ),
            if (quality != ArrivalQuality.realtime)
              TextSpan(
                text: ' (${qualityShortLabel(quality).toLowerCase()})',
                style: TextStyle(fontSize: 12, color: context.tokens.mutedText),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mantém a consulta das chegadas dos favoritos: roda ao abrir a aba, quando
/// o conjunto de pontos muda e quando o usuário toca em Atualizar.
class FavoriteArrivalsScope extends StatefulWidget {
  const FavoriteArrivalsScope({required this.child, super.key});

  final Widget child;

  @override
  State<FavoriteArrivalsScope> createState() => _FavoriteArrivalsScopeState();
}

class _FavoriteArrivalsScopeState extends State<FavoriteArrivalsScope> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(context.read<SavedStopsCubit>().state);
    });
  }

  void _sync(SavedStopsState state) {
    if (state.loading) return;
    unawaited(
      context.read<FavoriteArrivalsCubit>().refresh(favoriteStopCodes(state)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SavedStopsCubit, SavedStopsState>(
      listener: (context, state) => _sync(state),
      child: widget.child,
    );
  }
}

/// Pontos a consultar na aba Favoritos: os favoritos e os pontos das linhas
/// favoritas, sem repetir.
List<String> favoriteStopCodes(SavedStopsState state) => [
  ...{
    for (final stop in state.favorites) stop.code,
    for (final line in state.lines) line.stopCode,
  },
];

/// Botão Atualizar da aba Favoritos: refaz a consulta de todos os pontos.
class FavoriteArrivalsRefresh extends StatelessWidget {
  const FavoriteArrivalsRefresh({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoriteArrivalsCubit, FavoriteArrivalsState>(
      buildWhen: (a, b) => a.refreshing != b.refreshing,
      builder: (context, state) {
        return Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: state.refreshing
                ? null
                : () => context.read<FavoriteArrivalsCubit>().refresh(
                    favoriteStopCodes(context.read<SavedStopsCubit>().state),
                    force: true,
                  ),
            icon: state.refreshing
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Atualizar chegadas'),
          ),
        );
      },
    );
  }
}

/// Aba Linhas: as linhas que o app já viu **nesta sessão e nos seus
/// favoritos**, com o ponto onde cada uma apareceu. Não é o catálogo oficial
/// (isso depende de autorização da RMTC) e não diz ordem de percurso nem
/// sentido: só "esta linha passou por este ponto".
class SeenLinesPanel extends StatelessWidget {
  const SeenLinesPanel({
    required this.currentStopId,
    required this.currentGroups,
    required this.onOpen,
    required this.onSearchStop,
    super.key,
  });

  /// Ponto na tela agora e as linhas que a consulta dele trouxe.
  final String? currentStopId;
  final List<ArrivalGroup> currentGroups;

  /// Consulta o ponto (abre Pontos).
  final ValueChanged<String> onOpen;
  final VoidCallback onSearchStop;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SavedStopsCubit, SavedStopsState>(
      builder: (context, saved) {
        return BlocBuilder<FavoriteArrivalsCubit, FavoriteArrivalsState>(
          builder: (context, live) {
            final seen = <String, List<String>>{};
            void add(String route, String stop) {
              final stops = seen.putIfAbsent(route, () => []);
              if (!stops.contains(stop)) stops.add(stop);
            }

            if (currentStopId != null) {
              for (final group in currentGroups) {
                add(group.routeId, currentStopId!);
              }
            }
            for (final line in saved.lines) {
              add(line.routeId, line.stopCode);
            }
            for (final entry in live.byStop.entries) {
              for (final group in entry.value.groups) {
                add(group.routeId, entry.key);
              }
            }
            if (seen.isEmpty) {
              return MessageView(
                icon: Icons.format_list_bulleted_rounded,
                title: 'As linhas estarão disponíveis em breve.',
                body:
                    'Por enquanto, consulte as chegadas pelo código do ponto.',
                action: FilledButton.icon(
                  onPressed: onSearchStop,
                  icon: const Icon(Icons.location_on_outlined, size: 20),
                  label: const Text('Buscar um ponto'),
                ),
              );
            }
            final routes = seen.keys.toList()..sort();
            final tokens = context.tokens;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionLabel(
                  icon: Icons.directions_bus_outlined,
                  label: 'Linhas vistas',
                  trailing: Text(
                    '${routes.length}',
                    style: monoStyle(
                      TextStyle(fontSize: 12, color: tokens.mutedText),
                    ),
                  ),
                ),
                const SizedBox(height: Space.xs),
                for (final route in routes) ...[
                  _SeenLineTile(
                    routeId: route,
                    stops: seen[route]!,
                    onOpen: onOpen,
                  ),
                  const SizedBox(height: Space.xs),
                ],
                const FootNote(
                  child: Text(
                    'Linhas vistas nas suas consultas desta sessão e nos '
                    'seus favoritos. A lista completa de linhas depende de '
                    'autorização da RMTC.',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SeenLineTile extends StatelessWidget {
  const _SeenLineTile({
    required this.routeId,
    required this.stops,
    required this.onOpen,
  });

  final String routeId;
  final List<String> stops;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final label = stops.length == 1
        ? 'no ponto ${stops.first}'
        : 'nos pontos ${stops.take(3).join(', ')}'
              '${stops.length > 3 ? ' e mais ${stops.length - 3}' : ''}';
    return Semantics(
      button: true,
      label:
          'Linha $routeId, $label. Consultar as chegadas do ponto '
          '${stops.first}',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: tokens.hairline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: () => onOpen(stops.first),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.all(Space.sm),
              child: Row(
                children: [
                  RoutePlate(routeId),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(color: tokens.mutedText),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: tokens.mutedText),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
