# BusãoGyn 2.0 — Revisão de UX/UI e identidade visual

Branch: `feat/ux-redesign` (a partir de `5149186`, fim da Fase 6). Sem merge na
`main`, sem deploy. Nenhuma API, regra de dados, algoritmo de rota ou lógica de
previsão foi alterada.

## 1. Arquitetura anterior

- **Navegação (dock):** Pontos · Linhas · Meu ônibus · Favoritos. Meu ônibus era
  um destino fixo, vazio na maior parte do tempo. O planejador (só dev) abria por
  um botão flutuante sobre o mapa, fora da navegação.
- **Painel no celular:** `DraggableScrollableSheet` com alça decorativa (sem
  ação nem semântica) e altura do conteúdo medida por um `_SizeReporter`. Não
  havia como recolher o painel para ver o mapa a não ser arrastando.
- **Tablet/desktop:** o mesmo painel em coluna central sobre o mapa, cobrindo o
  trajeto enquadrado.
- **Voltar do sistema:** saía do app em qualquer contexto.
- **Carregamento:** `CircularProgressIndicator` genérico; skeleton pulsando mesmo
  com movimento reduzido.
- **Marcador do ônibus:** vista de cima com teto em blocos, sem faixa de destino.
- **Mapa:** trajeto ida/volta sem setas de sentido (só a viagem planejada tinha).

## 2. Problemas encontrados (auditoria)

| # | Problema | Impacto |
|---|----------|---------|
| 1 | Meu ônibus ocupava um lugar fixo no dock e quase sempre mostrava estado vazio | Navegação com um destino morto; acompanhamento some ao trocar de área |
| 2 | Planejador escondido em botão flutuante que disputava espaço com controles do mapa | Fluxo principal pouco descobrível |
| 3 | Painel sem estado recolhido acessível; alça só decorativa | Usuário não vê o mapa sem arrastar; leitor de tela não controla o painel |
| 4 | Selecionar uma viagem/trajeto mantinha o painel alto | Trajeto enquadrado numa faixa estreita |
| 5 | Tablet/desktop com painel central | Painel cobre o próprio trajeto |
| 6 | Voltar do Android fechava o app com busca, prévia ou linha abertas | Perda de contexto |
| 7 | Resumo do painel repetia o rótulo do dock ("Pontos") | Informação redundante |
| 8 | Favoritos e recentes repetiam o mesmo ponto e a dica offline aparecia duas vezes | Ruído |
| 9 | Spinners genéricos; skeleton animado com movimento reduzido | Sem identidade; não respeita acessibilidade |
| 10 | Seleção do dock com fundo + borda; sombras pesadas no vidro | Bordas duplas, excesso de peso visual |
| 11 | Setas de sentido escuras sobre traço escuro no tema escuro (viagem planejada) | Setas viravam "falhas" no traço |
| 12 | `animateTo` do painel com duração zero quando o movimento é reduzido | Painel não se movia (o `assert` do framework rejeita duração zero) |

## 3. Alternativas avaliadas

### Navegação

| | A. Manter 4 destinos fixos (com Meu ônibus) | B. **Pontos · Planejar · Linhas · Salvos + barra contextual de Meu ônibus** | C. 3 destinos + menu "Mais" |
|---|---|---|---|
| Descoberta do planejador | Ruim (botão flutuante) | Boa (destino próprio) | Média |
| Acompanhamento | Some ao trocar de área | Persiste em todas as áreas | Some |
| Estados vazios | Meu ônibus vazio quase sempre | Barra só existe quando há ônibus | — |
| Custo | Nenhum | Médio | Médio |

**Escolhida: B.** O acompanhamento é um estado, não um lugar: a `TrackingBar`
fica acima do dock em qualquer área enquanto há ônibus acompanhado, abre a ficha
completa e encerra com ×. Ajustes ficam no botão do topo. Sem o catálogo de
desenvolvimento (produção), Planejar não aparece e o dock tem 3 destinos.

### Painéis

| | A. Painel modal em tela cheia | B. **Folha com 3 alturas no celular + painel lateral em telas largas** | C. Folha única também em telas largas |
|---|---|---|---|
| Mapa visível | Não | Sim (recolhido mostra só resumo) | Sim |
| Tablet/desktop | Cobre tudo | Painel lateral, mapa enquadra à direita | Cobre trajeto |
| Recriação do MapLibre | — | Não (mapa sempre índice 0 da pilha) | Não |

**Escolhida: B.** Celular: recolhido (alça + resumo + "Mostrar painel"),
intermediário e expandido. Largura ≥ breakpoint: painel lateral de 360–440 px
(38% da largura) com o padding da câmera deslocado para a área visível.

## 4. Decisões e componentes alterados

- `home_chrome.dart` — `HomeTab {stop, plan, lines, saved, tracking, settings}`;
  `NavDock(showPlan:)`; seleção com ícone preenchido, peso 700 e fundo âmbar
  suave, sem borda; transição com `motion()`.
- `tracking_bar.dart` (novo) — barra compacta de Meu ônibus: placa da linha,
  "Ônibus N", destino, estado sem depender só de cor (ponto ao vivo × triângulo
  de posição antiga), abrir e encerrar com tooltips; semântica própria; texto
  limitado a 130% (a ficha completa acompanha a fonte do sistema).
- `stop_arrivals_page.dart` — geometria única (`_Geometry`) para folha e painel
  lateral; `_SheetTop` com alça acionável (toque, `onIncrease/onDecrease` da
  semântica), resumo contextual e botão Ver mapa/Mostrar painel; recolhimento
  automático ao escolher trajeto ou opção de viagem pelo usuário; `PopScope`
  que desfaz o contexto (prévia → busca → linha → ajustes → Pontos) antes de
  sair; espaço do teclado no fim da lista; salto direto sem animação quando o
  movimento é reduzido.
- `trip_planner_widgets.dart` — `setActive`, `clear`, `selectionByUser`; botão
  "Limpar" no lugar do fechar; botão flutuante removido.
- `saved_stops_widgets.dart` — Salvos = favoritos + recentes sem duplicar; dica
  offline uma vez.
- `busao_components.dart` — `motion()`; `BusaoLoader` (anel de 3 arcos
  acendendo em sequência em volta de um pino; estático com movimento reduzido;
  substitui todos os spinners); skeleton estático com movimento reduzido;
  sombra do vidro mais leve.
- `app_theme.dart` — `chipTheme` coerente com os tokens (âmbar suave na seleção).
- `busao_tokens.dart` — `Chrome.trackingBar`, `sidePanelMin/Max`.
- l10n pt/en/es — novas chaves; "ómnibus" → "autobús" em espanhol (uniforme).

## 5. Marcador do ônibus

Novo desenho vetorial (mesma API e tamanhos): carroceria arredondada,
retrovisores, faixa de destino em LED (âmbar claro no acompanhado), para-brisa
com reflexo, um bagageiro de teto e vidro traseiro; chevron de direção
arredondado. Acompanhado × secundário mantêm contraste por tamanho, cor e LED;
claro/escuro e posição antiga (esmaecida) seguem as regras anteriores de
rumo/animação. Sem marcas de operadora.

## 6. Estilos de linha do mapa (padronizados)

| Camada | Cor | Largura | Padrão | Outros sinais |
|---|---|---|---|---|
| Trajeto ida (ativo) | âmbar | 5 | contínuo | setas `›` no sentido |
| Trajeto volta (ativo) | cor do texto | 4,5 | tracejado 2/1,4 | setas `›` no sentido |
| Variantes/sentidos não ativos | neutro 30–35% | 3 | contínuo | — |
| Percurso oficial do ônibus acompanhado | neutro 55% | 4 | contínuo | — |
| Futuro estimado | âmbar | 5 | tracejado 1,2/1,2 | — |
| Rastro observado | âmbar ~50% | 2,5 | contínuo fino | — |
| Viagem planejada, 1º/3º ônibus | âmbar | 7 | contínuo | setas |
| Viagem planejada, 2º ônibus | cor do texto | 7 | contínuo | setas |
| Caminhada | neutro | 3 | pontilhado 0,4/1,6 | — |

Nenhuma camada se distingue só pela cor (largura e padrão também mudam).
Setas: clara com halo escuro no tema claro; escura com halo claro no tema
escuro (corrigido nesta revisão — antes ficavam ilegíveis no escuro). Pontos,
grupos (clusters) e controles mantidos; enquadramento usa sempre a área visível
(acima da folha no celular, à direita do painel lateral em telas largas).

## 7. Animações e micro-interações

- Todas as transições novas passam por `motion()` (respeita
  `disableAnimations`); folha e painel saltam direto com movimento reduzido.
- `BusaoLoader` em vez de spinner; estático com movimento reduzido; sem
  animações decorativas infinitas além do ponto "ao vivo" (indicador de estado).
- Seleção do dock anima fundo/peso em 200 ms.

## 8. Validação visual (pontual, local — capturas não versionadas)

Capturas reais do build web de desenvolvimento em `artifacts/` (ignorado pelo
Git, pois mostram dados CMTC):

- Celular 390×844 escuro: início, linhas, linha 350 com setas, painel recolhido.
- Celular 375×812 claro: início e linha 350 (setas legíveis).
- Tablet 768×1024 escuro: Salvos no painel lateral.
- Tablet 1024×1366 claro e desktop 1440×900: painel lateral, Planejar, mapa
  enquadrado à direita.
- Antes × depois comparados para início, linhas, linha aberta, tablet e desktop.

Problemas encontrados e corrigidos nas capturas: setas ilegíveis no escuro;
resumo do painel repetindo o dock; prévia repetindo "Ponto N"; transbordo da
barra de acompanhamento e do topo da folha a 200% de fonte.

## 9. Testes

- 589 testes Flutter passando; `flutter analyze` sem problemas.
- Novos/atualizados: dock com 3 destinos (produção) e 4 (dev); barra de Meu
  ônibus em todas as áreas, abrir/encerrar; sem acompanhamento não há barra;
  painel lateral em telas largas; Ver mapa/Mostrar painel/alça
  (recolhido ↔ intermediário ↔ expandido) preservando o conteúdo; movimento
  reduzido (painel sem animar, loader e skeleton estáticos); voltar do sistema
  desfaz o contexto; texto grande (200%); l10n pt/en/es; mapa criado uma única
  vez em todos os fluxos (`created == 1`).

## 10. Builds

| Build | Resultado | Dados CMTC (`check-no-official-catalog.sh`) |
|---|---|---|
| Web produção (release, Flutter 3.38.5) | OK, `main.dart.js` 3.799.586 bytes | **Ausentes** |
| Android produção (release APK) | OK, 86,1 MB | **Ausentes** |
| Android desenvolvimento (profile APK, `-t dev_catalog/main.dart`) | OK, 156,3 MB | Presentes (controle positivo: o verificador falha) |
| iOS produção (release, `--no-codesign`, Flutter master) | OK, 29,3 MB | **Ausentes** |
| Web desenvolvimento (profile) | OK (usado nas capturas) | Presentes |

## 11. O que ainda precisa de refinamento

- No desktop o painel do planejador repete o título "Planejar viagem" do
  cabeçalho.
- Largura das linhas fixa (não interpola com o zoom).
- Entrega visual completa (5 tamanhos, claro/escuro, galeria HTML + ZIP) fica
  para o final do desenvolvimento, como combinado.
- Validação em aparelho físico (gestos do sistema, teclado real, rotação).
