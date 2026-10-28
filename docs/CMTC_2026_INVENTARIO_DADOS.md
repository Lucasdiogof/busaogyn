# CMTC 2026 — Inventário dos dados oficiais

- **Data:** 27/10/2026 · **Fase:** BusãoGyn 2.0 — Fase 1 (engenharia de dados, sem mudança no app)
- **Processamento:** `data/cmtc/pipeline/build.py` (só biblioteca padrão do Python 3.9). Todos os números deste documento vêm de `data/cmtc/reports/inventory.json` e `quality_indicators.json`, gerados por essa execução.
- **Originais:** copiados sem alteração para `data/cmtc/raw/` (fora do Git por `data/cmtc/.gitignore`). Hash SHA-256 de cada arquivo em `data/cmtc/reports/raw_sha256.txt`.

Legenda: **OFICIAL** = valor como está no arquivo da CMTC · **DERIVADO** = transformação determinística (ex.: DMS → decimal) · **INFERIDO** = produzido por heurística (nunca tratar como oficial) · **NÃO FORNECIDO** = não consta em nenhum arquivo.

---

## 1. Documentos recebidos e condições de uso

| Documento | Data | Conteúdo relevante |
|---|---|---|
| Ofício nº 728/2026/CMTC (SEI 11922500) | 27/10/2026 | Encaminha o Parecer 226/2026 e os arquivos por link do Google Drive. |
| Parecer nº 226/2026 – GERES/DIROP – CMTC (SEI 11915933) | 26/10/2026 | Lista o que foi entregue: Cadastro Geral de Pontos, Cadastro Geral de Linhas, KMZ das linhas (trajeto) e planilhas horárias por terminal. |
| Ofício 5720/2026/CGM/OUVGER + comprovante da solicitação (protocolo 2026106554419306) | 06–07/10/2026 | O pedido original (LAI), que solicitava também GTFS, relação **ordenada** linha→sentido→pontos, dicionário de campos, periodicidade de atualização, canal oficial de sincronização e **licença/condições de uso, cache e redistribuição**. |

**O que a resposta não traz** (verificado na leitura integral das 8 páginas do PDF):
- nenhuma licença, termo ou condição de uso, armazenamento, cache ou redistribuição — **nem autorização, nem restrição**;
- nenhum dicionário de campos;
- nenhuma periodicidade ou procedimento de atualização, URL, API ou feed;
- nenhum GTFS;
- o item **(d) — relação ordenada linha → sentido → pontos — não foi entregue** como tal. Existe só a relação ponto → linha sem ordem (Cadastro de Pontos, colunas LINHA 01..27).

Conclusão: o fornecimento é oficial e se baseia na LAI, mas **não autoriza expressamente a redistribuição em aplicativo**. Não presumir autorização comercial. A regra do ADR‑0002 (item 6: identificador de autorização registrado antes de usar a base em produção) **continua pendente**. Recomendação: pedido complementar à CMTC citando o protocolo, solicitando licença/condições, dicionário e o item (d).

O PDF contém dados pessoais do solicitante (documento, telefone, e‑mail). Eles **não** foram copiados para nenhum relatório ou documento.

---

## 2. Arquivos

| # | Arquivo | Tipo | Tamanho | Data de referência declarada |
|---|---|---|---|---|
| 1 | `Cadastro Geral das Linhas da RMTC _Setembro-2026 01.09.2026.xlsx` | XLSX | 393 KB | 01/09/2026 (nome); coluna "Data de Vigência" por linha de 2022‑10‑10 a 2026‑08‑01 |
| 2 | `Cadastro Geral dos Pontos de Ônibus da RMTC- Outubro - 2026.xlsx` | XLSX | 4,2 MB | outubro/2026 (nome); "DATA DO CADASTRO" por ponto (seriais Excel ou "SEM CADASTRO") |
| 3 | `LINHAS RMTC.kmz` | KMZ (Google Earth Pro 7.3) | 2,2 MB (9,6 MB de KML) | sem data no arquivo |
| 4 | `PED_S MUNICIPIO.kmz` | KMZ | 271 KB (3,2 MB de KML) | sem data no arquivo |
| 5 | `Planilhas Horárias por Terminal da RMTC _ 28-10-2026/` | 29 XLSX (+ 9 temporários `~$`, ignorados) | 5,8 MB | 28/10/2026 (nome da pasta); campo "Data:" por aba, de 2022‑10‑10 a 2026‑10‑28 |
| 6 | Ofício 728 + Parecer 226 (PDF, 8 p.) | PDF | 222 KB | 26–27/10/2026 |

---

## 3. Cadastro Geral das Linhas

**Abas:** `Consulta` (ficha de consulta, 94×43, com fórmulas/mesclas — não é tabela), **`Cadastro GERAL`** (tabela, cabeçalho na linha 2), `Cadastro` (oculta, modelo de ficha) e `Validação ` (oculta, listas de domínio: status OPERAÇÃO/CANCELADA/SUSPENSA, tipos, formas, empresas, cidades).

**Colunas (24):** NÚMERO, DENOMINAÇÃO, STATUS DA LINHA, CARACTERÍSTICA, CIDADE DE ATENDIMENTO, ÁREA OPERACIONAL, ORIGEM (LOCAL‑1), DESTINO (LOCAL‑2), LOTE‑1, Empresa 1, Empresa 2, SUBSISTEMA, TIPO, FORMA, KM IDA, KM VOLTA, EXTENSÃO TOTAL, TIPO VEÍCULO, INTEGRAÇÃO, **LOGRADOURO ‑ IDA**, BAIRRO ‑ IDA, **LOGRADOURO ‑ VOLTA**, BAIRRO ‑ VOLTA, Data de Vigência.

| Medida | Valor |
|---|---|
| Registros | **426** (426 códigos únicos, sem duplicidade) |
| O que é cada registro | uma **variante** (`003-1`, `003-7`, `NS1-1`, `MGP-07`) |
| Linhas distintas (base) | **313** (`003`, `NS1`, `MGP-07`…) |
| Característica | Principal 302 · Sublinha 113 · Especial 11 |
| Status | 426 × OPERAÇÃO (canceladas/suspensas não vieram) |
| Formatos de código | `999-9` 413 · `AAA-99` 8 (MGP‑01..08, linhas especiais de evento) · `AA9-9` 5 (BRT NS1..NS5) |
| Tipo | Alimentadora 180, Eixo 77, Ligação 57, Semi Urbana 35, Expresso 26, Convencional 16, Conexão 13, Especial 11, Direta 8, Corujão 2, vazio 1 |
| Forma | Perimetral 176, Radial 155, **Circular 31**, Transversal 12, Troncal 8, Expressa 7, Diametral 5, Semi‑Expressa 1, vazio 31 |
| Cidade de atendimento | Goiânia 228, Aparecida 111, Senador Canedo 26, Trindade 14, +18 municípios; 2 vazias |
| Operadora | Empresa 1 quase sempre "Rápido Araguaia" (408); Empresa 2: HP Transportes 201, Reunidas 113, Cootego 93, Metrobus 10, combinações nas MGP |
| Data de Vigência | 2022: 179 · 2023: 69 · 2024: 65 · 2025: 63 · 2026: 49 · ausente 1 |
| Itinerário | listas de logradouros e bairros de ida e de volta, **em ordem**, uma por linha de célula (texto livre) |

Identificadores: `NÚMERO` (texto, zeros preservados). Não há ID numérico interno, código de operadora nem código de terminal estruturado.

---

## 4. Cadastro Geral dos Pontos

**Abas:** `Pesquisar` (ficha), **`Cadastro`** (tabela, cabeçalho na linha 2), `Validação de Dados` (oculta: modelos de PED, municípios, status).

**Colunas (48):** ID, TIPO, LOGRADOURO, REFERÊNCIA, Nº, QD., LT., LOCAL, BAIRRO, MUNICIPIO, **SENTIDO** (texto), ARCO, **LATITUDE**, **LONGITUDE** (texto em graus/minutos/segundos), SITUAÇÃO, MODELO DO PED, MÓDULO, ESTRUTURA, **LINHA 01..LINHA 27**, TOTAL DE LINHAS, DATA DO CADASTRO, ANO.

| Medida | Valor |
|---|---|
| Registros | **7.350** PEDs (IDs únicos, inteiros de 3 a 9.866) |
| Situação | 7.350 × ATIVADO |
| Municípios | Goiânia 3.827, Aparecida 1.447, Senador Canedo 580, Trindade 394, Goianira 228, +17 |
| Coordenadas | válidas 7.330 · ausentes 12 ("SEM CADASTRO"/"KMZ") · inválidas 8 (hemisfério trocado, latitude repetida na longitude, 1 fora da área) |
| Envelope (bbox) | lat −17,164 a −16,364 · lon −49,709 a −48,932 |
| SENTIDO | 94 rótulos distintos ("BAIRRO - TERMINAL" 2.791, "TERMINAL - BAIRRO" 2.307…), com variações de grafia |
| Relação ponto → linha | todos os pontos têm ≥ 1 linha; mediana 1, máximo 27; **293 bases** citadas; os códigos vêm como inteiro (`27`) ou texto (`NS1`), **sem variante e sem sentido** |
| TOTAL DE LINHAS | diverge da contagem de colunas preenchidas em 94 pontos |

Identificador: `ID` = **número do PED**. **Confirmado em 27/10/2026** que é o mesmo código usado pela API de chegadas do BusãoGyn/RMTC (`qryIdPontoParada`), em amostra de 7 consultas (`reports/api_stop_sample.json`): nos 6 PEDs do cadastro testados, todas as linhas devolvidas em tempo real estão na lista LINHA do ponto. Para generalizar, ver `CMTC_2026_QUALIDADE_DADOS.md` §6.

---

## 5. KMZ de trajetos — `LINHAS RMTC.kmz`

Um `doc.kml` com 912 Placemarks `LineString` (sem MultiGeometry, sem ExtendedData, sem descrição). As pastas organizam por eixo e terminal: `Arco Sul` (8 terminais), `Arco Leste`, `Arco Oeste`, `Eixo Anhanguera`, `P.A / PC`, `Expressas`, `Corujão`.

| Medida | Valor |
|---|---|
| Trajetos (Placemarks) | **912** |
| Nome | `<código>-<variante><i\|v> - <DESCRIÇÃO> - IDA\|VOLTA` (ex.: `003-1i - T. MARANATA / EIXO T-7 / T. PAULO GARCIA - IDA`) |
| Sentido | sufixo i/v em 906 · só no texto IDA/VOLTA em 4 · ausente em 2 (`120-1v`/`120-2v` sem sufixo legível "(L.A.)") |
| Variantes distintas | **466** (304 bases) |
| Sentidos por variante | ida+volta 436 · só ida 15 · só volta 10 · com trajeto repetido no mesmo sentido 4 (`iivv` 2, `vv` 1, `ivv` 1) · sem sentido 1 |
| Vértices | 294.474 · comprimento total 13.198 km · mediana 12,4 km por trajeto, mín. 1,6 km, máx. 74,5 km |
| Nomes repetidos | 5 (`182-2i`, `182-2v`, `518-1i`, `518-1v`, `601-2v`) |
| Geometrias idênticas | 15 grupos (ex.: `150-1i` = `356-1i`; `212-1i` = `215-1i`) |
| Trajetos "fechados" (início = fim) | 0 — linhas circulares vêm em ida/volta separadas |
| Variantes do KMZ ausentes do cadastro | 55 (sobretudo sub‑variantes `-21`, `-22`, `-31`; e `120`, `551`, `316` sem variante, `616-1`, `736-1`) |
| Variantes do cadastro sem KMZ | 15 (MGP‑01..08, 989‑1, 990‑1, 991‑1, 022‑3, 031‑2, 316‑1, 551‑1) |

Ordem dos vértices: **segue o sentido de circulação**. Validado comparando a ordem dos pontos projetados com a ordem oficial dos logradouros do cadastro de linhas: 483 de 483 trajetos testáveis com Spearman > 0,5 (§ map matching).

---

## 6. KMZ de pontos — `PED_S MUNICIPIO.kmz`

| Medida | Valor |
|---|---|
| Placemarks `Point` | **7.435** em 3 pastas: `PEDS GERAL / PED'S - ATIVOS` 7.349 · `ESTAÇÕES BRT NORTE SUL` 50 · `EIXO ANHANGUERA` 36 |
| Nome | `<código> - <descrição>` (ex.: `40000 - AV. ANHANGUERA (PLATAFORMA ANHANGUERA)`) |
| Códigos distintos | 7.424 (9 repetidos: 161, 430, 6398, 6593, 6602, 7090, 7665, 8019, 9777) |
| Em ambas as fontes | 7.294 · só no cadastro 56 · só no KMZ 130 (86 deles são estações 40000+ do Eixo/BRT) |
| Distância cadastro × KMZ | mediana 0,0 m · p95 23,6 m · 249 pontos acima de 50 m |

As estações do Eixo Anhanguera e do BRT Norte‑Sul (faixa 40000+) **só existem no KMZ** e não têm relação ponto→linha. Mesmo assim, a API respondeu chegadas para `40000` (linhas 110, 111, 113, 116, 117, 120).

---

## 7. Planilhas horárias por terminal

29 arquivos (um por terminal/agrupamento: Araguaia, Bandeiras, BRT Norte‑Sul, Corujão, Cruzeiro, Dergo, Diretas, Eixo Anhanguera, Expressas, Garavelo, Goianira, Hailé Pinheiro, Isidória, Maranata, Nerópolis, Novo Mundo, Padre Pelágio, Parque Oeste, Paulo Garcia, PC Cora Coralina, Ponto de Conexão, Praça A, Praça da Bíblia, Recanto do Bosque, Senador Canedo, Trindade, Veiga Jardim, Vera Cruz, Vila Brasília). **303 abas**, uma por linha. Uma aba está **oculta** (`Goianira_.xlsx` › `214 (3)`, com horários inválidos: rascunho) e fica fora do catálogo.

**Estrutura:** um único gabarito ("Anexo II" da Ordem de Serviço Operacional — OSO) em 303/303 abas. O parser localiza os rótulos em vez de usar posições fixas (`pipeline/cmtc/schedules.py`):
- identificação: Linha, denominação, Grupo, Concessionárias, Tipo de Veículo, Número da Planilha, **Data**, **OSO**;
- dados operacionais por tipo de dia (seg‑sex, sábado, domingo/feriado): intervalo médio pico/entre‑pico, frota, tempo médio de viagem pico/entre‑pico, nº de viagens, velocidade média, extensão (ida e volta), horário de início/término;
- três blocos de partidas (DIA ÚTIL, SÁBADO, DOMINGO): Nº de Ordem, Nº da Linha (**variante**, ex.: `032-1`), Horário, Operadora, tipo de viagem (`VG`, `MVGI`, `MVGV`);
- observações (legenda "Mvg – Meia Viagem…" e, em várias abas, a denominação das variantes, ex.: `018-2 T. Araguaia / Praça Cívica`).

| Medida | Valor |
|---|---|
| Linhas (base) com planilha | **302** (abas visíveis; 1 por linha, sem repetição) |
| Partidas programadas | **17.448** (dia útil 8.903 · sábado 5.140 · domingo/feriado 3.405) |
| Variantes citadas | 417 (413 existem no cadastro; 4 só pela base: `112-3`, `601-3`, `020-3`, `733-2`) |
| Abas com 2+ variantes | 79 de 302 |
| Tipo de viagem | VG 14.242 · MVGV 1.718 · MVGI 1.476 · vazio 12 |
| Operadoras (sigla) | RA 8.080, HP 4.167, RE 2.339, CO 1.898, MB 926, VR 37 |
| Partidas após meia‑noite | 163 (gravadas como `24:xx`, convenção GTFS) |
| Duplicidade exata (dia, variante, hora, tipo) | 5 · fora de ordem 6 |
| "Data:" da aba | 2026: 209 · 2025: 64 · 2024: 25 · 2022: 4 (2022‑10‑10 a 2026‑10‑28) |
| OSO | 24 numerações diferentes, de 0001/2022 a 0011/2026 |

**O que não existe nas planilhas:** de onde parte cada horário (terminal de origem? ambos os extremos?), o sentido da partida, horários por ponto intermediário, calendário de feriados, datas de início/fim de vigência. "Data:" é a data da planilha, não um período de validade.

---

## 8. Relações entre os arquivos

```text
Cadastro de Linhas (variante 003-1) ──código idêntico── KMZ trajetos (003-1i / 003-1v)   411/426 variantes
        │                          ──código idêntico── Planilhas ("Nº da Linha" 003-1)   413/426 variantes
        │ base (003)
        └──────────────── Cadastro de Pontos (LINHA 01..27 = base, sem variante/sentido)  293/313 bases
                                    │ ID (PED)
                                    ├── KMZ de pontos (nome "ID - descrição")           7.294 em comum
                                    └── API em tempo real (stopId)                       amostra 6/6
Cadastro de Linhas base (003) ───── API em tempo real routeId ("003")                    mesma normalização
```

Tabela completa de correspondência, com confiança e evidência: `data/cmtc/reports/id_crosswalk.csv` (1.310 linhas).

---

## 9. Situação de vigência

| Base | Sinal de vigência | Avaliação |
|---|---|---|
| Linhas | nome "Setembro‑2026"; Data de Vigência por linha (88% anteriores a 2026) | a data é de **início** da configuração; antiga ≠ desatualizada. Linhas canceladas não vieram. |
| Pontos | nome "Outubro‑2026"; todos ATIVADO | sem data de corte; 143 pontos com "SEM CADASTRO" na data |
| KMZ | nenhuma data | **vigência incerta**; 55 variantes não existem no cadastro (podem ser antigas ou novas) |
| Horários | pasta "28‑10‑2026"; "Data:" por aba | 93/302 abas (30,8%) com data anterior a 2026 → tratar como **vigência incerta** até confirmação |

---

## 10. Arquivos gerados nesta fase

| Caminho | Versionável? | Conteúdo |
|---|---|---|
| `data/cmtc/raw/` | não (gitignore) | originais intactos |
| `data/cmtc/processed/` (28 MB) | não (gitignore) | `lines.csv`, `stops.csv`, `shapes_index.csv`, `departures.csv`, `inferred_stop_sequences.csv`, `inferred_stop_direction.csv`, `shapes_tol{0,3,8}m.geojson`, `catalog_prototype.sqlite`, `examples/*.geojson` |
| `data/cmtc/reports/` (248 KB) | **não** (gitignore; o repositório é público e os relatórios contêm dados derivados da CMTC) | `inventory.json`, `quality_indicators.json`, `issues.csv`, `id_crosswalk.csv`, `direction_levels.csv`, `tolerance_sensitivity.json`, `realtime_join_capacity.json`, `api_stop_sample.json`, `vehicle_probe_30402.json`, `sequence_examples.md`, `raw_sha256.txt` |
| `data/cmtc/pipeline/` | sim | código e testes |

Reexecução: `cd data/cmtc && python3 -I pipeline/build.py && python3 -I pipeline/examples.py` (~45 s). Testes: `python3 -I -m unittest discover -s pipeline/tests`.
