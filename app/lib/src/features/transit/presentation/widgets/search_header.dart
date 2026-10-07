import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';

/// Identidade + busca por código RMTC. Só aceita dígitos e mantém zeros à
/// esquerda (o código é tratado como texto).
class SearchHeader extends StatefulWidget {
  const SearchHeader({
    required this.controller,
    required this.loading,
    required this.onSearch,
    this.floating = true,
    super.key,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSearch;

  /// Sobre o mapa (com sombra) ou embutido no painel lateral.
  final bool floating;

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

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.sm,
        Space.sm,
        Space.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: Space.xs),
            child: BrandMark(size: 28),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onSubmitted: (_) => widget.onSearch(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: 0.6,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Digite o código do ponto',
                    hintStyle: TextStyle(
                      color: tokens.mutedText,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                    prefixIcon: const Icon(Icons.signpost_outlined),
                    suffixIcon: hasText
                        ? IconButton(
                            tooltip: 'Limpar código',
                            onPressed: widget.controller.clear,
                            icon: const Icon(Icons.close_rounded, size: 20),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: Space.xs),
              FilledButton(
                onPressed: widget.onSearch,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md),
                ),
                child: widget.loading
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Text('Buscar'),
              ),
            ],
          ),
        ],
      ),
    );

    if (!widget.floating) return content;
    return Material(
      color: tokens.floatingSurface,
      elevation: 6,
      shadowColor: tokens.shadow,
      borderRadius: BorderRadius.circular(Radii.panel - 4),
      child: content,
    );
  }
}
