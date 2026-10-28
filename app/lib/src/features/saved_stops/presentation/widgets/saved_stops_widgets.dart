import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
import '../../../catalog/presentation/catalog_access.dart';
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
            ? l10n.favoriteStopRemove(code)
            : l10n.favoriteStopAdd(code);
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
        SnackBar(
          content: Text(l10n.favoriteLinesLimit(defaultFavoriteLinesLimit)),
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
            ? l10n.favoriteLineRemove(routeId, stopCode)
            : l10n.favoriteLineAdd(routeId);
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
                    // Feedback ao favoritar: a estrela troca com um leve salto.
                    AnimatedSwitcher(
                      duration: motion(
                        context,
                        const Duration(milliseconds: 220),
                      ),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                        child: child,
                      ),
                      child: Icon(
                        favorite
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        key: ValueKey(favorite),
                        size: 20,
                        color: favorite ? tokens.accentText : tokens.mutedText,
                      ),
                    ),
                    const SizedBox(width: Space.xs),
                    Flexible(
                      child: Text(
                        favorite ? l10n.favoriteLineOn : l10n.favoriteLineOff,
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
      if (!state.persistent) (Icons.save_outlined, l10n.storageNotPersistent),
      if (state.readFailed)
        (Icons.sync_problem_rounded, l10n.storageReadFailed),
      if (state.writeFailed)
        (Icons.sync_problem_rounded, l10n.storageWriteFailed),
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
    // Nome guardado (quando a fonte deu um) ou, com o catálogo oficial
    // ligado, o endereço do cadastro. Só exibição: nada muda no que foi salvo.
    final catalogStop = context.catalog?.stop(stop.code);
    final name = stop.name ?? catalogStop?.address;
    final place = catalogStop?.place;
    final named = name != null;
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
                  label: named
                      ? l10n.stopOpenArrivalsNamed(stop.code, name)
                      : l10n.stopOpenArrivals(stop.code),
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
                                      name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: tokens.strongText,
                                      ),
                                    ),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${l10n.stopWord} ',
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
                                        if (place != null)
                                          TextSpan(
                                            text: ' · $place',
                                            style: TextStyle(
                                              color: tokens.mutedText,
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
    final address = context.catalog?.stop(line.stopCode)?.address;
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
                  label: address == null
                      ? l10n.lineOpenArrivals(line.routeId, line.stopCode)
                      : '${l10n.lineOpenArrivals(line.routeId, line.stopCode)}, $address',
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
                                      text: '${l10n.atStopWord} ',
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
                                    if (address != null)
                                      TextSpan(
                                        text: ' · $address',
                                        style: TextStyle(
                                          color: tokens.mutedText,
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
                  tooltip: l10n.favoriteLineRemove(line.routeId, line.stopCode),
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
              title: l10n.favoritesEmptyTitle,
              body: l10n.favoritesEmptyBody,
              action: FilledButton.icon(
                onPressed: onSearchStop,
                icon: const Icon(Icons.location_on_outlined, size: 20),
                label: Text(l10n.searchStopAction),
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
                  label: l10n.favoriteStopsSection,
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
                    removeTooltip: l10n.favoriteStopRemove(stop.code),
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
                  label: l10n.favoriteLinesSection,
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
          children.add(FootNote(child: Text(l10n.offlineHint)));
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
    this.showHint = true,
    this.hideFavorites = false,
    super.key,
  });

  /// Nota sobre consulta e internet; em Salvos ela já vem dos favoritos.
  final bool showHint;

  /// Em Salvos, um favorito já aparece na lista de cima: não repete.
  final bool hideFavorites;

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
        title: Text(l10n.clearRecentsTitle),
        content: Text(l10n.clearRecentsBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.clear),
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
            if (stop.code != excludeCode &&
                !(hideFavorites &&
                    state.favorites.any((f) => f.code == stop.code)))
              stop,
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
              label: l10n.recentsSection,
              trailing: recents.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => _confirmClear(context),
                      child: Text(l10n.clear),
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
                  l10n.recentsEmpty,
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
                  removeTooltip: l10n.recentStopRemove(stop.code),
                  onOpen: () => onOpen(stop.code),
                  onRemove: () =>
                      context.read<SavedStopsCubit>().removeRecent(stop.code),
                ),
                const SizedBox(height: Space.xs),
              ],
              if (showHint) FootNote(child: Text(l10n.offlineHint)),
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
      label: l10n.loadingSavedStops,
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
          FavoriteStopStatus.loading => Text(
            l10n.favoriteStatusLoading,
            style: style,
          ),
          FavoriteStopStatus.offline => Text(
            l10n.favoriteStatusOffline,
            style: style,
          ),
          FavoriteStopStatus.failed => Text(
            l10n.favoriteStatusFailed,
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
    if (groups.isEmpty) {
      return Text(
        hour == null ? l10n.noArrivalsNow : l10n.noArrivalsNowAt(hour),
        style: style,
      );
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
              ? (hour == null ? l10n.lastValidData : l10n.lastValidDataAt(hour))
              : (hour == null ? l10n.queriedNow : l10n.queriedAtHour(hour)),
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
      <= 0 => l10n.minutesLessThanOne,
      final m => l10n.minutesShort(m),
    };
    return Semantics(
      container: true,
      label: l10n.lineSemantics(
        group.routeId,
        minutesSemantics(minutes),
        qualityShortLabel(quality),
      ),
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
                ? const BusaoLoader(size: 16)
                : const Icon(Icons.refresh_rounded, size: 20),
            label: Text(l10n.refreshArrivals),
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
                title: l10n.seenLinesEmptyTitle,
                body: l10n.seenLinesEmptyBody,
                action: FilledButton.icon(
                  onPressed: onSearchStop,
                  icon: const Icon(Icons.location_on_outlined, size: 20),
                  label: Text(l10n.searchStopAction),
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
                  label: l10n.seenLinesSection,
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
                FootNote(child: Text(l10n.seenLinesNote)),
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
        ? l10n.seenAtStop(stops.first)
        : (stops.length > 3
              ? l10n.seenAtStopsMore(stops.take(3).join(', '), stops.length - 3)
              : l10n.seenAtStops(stops.take(3).join(', ')));
    return Semantics(
      button: true,
      label: l10n.seenLineSemantics(routeId, label, stops.first),
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
