# BusãoGyn 2.0 — Etapa D: QA, estabilidade e testes reais

Branch `feat/ux-redesign` (a partir de `42988f0`). Sem merge na `main`, sem
deploy, sem publicação em loja. Nenhuma API, regra de confiabilidade ou dado
oficial foi alterado.

## 1. Matriz de dispositivos e plataformas

| Ambiente | Disponível | Usado | Observação |
|---|---|---|---|
| iPhone 17 (simulador, iOS 26.5) | Sim | Sim | build debug com catálogo de dev; localização **simulada** |
| iPad (simuladores) | Sim | Não | só o painel lateral foi visto em paisagem no iPhone; iPad fica para a Etapa F |
| Android emulador (Medium_Phone, Android 37.1, arm64) | Sim | Sim | debug e profile, dev e produção; localização **simulada** (`geo fix`) |
| Android físico | Não conectado | — | lacuna |
| iPhone físico | Não conectado | — | lacuna |
| Web (Chromium via Playwright) | Sim | Sim | build de produção e de dev; offline e erros simulados |
| Safari | Instalado | Não | sem automação; lacuna |

**Nenhum teste desta etapa foi feito em aparelho físico.**

Ambiente: a variável `ANDROID_AVD_HOME` do shell aponta para
`/Volumes/DevSSD/Android/avd` (vazia); o AVD está em `~/.android/avd`. O
emulador foi iniciado com as variáveis só no comando (configuração do usuário
intacta) e com `-no-snapshot-save` (o estado do AVD não foi alterado).

## 2. Testes executados

### Automatizados
- **Flutter:** 622 testes (eram 612), `flutter analyze` limpo, `dart format`
  sem mudanças.
- **Python (pipeline):** 51 testes (`cd data/cmtc && python3 -I -m unittest
  discover -s pipeline/tests`).
- **Diretrizes de acessibilidade do Flutter** (novo): alvos de toque Android
  48 dp e iOS 44 pt, alvos tocáveis com rótulo e contraste de texto em Pontos,
  Perto de mim, chegadas, Linhas, linha aberta, Planejar, Salvos e
  acompanhamento — temas claro e escuro, com e sem catálogo.

### Manuais / instrumentados
| Área | iOS sim | Android emu | Web | Resultado |
|---|---|---|---|---|
| Perto de mim: pedido só no toque, lista por distância, você no mapa | ✓ | ✓ | ✓ (Etapa C) | ok |
| Permissão concedida / negada / negada de vez / serviço desligado / "Abrir ajustes" | ✓ (negar no iOS já é definitivo) | ✓ todos | ✓ negada | ok |
| Sem localização em segundo plano | diálogo só "uma vez"/"durante o uso" | diálogo sem "o tempo todo"; `dumpsys location`: cada pedido é removido ~4 s depois | — | ok |
| Linha: abrir, trajeto, setas, compartilhar | ✓ | — | ✓ | **QA-01** corrigido |
| Toque em ponto no mapa | ✓ | ✓ | — | **QA-08** corrigido |
| Tema escuro, fonte de acessibilidade máxima (~310 %) | ✓ | — | — | sem transbordo |
| Rotação (paisagem) | ✓ | — | — | **QA-02** corrigido |
| Sem internet, erro 500, JSON inválido, reconexão | — | — | ✓ produção | **QA-03** corrigido |
| Acompanhamento: frequência, troca de aba, internet perdida, reconexão | — | — | ✓ produção (API real) | **QA-04** corrigido |
| Idiomas pt/en (es por testes) | pt | en | pt | ok |
| Teclado no Web (Tab e Enter), com e sem leitor de tela | — | — | ✓ produção | **QA-11** corrigido |
| Produção sem catálogo: abas e botões | — | ✓ | ✓ | **QA-05** corrigido |

Dados: chegadas e posições vieram da API real (poucas consultas, um ponto,
um ônibus; nenhum número de veículo registrado aqui). Cenários de falha foram
simulados interceptando a rede no navegador.

## 3. Não executado (e por quê)

- Aparelhos físicos Android e iPhone: nenhum conectado.
- VoiceOver/TalkBack com leitor de tela ligado: não automatizável aqui;
  coberto por rótulos de semântica e diretrizes automáticas.
- Timeout real de GPS e posição imprecisa em aparelho: só em testes de widget
  (fake de localização).
- iPad e Safari: sem execução nesta etapa.
- Transição foreground/background em aparelho: coberta por testes de cubit
  (pausa/retoma) e pelo `dumpsys`; não em aparelho físico.
- Uso de bateria: não mensurável no emulador.

## 4–5. Problemas e correções

| ID | Gravidade | Plataforma | Reprodução | Causa | Correção | Regressão | Situação |
|---|---|---|---|---|---|---|---|
| QA-08 | **P1** | iOS e Android | Tocar num ponto do mapa abre "Ponto null" (relatado pelo usuário) | No nativo o toque devolve o `id` da feição; o `promoteId` só vale no Web, e a feição não tinha `id` | Código do ponto também no `id` da feição; toque com id vazio/"null" ignorado | `network_test` (todas as feições de ponto com `id`) | Corrigido e verificado no iOS sim e no emulador Android |
| QA-01 | **P1** | iOS 26 | Compartilhar linha/ponto/viagem só copiava o texto | `share_plus` exige a área de origem também no iPhone (iOS 26) | Origem = retângulo do botão tocado | widget: origem não vazia | Corrigido; folha nativa abriu no simulador |
| QA-02 | P2 | iOS/Android em paisagem | Girar o iPhone: a ilha/notch cobre o painel lateral | Geometria ignorava `padding.left/right` | Margens laterais seguras no painel, dock, cabeçalho, controles e câmera | `home_shell_v2_test` (paisagem com 59 pt) | Corrigido e verificado no simulador |
| QA-03 | P2 | Todas | Resumo do painel ficava "consultando chegadas…" após erro ou sucesso | Resumo montado no `build` da página, que não reconstrói com o cubit | Resumo dentro de `BlocBuilder` | `home_shell_v2_test` (offline) | Corrigido; reconfirmado no Web |
| QA-04 | P3 | Todas (≤ 400 px) | Status do topo mostrava "Desat…" | Rótulo e idade dividiam o espaço igualmente | Rótulo inteiro; a idade sai quando não cabe (fica no rótulo de semântica) | `live_status_pill_test` | Corrigido |
| QA-05 | P2 | Produção | Aba Linhas dizia "Em breve" | Texto antigo; a aba já lista as linhas dos pontos consultados | "Linhas dos pontos que você consultou" / "Nenhuma linha por aqui ainda" | `catalog_ui_test` (sem "breve") | Corrigido |
| QA-06 | P2 | Dev (catálogo) | Buscar "jardim america" ou "setor bueno" não achava nada | Cadastro guarda "AMÉRICA", "BUENO" sem o tipo | Tipos de bairro (setor, jardim, vila, parque, residencial, bairro, conjunto) opcionais quando não casam; outra palavra precisa casar | `nearby_search_test` | Corrigido ("jardim america": 0 → 107) |
| QA-07 | P2 | Android | "Buscar" (44 dp) e "Atualizar chegadas" (44 dp) abaixo do mínimo de 48 dp | Tamanho fixo de 44 | 48 dp | teste de diretrizes de acessibilidade | Corrigido |
| QA-11 | P2 | Web (e leitores de tela) | Com a árvore de acessibilidade ligada, o Tab do navegador ficava preso em "Buscar"; Ajustes, dock e botões do painel nunca recebiam foco. Sem leitor de tela o Tab funcionava | **Isolado:** com o mapa trocado por um painel vazio o defeito continuava (não é o MapLibre). No DOM, só os botões padrão tinham `tabindex`; os 15 botões desenhados à mão usavam `Semantics(excludeSemantics: true)` em volta de um `InkWell`, o que escondia a ação de toque e o foco: os nós não tinham ação de toque, não eram focáveis e não refletiam o foco do Flutter, então o motor devolvia o foco ao "Buscar". Na mesma revisão apareceu um defeito pior: os chips Ida/Volta do detalhe da linha, ativados por leitor de tela, chamavam "voltar às linhas" | Novo componente `FocusLink` (foco próprio ligado a `focused`/`onFocus` do nó, ação de toque, Enter/Espaço e anel de foco só no teclado) nos 15 botões; chips Ida/Volta com a ação certa | Diretriz "todo botão tem toque e é focável" nas telas principais (dev e produção); Tab chega a "Salvos", o nó fica focado e Enter abre; leitor de tela em "Volta" mostra o trajeto de volta. Verificado por mutação (os testes falham sem a correção) | Corrigido; no navegador o Tab percorre mapa → Ajustes → campo → Buscar → painel → Pontos → Linhas → Salvos e Enter abre a aba |
| QA-09 | P3 | Local | Pastas `swiftpm/` vazias | `flutter clean` (28/10 10:42) apagou `Package.resolved` gerados por um build iOS de 27/10 (não eram do usuário) | Nenhuma necessária: o build iOS seguinte os recriou com o mesmo conteúdo (pin do `maplibre-gl-native-distribution` 6.28.0) | — | Resolvido |
| QA-12 | P2 | Web | Com a janela do navegador sem foco (outra janela ou outro monitor), mas a aba **visível**, o acompanhamento parava (0 consultas em 31 s) | O Flutter Web transforma `blur` da janela em `inactive`, e a página pausava em `inactive` | Pausa só em `hidden`/`paused`/`detached`; `inactive` continua (no celular sempre passa por `hidden` antes de sair da tela) | `catalog_map_ui_test` "ciclo de vida": inativo continua (2 consultas em 31 s), oculto pausa (0 em 3 min), volta faz 1 consulta na hora e segue a cada 15 s | Corrigido |
| QA-10 | P3 | Ferramenta | Build iOS de simulador com Flutter master falha ("não contém arm64 x86_64" embora contenha) | Bug do flutter_tools master | Contorno: `--config-only` + `xcodebuild ARCHS=arm64` | — | Contornado; não afeta o CI (3.38.5) |

Notas que **não** são defeitos: a primeira negação no iOS já é definitiva
(regra do sistema); o ponto "você" continua no mapa ao trocar de aba enquanto a
posição está na memória.

## 6. Desempenho (medido)

| Medida | Resultado | Onde |
|---|---|---|
| Decodificar catálogo (2,0 MB, 7.502 pontos) | 94 ms | VM de teste |
| Montar camada de pontos (GeoJSON) | 5 ms | VM |
| Busca de pontos (7 consultas reais) | 1–12 ms | VM |
| Perto de mim (7,5 mil pontos) | ~1 ms | VM |
| Planejador | mediana 0 ms, máx. 6 ms (20 pares) | VM |
| Abertura a frio, produção (profile) | ~4,7–4,9 s | emulador arm64 |
| Abertura a frio, dev com catálogo (profile) | ~4,4–5,7 s | emulador |
| Memória após 15 s (PSS) | produção 160 MB; dev 204 MB | emulador |
| CPU ociosa | 0–0,9 % | emulador |
| Consultas no acompanhamento | 18/min no total (ônibus acompanhado a cada 15 s + ônibus próximos a cada 30 s), sem duplicação ao trocar de aba | Web, API real |
| Consulta de chegadas | 1 requisição por tentativa; nenhum laço automático em erro | Web |

Auditoria de recursos: todos os timers são cancelados no `close()` dos cubits;
o polling pausa fora do primeiro plano; controladores, listeners e observers
são liberados no `dispose`; o mapa é criado uma vez (testes `created == 1`).

### Polling com a aba oculta (Web, API simulada, dados fictícios)

Medido no build de produção com a rede interceptada (respostas fictícias, um e
cinco ônibus), simulando `blur`/`focus` e `visibilitychange`:

| Fase | Antes da correção | Depois |
|---|---|---|
| Visível (31 s) | 2 consultas do ônibus acompanhado (a cada 15 s) | igual |
| Janela sem foco, aba visível (31 s) | **0** (acompanhamento parado) | continua a cada 15 s (teste de widget) |
| Aba oculta (46 s) | 0 do acompanhado; 2 dos ônibus próximos logo no início, vindas do retorno do `focus` imediatamente antes | 0 |
| Aba de volta | 1 consulta imediata do acompanhado + os próximos, depois a cada 15 s; nenhuma duplicada (< 2 s) | igual |

Ao voltar, a consulta imediata só acontece se a última tentativa tiver mais de
10 s (evita rajada ao alternar janelas). Navegadores ainda limitam timers em
abas ocultas; o app não depende disso porque pausa sozinho.

## 7. Regressões

Nenhuma regressão encontrada nas funções das etapas anteriores. Os testes
existentes continuam passando; três expectativas foram ajustadas de propósito
(texto "Em breve", idade no status do topo agora verificada pela semântica e
assinatura de `sharePlatform`).

## 8. Builds

| Build | Resultado | Verificador CMTC | Observação |
|---|---|---|---|
| Web produção (release, Flutter 3.38.5) | OK, `main.dart.js` 3.918.746 bytes | Ausente | — |
| Android produção (release APK) | OK, 86,7 MB | Ausente | 0 permissões de localização (`aapt`) |
| Android dev (profile, catálogo) | OK, 151,5 MB | Presente (controle positivo: verificador falha) | — |
| iOS produção (release, `--no-codesign`, Flutter master) | OK, 29,7 MB | Ausente | — |
| iOS simulador dev (debug) | OK via `xcodebuild ARCHS=arm64` | — | ver QA-10 |
| Android dev (debug) no emulador | OK | — | — |

## 9. Segurança e privacidade

- Android release: sem permissão de localização nem serviço de localização
  (`aapt`); dev (debug/profile): só `COARSE/FINE` em primeiro plano.
- iOS: só `NSLocationWhenInUseUsageDescription`; sem `UIBackgroundModes`.
- Nenhuma coordenada gravada ou enviada; nenhum histórico de posição.
- Logs: só erros técnicos (catálogo ignorado, falha do compartilhamento), sem
  dados pessoais nem texto compartilhado.
- Hosts de rede do app: API própria e tiles do OpenFreeMap; nenhum novo.
- Nenhum segredo versionado; nenhum dado CMTC no Git (verificado com
  `git ls-files` e com o verificador nos artefatos).
- Compartilhamento: só texto, sem links nem posição.
- `docs/PRIVACY.md` coerente com o comportamento atual.

## 10–11. Limitações e riscos remanescentes

- Sem teste em aparelho físico (GPS real, gestos do sistema, teclado real,
  desempenho real).
- Precisão das previsões não avaliada além da amostra da Fase 6.
- Licença/redistribuição dos dados CMTC pendente: funções de catálogo seguem
  só em desenvolvimento.
- Abertura a frio de ~5 s no emulador (sem aceleração de GPU real); medir em
  aparelho antes de otimizar.
- Build iOS de simulador depende de contorno no Flutter master local.

## 12. Recomendação para a Etapa E

1. Teste em pelo menos um Android e um iPhone físicos (lista de cenários da
   seção 2).
2. Fechar a decisão de licença CMTC antes de qualquer publicação com catálogo.
3. Preparar lojas: ícones, capturas (Etapa F), formulários de privacidade a
   partir do `docs/PRIVACY.md`, política pública atualizada.
4. Definir domínio/deploy para links compartilháveis e canal de suporte.
5. Testar VoiceOver e TalkBack em aparelho (o QA-11 foi validado no Web e por testes).
6. **Não** declarar o app pronto para publicação enquanto houver os
   bloqueadores acima.
