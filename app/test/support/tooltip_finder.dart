import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// `find.byTooltip` (flutter_test 3.50) não enxerga o [Tooltip] do material_ui
/// quando `excludeFromSemantics: true`; este finder cobre os dois casos.
extension TooltipFinder on CommonFinders {
  Finder byTip(Pattern message) => byWidgetPredicate((widget) {
        if (widget is! Tooltip) return false;
        final text = widget.message ?? widget.richMessage?.toPlainText() ?? '';
        return message is RegExp ? message.hasMatch(text) : text == message;
      }, skipOffstage: true);
}
