import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
import '../formatters/search_feedback.dart';

/// Busca por código RMTC. Só aceita dígitos e mantém zeros à esquerda (o
/// código é tratado como texto). Com [allowText] (catálogo oficial ligado)
/// aceita também rua, bairro e cidade, que são buscados localmente.
class SearchHeader extends StatefulWidget {
  const SearchHeader({
    required this.controller,
    required this.loading,
    required this.onSearch,
    this.focusNode,
    this.onCancel,
    this.error,
    this.onEdited,
    this.onRetry,
    this.allowText = false,
    super.key,
  });

  /// Aceita texto livre além do código (busca no catálogo local).
  final bool allowText;

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool loading;
  final VoidCallback onSearch;

  /// Volta ao ponto já exibido sem buscar outro.
  final VoidCallback? onCancel;

  /// Última busca falhou: borda de erro e aviso curto logo abaixo do campo.
  final SearchFeedback? error;

  /// O código foi editado (o aviso de erro deixa de valer).
  final VoidCallback? onEdited;

  /// Repete a busca do código digitado (falha de conexão ou da fonte).
  final VoidCallback? onRetry;

  @override
  State<SearchHeader> createState() => _SearchHeaderState();
}

class _SearchHeaderState extends State<SearchHeader> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant SearchHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  String _lastText = '';

  void _onTextChanged() {
    final text = widget.controller.text;
    if (text != _lastText) {
      _lastText = text;
      if (widget.error != null) widget.onEdited?.call();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hasText = widget.controller.text.isNotEmpty;
    final error = widget.error;

    final field = GlassSurface(
      radius: Radii.field,
      // Falha de conexão não é culpa do código: sem borda de erro.
      borderColor: error == null || error.isConnectivity ? null : tokens.danger,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: Space.md),
            Icon(Icons.search_rounded, size: 20, color: tokens.mutedText),
            const SizedBox(width: Space.sm),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                keyboardType: widget.allowText
                    ? TextInputType.text
                    : TextInputType.number,
                textInputAction: TextInputAction.search,
                inputFormatters: widget.allowText
                    ? [LengthLimitingTextInputFormatter(60)]
                    : [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                onSubmitted: (_) => widget.onSearch(),
                style: widget.allowText
                    ? TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tokens.strongText,
                      )
                    : monoStyle(
                        TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: tokens.strongText,
                        ),
                      ),
                decoration: InputDecoration(
                  // Área de toque com a altura da barra, não só a da linha.
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  hintText: widget.allowText
                      ? l10n.catalogSearchHint
                      : l10n.searchHint,
                  hintStyle: TextStyle(
                    fontFamily: BusaoFonts.sans,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                    color: tokens.mutedText,
                  ),
                ),
              ),
            ),
            if (hasText)
              IconButton(
                tooltip: l10n.clearCode,
                onPressed: widget.controller.clear,
                icon: const Icon(Icons.close_rounded, size: 20),
              )
            else if (widget.onCancel != null)
              IconButton(
                tooltip: l10n.backToStop,
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            Padding(
              padding: const EdgeInsets.only(right: Space.xs),
              // 48 dp: alvo mínimo de toque do Android (o iOS pede 44 pt).
              child: SizedBox.square(
                dimension: 48,
                child: Tooltip(
                  message: l10n.search,
                  excludeFromSemantics: true,
                  child: FilledButton(
                    onPressed: widget.onSearch,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size.square(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.plate),
                      ),
                    ),
                    child: widget.loading
                        ? BusaoLoader(size: 18, color: tokens.onAccent)
                        : Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            semanticLabel: l10n.search,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (error == null) return field;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        const SizedBox(height: Space.xs),
        SearchErrorNote(
          error,
          onRetry: error.isConnectivity ? widget.onRetry : null,
        ),
      ],
    );
  }
}

/// Aviso compacto de busca que falhou: ícone, título e uma linha de ajuda.
class SearchErrorNote extends StatelessWidget {
  const SearchErrorNote(this.feedback, {this.onRetry, super.key});

  final SearchFeedback feedback;

  /// Uma consulta por toque; nunca repete sozinha.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final icon = switch (feedback.kind) {
      SearchFeedbackKind.offline => Icons.wifi_off_rounded,
      SearchFeedbackKind.timeout => Icons.hourglass_bottom_rounded,
      SearchFeedbackKind.unavailable => Icons.cloud_off_rounded,
      _ => Icons.error_outline_rounded,
    };
    return Semantics(
      liveRegion: true,
      label: '${feedback.title}. ${feedback.message}',
      excludeSemantics: true,
      child: GlassSurface(
        radius: Radii.plate,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.sm,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: tokens.danger),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: feedback.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: tokens.danger,
                        ),
                      ),
                      TextSpan(
                        text: ' · ${feedback.message}',
                        style: TextStyle(color: tokens.softText),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.3),
                ),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                  ),
                  child: Text(l10n.retry),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cartão de contexto: selo/placa à esquerda, título, subtítulo em Geist
/// Mono e uma ação à direita.
class ContextHeader extends StatelessWidget {
  const ContextHeader({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.action,
    this.semanticsLabel,
    this.tallAction = false,
    super.key,
  });

  final Widget leading;
  final String title;
  final Widget subtitle;
  final Widget? action;
  final String? semanticsLabel;

  /// Dá 48 dp de altura à [action] (respiro vertical de 8 em vez de 10, com a
  /// mesma altura de cartão), para botões que precisam do alvo de toque
  /// mínimo. O padrão mantém o cartão como sempre foi.
  final bool tallAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final scaler = MediaQuery.textScalerOf(context);
    final subtitleLines = Chrome.headerSubtitleLines(scaler);
    return GlassSurface(
      child: SizedBox(
        height: Chrome.headerHeight(scaler),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            10,
            tallAction ? 8 : 10,
            6,
            tallAction ? 8 : 10,
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: Space.sm),
              Expanded(
                child: Semantics(
                  label: semanticsLabel,
                  container: true,
                  excludeSemantics: semanticsLabel != null,
                  // A altura da barra acompanha a escala (Chrome.headerHeight),
                  // mas o texto para em 130%: acima disso o subtítulo ganha
                  // uma segunda linha em vez de a barra crescer sem limite.
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: Chrome.headerMaxTextScale,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: tokens.strongText,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        DefaultTextStyle.merge(
                          maxLines: subtitleLines,
                          overflow: TextOverflow.ellipsis,
                          style: monoStyle(
                            TextStyle(
                              fontSize: 11.5,
                              color: tokens.mutedText,
                              height: 1.2,
                            ),
                          ),
                          child: subtitle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ?action,
            ],
          ),
        ),
      ),
    );
  }
}

/// Selo âmbar quadrado do cartão de contexto.
class HeaderTile extends StatelessWidget {
  const HeaderTile(this.icon, {this.filled = true, super.key});

  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ExcludeSemantics(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: filled ? tokens.accent : tokens.background,
          borderRadius: BorderRadius.circular(Radii.plate),
          border: filled ? null : Border.all(color: tokens.hairline),
        ),
        child: Icon(
          icon,
          size: 22,
          color: filled ? tokens.onAccent : tokens.mutedText,
        ),
      ),
    );
  }
}
