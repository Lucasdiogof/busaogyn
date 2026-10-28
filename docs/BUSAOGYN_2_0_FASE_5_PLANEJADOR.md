# BusãoGyn 2.0 — Fase 5: planejador de viagens (desenvolvimento)

- **Data:** 28/10/2026
- **Branch:** `feat/cmtc-catalogo-dev` (sem merge na `main`, sem deploy)
- **Status:** implementado e funcionando **só no build de desenvolvimento** (`dev_catalog/main.dart`). Em produção não há catálogo, logo o botão "Planejar viagem" não aparece e o planejador não tem dados (teste negativo + verificação de artefatos, §10).
- **Base de decisão:** [ADR‑0002](adr/0002-dados-confiaveis-e-nao-inferencia.md) (produção) e [ADR‑0005](adr/0005-sequencia-estimada-so-em-desenvolvimento.md) (exceção limitada ao desenvolvimento). Nenhuma regra nova de inferência foi criada: o planejador só usa a sequência já classificada na Fase 4.

---

## 1. O que o passageiro faz

1. Aba **Pontos** → **Planejar viagem** (sem aba nova).
2. **Origem** e **Destino**: busca local por código, endereço/logradouro, bairro ou município (a mesma busca da Fase 2; nada sai do aparelho), ou **Escolher no mapa** (o próximo toque num ponto preenche o campo em vez de abrir o ponto). O mapa vai até o ponto escolhido. Sem GPS do usuário, sem geocodificação remota.
3. **Inverter** troca origem e destino. **Buscar viagens**.
4. Alternativas (até 6): selo **Confiável**/**Estimada**, "N ônibus · direto/1 baldeação", embarque, linha (placa) + variante + sentido + nº de paradas + km pelo trajeto, baldeação (e caminhada, se houver), desembarque, avisos do que é inferido.
5. **Ver no mapa** (ou tocar no cartão): a viagem é desenhada e enquadrada; os pontos gerais saem do mapa. Toque num ponto da viagem no mapa abre o ponto.
6. Mensagens claras para: origem = destino, ponto inexistente, origem/destino fora do planejador ("fora do planejador" já aparece na busca), e "nenhuma viagem com evidência suficiente" (dizendo que isso não prova que não existe ônibus).
7. **Offline**: tudo vem do catálogo do aparelho (teste com repositório sem rede). Chegadas e posições continuam online e separadas.

**Sem horário nem tempo de viagem** (§6): só itinerário, conexões e extensão em km medida no trajeto oficial.

---

## 2. Arquitetura

```text
catálogo dev (payload, fora do Git)
  └─ sequences (Fase 4) + streetRho (novo)        export_catalog.py
TransitCatalog ─► TripPlanner (domain/trip_planner.dart)        ← grafo + busca
                     TripPlan / TripOption / TripLeg / TripCaution
TripPlannerController (ChangeNotifier) ─► TripPlannerPanel      ← aba Pontos
       │ selectedOption
       ▼
NetworkOverlayBuilder.build(plan:) ─► planCollection ─► source busao-net-plan
       ▼
TransitMap (_syncNetwork: só o que mudou)  — mesma instância do MapLibre
```

- **Sem backend, sem serviço pago, API inalterada.**
- Arquivos novos: `domain/trip_planner.dart`, `presentation/trip_planner_widgets.dart`, `test/features/catalog/trip_planner_test.dart`, `test/dev_catalog/planner_metrics_test.dart`.
- Alterados: `route_geometry.dart` (`slice`), `stop_sequence.dart` + `catalog_codec.dart` (`streetRho`), `network_geojson.dart` (`planCollection`), `network_map_layers.dart` (camadas da viagem), `tracked_vehicle_map.dart` (sync/toque), `stop_arrivals_page.dart` (integração, enquadramento), ARBs (37 chaves), `export_catalog.py` (`streetRho`), checker, testes de UI.

---

## 3. Modelo de grafo

| Elemento | No modelo |
|---|---|
| Nó | ponto do cadastro presente em alguma sequência `estimated` |
| Aresta | par de paradas consecutivas de um trajeto (variante + sentido), na ordem estimada |
| Serviço | trajeto do KMZ (`CatalogShape`: linha, variante, sentido) |
| Sentido | só existe no trajeto: embarque no índice *i*, desembarque em *j > i* do **mesmo** trajeto |
| Passagem repetida | o ponto aparece duas vezes no trajeto; cada passagem é um índice próprio |
| Baldeação | (a) mesmo ponto, entre trajetos de **linhas diferentes**; (b) a pé até **150 m em linha reta** entre pontos do grafo — sempre "estimada" |
| Fora do grafo | trajetos `partial`/`none` (sem ordem), pontos ambíguos, estações do Eixo/BRT sem sequência |

Regras de não‑invenção: pertencer ao cadastro de uma linha **não** gera aresta; proximidade sozinha **não** gera baldeação (exige trajeto utilizável dos dois lados e vira aviso); nenhuma ligação fictícia; nenhuma ordem para trajetos ambíguos.

**Restrições de embarque/desembarque:** os dados não trazem paradas só de embarque ou só de desembarque; não se assume nenhuma. Também não há marcação de terminais fechados/integração tarifária no catálogo — a baldeação no mesmo ponto não significa integração tarifária.

## 4. Algoritmo

Busca exaustiva **limitada** (a rede utilizável é pequena: 208 trajetos, 3.331 nós):

1. Índice ponto → lista de (trajeto, índice) — montado em ~2 ms no primeiro uso.
2. **Diretas:** para cada ocorrência da origem (*s*, *i*), o menor *j > i* do destino no mesmo trajeto.
3. **Uma baldeação:** para cada ocorrência da origem e cada parada *k > i* do 1º trajeto (até chegar ao destino), candidatos de embarque = o mesmo ponto + pontos a ≤ 150 m; para cada trajeto de outra linha que passa ali (índice *m*), o menor *j > m* do destino.
4. Linhas que já resolvem sem baldeação não geram alternativas com baldeação (dominadas).
5. **Deduplicação:** uma alternativa por sequência de linhas (`'003'`, `'603>520'`): variantes da mesma linha e pontos de baldeação equivalentes no mesmo corredor viram uma só (a melhor pelo critério abaixo).
6. **Ordenação:** confiável → menos baldeações → menos caminhada → menor extensão → menos pontos incertos. Até 6 alternativas.
7. **Limite:** 200.000 combinações por busca; se atingido, a busca para e avisa (não ocorreu em nenhuma das 1.000 buscas da amostra).

Sem ciclos possíveis (índices sempre crescentes, no máximo 2 trechos, nunca a mesma linha duas vezes).

## 5. Regras de confiabilidade

| Classe | Critério |
|---|---|
| **Confiável** | todo trecho em trajeto `estimated` **com ordem conferida contra os logradouros oficiais** (Spearman ≥ 0,5 — 80 dos 208 trajetos), embarque e desembarque de confiança alta, sem passagem repetida nesses pontos, e baldeação (se houver) **no mesmo ponto** |
| **Estimada** | plausível, mas com pelo menos um aviso: ordem não conferida com logradouros; ponto de posição incerta; passagem repetida; baldeação a pé (travessia, calçada e acessibilidade não verificadas) |
| **Indisponível** | sem evidência: não aparece como sugestão; a tela explica o motivo |

Importante: mesmo "Confiável" usa a sequência **estimada pela geometria oficial** (não existe sequência oficial da CMTC); o selo significa "a melhor evidência disponível concorda", e o rodapé de cada busca diz isso. **Nenhuma conexão é declarada acessível.**

## 6. Horários e tempo de viagem

Nada de horário, duração, chegada ou conexão temporal: os quadros não têm vigência confirmada (Fase 4), não há horário por ponto e não há tempo de viagem confiável. A extensão em km é medida no trajeto oficial entre as posições estimadas dos pontos e é rotulada como tal; não é convertida em tempo.

## 7. Camadas do mapa

Source `busao-net-plan` (só existe com catálogo; recriada a cada estilo como as demais):

| Camada | Desenho |
|---|---|
| `plan-leg1` | 1º ônibus: âmbar, 7 px |
| `plan-leg2` | 2º ônibus: cor do texto (claro no escuro, escuro no claro), 7 px |
| `plan-walk` | caminhada: pontilhado cinza |
| `plan-arrows` | setas `›` ao longo dos trechos (sentido), branco com halo escuro |
| `plan-points` | origem (anel), baldeação (anel âmbar), destino (âmbar cheio); tocáveis |

Distinto do trajeto de linha (ida contínua/volta tracejada, 5 px) e do rastreamento real (rastro âmbar fino, oficial cinza, futuro tracejado). Os pontos gerais saem enquanto há viagem; o trajeto de linha aberto é fechado. Mapa preservado: mesma instância ao abrir, trocar alternativas e fechar (teste `_CountingMap.created == 1`). Enquadramento depois de o painel se acomodar (celular: folha no meio; tablet: painel limitado à metade de baixo).

---

## 8. Cobertura medida (catálogo real, out/2026)

**Grafo**

| Item | Valor |
|---|---|
| Trajetos elegíveis (sequência `estimated`) | **208** de 912 (80 com ordem conferida por logradouros) |
| Pontos no grafo | **3.331** de 7.480 |
| Conexões (arestas) | **6.708** |
| Linhas utilizáveis | **103** de 313 |
| Pontos de baldeação no mesmo ponto (2+ linhas) | **892** |
| Pares de pontos para baldeação a pé (≤ 150 m) | **1.350** (todos "estimada") |
| Pares origem→destino com rota **direta** | **136.538** (63.060 deles num único trajeto conferido, com pontos de confiança alta) |

**Amostras reproduzíveis** (`flutter test test/dev_catalog/planner_metrics_test.dart`, semente 42, 500 pares cada):

| Amostra | Com rota | Detalhe |
|---|---|---|
| A — pares aleatórios entre pontos **do grafo** | **30 (6,0 %)** | confiável direta 4 · estimada direta 6 · confiável c/ baldeação 2 · estimada c/ baldeação 18 · sem rota 470 |
| B — pares aleatórios entre **todos** os pontos | **3 (0,6 %)** | origem fora 263 · destino fora 127 · sem rota 107 · estimada 3 |

Estas amostras **não** são a cobertura da rede para viagens reais (pares aleatórios ligam pontos de cidades diferentes, que muitas vezes exigiriam 2+ baldeações). O que limita os resultados:
1. só 23 % dos trajetos têm ordem utilizável (Fase 4); 77 % ficam fora por não ter ordem confiável;
2. máximo de uma baldeação;
3. baldeação apenas no mesmo ponto ou a ≤ 150 m;
4. Eixo/BRT (estações 40000+) não estão no cadastro de pontos → sem sequência.

## 9. Desempenho (catálogo real, VM de teste no Mac)

| Medida | Valor |
|---|---|
| Decodificação do catálogo | 90–150 ms (já existia; nada novo no início do app) |
| Montagem do grafo (1º uso do planejador) | **~2 ms** |
| Busca (1.000 buscas) | mediana **0,01 ms**, p95 **0,14 ms**, máx **2,9 ms**; nenhuma truncada |
| Rede sintética de estresse (220 trajetos × 32 paradas, 300 buscas) | < 3 s no total (teste) |
| Payload extra | +4 KB (`streetRho`) |
| Build de produção | sem mudança de tamanho (sem dados) |

Tudo roda na thread principal sem bloqueio perceptível; não foi necessário isolate nem índice mais complexo (medido antes de decidir). No Web dev a busca respondeu instantaneamente nas validações visuais.

---

## 10. Testes

| Suíte | Resultado |
|---|---|
| Flutter (todos, nesta máquina) | **581/581** (inclui as 2 métricas com dados reais; no CI elas são puladas por falta do catálogo) |
| `trip_planner_test.dart` (rede sintética) | origem = destino; ponto inexistente; sem cobertura; direta no sentido certo; sentido invertido (só a volta); variantes da mesma linha deduplicadas; passagem repetida (embarca na passagem certa + aviso); baldeação no mesmo ponto confiável; ordenação confiável > estimada; baldeação a pé estimada com aviso; ponto a 300 m não conecta; sequência `partial` não conecta; desempenho |
| `planner_metrics_test.dart` (catálogo real, local) | exemplo real escolhido do catálogo: direta encontrada no sentido certo e nunca no contrário; cobertura e tempos |
| UI (`catalog_map_ui_test.dart`) | busca local + escolha no mapa; baldeação; camadas (leg1, leg2, origem, baldeação, destino); pontos gerais escondidos; enquadramento; km no formato do idioma; inverter; sem rota; mesmo ponto; fechar sem recriar o mapa; offline; sem overflow 320 px/100 %, 390 px/200 %, 1024 px/130 % |
| Produção (`catalog_ui_test.dart`) | sem catálogo, não há "Planejar viagem" |
| Pipeline Python | 44/44 |
| `flutter analyze` / `dart format` | limpos |
| Visual (Web dev) | celular escuro (baldeação 298→5990, troca de alternativa) e tablet claro (direta 6578→9142); problemas achados e corrigidos: km com ponto em pt, mapa não ia até o ponto escolhido, painel do tablet cobrindo a viagem, setas pouco visíveis no tema claro |

Os exemplos reais usados na validação visual não estão no código (escolhidos em tempo de execução).

### Builds

| Build | Resultado | Dados CMTC |
|---|---|---|
| Web produção (release) | OK, `main.dart.js` 3.788.828 bytes | **ausentes** (verificador OK) — o código da tela existe, mas sem catálogo ela nunca aparece |
| Web desenvolvimento (profile) | OK | presentes (controle positivo) |
| Android produção (release APK) | OK, 86,0 MB (igual às fases anteriores) | **ausentes** |
| Android desenvolvimento (profile APK) | OK, 155,8 MB | presentes (controle positivo) |
| iOS produção (release, `--no-codesign`, Flutter master) | OK, 29,2 MB | **ausentes** |
| iOS desenvolvimento (profile) | OK, 42,8 MB | presentes (controle positivo) |

## 11. Limitações e riscos

1. **Licença** — continua pendente; nada pode ir para produção.
2. **Cobertura baixa** — consequência direta de não haver sequência oficial; o planejador prefere dizer "sem evidência" a inventar.
3. **"Confiável" ≠ oficial** — significa evidência geométrica + logradouros concordando; a CMTC não validou.
4. **Baldeações** — sem dados de travessia, calçada, acessibilidade, integração tarifária ou terminal; a pé sempre "estimada".
5. **Sem tempo** — sem horário vigente nem tempo de viagem; frequência e espera desconhecidas.
6. **Escolha por ponto** — origem/destino precisam ser pontos de ônibus (sem GPS nem endereço livre).
7. **Geometria** — o trecho desenhado usa o trajeto simplificado (3 m) entre posições estimadas dos pontos (calculadas no trajeto original); diferenças de poucos metros.
8. **Web** — a roda do mouse sobre o painel às vezes também move o mapa (comportamento anterior a esta fase).

## 12. Próxima fase recomendada

1. **Obter da CMTC** a sequência oficial de paradas por variante/sentido (e a licença): com ela, a cobertura do planejador sobe de 23 % para potencialmente todos os trajetos, e "confiável" passa a significar "oficial".
2. Enquanto isso, **aumentar a cobertura com evidência**: conferir manualmente a ordem dos trajetos `partial` das linhas mais usadas (amostra), e usar as estações do Eixo/BRT do KMZ de pontos.
3. Depois disso: acesso a pé à origem/destino (pontos a ≤ 300 m, sinalizado) e até duas baldeações, medindo antes o custo.
