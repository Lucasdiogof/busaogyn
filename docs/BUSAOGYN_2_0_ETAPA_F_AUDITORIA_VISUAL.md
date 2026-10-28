# BusãoGyn 2.0 — Etapa F: auditoria visual final e capturas completas

- **Data:** 28/10/2026 · **Branch:** `feat/ux-redesign` (base `7eb1a4c`)
- **Escopo:** inventário de telas, capturas reais em 5 tamanhos e 2 temas, correção dos defeitos visuais comprovados, galeria e ZIP. Sem merge, sem deploy, sem envio às lojas.
- **Capturas:** todas reais, tiradas do app rodando. Nenhuma imagem foi gerada ou retocada. As que mostram o catálogo da CMTC ficam **só na máquina local** (`artifacts/`, fora do Git).

## 1. Onde estão os arquivos

| Item | Caminho (máquina local) |
| --- | --- |
| Galeria HTML navegável | `artifacts/final_visual/galeria.html` |
| Visão geral (miniaturas) | `artifacts/final_visual/VISAO_GERAL_MINIATURAS.png` |
| Índice das capturas | `artifacts/final_visual/INDICE.csv` e `INDICE.json` |
| Antes e depois | `artifacts/final_visual/_antes/`, `_depois/`, `ANTES_DEPOIS.json` (aba "Antes e depois" da galeria) |
| ZIP completo | `artifacts/busaogyn_etapa_f_visual.zip` |

`artifacts/` está no `.gitignore`: nada disso vai ao GitHub público.

## 2. Plataformas realmente usadas

| Plataforma | O que é | Uso |
| --- | --- | --- |
| **Web real** (Chromium, Playwright) | Builds Web reais servidos localmente: produção (sem catálogo) e desenvolvimento (com catálogo) | Matriz completa: 375×812, 390×844, 768×1024, 1024×1366, 1440×900, claro e escuro |
| **Simulador iOS** (iPhone 17, iOS 26.5) | App **nativo** de desenvolvimento, build Debug | Planejador com teclado real, viagem no mapa, linha, ajustes, privacidade, acompanhamento real da 016, tema escuro |
| Emulador Android | Usado na Etapa E (APK release); nesta etapa não houve captura nova | — |
| Aparelho físico | **Nenhum** | — |

As capturas Web **não** são apresentadas como capturas de iOS. As de iOS estão em `ios_sim/` e vêm do app nativo no simulador.

**Fontes dos dados** (coluna "fonte" no índice e na galeria):

- API real do BusãoGyn: chegadas e posições ao vivo.
- Catálogo local de desenvolvimento (CMTC, restrito).
- Dados simulados, sempre identificados:
  - ônibus fictício 90016 andando sobre a geometria oficial da 016;
  - localização do navegador na Praça Cívica;
  - erro 500 da API;
  - resposta lenta;
  - sem internet.

## 3. Inventário das telas e estados

| Funcionalidade | Build | Capturada em |
| --- | --- | --- |
| Inicialização / mapa principal | Prod e dev | Web (5 tamanhos × 2 temas), iOS |
| Pesquisa de pontos (código, rua, bairro) | Dev (texto); prod (código) | Web |
| Detalhes do ponto (cadastro) | Dev | Web |
| Previsões de chegada | Prod e dev, API real | Web, iOS |
| Painel intermediário, expandido, recolhido ("Ver mapa") | Celular | Web 375/390, iOS |
| Painel lateral | Tablet e desktop | Web 768, 1024 e 1440 |
| Favoritos, recentes, Salvos vazio | Prod e dev | Web |
| Catálogo de linhas e pesquisa de linhas | Dev | Web, iOS |
| Linha: ida e volta no mapa, variantes | Dev | Web, iOS |
| Sequência estimada de paradas | Dev | Web |
| Horários programados | Dev | Web |
| Estações e terminais (sugestões "Estacao Civica", "T. Cruzeiro · terminal (inferido)") | Dev | Web, iOS |
| Planejador: vazio, origem, destino, sugestões | Dev | Web, iOS (com teclado) |
| Rotas diretas e com baldeação; viagem no mapa | Dev | iOS |
| Viagens salvas ("Salvar viagem") | Dev | iOS |
| Acompanhamento real (ônibus da API) | Prod e dev | Web, iOS |
| Barra contextual de acompanhamento em outra aba | Dev | Web |
| Rastro, percurso futuro estimado, próximos pontos (016) | Dev | Web (simulado, 3 tamanhos × 2 temas, 2 zooms) e iOS (ônibus real) |
| Compartilhar | Prod | Etapa E (Safari iOS: folha nativa; desktop: cópia/aviso) |
| Ajustes e Privacidade | Prod e dev | Web, iOS (claro e escuro) |
| Perto de mim: localização simulada e permissão negada | Dev | Web |
| Carregando (BusaoLoader) | Prod | Web |
| Sem internet, falha 500 da API, código inexistente | Prod | Web |
| Idiomas en/es | Prod | Web |

## 4. Problemas encontrados e corrigidos

Cada correção tem teste de regressão. Os marcados com "mutação" foram conferidos assim: sem a correção, o teste falha.

| # | Problema | Onde | Correção | Evidência |
| --- | --- | --- | --- | --- |
| F-1 | Leitor de tela: o campo **Destino** do planejador era anunciado com o aviso do painel e o cartão da origem no nome | Planejador | O aviso e o cartão da origem ganham contêiner de acessibilidade próprio. Envolver o próprio campo quebrava a digitação no Web, então essa versão foi descartada | Teste (falha antes); DOM do Web: campo "Destino", grupo "Origem" |
| F-2 | Acompanhamento com percurso oficial confirmado: o cartão dizia que **"o mapa não mostra percurso futuro"** enquanto o mapa mostrava | Meu ônibus | O aviso acompanha o que o mapa desenha (pt/en/es). Sem confirmação, continua o texto antigo | Teste; antes/depois |
| F-3 | Tema claro: trajeto âmbar sobre mapa claro com contraste < 3:1 | Linha, planejador | Contorno âmbar escuro (`accentText`) por baixo da ida e do 1º trecho da viagem | Teste de ordem e cor das camadas; antes/depois |
| F-4 | **iOS:** botão de atribuição do mapa (i) no topo, sob a barra de status e a bateria | Mapa (iOS) | O MapLibre iOS já soma o inset da câmera; o app não soma de novo | Teste da margem por plataforma; antes/depois no simulador |
| F-5 | **iOS:** o teclado cobria o campo do planejador e as sugestões | Planejador (celular) | O painel termina acima do teclado e vai à altura máxima. Ao digitar, o campo sobe e as sugestões ficam à vista | 2 testes (mutação); antes/depois no simulador |
| F-6 | **iOS:** depois de "Ver no mapa", o mapa parava num pedaço da viagem | Planejador | A troca de inset interrompia a animação. Se o painel muda em até 3 s depois de um enquadramento, ele é refeito; toque no mapa cancela. Tocar de novo em "Ver no mapa" reenquadra | 2 testes (mutação); antes/depois |
| F-7 | Painel recolhido mostrava um pedaço cortado de cartão, sem alça nem resumo | Painel (celular) | Ao recolher, a lista volta ao topo | Teste (mutação); antes/depois |
| F-8 | Ônibus pequeno no mapa (pedido do usuário) | Mapa | Acompanhado +40% (0,30 → 0,42), secundários +30% (0,20 → 0,26), halo 30 → 40 | Simulador iOS com ônibus real |

**Observado e não alterado (documentado):**

- O rótulo flutuante "Origem" fica muito perto da borda superior do painel quando o campo sobe com o teclado (iOS). É detalhe, ainda legível.
- `AlertDialog` (privacidade, limpar histórico) usa o estilo Material também no iOS. É aceito pela App Store e consistente entre plataformas.

## 5. Auditoria especial do acompanhamento (linha 016)

- **Veículo citado no pedido:** não estava em circulação durante a etapa (consultas aos pontos 77 e 6012 da 016).
- **Caso real equivalente:** outro ônibus em circulação na 016, com destino "ST AEROPORTO", o mesmo trecho do meio da denominação que causava o problema. Ele foi acompanhado no app nativo de desenvolvimento, no simulador iOS, com a API real e o catálogo local:
  - parado, o app não desenha percurso. É a regra conservadora: precisa andar 20 m;
  - depois de andar cerca de 240 m, o **percurso oficial (cinza)** e o **trecho à frente (âmbar tracejado)** aparecem sobre a avenida, o rastro observado continua, e o cartão diz que o trecho à frente é estimado e sem horário por ponto;
  - capturas: `ios_sim/iphone17_402x874/claro/11_016_real_*` e `12_016_real_*`.
- **Cenário reproduzível (SIMULADO):**
  - ônibus fictício 90016, com o itinerário e o destino reais da RMTC, andando a cada 15 s sobre a geometria oficial da ida (`sim016.json`);
  - capturado no Web em 390×844, 768×1024 e 1440×900, claro e escuro;
  - confirma em ~30 s e mostra posição, rastro, percurso futuro, 16 próximos pontos estimados, painel recolhido e expandido, zoom aproximado e afastado;
  - o traçado acompanha as ruas nos dois zooms, e as setas e o tracejado continuam legíveis no tema escuro.
- **Ambiguidade:** as regras não foram relaxadas. Com ida e volta igualmente coerentes, o app não desenha nada.

## 6. Auditoria de consistência

| Item | Resultado |
| --- | --- |
| Design system (tokens, GlassSurface, raios, tipografia Geist) | Seguido em todas as telas capturadas |
| Spinner genérico | Nenhum (`CircularProgressIndicator` não aparece no código); carregamento com `BusaoLoader` |
| Bottom sheets | Mesmo comportamento nas abas: 3 alturas, "Ver mapa"/"Mostrar painel"; corrigidos F-5 e F-7 |
| Mapa visível no planejamento | Sim: faixa de mapa acima do painel e viagem enquadrada ao escolher (F-6) |
| Acompanhamento acessível durante a navegação | Barra contextual nas outras abas (capturada) |
| Tema claro legível | Trajeto com contorno (F-3) |
| Tema escuro | Setas e tracejado visíveis; privacidade legível |
| pt/en/es | Capturas em en e es (chegadas, ajustes): sem corte |
| Estados vazios | Explicam o próximo passo (Salvos, busca, Perto de mim sem permissão) |
| Feedback de botões | Favoritar, compartilhar, copiar link: aviso na tela |

## 7. Testes e builds

Os resultados finais estão no checkpoint (`docs/BUSAOGYN_2_0_CHECKPOINT_CONTINUIDADE.md`) e no fim deste documento.

## 8. Limitações

- **Web e iOS:**
  - automatizado no Chromium: o navegador perde as primeiras teclas no campo do planejador (o Flutter Web liga o campo de edição depois do foco);
  - por isso, os resultados do planejador e a viagem com baldeação foram capturados no **simulador iOS**, com teclado real, e não no Web;
  - no Web automatizado o planejador foi capturado até a origem escolhida e as sugestões.
- **Sem aparelho físico:**
  - VoiceOver e TalkBack não foram usados por uma pessoa;
  - o Android não ganhou capturas novas nesta etapa (Etapa E: APK release no emulador).
- **Tablet nativo:** o iPad foi validado na Etapa E. Nesta etapa os tamanhos de tablet são do Web.
- **Pré-visualizações das lojas:** as capturas para a App Store precisam ser refeitas no tamanho exigido (iPhone 6.9" e iPad 13") a partir do build iOS, e só da **versão pública** (sem catálogo).

## 9. Pendências antes da publicação

1. Autorizar o merge na `main`, o deploy do Web e o deploy do Worker (lote do ADR-0006).
2. Capturas de loja da versão pública (sem catálogo) nos tamanhos exigidos, a partir dos builds nativos.
3. Teste em aparelho físico e com leitores de tela.
4. Licença da CMTC para a versão completa (pedido técnico preparado na Etapa E, não enviado).
