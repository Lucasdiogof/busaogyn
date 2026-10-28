# BusãoGyn 2.0 — Checkpoint de continuidade

Atualizado em 2026-10-28 (Etapa C). Serve para qualquer sessão retomar sem reconstruir o
histórico. Não contém dados oficiais nem pessoais.

## Estado do Git

| Branch | Papel | HEAD (local = remoto) |
|---|---|---|
| `main` | Produção (push dispara deploy-web) | `758adac` |
| `feat/cmtc-catalogo-dev` | Fases 2–6 (catálogo só em dev) | `5149186` |
| `feat/ux-redesign` | Redesign UX/UI, criada a partir de `5149186` | ver `git log -1` (commit desta atualização) |

CI (`flutter-ci.yml`: flutter, build-android-web, build-ios) aprovado em
`34cb7ac`. O CI só roda quando `app/**` muda.

Arquivos locais do usuário que **nunca** entram em commit: `app/pubspec.lock`,
`app/ios/Podfile.lock`, `app/ios/Runner.xcodeproj/project.pbxproj`, pastas
`swiftpm/`, `.DS_Store`. Também nunca: `data/cmtc/raw|processed|reports`,
`app/dev_catalog/`, `/artifacts/` (todos no `.gitignore`).

## Concluído

- Fases 1–6 (dados CMTC locais, catálogo dev, mapas, horários/sequências,
  planejador, cobertura). Ver `docs/BUSAOGYN_2_0_FASE_*.md`.
- Redesign UX/UI (`docs/BUSAOGYN_2_0_UX_UI_REDESIGN.md`): dock Pontos ·
  Planejar (só com catálogo) · Linhas · Salvos; Meu ônibus como barra
  contextual persistente; folha com 3 alturas, Ver mapa, alça acessível,
  recolhimento ao escolher trajeto, voltar previsível; painel lateral em telas
  largas; `BusaoLoader`; novo marcador vetorial; setas de sentido; estilos de
  linha padronizados; título do planejador sem repetição; estrela de favorito
  com feedback animado (respeita movimento reduzido).

- Etapa C (`docs/BUSAOGYN_2_0_ETAPA_C_FUNCIONALIDADES.md`): Perto de mim
  (só dev, local, sem segundo plano), viagens salvas (schema 3 com migração),
  compartilhar ponto/linha/viagem (texto, sem links), busca com um erro de
  digitação, avisos acima do dock; estudos de alertas e de "reportar
  problema" (não implementados, dependem de decisão).

## Testes e builds (último ciclo)

- 612 testes Flutter, `flutter analyze` limpo, formatação ok.
- Builds produção web/APK/iOS sem dados CMTC (`app/scripts/check-no-official-catalog.sh <pasta>`);
  APK dev como controle positivo (verificador falha, como esperado).

## Próxima ação (Etapa D — qualidade e estabilidade)

1. Testar Perto de mim, viagens salvas e compartilhar em aparelho físico
   (Android e iPhone) e no navegador do celular.
2. QA real: chegadas, seguir ônibus, GPS antigo, API fora, reconexão,
   foreground/background, offline, desempenho.
3. Decisões pendentes do usuário: alertas só com o app aberto; canal de
   "Reportar problema"; links compartilháveis (domínio + deploy).

Depois: E (publicação), F (entrega
visual completa — 375×812, 390×844, 768×1024, 1024×1366, 1440×900, claro e
escuro, HTML + ZIP).

## Restrições e riscos

- Licença/redistribuição CMTC pendente: nada de dados CMTC em produção, no
  GitHub ou em deploy; sem merge na `main`; sem deploy.
- Sequências são inferidas e horários têm vigência não confirmada — nunca
  apresentar como oficiais/atuais.
- Validação real da Fase 6 com 8 ônibus: insuficiente para afirmar precisão.
- Sem varreduras extensas da API RMTC.

## Ambiente local (dicas)

- Flutter do CI: `/Volumes/DevSSD/Flutter/fvm_cache/versions/3.38.5/bin`;
  iOS com Flutter master `/Volumes/DevSSD/flutter/bin`.
- Android: `GRADLE_OPTS=-Dorg.gradle.java.home=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home`.
- Após cada comando Flutter, restaurar os lockfiles locais do usuário. O
  `pubspec.lock` versionado é o do CI (3.38.5); o local do usuário = versionado
  + o diff do SDK dele (Flutter master).
- Se o web acusar `MissingPluginException`, rode `flutter clean` (registro de
  plugins em cache).
- Catálogo dev: `python3 -I data/cmtc/pipeline/export_catalog.py` →
  `app/dev_catalog/`; web dev: `flutter build web --profile -t dev_catalog/main.dart`.
