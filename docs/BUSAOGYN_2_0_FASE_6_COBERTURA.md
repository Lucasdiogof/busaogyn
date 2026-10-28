# BusãoGyn 2.0 — Fase 6: cobertura, estações, terminais, baldeações e validação

- **Data:** 28/10/2026
- **Branch:** `feat/cmtc-catalogo-dev` (sem merge na `main`, sem deploy)
- **Status:** só no build de desenvolvimento. Produção continua sem catálogo (verificado em Web, Android e iOS, §9).
- **Base:** [ADR‑0002](adr/0002-dados-confiaveis-e-nao-inferencia.md) para produção; [ADR‑0005](adr/0005-sequencia-estimada-so-em-desenvolvimento.md) para o desenvolvimento. Nenhum critério de segurança foi relaxado: cada recuperação tem uma **evidência nova e nomeada**, registrada por trajeto (`evidence`) e exibida na interface.

---

## 1. Diagnóstico inicial (reproduzido)

As métricas da Fase 5 foram reproduzidas exatamente (mesmo payload, mesma semente 42): 208 de 912 trajetos, 3.331 pontos, 6.708 conexões, 103 de 313 linhas, 6,0 % e 0,6 % nas amostras.

Script reproduzível: `python3 -I pipeline/coverage_report.py --baseline` (regras da Fase 5) e sem `--baseline` (Fase 6). Saída local em `reports/coverage_diagnosis*.json` (fora do Git), com a causa de cada trajeto, linha e ponto.

**Por que cada trajeto ficava fora (Fase 5):**

| Causa | Trajetos |
|---|---|
| Sentido ambíguo (ida e volta a menos de 25 m: < 70 % de pontos com confiança alta) | 510 |
| Muitos pontos ambíguos (> 15 %) | 103 |
| Poucos pontos associados (< 5) | 52 |
| Falta de ligação ponto‑linha no cadastro | 16 |
| Linha de corredor: as paradas são estações, que não estão no cadastro de pontos | 12 |
| Nenhum ponto da linha perto do trajeto | 8 |
| Sentido ausente no nome do trajeto | 2 |
| Ordem contradiz os logradouros oficiais | 1 |

**Linhas fora (210):** 149 por sentido ambíguo, 27 por muitos ambíguos, 13 por poucos pontos, 11 sem trajeto no KMZ, 5 sem ligação ponto‑linha, 4 de corredor, 1 sem pontos perto.

**Pontos fora (4.019):** 3.606 porque nenhuma linha do ponto tinha trajeto utilizável, 393 fora da ordem (ambíguos, sentido oposto ou longe), 20 sem coordenada.

Conclusão do diagnóstico: o gargalo não era o algoritmo de busca, e sim **a regra que exigia 70 % de pontos de confiança alta**. Em vias de mão dupla, ida e volta passam a menos de 25 m, os pontos ficam com sentido "médio" e a ordem era descartada, mesmo quando concordava com a lista oficial de logradouros. Além disso: estações e terminais não existiam como nós.

---

## 2. Alterações implementadas

### 2.1 Recuperação de sequências pela lista oficial de logradouros
Novo validador (`stop_sequences.recover`): um trajeto `partial` com ≥ 5 pontos ordenados e **Spearman ≥ 0,7** entre a posição estimada e a ordem do logradouro na lista **oficial** do sentido (Cadastro de Linhas) passa a ter ordem utilizável:
- `estimated` (evidência `logradouros`) se ≤ 15 % dos pontos ficaram ambíguos;
- **`ordered`** (novo status: ordem conferida, **lista incompleta**) se mais de 15 % ficaram de fora.

`ordered` serve ao planejador e ao contexto do ponto, **não** à lista de "próximos pontos" do Meu ônibus (lista incompleta poderia pular uma parada real). Na tela, a lista aparece numerada com o aviso "Lista incompleta".

Todos os 249 trajetos recuperados têm ρ ≥ 0,9 (o limiar 0,7 não foi decisivo). Pontos ambíguos continuam fora; nada é forçado.

### 2.2 Estações do Eixo Anhanguera e do BRT Norte‑Sul
- **Estação → corredor (oficial):** as 86 estações (códigos 40000+) estão nas pastas `EIXO ANHANGUERA` (36) e `ESTAÇÕES BRT NORTE SUL` (50) do KMZ de pontos.
- **Linha → corredor (oficial):** arquivos de planilha `Eixo Anhanguera_.xlsx` (110–118, 120) e `BRT Norte-Sul_.xlsx` (NS1–NS5), e denominação "Eixo Anhanguera / …" no cadastro.
- **Linhas que não param nas estações ficam fora:** tipo `Direta` (111, 115), "Direto" (120) e "Semiexpresso" (NS2). Passar perto não é parar.
- **Estação → trajeto (geometria):** a até 30 m do trajeto oficial da linha do corredor (medido: estações a ≤ 30 m ou > 60 m, quase nada no meio).
- Resultado: associação **inferida** (nunca oficial), nível médio, utilizável no roteamento sempre como "estimada" e com o aviso "estação ou terminal: ligação inferida".
- Plataformas com o mesmo nome no corredor formam um **grupo** (mesma estação); a troca entre elas é a "baldeação na mesma estação" (§4). Qual plataforma atende cada sentido **não é informado** e a interface diz isso.
- Estações aparecem na busca ("estação", "plataforma" + nome), no mapa e no catálogo.

| Corredor | Linhas que param (associação inferida) | Linhas fora (não param) |
|---|---|---|
| Eixo Anhanguera | 110, 112, 113, 116, 117, 118 | 111, 115, 120 |
| BRT Norte‑Sul | NS1, NS3, NS4, NS5 | NS2 |

### 2.3 Terminais
- Não há terminais no cadastro de pontos. Um terminal é identificado por **duas fontes oficiais**: o nome "T. X" no primeiro/último trecho da denominação da variante e o extremo correspondente do trajeto do KMZ.
- Posição = mediana dos extremos que concordam (≤ 300 m); exige ≥ 3 extremos. 22 terminais identificados; 21 entram no grafo. Exemplos de concordância: Araguaia (mediana 17 m), Maranata (23 m), Bíblia (58 m, 89 de 95 extremos).
- Nó com id interno `T-…` (nunca mostrado como código de ponto: a tela mostra "terminal (inferido)"), **sem consulta de chegadas** e sem favorito. Busca por "terminal" + nome.
- Integração tarifária **não** é afirmada (o cadastro só tem a marca genérica "i").

### 2.4 Planejador
- Usa trajetos `estimated` **e** `ordered`.
- **Até duas baldeações**, só quando não há viagem direta nem com uma; na segunda etapa, só baldeação no mesmo ponto/terminal (sem caminhada); linhas nunca repetidas.
- Novos avisos: estação/terminal (ligação inferida) e troca de plataforma na mesma estação.
- Busca e UI: terminais e estações com ícone próprio; textos "até duas baldeações".

---

## 3. Estações integradas

86 estações (36 Eixo + 50 BRT) com código, nome do KMZ, coordenadas, corredor e grupo. As linhas associadas a cada estação ficam no contexto "No itinerário (estimado)" do ponto (derivado dos trajetos), sempre como inferência. Nenhuma estação ganhou linha só por proximidade: são exigidas as duas relações oficiais de corredor.

## 4. Conexões e baldeações

| Tipo | Classificação | Quantidade (grafo atual) |
|---|---|---|
| Mesmo ponto do cadastro, linhas diferentes | sustentada por regra conservadora (mesmo ponto físico) | 2.088 pontos com 2+ linhas (Fase 5: 892) |
| Mesmo terminal (inferido) | inferida: nome oficial + extremo do trajeto | 21 terminais |
| Plataformas da mesma estação | inferida: mesmo nome na pasta oficial do corredor | grupos de 2 plataformas |
| A pé ≤ 150 m em linha reta | **não validada**: travessia, calçada, acessibilidade desconhecidas | 2.311 pares (Fase 5: 1.350) |
| **Confirmada** (relação oficial de integração) | não existe nos dados | 0 |

Nenhuma caminhada é traçada por ruas (só a linha reta, rotulada). Nenhuma acessibilidade ou integração tarifária é declarada.

## 5. Sequências recuperadas (evidência por trajeto)

| Evidência | Status | Trajetos |
|---|---|---|
| geometria (fase 4) | estimated | 128 |
| geometria + logradouros (fase 4) | estimated | 80 |
| **logradouros** (novo) | estimated | **68** |
| **logradouros** (novo) | ordered (lista incompleta) | **181** |
| **corredor** (novo, estações) | ordered | **24** (linhas 110, 112, 116, 117, NS1, NS3, NS4, NS5) |
| **Total utilizável** | | **481** (Fase 5: 208) |

Continuam fora: 289 por sentido ambíguo sem concordância suficiente com logradouros (muitos sem lista de logradouros verificável), 61 com muitos ambíguos, 52 com poucos pontos, 16 sem ligação ponto‑linha, 8 sem pontos perto, 2 de corredor que não param nas estações, 2 sem sentido, 1 contradiz os logradouros. Circulares (início = fim): 0 no KMZ (vêm divididos em ida/volta). O relatório local `reports/coverage_diagnosis.json` lista cada trajeto, a causa e a evidência.

---

## 6. Validação de rotas reais (por evidência)

`app/test/dev_catalog/route_samples_test.dart` (só com o catálogo local) sorteia viagens reais por categoria (semente 2026) e grava `reports/route_samples.json`; `pipeline/route_validation.py` confere cada trecho contra **evidências oficiais independentes da geometria**:

1. relação ponto‑linha do Cadastro de Pontos (embarque e desembarque listam a linha?);
2. ordem dos logradouros oficiais do sentido para **todos** os pontos percorridos no trecho (pares na mesma ordem ≥ 75 % = concorda; ≤ 25 % = contradiz).

| Categoria | Viagens com rota / tentativas |
|---|---|
| Goiânia → Goiânia | 4 / 7 |
| Aparecida de Goiânia → Goiânia | 4 / 11 |
| Senador Canedo → Goiânia | 4 / 28 |
| Trindade → Goiânia | 4 / 8 |
| Goianira → Goiânia | 4 / 14 |
| Estação do Eixo → qualquer | 4 / 9 |
| qualquer → Estação do BRT | 4 / 6 |
| Terminal → qualquer | 4 / 8 |

**Resultado (32 viagens, 85 trechos):** relação ponto‑linha **oficial em 112** extremos de trecho e **inferida em 58** (estações/terminais); ordem pelos logradouros: **15 concordam, 0 contradizem**, 70 não verificáveis (trechos curtos ou que começam/terminam em terminal/estação). Todas as 32 melhores alternativas ficaram "estimadas" (avisos de estação/terminal ou ponto incerto). Retornar uma rota não prova que ela está certa: isto mede o apoio oficial, e nenhum trecho foi contradito.

Circulares: o KMZ não tem trajeto com início = fim; não houve caso para testar além dos testes sintéticos (passagem repetida).

## 7. Validação com ônibus reais (map matching)

Mecanismo da Fase 4 (`pipeline/match_eval.py`), agora com as mesmas regras de sequência do app desta fase (estações, terminais, recuperação). Duas execuções únicas em 28/10/2026, 08h38 e 08h41 (horário de pico), cada uma com no máximo 3 pontos, 4 veículos e 5 posições a cada 25 s (≤ 27 requisições à API BusãoGyn). Sem rotina e sem segundo plano. Uma execução adiada para a madrugada foi cancelada. Na madrugada (00h47 e 02h44) não havia nenhum ônibus: 0 grupos de chegada.

| Veículo | Linha | Resultado final | Variante e sentido | Próximos pontos | Leitura |
|---|---|---|---|---|---|
| v1 | 180 | sem posição | — | — | a API não devolveu posição (erro HTTP nas 5 consultas) |
| v2 | 042 | pendente (aguardando deslocamento) | 042‑1 · Volta | não | ônibus parado (5 posições idênticas) |
| v3 | 187 | pendente (aguardando deslocamento) | 187‑1 · Ida | não | ônibus parado |
| v4 | 008 | **confirmado** na 2ª amostra | 008‑1 · Ida | não (sequência `partial`) | — |
| v5 | 039 | ambíguo (fora do trajeto) | 039‑1 · Ida pelo destino | não | o destino da API indica a ida, mas as 3 últimas posições ficam a 8–9 m da **volta** e a 50 m da ida: as evidências conflitam e a recusa é o comportamento correto |
| v6 | 971 | **confirmado** na 4ª amostra (antes: recuo e trecho repetido) | 971‑1 · Volta | não (`partial`) | — |
| v7 | 003 | **confirmado** na 2ª amostra | 003‑1 · Volta | **sim, 11 pontos** | trajeto recuperado nesta fase pelos logradouros |
| v8 | 020 | ambíguo (itinerário fora do cadastro) | — | não | a API informa "T. Garavelo / T. Bíblia – via T. Isidória", que não existe no cadastro; o ônibus também estava parado |

**Contagem:** 8 veículos em 8 linhas distintas; 7 com posição atualizada (1 sem posição; nenhuma posição vencida); variante e sentido identificados em 5 (3 confirmados e 2 pendentes por estarem parados); 2 ambíguos (conflito destino × geometria; itinerário fora do cadastro); próximos pontos exibidos em 1 (003). **Nenhum caso incorreto foi detectado**: nas confirmações, o sentido pelo destino e a geometria concordaram. Mas não há gabarito independente da posição real, e 8 veículos não permitem declarar precisão geral.

Nenhum problema comprovado no algoritmo, então nenhuma regra foi alterada a partir desta amostra. A gravação da Fase 1 (linha 003), reavaliada, também passa a mostrar próximos pontos depois de confirmada (32), porque o trajeto 003‑1i foi recuperado nesta fase.

## 8. Comparação antes/depois (mesma semente e metodologia)

`flutter test test/dev_catalog/planner_metrics_test.dart` (catálogo local; 500 pares, semente 42). A amostra "pontos do grafo da fase 5" usa **o mesmo conjunto de 3.331 pontos** da Fase 5 (mesmos pares sorteados); "todos os pontos" usa o mesmo universo de códigos numéricos.

| Indicador | Antes (Fase 5) | Depois (Fase 6) |
|---|---|---|
| Trajetos elegíveis | 208 | **481** |
| Linhas cobertas | 103 | **227** |
| Pontos no planejador | 3.331 | **5.239** (5.132 do cadastro + 86 estações + 21 terminais) |
| Conexões (arestas) | 6.708 | **15.858** |
| Pontos com baldeação no mesmo ponto | 892 | **2.088** |
| Pares de baldeação a pé (≤ 150 m) | 1.350 | **2.311** |
| Cobertura da amostra elegível (pontos da Fase 5) | 6,0 % | **31,8 %** |
| Cobertura geral da amostra (todos os pontos) | 0,6 % | **17,0 %** |
| Cobertura entre pontos do grafo atual | — | 28,6 % |

Composição (amostra elegível, mesmos 500 pares): confiáveis **6 → 23** (+17: direta 4→5, 1 baldeação 2→3, 2 baldeações 0→15); estimadas **24 → 136** (+112). Amostra geral: confiáveis **0 → 7**, estimadas **3 → 78**.

Contribuição da segunda baldeação (medida antes de decidir, mesmas amostras): só com até uma baldeação a cobertura seria 10,6 % (elegível) e 5,2 % (geral); a segunda baldeação a leva a 31,8 % e 17,0 %, com busca ainda rápida (abaixo).

## 9. Testes, builds e desempenho

| Item | Resultado |
|---|---|
| Flutter (todos, nesta máquina) | **587/587** (inclui 3 testes com o catálogo real, pulados no CI por falta do arquivo) |
| Pipeline Python | 51/51 (+7: estações, corredores, terminais, recuperação, entradas de corredor e terminal) |
| Novos testes Flutter | duas baldeações só sem opção simples; mesma estação e associação inferida sinalizadas; `ordered` no planejador e fora dos próximos pontos; terminal só com id `T-…` + tipo terminal; busca de terminal; terminal sem chegadas/favorito e sem expor o id interno |
| `flutter analyze` / `dart format` | limpos |
| Web produção (release) | OK, `main.dart.js` 3.793.562 bytes; **sem dados CMTC** |
| Web desenvolvimento | OK; dados presentes (controle positivo) |
| Android produção / desenvolvimento | OK, 86,0 MB (igual) / 156,2 MB; **sem dados** / com dados |
| iOS produção / desenvolvimento (`--no-codesign`, Flutter master) | OK, 29,2 MB (igual) / 43,0 MB; **sem dados** / com dados |

**Desempenho (catálogo real, VM de teste no Mac):**

| Medida | Fase 5 | Fase 6 |
|---|---|---|
| Payload de desenvolvimento | 2,03 MB | 2,10 MB (+70 KB: terminais, grupos, evidência) |
| Decodificação | 90–150 ms | 150–190 ms |
| Montagem do grafo | ~2 ms | ~6–7 ms |
| Busca (mediana / p95 / máx., amostra elegível) | 0,01 / 0,14 / 2,9 ms | 0,13 / 1,6 / 20 ms |
| Buscas truncadas no limite | 0 | 0 |

Tudo continua na thread principal sem bloqueio perceptível; nenhum isolate nem banco foi necessário. Build de produção sem mudança de dados.

## 10. Interface (ajustes pontuais, validados no Web)

- Terminais e estações com ícone próprio no planejador e nas listas; o id interno do terminal nunca aparece (mostra "terminal (inferido)"); o cabeçalho do ponto mostra o nome do terminal.
- Busca acha "terminal pelágio" e "estação/plataforma …" acima de ruas homônimas.
- Sequência `ordered`: lista numerada com o aviso "Lista incompleta".
- Planejador: "até duas baldeações"; cartões com 3 ônibus (1º e 3º no mesmo estilo no mapa, 2º contrastante).
- Validação visual pontual (celular escuro): terminal como origem → ponto em Aparecida, 2 baldeações, mapa e cartão corretos.

## 11. Limitações

1. **Licença** — pendente; nada vai para produção.
2. **Nada disto é sequência oficial.** "Confiável" continua sendo concordância de evidências, não validação da CMTC.
3. Listas `ordered` são incompletas por definição (pontos ambíguos fora).
4. Estações: qual plataforma serve cada sentido não é conhecido; ligação estação‑linha inferida.
5. Terminais: posição pela mediana dos extremos; sem integração tarifária afirmada; sem chegadas pela API.
6. Segunda baldeação só no mesmo ponto; sem tempo de viagem nem horário.
7. 289 trajetos continuam fora por sentido ambíguo; 11 linhas não têm trajeto no KMZ.

## 12. Riscos

- Um trajeto recuperado pela lista de logradouros pode ter a lista oficial desatualizada; mitigado pelo ρ ≥ 0,9 observado e por não exibir próximos pontos em listas incompletas.
- Linhas "Ligação" do Eixo foram tratadas como paradoras nas estações (só Direta/Direto/Semiexpresso excluídas); se alguma não parar em todas as estações, o planejador pode sugerir embarque numa estação não servida — sempre como "estimada" com aviso.
- Duas baldeações aumentam a chance de uma conexão impraticável no tempo (sem horários).

## 13. Próximas prioridades

1. Pedir à CMTC: sequência oficial, relação estação‑linha por plataforma/sentido, terminais de integração e licença.
2. Rodar `match_eval.py` em pico em dias diferentes (amostras pequenas, sem rotina).
3. Validar manualmente uma amostra dos 181 trajetos `ordered` mais usados para promovê‑los ou não.
4. Acesso a pé à origem/destino (≤ 300 m, sinalizado) para quem está fora do grafo.
