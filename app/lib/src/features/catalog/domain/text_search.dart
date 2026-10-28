/// Normalização de texto para busca: minúsculas, sem acento, só letras e
/// dígitos separados por espaço. Tudo local; nada sai do aparelho.
library;

const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ç': 'c', 'ñ': 'n', 'º': 'o', 'ª': 'a',
};

final _nonWord = RegExp(r'[^a-z0-9]+');

/// 'Praça Cívica, nº 3' -> 'praca civica no 3'.
String normalizeSearch(String? text) {
  if (text == null || text.isEmpty) return '';
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_accents[ch] ?? ch);
  }
  return buffer.toString().replaceAll(_nonWord, ' ').trim();
}

/// Palavras normalizadas; abreviações comuns de endereço viram a forma longa
/// (a busca por prefixo já cobre "av" -> "avenida").
List<String> searchTokens(String? text) {
  final normalized = normalizeSearch(text);
  if (normalized.isEmpty) return const [];
  return [
    for (final word in normalized.split(' '))
      if (word.isNotEmpty) _synonyms[word] ?? word,
  ];
}

const _synonyms = {
  'pca': 'praca',
  'pc': 'praca',
  'rod': 'rodovia',
  'est': 'estrada',
  'jd': 'jardim',
  'res': 'residencial',
  'st': 'setor',
  'vl': 'vila',
  'pq': 'parque',
  'term': 'terminal',
};

/// Texto em caixa alta do cadastro ('RUA ARAGUAIA') para leitura ('Rua
/// Araguaia'). Siglas curtas, números romanos e códigos ficam como estão.
String displayCase(String? text) {
  if (text == null) return '';
  final words = text.trim().split(RegExp(r'\s+'));
  return [
    for (var i = 0; i < words.length; i++)
      _displayWord(words[i], first: i == 0),
  ].join(' ');
}

const _lowerWords = {
  'a', 'o', 'as', 'os', 'ao', 'aos', 'de', 'da', 'do', 'das', 'dos', //
  'e', 'em', 'na', 'no', 'nas', 'nos', 'com', 'para', 'por',
};
final _keepUpper = RegExp(r'^(?:[IVX]+|[A-Z]{1,2}-?\d.*|\d.*|[A-Z]\.?)$');

String _displayWord(String word, {required bool first}) {
  if (word.isEmpty) return word;
  if (_keepUpper.hasMatch(word) && word.toUpperCase() == word) return word;
  final lower = word.toLowerCase();
  if (!first && _lowerWords.contains(lower)) return lower;
  // Hífens e barras: cada pedaço com inicial maiúscula ('SANTA-FÉ').
  return lower.splitMapJoin(
    RegExp(r'[-/(]'),
    onNonMatch: (part) =>
        part.isEmpty ? part : part[0].toUpperCase() + part.substring(1),
  );
}
