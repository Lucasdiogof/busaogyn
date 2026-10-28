# CMTC 2026 — Qualidade dos dados

- **Data:** 27/10/2026 · reexecutável com `cd data/cmtc && python3 -I pipeline/build.py`
- **Fontes dos números:** `data/cmtc/reports/quality_indicators.json` (indicadores), `issues.csv` (467 ocorrências item a item), `tolerance_sensitivity.json`, `realtime_join_capacity.json`, `api_stop_sample.json`, `vehicle_probe_30402.json`.
- Nenhum percentual abaixo é estimado: todos têm numerador, denominador e método. Os indicadores marcados **INFERIDO** medem a heurística do protótipo, não um dado oficial.

---

## 1. Indicadores

| Indicador | Num. | Den. | % | Método |
|---|---:|---:|---:|---|
| Variantes do cadastro com trajeto no KMZ | 411 | 426 | 96,48 | código da variante (`003-1`) igual ao do nome do Placemark |
| Linhas (base) do cadastro com trajeto | 302 | 313 | 96,49 | base (`003`) presente em algum trajeto |
| Trajetos com sentido identificável | 910 | 912 | 99,78 | sufixo `i`/`v` ou IDA/VOLTA no nome |
| …pelo sufixo i/v | 906 | 912 | 99,34 | só o sufixo |
| Variantes do KMZ com ida e volta | 439 | 466 | 94,21 | ao menos um trajeto `i` e um `v` |
| Variantes do KMZ presentes no cadastro | 411 | 466 | 88,20 | código idêntico |
| Pontos com coordenada válida | 7.330 | 7.350 | 99,73 | DMS/decimal legível, hemisfério correto, dentro do envelope da RMTC |
| Pontos do cadastro presentes no KMZ | 7.294 | 7.350 | 99,24 | ID = código numérico do Placemark |
| Pontos do KMZ presentes no cadastro | 7.294 | 7.424 | 98,25 | idem, sentido inverso |
| Pontos em ambas as fontes a até 10 m | 6.768 | 7.274 | 93,04 | haversine cadastro × KMZ |
| Pontos com ao menos uma linha associada | 7.350 | 7.350 | 100,00 | colunas LINHA 01..27 |
| Linhas principais com planilha horária | 302 | 302 | 100,00 | base da linha principal = número da aba visível |
| Variantes com partidas programadas | 413 | 426 | 96,95 | variante citada em "Nº da Linha" |
| Códigos de variante das planilhas no cadastro | 413 | 417 | 99,04 | código idêntico |
| Pares ponto‑linha oficiais cobertos pela sequência **(INFERIDO)** | 16.358 | 16.476 | 99,28 | ponto a ≤ 25 m de algum trajeto da linha, confiança ≥ 0,5 |
| Associações ponto‑trajeto com confiança ≥ 0,9 **(INFERIDO)** | 31.681 | 37.738 | 83,95 | score de `sequence.py` |
| Trajetos cuja ordem inferida acompanha os logradouros oficiais | 483 | 483 | 100,00 | Spearman > 0,5 entre posição no trajeto e índice do logradouro do ponto na lista oficial do sentido (≥ 6 pontos com logradouro único) |
| Sentido do ponto por variante — nível alta **(INFERIDO)** | 11.620 | 23.802 | 48,82 | ponto perto de só um dos sentidos |
| Sentido do ponto por variante — ambíguo **(INFERIDO)** | 4.720 | 23.802 | 19,83 | perto dos dois sentidos, sem desempate |
| Associações removidas por pertencerem ao outro sentido **(INFERIDO)** | 7.496 | 37.737 | 19,86 | ponto atribuído ao sentido oposto da mesma variante |
| Abas de horário com data anterior a 2026 | 93 | 302 | 30,79 | campo "Data:" da aba |
| Linhas com Data de Vigência anterior a 2026 | 376 | 426 | 88,26 | coluna "Data de Vigência" (início da configuração, não validade) |

Níveis do sentido por ponto (`direction_levels.csv`): alta 11.620 · média 1.203 (logradouro só na lista oficial de um sentido) · baixa 6.259 (perto dos dois; ≥ 10 m mais perto de um) · ambíguo 4.720.

### Junção com o tempo real

| Indicador | Num. | Den. | Método |
|---|---:|---:|---|
| PEDs do cadastro em que todas as linhas da API estão na lista LINHA do ponto | 6 | 6 | 6 consultas reais a `/v1/stops/{id}/arrivals` em 27/10/2026 (5 sorteados com seed fixa + 9854) |
| Variantes com denominação única dentro da própria linha | 376 | 426 | DENOMINAÇÃO normalizada (palavras sem acento, ordem livre) |
| …entre linhas que têm 2+ variantes | 142 | 192 | idem, só nas 79 linhas com mais de uma variante |
| Variantes em que o destino pode indicar o sentido | 422 | 426 | 1º e último trecho da DENOMINAÇÃO (`A / … / B`) sem palavras em comum |
| Veículo real com variante identificada pelo `routeName` | 1 | 1 | amostra única: ônibus 50612, linha 003 → `003-1` (`vehicle_probe_30402.json`) |

Amostras pequenas (n = 6 e n = 1) **não** permitem generalizar estatisticamente: são evidência de que a junção funciona, não medida de taxa.

---

## 2. Sensibilidade à tolerância da projeção

`tolerance_sensitivity.json` (três execuções completas do pipeline):

| Tolerância | Pares cobertos | Confiança ≥ 0,9 | Sentido "alta" | Sentido ambíguo | Removidos (outro sentido) |
|---|---|---|---|---|---|
| 25 m (**padrão adotado**) | 99,28% | 83,95% | 48,82% | 19,83% | 19,86% |
| 40 m | 99,43% | 87,23% | 39,33% | 19,80% | 24,39% |
| 60 m | 99,48% | 89,12% | 34,29% | 19,79% | 26,61% |

De 25 m para 60 m a cobertura sobe só 0,2 ponto, mas o sentido "alta" cai 14,5 pontos: tolerância maior captura o ponto do outro lado de vias largas. Por isso o padrão é 25 m. A fração ambígua (~19,8%) não muda com a tolerância: são pontos onde ida e volta usam **o mesmo eixo desenhado** e nada nos dados separa os sentidos.

---

## 3. Duplicidades e inconsistências (por base)

### Cadastro de Linhas
- Sem códigos duplicados; KM IDA + KM VOLTA = EXTENSÃO TOTAL em todos.
- 1 linha sem Data de Vigência legível; 2 sem cidade (`118-2`, `364-1`); 31 sem FORMA; 39 sem SUBSISTEMA; 1 sem TIPO.
- Grafia livre nos campos de texto: "Nova Neneza" (sic), espaços extras em "Oeste ", "Autódromo ".
- `INTEGRAÇÃO`: `i` 349, `I` 1, `0` 32, vazio 44 — semântica não documentada.

### Cadastro de Pontos
- 20 pontos sem coordenada utilizável: 12 "SEM CADASTRO"/"KMZ"; 6 com a latitude repetida no lugar da longitude; 1 com hemisfério trocado; 1 fora da RMTC (`1155`, latitude 6° em vez de 16°).
- 18 grupos de pontos distintos com coordenada idêntica.
- 94 pontos em que TOTAL DE LINHAS não confere com as colunas preenchidas.
- 23 células LINHA com `-`.
- 94 rótulos de SENTIDO para poucos conceitos (`TERMINAL-BAIRRO` × `TERMINAL - BAIRRO` × `BAIRRO / TERMINAL`).
- Datas de cadastro: 7.154 seriais Excel, 159 textos ("SEM CADASTRO"), 37 vazias.

### KMZ de pontos
- 9 códigos com 2 Placemarks.
- 249 pontos com mais de 50 m entre cadastro e KMZ (p95 = 23,6 m). Qual coordenada é a correta não é determinável aqui.
- 130 códigos só no KMZ (86 estações 40000+); 56 só no cadastro.

### KMZ de trajetos
- 5 nomes repetidos; 15 grupos de geometria idêntica (variantes diferentes com o mesmo traçado num sentido, ex.: `212-1i` = `215-1i` "horário"/"anti‑horário" — **suspeita de cópia**, a confirmar com a CMTC).
- 1 trajeto com sufixo divergente do texto IDA/VOLTA; 2 sem sentido.
- 55 variantes que não existem no cadastro e 15 do cadastro sem trajeto (MGP, 989–991 e outras).

### Planilhas horárias
- 1 aba oculta com horários ilegíveis (excluída).
- 23 blocos de dados operacionais com campos faltando (`-` = sem operação naquele dia é tratado como ausência, não como erro).
- 5 partidas exatamente duplicadas (mesmo dia, variante, hora e tipo) e 6 partidas fora de ordem.
- 4 variantes citadas sem registro no cadastro (`112-3`, `601-3`, `020-3`, `733-2`).
- Abas com datas de 2022 a 2026 e 24 OSO distintas: **vigência heterogênea**.

---

## 4. Linhas sem horário, sem trajeto, sem pontos

| Situação | Quantidade | Exemplos |
|---|---|---|
| Base do cadastro sem nenhum ponto associado | 20 | `115`, `117`, `185`, `612`–`615`, `989`–`991`, `MGP-01..08`, `NS4`, `NS5` |
| Trajetos sem nenhum ponto casado | 31 (13 bases) | `115`, `117`, `120`, `185`, `612`–`616`, `736`, `739`, `NS4`, `NS5` (linhas diretas/expressas e Eixo/BRT, cujas paradas são estações 40000+ fora do cadastro) |
| Variantes do cadastro sem partidas | 13 | ver `id_crosswalk.csv` |
| Variantes do cadastro sem trajeto | 15 | MGP‑01..08, 989‑1, 990‑1, 991‑1, 022‑3, 031‑2, 316‑1, 551‑1 |

---

## 5. Classificação da informação de horário

| Classe | O que é | Onde aparece |
|---|---|---|
| **Programado oficial** | horário de partida da planilha OSO, com variante, dia, operadora, tipo de viagem | `departures.csv` (`quality = PROGRAMADO_OFICIAL`) |
| **Calculado** | qualquer horário derivado (chegada no outro extremo = partida + tempo médio de viagem; horário em ponto intermediário por distância) | **não gerado nesta fase**; se gerado, rotular CALCULADO |
| **Previsão em tempo real** | `previsaochegada` com `Qualidade = "Tempo real"` | API atual, inalterada |
| **Vigência incerta** | aba com "Data:" antiga (93), KMZ sem data, variantes fora do cadastro | marcar na versão do catálogo; não esconder |

A própria fonte em tempo real já devolve "Tabela Horária" (`quality = scheduled`) para chegadas sem GPS. Essas são previsões programadas **da RMTC**, distintas das planilhas OSO. As duas não devem ser misturadas sem conciliação.

---

## 6. Resultados inconclusivos (declarados)

- **Lado da via** não serve para atribuir sentido: só concorda com os logradouros oficiais em ~50% dos casos (medido antes de ser descartado; ver `sequence.py`).
- **Sentido de partida das planilhas** não está nos arquivos.
- **Qual coordenada vale** quando cadastro e KMZ divergem > 50 m (249 pontos).
- **Equivalência `00294` × `294`**: todos os IDs do cadastro são inteiros sem zeros à esquerda; a pergunta do ADR‑0002 continua aberta para códigos digitados com zeros.
- **Generalização da junção ponto/linha e do `routeName`**: n = 6 e n = 1.
