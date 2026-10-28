# BusãoGyn 2.0 — Fase 4: horários oficiais, sequência de paradas e validação do tracking

- **Data:** 28/10/2026
- **Branch:** `feat/cmtc-catalogo-dev` (sem merge na `main`, sem deploy)
- **Status:** implementado **só no build de desenvolvimento** (`dev_catalog/main.dart`). Produção continua sem catálogo, horários, sequências e próximos pontos (verificado nos artefatos de Web, Android e iOS, §9).
- **Decisão arquitetural:** [ADR‑0005](adr/0005-sequencia-estimada-so-em-desenvolvimento.md) — exceção explícita e limitada ao ADR‑0002 para o ambiente interno. A regra de produção não mudou.
- **Restrição permanente:** licença/redistribuição dos dados CMTC pendente; nada disto pode ir para produção.

---

## 1. Funcionalidades implementadas

| Área | O que o passageiro vê (catálogo de desenvolvimento) | Situação |
|---|---|---|
| **Linhas → Horários programados** | Quadro da linha com Dias úteis / Sábado / Domingo e feriado (abre no tipo de dia de hoje), partidas em ordem cronológica, filtro por código da planilha (variantes), marcas `+1` (após a meia-noite), `MI`/`MF` (meia viagem), `×2` (repetida na planilha), data de referência, OSO e planilha de origem | Funciona; validado em celular, tablet, tema claro e escuro |
| Validade dos horários | Faixa explícita: *vigência confirmada* / *referência recente, vigência não confirmada* / *referência antiga* (escondido até "Ver mesmo assim") / *indisponível* | Funciona; nenhum quadro está confirmado hoje |
| **Linhas → Paradas estimadas** | Para o trajeto (variante + sentido) aberto no mapa: lista numerada **rotulada como estimativa** quando a confiança permite; senão "Pontos perto deste trajeto" **sem ordem**; ou aviso de que não há pontos associados. Pontos de posição incerta e passagens repetidas são marcados; ambíguos ficam de fora e são contados | Funciona |
| **Pontos → No itinerário (estimado)** | No detalhe do ponto: "350‑1 · Ida — parada 7 de 11"; toque abre a linha com o trajeto enquadrado. Só aparece com sequência estimada confiável; nenhum horário de passagem | Funciona |
| Mapa | Anéis dos pontos da linha agora são **tocáveis** (com trajeto aberto, os pontos gerais saem do mapa) | Funciona (Web) |
| **Meu ônibus → Próximos pontos (estimado)** | Só com associação confirmada **e** sequência confiável: próximo ponto em destaque (se de confiança alta), até 5 pontos seguintes, quantos faltam até o fim. Sem previsão de chegada por ponto | Funciona em testes; **experimental**: não observado com ônibus real (§6) |
| Associação ônibus → trajeto | Agora com continuidade ao longo do rastro (retornos, laços, geometria sinuosa) e detecção de salto | Funciona em testes e numa gravação real (§6) |
| Avaliação com veículos reais | `data/cmtc/pipeline/match_eval.py`: amostra pequena, limites fixos, pseudônimos, local | Pronto; execução real sem ônibus em circulação (§6) |
| Offline | Linhas, pontos, busca, trajetos, horários, sequência estimada e dados estáticos de favoritos vêm do catálogo embutido; chegadas, posição e tracking continuam dependendo de internet | Teste "offline" com repositório sem rede |
| Textos | 40 chaves novas em pt/en/es (todas as formas plurais com `=0`) | `l10n_test` |

---

## 2. Modelos e arquitetura

```text
raw/ (fora do Git)
 ├─ Planilhas Horárias … 28-10-2026/*.xlsx ─ schedules.parse_sheet ─ timetables.build_timetables
 ├─ LINHAS RMTC.kmz + cadastros ──────────── stop_sequences.sequence_shapes
 └─                                             │
export_catalog.py ──► app/dev_catalog/cmtc_catalog_payload.g.dart (fora do Git)
                        tabelas novas: timetables, trips, sequences (+ version.sequenceMethod)
                                                 │
app: catalog_codec ─► TransitCatalog.timetablesOf / tripsOf / sequenceOf / itineraryOf
     domain/timetable.dart        (validade, tipo de dia, partidas, duplicidade, +1)
     domain/stop_sequence.dart    (status, níveis, nextStopsFor)
     domain/route_match.dart      (continuidade, salto, trecho repetido)
     presentation/catalog_schedule_widgets.dart
        LineTimetableSection · ShapeStopsSection · StopItinerary · NextStopsCard
```

- **Sem backend novo**, sem Supabase, sem serviço pago; Worker e API inalterados.
- Mesmo padrão das fases 2–3: tabelas `fields/rows`, decodificação tolerante (linha malformada é descartada; validade/status desconhecidos viram o nível **mais fraco**).
- Regras do app espelhadas em Python (`cmtc/tracking.py`) para a avaliação real medir exatamente o que o app faria; os testes dos dois lados usam os mesmos cenários.
- Mapa: instância única preservada (teste `_CountingMap.created == 1`).

---

## 3. Origem e validade dos horários

**Fonte:** 29 arquivos "Planilhas Horárias por Terminal da RMTC" (entregues em 28/10/2026), 303 abas no gabarito OSO Anexo II.

| Item | Valor |
|---|---|
| Abas | 303 (302 visíveis + 1 oculta) |
| Partidas nas abas visíveis | **17.448** (+17 na aba oculta, não exibidas) |
| Após a meia-noite (`24:xx`) | 163 — exibidas como `00:xx +1` |
| Duplicidades exatas | 5 — mantidas e marcadas (`×2`), exibidas uma vez |
| Fora de ordem na planilha | 6 — mantidas; a tela ordena por horário |
| Partidas cujo código não existe no cadastro | 17 visíveis (`112‑3`, `601‑3`, `020‑3`, `733‑2`) — exibidas como "(sem cadastro)", sem variante associada |
| Conflito (mesma linha em abas diferentes) | 0 (detecção implementada e testada) |

**Classes de validade** (`cmtc/timetables.py: classify_validity`):

| Classe | Critério | Abas | Partidas | Na tela |
|---|---|---|---|---|
| Vigência confirmada | aba registrada em `CONFIRMED_SHEETS` com o documento da CMTC | **0** | 0 | faixa verde |
| Referência recente, vigência não confirmada | data da aba no ano da entrega (2026) e não posterior a ela | 209 | 12.973 | faixa de aviso, sempre visível |
| Referência antiga | data da aba anterior a 2026 (2022: 4, 2024: 25, 2025: 64) | 93 | 4.475 | **oculto** até "Ver mesmo assim", com aviso permanente |
| Inconsistente / insuficiente | sem data, data futura, sem partidas, aba oculta ou conflito | 1 | 17 | não exibido |

Regras mantidas:
- Horário de **partida** nunca vira horário de passagem em ponto intermediário (nada é calculado).
- **Sentido e local de partida não são atribuídos**: a planilha não os informa. O nome do arquivo ("Araguaia", "Diretas") aparece como *planilha de origem*, não como local de partida.
- **Feriados:** a planilha traz um só quadro "DOMINGO" e os dados operacionais dizem "Domingos e feriados"; não há calendário de feriados nem exceções nos arquivos. O app abre no tipo de dia da data (feriado em dia útil abre "Dias úteis"; o passageiro escolhe "Domingo e feriado").
- Horários programados ficam separados das previsões da API (nenhuma mistura; a nota diz que não são tempo real).
- **Dados pessoais:** as observações das planilhas trazem o nome de quem assina; não são exportadas. Operadoras também não.

---

## 4. Critérios de classificação das sequências

Método `projecao-kmz-v2` (`cmtc/stop_sequences.py`), **estimativa por geometria, não sequência oficial**:

1. Pontos do cadastro ligados à linha (base) são projetados sobre cada trajeto do KMZ (a ordem dos vértices segue o sentido de circulação — validado na Fase 1 em 508 de 511 trajetos testáveis).
2. Distância > 25 m → **não associado** ao trajeto. Confiança < 0,5 → **ambíguo**.
3. Ponto perto da ida e da volta da mesma variante: sentido decidido por `assign_direction` (só perto de um; logradouro só na lista oficial de um sentido; diferença ≥ 10 m). Sem desempate → **ambíguo**; atribuído ao outro sentido → sai deste trajeto.
4. Nível por ponto: **alta** (confiança ≥ 0,9, uma passagem, sentido inequívoco) ou **intermediária** (o resto). **Confirmada por relação oficial**: não existe fonte; nunca preenchida.
5. Passagens repetidas (retorno, laço) geram **uma entrada por passagem**, ambas intermediárias.
6. Status do trajeto:
   - `estimated` (ordem exibida como estimativa): ≥ 5 pontos, ≥ 70 % de confiança alta, ≤ 15 % ambíguos e, quando houver ≥ 6 pontos com logradouro único na lista oficial do sentido, Spearman ≥ 0,5 com essa ordem;
   - `partial`: pontos sem ordem;
   - `none`: nenhum ponto.

**Cobertura (out/2026):**

| Indicador | Valor |
|---|---|
| Trajetos com sentido | 910 de 912 |
| `estimated` | **208 (22,9 %)** — 6.916 entradas ordenadas; 61 deles são a ida da variante principal |
| `partial` | 666 (73,2 %) |
| `none` | 36 (4,0 %) — Eixo/BRT/expressas cujas paradas (estações 40000+) não estão no cadastro de pontos |
| Entradas associadas (todos os trajetos) | 21.074: alta 12.387 · intermediária 8.687 · passagens repetidas 686 |
| Ambíguos mantidos fora da ordem | 9.544 associações ponto‑trajeto |
| Atribuídos ao sentido oposto | 7.463 |
| Trajetos com Spearman calculável / abaixo de 0,5 | 331 / 1 |
| Circulares (início = fim) | 0 (os circulares do KMZ vêm divididos em ida/volta) |

O principal motivo de `partial` é a proporção de pontos de confiança alta (vias de mão dupla em que ida e volta passam a menos de 25 m uma da outra). É o comportamento desejado: não se força ordem.

---

## 5. Regras de identificação do próximo ponto

Só com **todas** as condições (senão, o tracking tradicional continua igual):

1. associação **confirmada**: `routeName` = denominação de exatamente uma variante; destino aponta um sentido; trajeto único; posição atual **não vencida** e acompanhamento ativo;
2. **projeção coerente** ao longo do rastro observado (app: até 20 posições reais):
   - cada amostra a até 50 m do trajeto;
   - continuidade: cada amostra fica na passagem mais próxima **à frente** da anterior (recuo tolerado: 15 m);
   - avanço entre amostras ≤ 1,5 × deslocamento em linha reta + 300 m (senão **salto**);
   - várias cadeias coerentes: aceitas só se terminam a até 50 m umas das outras (geometria sinuosa); senão **trecho repetido** (ambíguo);
   - avanço total ≥ 20 m (senão **pendente**: ônibus parado ou recém-iniciado);
3. sequência do trajeto com status `estimated`.

Próximos pontos = entradas com `posição + 40 m > posição do ônibus` (um ponto só conta como passado com o ônibus 40 m além dele: passar perto não basta). O primeiro só ganha destaque "Próximo" se for de confiança alta; senão a lista aparece sem destaque, com o aviso. Fim do trajeto → "Ônibus no fim do trajeto". **Nunca** há horário de chegada por ponto.

Troca de itinerário: `routeName`/destino novos refazem a associação; o rastro anterior projetado no trajeto novo recua ou salta → ambíguo, até haver avanço coerente. GPS vencido: o app passa posição nula → indisponível.

---

## 6. Resultado das validações com veículos reais

**Mecanismo** (`python3 -I pipeline/match_eval.py`): até 3 pontos (padrão: os 3 do cadastro com mais linhas) × 1 consulta de chegadas; até 4 veículos ao vivo (um por linha) × até 6 posições com intervalo ≥ 20 s; ≤ 27 requisições à API BusãoGyn (com cache), execução única. Número do veículo vira `v1…` na coleta; nada sai da máquina; `reports/` é ignorado pelo Git; arquivos com mais de 7 dias são apagados a cada execução; o resumo `.md` não tem posições nem identificadores. `--reanalyze` refaz a análise sem rede.

| Execução | Resultado |
|---|---|
| Coleta ao vivo, 28/10/2026 00:47 (BRT) | **Nenhum ônibus**: os 3 pontos devolveram 0 grupos de chegada (madrugada). 3 requisições. |
| Gravação real da Fase 1 (27/10, 22:17, linha 003, 4 posições), reavaliada com as regras atuais (`--from-probe`) | amostras 1–3: **ambíguo — trecho repetido**; amostra 4: **confirmado 003‑1 · Ida** (mesma conclusão da análise manual da Fase 1). Próximos pontos: **desligados** (sequência de 003‑1i é `partial`). |

O que essa gravação ensinou: perto do ponto 30402 o trajeto oficial contorna uma quadra, e as primeiras amostras ficavam a até 50 m de três passagens. A primeira versão da regra declarava "trecho repetido" para sempre; a regra de **convergência** (§5) foi criada a partir disso e coberta por testes sintéticos nos dois lados.

**Não há base para declarar precisão geral** (n = 1 veículo). Próximo passo: rodar `match_eval.py` em horário de pico, algumas vezes, e registrar os motivos.

---

## 7. Casos ambíguos (tratamento)

| Caso | Tratamento |
|---|---|
| Ponto perto da ida e da volta sem desempate | fora da ordem dos dois sentidos; contado ("N pontos ficaram de fora") |
| Ponto com duas passagens do mesmo trajeto | duas entradas intermediárias ("passa de novo") |
| Trajeto com poucos pontos de confiança alta | `partial`: lista sem ordem |
| Ordem contrária aos logradouros oficiais | `partial` |
| `routeName` igual a várias variantes / a nenhuma | associação ambígua; tracking tradicional |
| Destino que casa com os dois extremos | ambígua |
| Rastro compatível com passagens diferentes | ambígua (trecho repetido) até as cadeias convergirem |
| Salto ao longo do trajeto | ambígua (salto) |
| Quadro antigo / sem data / em conflito | oculto com aviso / indisponível |
| Código de planilha sem variante no cadastro | exibido como "(sem cadastro)", sem associação |

---

## 8. Testes executados

| Suíte | Resultado |
|---|---|
| Flutter (todos) | **568/568** |
| — `schedule_sequence_test.dart` (novo) | codec das tabelas novas, validade, partidas (ordem, duplicidade, +1, filtro), tipo de dia, sequência (malformadas, sem ordem), contexto do ponto, próximos pontos (confirmado, parcial, pendente, GPS vencido, margem de 40 m, fim), retorno pelo mesmo trecho, geometria sinuosa, salto |
| — `catalog_map_ui_test.dart` (ampliado) | horários (dias, validade, marcas, filtro), antigo só com aviso, insuficiente, sequência (estimada/sem ordem/nenhuma), ponto → itinerário → linha reenquadrada (também com o painel expandido), offline, Meu ônibus com próximos pontos, sem overflow 320 px 100 %, 390 px 200 %, 1024 px 130 % |
| — `network_map_test.dart` | + toque nos anéis da linha |
| — `l10n_test.dart` | plurais com `=0` (achou 4 faltando; corrigido) |
| Pipeline Python | **44/44** (+16: quadros, validade, conflitos, sequências, retorno, sentido oposto, rho, tracking, salto, convergência, próximos pontos) |
| `flutter analyze` | sem problemas |
| `dart format` | sem mudanças (exceto o payload gerado, fora do Git) |
| Visual (Web dev, painel do navegador) | celular 375×812 e tablet 768×1024, tema escuro e claro: horários, sequência, itinerário do ponto, anéis tocáveis, reenquadramento |

Problemas encontrados e corrigidos nesta fase: regra de trecho repetido rígida demais (gravação real); cadeia que pulava para a outra passagem de um retorno (limite de avanço por deslocamento); chave duplicada no aviso de validade; plurais sem `=0`; anéis da linha não tocáveis com trajeto aberto; enquadramento que podia não acontecer quando o painel estava expandido (a espera pela animação da folha foi trocada por um intervalo fixo — a causa exata não foi reproduzida em teste de widget, só observada no Web).

---

## 9. Builds realizados

| Build | Resultado | Dados CMTC no artefato |
|---|---|---|
| Web produção (`flutter build web --release`, Flutter 3.38.5) | OK, `main.dart.js` 3.758.278 bytes | **Ausentes** (verificador OK) |
| Web desenvolvimento (profile, `-t dev_catalog/main.dart`) | OK | Presentes, inclusive `trips`, `sequences` e `projecao-kmz-v2` (controle positivo) |
| Android produção (release APK) | OK, 86,0 MB (igual à Fase 3) | **Ausentes** |
| Android desenvolvimento (profile APK) | OK, 155,4 MB (Fase 3: 151,2 MB) | Presentes (controle positivo) |
| iOS produção (release, `--no-codesign`, Flutter master) | OK, 29,2 MB (igual à Fase 3) | **Ausentes** |
| iOS desenvolvimento (profile) | OK, 42,7 MB (Fase 3: 41,2 MB) | Presentes (controle positivo) |

O verificador (`app/scripts/check-no-official-catalog.sh`) agora também procura `"trips":{"fields"`, `"sequences":{"fields"` e o id do método (`projecao-kmz-v2`), em UTF‑8 e UTF‑16LE, inclusive dentro de APK. O tamanho dos builds de produção não mudou.

---

## 10. Impacto em desempenho e armazenamento

| Item | Fase 3 | Fase 4 |
|---|---|---|
| Payload JSON de desenvolvimento | 1,44 MB | **2,02 MB** (+580 KB: horários 190 KB, sequências 389 KB) |
| Decodificação do catálogo real (VM de teste, Mac local) | — | **90 ms** |
| Índice "ponto → itinerário" (1º uso) | — | 2 ms |
| Partidas de dia útil de todas as 303 abas | — | 10 ms |
| Build de produção | inalterado (sem catálogo) | inalterado (sem catálogo) |

A sequência guarda `ponto,metros,nível` em texto compacto e só é decodificada quando um trajeto é aberto. Os horários vão agrupados (aba × dia × código × tipo → lista de minutos). Continua cabendo no mesmo mecanismo da Fase 2 (string no binário de desenvolvimento); se um dia for distribuído, convém compactar (gzip reduz JSON desse tipo a ~20–25 %).

---

## 11. Riscos e limitações

1. **Licença** — nada pode ir para produção sem autorização de redistribuição registrada.
2. **Vigência dos horários** — nenhuma aba confirmada; 93 abas antigas (2022–2025).
3. **Sequência estimada** — 23 % dos trajetos têm ordem utilizável; não é oficial; pode errar em vias de mão dupla, retornos e onde o cadastro de pontos diverge do KMZ (249 pontos com > 50 m de diferença, Fase 1).
4. **Próximos pontos** — sem observação com ônibus real; a única gravação real cai num trajeto `partial`.
5. **Map matching** — n = 1 gravação; precisão geral desconhecida.
6. **Feriados** — sem calendário nos dados; escolha manual.
7. **Web** — enquadramento após troca de conteúdo do painel dependia da animação da folha; corrigido e observado, mas o teste de widget não reproduz a falha original.
8. **Ambiente local de iOS** — só compila com o Flutter master (Xcode 27.1).

## 12. Próximos passos

1. Rodar `match_eval.py` 3–5 vezes em horário de pico (7h–9h, 17h–19h) e registrar motivos e tempo até confirmar.
2. Pedir à CMTC: confirmação de vigência por aba (preencher `CONFIRMED_SHEETS`), sequência oficial ponto‑a‑ponto por variante/sentido, calendário de feriados/exceções e a licença de redistribuição.
3. Com sequência oficial, trocar `projecao-kmz-v2` por relação explícita (nível "confirmada") e reavaliar o ADR‑0005.
