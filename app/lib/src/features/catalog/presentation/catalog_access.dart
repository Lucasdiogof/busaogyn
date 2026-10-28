import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/transit_catalog.dart';

/// Acesso ao catálogo oficial pela árvore. [catalog] `null` = recurso
/// desligado; quem lê deve manter o comportamento anterior.
class CatalogAccess {
  const CatalogAccess(this.catalog);

  final TransitCatalog? catalog;
}

extension CatalogContext on BuildContext {
  /// Catálogo ligado, ou `null`. Sem provedor (testes antigos) também `null`.
  TransitCatalog? get catalog {
    try {
      return read<CatalogAccess>().catalog;
    } on ProviderNotFoundException {
      return null;
    }
  }
}
