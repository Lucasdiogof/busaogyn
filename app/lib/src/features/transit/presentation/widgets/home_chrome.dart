import 'package:flutter/material.dart';

import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
import '../formatters/transit_labels.dart';

/// Abas do dock: Chegadas (o que chega no ponto), Meu ônibus (onde está o
/// ônibus escolhido) e Ajustes.
enum HomeTab { stop, tracking, settings }

/// Dock inferior flutuante com três destinos.
class AppDock extends StatelessWidget {
  const AppDock({
    required this.selected,
    required this.onSelected,
    required this.trackingActive,
    super.key,
  });

  final HomeTab selected;
  final ValueChanged<HomeTab> onSelected;

  /// Marca a aba Meu ônibus quando há um ônibus acompanhado.
  final bool trackingActive;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: Radii.dock,
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        height: Chrome.dock - 12,
        child: Row(
          children: [
            _DockItem(
              icon: Icons.departure_board_rounded,
              label: 'Chegadas',
              selected: selected == HomeTab.stop,
              onTap: () => onSelected(HomeTab.stop),
            ),
            const SizedBox(width: 4),
            _DockItem(
              icon: Icons.directions_bus_outlined,
              label: 'Meu ônibus',
              selected: selected == HomeTab.tracking,
              badge: trackingActive,
              onTap: () => onSelected(HomeTab.tracking),
            ),
            const SizedBox(width: 4),
            _DockItem(
              icon: Icons.tune_rounded,
              label: 'Ajustes',
              selected: selected == HomeTab.settings,
              onTap: () => onSelected(HomeTab.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final radius = BorderRadius.circular(Radii.dock - 6);
    return Expanded(
      child: Semantics(
        container: true,
        selected: selected,
        button: true,
        label: badge ? '$label, ônibus acompanhado' : label,
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? tokens.accentSoft : Colors.transparent,
            borderRadius: radius,
            border: Border.all(
              color: selected ? tokens.accent : Colors.transparent,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        icon,
                        size: 22,
                        color: selected ? tokens.accentText : tokens.mutedText,
                      ),
                      if (badge)
                        Positioned(
                          right: -3,
                          top: -2,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: tokens.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: tokens.background,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? tokens.strongText : tokens.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marca à esquerda e status dos dados à direita.
class TopBar extends StatelessWidget {
  const TopBar({required this.status, super.key});

  /// `null` esconde o status (nada consultado ainda).
  final LiveStatus? status;

  @override
  Widget build(BuildContext context) {
    final status = this.status;
    // Com fonte muito grande o wordmark (decorativo) sai e fica só o selo,
    // deixando a largura para o status ao vivo, que continua escalando.
    final wordmark = MediaQuery.textScalerOf(context).scale(1) < 1.5;
    return Row(
      children: [
        GlassSurface(
          radius: Radii.pill,
          padding: EdgeInsets.fromLTRB(6, 0, wordmark ? 14 : 6, 0),
          child: SizedBox(
            height: Chrome.pill,
            child: Center(
              widthFactor: 1,
              child: wordmark
                  ? const BrandMark()
                  : Semantics(
                      label: 'BusãoGyn',
                      child: const BrandMark(showWordmark: false),
                    ),
            ),
          ),
        ),
        const SizedBox(width: Space.xs),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: 0.92, end: 1.0).animate(animation),
                  alignment: Alignment.centerRight,
                  child: child,
                ),
              ),
              child: status == null
                  ? const SizedBox.shrink()
                  : LiveStatusPill(
                      key: ValueKey('${status.label}-${status.tone}'),
                      status: status,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class LiveStatusPill extends StatelessWidget {
  const LiveStatusPill({required this.status, super.key});

  final LiveStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = switch (status.tone) {
      LiveTone.live => tokens.realtime,
      LiveTone.scheduled => tokens.mutedText,
      LiveTone.aging => tokens.mutedText,
      LiveTone.stale => tokens.unconfirmed,
    };
    return Semantics(
      label: status.semantics,
      liveRegion: true,
      excludeSemantics: true,
      child: GlassSurface(
        radius: Radii.pill,
        padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
        child: SizedBox(
          height: Chrome.pill,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status.tone == LiveTone.stale)
                Icon(Icons.warning_amber_rounded, size: 16, color: color)
              else
                StatusDot(
                  color: color,
                  pulsing: status.tone == LiveTone.live,
                  pulseKey: status.receivedAt,
                ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  status.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.strongText,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  status.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: monoStyle(
                    TextStyle(fontSize: 11, color: tokens.mutedText),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
