import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// O plugin web ignora `attributionButtonMargins`; o `web/index.html` lê esta
/// variável para manter o controle nativo de atribuição acima do painel.
void setWebMapAttributionOffset(double bottom) {
  final style = globalContext
      .getProperty<JSObject>('document'.toJS)
      .getProperty<JSObject>('documentElement'.toJS)
      .getProperty<JSObject>('style'.toJS);
  style.callMethod(
    'setProperty'.toJS,
    '--busao-map-attribution-bottom'.toJS,
    '${bottom.round()}px'.toJS,
  );
}
