# BusãoGyn 2.0 — Checkpoint de continuidade

Atualizado em 2026-10-28 (Etapa F). Serve para qualquer sessão retomar sem reconstruir o
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

- Etapa D (`docs/BUSAOGYN_2_0_ETAPA_D_QA_ESTABILIDADE.md`): QA em simulador
  iOS, emulador Android e Web (sem aparelho físico). Corrigidos: "Ponto null"
  ao tocar no mapa (iOS/Android), compartilhamento no iOS 26, paisagem sob a
  ilha/notch, resumo do painel desatualizado, status cortado, "Em breve" na
  aba Linhas de produção, busca por bairro com tipo omitido, alvos de 44 dp,
  Tab/leitor de tela no Web com os botões desenhados à mão (`FocusLink`;
  QA-11) e acompanhamento que parava com a janela sem foco (QA-12).
  Nenhum problema aberto da etapa.

- Etapa E (`docs/BUSAOGYN_2_0_ETAPA_E_PUBLICACAO.md`): auditoria de publicação
  sem publicar. Corrigidos:
  - política de privacidade dentro do app (Ajustes → Privacidade; App Store
    5.1.1(i));
  - compartilhar no Web de desktop (sem `mailto:`, cópia com tratamento);
  - declaração "app independente" (Play);
  - "seguinte" duplicado quando a fonte repete o próximo ônibus;
  - ícone de compartilhar adaptativo;
  - CI com verificador de catálogo nos artefatos (com controle positivo) e
    deploy Web alinhado ao Flutter 3.38.5.

  Matriz de release:
  - versão pública (Android, iOS, Web): pronta com ressalvas;
  - 2.0 completo: bloqueado pela licença CMTC
    (`docs/CMTC_2026_PEDIDO_AUTORIZACAO.md`, não enviado).

- Complemento da Etapa E (seção 16 do documento da etapa):
  - **Percurso futuro da linha 016**: quando o destino da RMTC é um trecho do
    meio da denominação, o deslocamento decide o sentido (Dart e Python
    iguais). Confirmado com um ônibus real.
  - **Posições em lote** (ADR-0006): de 15 para 4,5 requisições por minuto
    parado num ponto, com o app voltando à consulta por ônibus enquanto o
    Worker publicado não tiver o lote. **Worker não publicado.**

- Etapa F (`docs/BUSAOGYN_2_0_ETAPA_F_AUDITORIA_VISUAL.md`): capturas reais
  (Web em 5 tamanhos × claro/escuro; app nativo no simulador iOS), galeria,
  miniaturas, antes/depois e ZIP em `artifacts/` (local, fora do Git). Corrigidos:
  - F-1 nome acessível do campo Destino;
  - F-2 aviso do acompanhamento contradizia o mapa;
  - F-3 contraste do trajeto no tema claro;
  - F-4 atribuição do mapa sob a barra de status (iOS);
  - F-5 teclado cobria o planejador;
  - F-6 viagem enquadrada pela metade (iOS);
  - F-7 painel recolhido sem alça;
  - F-8 ônibus maior no mapa;
  - F-9 rastro seguindo o trajeto confirmado (não corta quarteirões).

## Testes e builds (último ciclo, Etapa F)

- 642 testes Flutter (inclui diretrizes de acessibilidade), 52 Python, 30 do
  Worker, `flutter analyze` limpo, formatação ok.
- Builds de produção (Web, APK, AAB, iOS release) sem dados da CMTC
  (`app/scripts/check-no-official-catalog.sh <artefatos>`); Web e APK de
  desenvolvimento como controle positivo (o verificador falha, como esperado).
- APK release: só permissões de rede; 16 KB ok. Sem aparelho físico.

## Próxima ação

1. Decisões do usuário:
   - merge na `main` e deploy do Web;
   - deploy do Worker com o lote (ADR-0006), que reduz a carga em 70%;
   - envio do pedido à CMTC;
   - alertas com app aberto e canal "Reportar problema".
2. Teste em aparelho físico Android e iPhone, com TalkBack/VoiceOver por uma
   pessoa.
3. Lojas: formulários com as respostas da Etapa E, ficha com a declaração de
   independência, build numbers acima dos últimos envios.

Capturas de loja: refazer a partir dos builds nativos da versão pública (sem
catálogo), nos tamanhos exigidos; nunca usar as capturas Web como iOS.

## Restrições e riscos

- Licença/redistribuição CMTC pendente: nada de dados CMTC em produção, no
  GitHub ou em deploy; sem merge na `main`; sem deploy.
- Sequências são inferidas e horários têm vigência não confirmada — nunca
  apresentar como oficiais/atuais.
- Validação real da Fase 6 com 8 ônibus: insuficiente para afirmar precisão.
- Sem varreduras extensas da API RMTC.
- Capacidade: cerca de 15 req/min por pessoa parada num ponto (4,5 com o lote
  do ADR-0006, depois do deploy do Worker), contra 100 mil req/dia do Workers
  gratuito (E-8).

## Ambiente local (dicas)

- Flutter do CI: `/Volumes/DevSSD/Flutter/fvm_cache/versions/3.38.5/bin`;
  iOS com Flutter master `/Volumes/DevSSD/flutter/bin`.
- Android: `GRADLE_OPTS=-Dorg.gradle.java.home=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home`.
- Após cada comando Flutter, restaurar os lockfiles locais do usuário. O
  `pubspec.lock` versionado é o do CI (3.38.5); o local do usuário = versionado
  + o diff do SDK dele (Flutter master).
- Emulador Android: o shell define `ANDROID_AVD_HOME=/Volumes/DevSSD/Android/avd`
  (vazio); use `ANDROID_AVD_HOME=$HOME/.android/avd ANDROID_SDK_ROOT=$HOME/Library/Android/sdk`
  só no comando, com `-no-snapshot-save`.
- Simulador iOS (Flutter master): `flutter build ios --simulator --config-only
  -t dev_catalog/main.dart` e depois `xcodebuild ... ARCHS=arm64` (bug de
  arquitetura do flutter_tools master).
- Botão desenhado à mão (`Semantics(excludeSemantics: true)` + `InkWell`):
  envolver em `FocusLink` (core/ui) e passar `onTap`, `focusable`,
  `focused`/`onFocus` ao nó; o teste de diretrizes reprova botão sem toque
  ou não focável.
- Se o web acusar `MissingPluginException`, rode `flutter clean` (registro de
  plugins em cache).
- Disco interno quase cheio (menos de 3 GB livres): o emulador Android recusa
  iniciar. Limpe só a pasta temporária da sessão.
- `flutter build ios` com o 3.38.5 roda `pod install` e altera o
  `Podfile.lock` e o `project.pbxproj` locais do usuário: restaure os dois
  depois (guarde cópias antes do build).
- Catálogo dev: `python3 -I data/cmtc/pipeline/export_catalog.py` →
  `app/dev_catalog/`; web dev: `flutter build web --profile -t dev_catalog/main.dart`.
