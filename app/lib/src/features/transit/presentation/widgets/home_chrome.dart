import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
import '../formatters/transit_labels.dart';

/// Destinos da home. No dock: Pontos ([stop]), Planejar ([plan], só com o
/// catálogo), Linhas ([lines]) e Salvos ([saved]). Meu ônibus ([tracking]) é
/// contextual: abre pela barra de acompanhamento. Ajustes ([settings]) abre
/// pela TopBar.
enum HomeTab { stop, plan, lines, saved, tracking, settings }

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.labelLines,
    required this.selected,
    required this.onTap,
    this.fitContent = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final int labelLines;
  final bool selected;
  final VoidCallback onTap;

  /// Encolhe o conteúdo (só se não couber) em vez de estourar a altura ou a
  /// largura do item. Usado pelo dock de quatro destinos, onde cada aba é
  /// mais estreita; o dock de três destinos segue como sempre foi.
  final bool fitContent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final radius = BorderRadius.circular(Radii.dock - 6);
    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      color: selected ? tokens.strongText : tokens.mutedText,
    );
    // Cada palavra numa linha própria quando o rótulo não cabe em uma; o
    // FittedBox só encolhe uma palavra que, sozinha, passe da largura da
    // aba (nunca corta a letra).
    final words = labelLines > 1 ? label.split(' ') : [label];
    final content = Column(
      mainAxisSize: fitContent ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 22,
          color: selected ? tokens.accentText : tokens.mutedText,
        ),
        const SizedBox(height: 3),
        for (final word in words)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(word, maxLines: 1, softWrap: false, style: labelStyle),
          ),
      ],
    );
    return Expanded(
      child: Semantics(
        container: true,
        selected: selected,
        button: true,
        label: label,
        excludeSemantics: true,
        // Seleção sem depender só de cor: ícone preenchido, rótulo em negrito
        // e fundo suave (sem borda extra).
        child: AnimatedContainer(
          duration: motion(context, const Duration(milliseconds: 200)),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? tokens.accentSoft : Colors.transparent,
            borderRadius: radius,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              // O item inteiro continua sendo a área de toque; só o conteúdo
              // encolhe, e só quando não cabe.
              child: fitContent
                  ? SizedBox.expand(
                      child: FittedBox(fit: BoxFit.scaleDown, child: content),
                    )
                  : content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Navegação principal: Pontos, Planejar (com catálogo), Linhas e Salvos.
/// Meu ônibus fica na barra contextual ([TrackingBar]); Ajustes, na [TopBar].
class NavDock extends StatelessWidget {
  const NavDock({
    required this.selected,
    required this.onSelected,
    required this.layout,
    this.showPlan = false,
    super.key,
  });

  /// Destino atual; com Ajustes ou Meu ônibus aberto nenhum item aparece
  /// selecionado.
  final HomeTab selected;
  final ValueChanged<HomeTab> onSelected;

  /// Planejar só existe com o catálogo (desenvolvimento).
  final bool showPlan;

  final ({int labelLines, double height}) layout;

  @override
  Widget build(BuildContext context) {
    Widget item(
      HomeTab tab,
      IconData icon,
      IconData selectedIcon,
      String label,
    ) => _DockItem(
      key: ValueKey('dock-${tab.name}'),
      icon: selected == tab ? selectedIcon : icon,
      label: label,
      labelLines: layout.labelLines,
      selected: selected == tab,
      fitContent: true,
      onTap: () => onSelected(tab),
    );
    final items = [
      item(
        HomeTab.stop,
        Icons.location_on_outlined,
        Icons.location_on_rounded,
        l10n.dockStops,
      ),
      if (showPlan)
        item(
          HomeTab.plan,
          Icons.alt_route_outlined,
          Icons.alt_route_rounded,
          l10n.dockPlan,
        ),
      item(
        HomeTab.lines,
        Icons.format_list_bulleted_rounded,
        Icons.view_list_rounded,
        l10n.dockLines,
      ),
      item(
        HomeTab.saved,
        Icons.bookmark_border_rounded,
        Icons.bookmark_rounded,
        l10n.dockSaved,
      ),
    ];
    return GlassSurface(
      radius: Radii.dock,
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        height: layout.height - 12,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              items[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Marca à esquerda e status dos dados à direita. Com [onSettings],
/// o botão Ajustes fica no canto direito.
class TopBar extends StatelessWidget {
  const TopBar({
    required this.status,
    required this.onSettings,
    this.settingsSelected = false,
    super.key,
  });

  /// `null` esconde o status (nada consultado ainda).
  final LiveStatus? status;

  /// Abre (ou fecha) Ajustes.
  final VoidCallback onSettings;
  final bool settingsSelected;

  @override
  Widget build(BuildContext context) {
    final status = this.status;
    // Com fonte muito grande o wordmark (decorativo) sai e fica só o selo,
    // deixando a largura para o status ao vivo, que continua escalando.
    // Com o botão Ajustes ao lado a marca perde o nome um pouco antes.
    // Em telas de 320 px o status ao vivo também não caberia ao lado do nome.
    final wordmark =
        MediaQuery.textScalerOf(context).scale(1) < 1.3 &&
        MediaQuery.sizeOf(context).width >= 360;
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
        const SizedBox(width: Space.xs),
        _SettingsButton(onPressed: onSettings, selected: settingsSelected),
      ],
    );
  }
}

/// Ajustes na TopBar: alvo de toque de 48 dp, com a mesma pílula de vidro dos
/// demais itens e estado selecionado que não depende só de cor.
class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onPressed, required this.selected});

  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: l10n.settings,
      excludeSemantics: true,
      child: Tooltip(
        message: l10n.settings,
        excludeFromSemantics: true,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: GlassSurface(
              radius: Radii.pill,
              borderColor: selected ? tokens.accent : null,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPressed,
                  child: SizedBox.square(
                    dimension: Chrome.pill,
                    child: Icon(
                      selected ? Icons.tune_rounded : Icons.tune_outlined,
                      size: 22,
                      color: selected ? tokens.accentText : tokens.strongText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
    const labelStyle = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600);
    return Semantics(
      label: status.semantics,
      liveRegion: true,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // O rótulo ("Desatualizado") é o que importa: quando rótulo e idade
          // não cabem juntos, a idade sai (continua no rótulo de semântica).
          final label = TextPainter(
            text: TextSpan(text: status.label, style: labelStyle),
            textDirection: TextDirection.ltr,
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          // Padding (24) + ícone (16) + espaço (6) + idade mínima legível.
          final showDetail = constraints.maxWidth - 46 - label.width >= 56;
          label.dispose();
          return _pill(context, color, labelStyle, showDetail: showDetail);
        },
      ),
    );
  }

  Widget _pill(
    BuildContext context,
    Color color,
    TextStyle labelStyle, {
    required bool showDetail,
  }) {
    final tokens = context.tokens;
    return GlassSurface(
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
            // Com a idade à vista o rótulo já cabe inteiro (medido acima);
            // sem ela, só encolhe em telas estreitas demais.
            Flexible(
              flex: showDetail ? 0 : 1,
              child: Text(
                status.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle.copyWith(color: tokens.strongText),
              ),
            ),
            // Textos mais longos (es: "hace 13 s") encolhem em vez de
            // serem cortados com reticências.
            if (showDetail) const SizedBox(width: 6),
            if (showDetail)
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    status.detail,
                    maxLines: 1,
                    softWrap: false,
                    style: monoStyle(
                      TextStyle(fontSize: 11, color: tokens.mutedText),
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
