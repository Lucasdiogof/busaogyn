import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';

/// Busca por código RMTC. Só aceita dígitos e mantém zeros à esquerda (o
/// código é tratado como texto).
class SearchHeader extends StatefulWidget {
  const SearchHeader({
    required this.controller,
    required this.loading,
    required this.onSearch,
    this.focusNode,
    this.onCancel,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool loading;
  final VoidCallback onSearch;

  /// Volta ao ponto já exibido sem buscar outro.
  final VoidCallback? onCancel;

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

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hasText = widget.controller.text.isNotEmpty;

    return GlassSurface(
      radius: Radii.field,
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
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.search,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onSubmitted: (_) => widget.onSearch(),
                style: monoStyle(
                  TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: tokens.strongText,
                  ),
                ),
                decoration: InputDecoration(
                  hintText: 'Código do ponto, ex.: 30402',
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
                tooltip: 'Limpar código',
                onPressed: widget.controller.clear,
                icon: const Icon(Icons.close_rounded, size: 20),
              )
            else if (widget.onCancel != null)
              IconButton(
                tooltip: 'Voltar ao ponto',
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            Padding(
              padding: const EdgeInsets.only(right: Space.xs),
              child: SizedBox.square(
                dimension: 40,
                child: Tooltip(
                  message: 'Buscar',
                  excludeFromSemantics: true,
                  child: FilledButton(
                    onPressed: widget.onSearch,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size.square(40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.plate),
                      ),
                    ),
                    child: widget.loading
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: tokens.onAccent,
                            ),
                          )
                        : const Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            semanticLabel: 'Buscar',
                          ),
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

/// Cartão de contexto: selo/placa à esquerda, título, subtítulo em Geist
/// Mono e uma ação à direita.
class ContextHeader extends StatelessWidget {
  const ContextHeader({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.action,
    this.semanticsLabel,
    super.key,
  });

  final Widget leading;
  final String title;
  final Widget subtitle;
  final Widget? action;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GlassSurface(
      child: SizedBox(
        height: Chrome.header,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: Space.sm),
              Expanded(
                child: Semantics(
                  label: semanticsLabel,
                  container: true,
                  excludeSemantics: semanticsLabel != null,
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
                        maxLines: 1,
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
