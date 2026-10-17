/// Navegação do app (Linhas, Pontos, Favoritos e Meu ônibus, com Ajustes na
/// TopBar). É a navegação padrão; `--dart-define=BUSAOGYN_V2_NAV=false` volta
/// ao dock antigo, só para os testes dele.
abstract final class NavConfig {
  static const v2Nav = bool.fromEnvironment(
    'BUSAOGYN_V2_NAV',
    defaultValue: true,
  );
}
