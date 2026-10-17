/// Navegação da v2 (Linhas, Pontos, Favoritos e Meu ônibus, com Ajustes na
/// TopBar). Desligada por padrão: sem a flag o app é o de sempre.
///
/// Ligue só para validação: `--dart-define=BUSAOGYN_V2_NAV=true`. Builds de
/// release não devem sair com ela ligada antes da validação do HomeShell.
abstract final class NavConfig {
  static const v2Nav = bool.fromEnvironment('BUSAOGYN_V2_NAV');
}
