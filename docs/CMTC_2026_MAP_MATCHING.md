# CMTC 2026 — Associação de pontos e veículos aos itinerários (map matching)

- **Data:** 27/10/2026 · **Status:** protótipo offline, **fora do app**. Tudo o que é marcado INFERIDO aqui é heurística e **não pode ser apresentado como oficial**.
- **Código:** `data/cmtc/pipeline/cmtc/geo.py`, `sequence.py`, `matching.py`; executores `build.py`, `examples.py`, `vehicle_probe.py`.
- **Saídas:** `processed/inferred_stop_sequences.csv`, `processed/inferred_stop_direction.csv`, `processed/examples/*.geojson`, `reports/sequence_examples.md`, `reports/vehicle_probe_30402.json`.

---

## 1. Pergunta central

> Os dados permitem construir a sequência de pontos de cada itinerário?

**Não explicitamente. Sim geometricamente, com confiança mensurável e limites claros.**

- **Não existe** relação oficial linha → sentido → pontos ordenados. O item (d) do pedido não foi entregue.
- **Existe** (oficial):
  1. relação ponto → linha **sem ordem e sem sentido** (Cadastro de Pontos, LINHA 01..27);
  2. trajeto por variante e sentido com vértices **na ordem de circulação** (KMZ);
  3. sequência **ordenada de logradouros** por sentido (Cadastro de Linhas, LOGRADOURO ‑ IDA/VOLTA).
- Combinando 1 + 2, a projeção ordena os pontos. O item 3 serve de **validação independente** da ordem.

---

## 2. Método — pontos → trajeto

Para cada trajeto (variante + sentido) do KMZ:

1. **Candidatos oficiais:** só pontos cuja lista LINHA contém a base da linha. Ponto que está perto mas não pertence à linha não entra. Isso elimina a maioria das vias paralelas e dos corredores compartilhados.
2. **Projeção** em plano local equiretangular (erro desprezível na escala da RMTC). A projeção encontra **todas as passagens** do trajeto a até `tolerance_m` (padrão **25 m**). Passagens são separadas quando a posição ao longo do trajeto salta mais que 2× a tolerância. Assim, retornos em U e laços contam como duas passagens (havia um bug que fundia as duas; foi coberto por teste).
3. **Confiança** em [0, 1]: começa em 1,0; perde até 0,4 linearmente entre 15 m e a tolerância; perde 0,2 se o trajeto passa mais de uma vez perto do ponto. Abaixo de 0,5 o ponto vai para `AMBIGUO`. Fora da tolerância vai para `SEM_CORRESPONDENCIA` (normal: a base da linha agrupa pontos de todas as variantes e dos dois sentidos).
4. **Sentido do ponto na variante** (`assign_direction`), em ordem de confiabilidade:

| Nível | Regra | Quantidade |
|---|---|---:|
| alta | ponto perto de **só um** dos sentidos | 11.620 |
| média | perto dos dois; o logradouro do ponto aparece **só** na lista oficial de um sentido | 1.203 |
| baixa | perto dos dois; ≥ 10 m mais perto de um | 6.259 |
| ambíguo | perto dos dois, sem desempate | 4.720 |

5. **Sequência final do trajeto:** retira pontos atribuídos ao sentido oposto (`OUTRO_SENTIDO`, 7.496 associações) e mantém os de sentido ambíguo marcados (`INFERIDO_SENTIDO_AMBIGUO`).

Parâmetros em `sequence.Params` (tolerância, faixa sem penalidade, confiança mínima, penalidades, desempate). Linha de comando: `build.py --tolerance N`.

### Hipótese testada e descartada: lado da via
No Brasil o PED fica à direita do sentido de circulação. Medido nos dados: o lado (direita/esquerda da polilinha) concorda com a lista oficial de logradouros só ~50% das vezes (305 × 247 e 238 × 327). Provavelmente o trajeto foi desenhado no eixo da via e o PED não tem precisão lateral. Por isso a penalidade de lado é **0 por padrão** e o lado fica registrado só como informação.

---

## 3. Resultados

| Medida | Resultado |
|---|---|
| Pares oficiais ponto‑linha cobertos por alguma sequência | 16.358 / 16.476 (99,28%) |
| Ordem validada contra os logradouros oficiais (Spearman > 0,5) | **483 / 483 trajetos testáveis** (mediana ρ = 1,0) |
| Pontos por trajeto (sequência final) | mediana 28 · p10 11 · p90 66 |
| Trajetos com ponto de 2+ passagens (laços, retornos) | 185 |
| Trajetos sem nenhum ponto | 31 (linhas diretas/expressas e Eixo/BRT, cujas estações 40000+ não estão no cadastro de pontos) |

**Por que a validação é independente:** a lista de logradouros vem de outra planilha (Cadastro de Linhas), escrita à mão pela CMTC. Se o KMZ estivesse desenhado ao contrário, ou a projeção trocasse a ordem, ρ seria negativo.

### Casos difíceis inspecionados (`reports/sequence_examples.md`, GeoJSON em `processed/examples/`)

| Caso | Trajeto | Observação |
|---|---|---|
| Linha longa com 3 terminais | `003-1i`/`003-1v` (23,5 / 28,5 km) | ρ = 1,0 nos dois sentidos; terminais Garavelo e Bandeiras no meio |
| Circular | `032-1i` (5,1 km) | as 31 linhas de FORMA "Circular" vêm em ida/volta separadas no KMZ (nenhum trajeto fechado); a ordem segue o desenho |
| Variantes do Eixo | `113-1i/v`, `113-2i/v` | os primeiros ~15 km (trecho do Eixo em Goiânia) ficam sem pontos: as paradas são estações 40000+ só no KMZ. No trecho rodoviário (GO‑070), pontos dos dois lados da pista dupla entravam com 40 m; com 25 m e a regra de sentido, ficam no sentido certo |
| Laço / volta pelo mesmo corredor | `582-1v` (74,5 km) | trajeto com mais pontos de passagem múltipla (15); 122 pontos na sequência, 8 com sentido ambíguo; confiança reduzida e marcada |
| BRT | `NS1-1i` | 23 pontos na sequência (3 com sentido ambíguo), 18 atribuídos ao outro sentido, 3 longe |
| Sem pontos | `115-1i` | linha direta: não há PED associado no cadastro |

### Limitações da sequência inferida
1. **Sentido ambíguo em ~20% dos pares**, em vias de mão dupla onde ida e volta compartilham o mesmo eixo desenhado.
2. **Estações do Eixo/BRT** (40000+) ficam fora, porque não estão na relação ponto→linha. Casá‑las só por geometria seria inferência sem pertencimento oficial.
3. Pontos com coordenada divergente entre cadastro e KMZ (> 50 m, 249) podem cair longe do trajeto.
4. Variantes que compartilham geometria (15 grupos) recebem a mesma sequência.
5. **ADR‑0002** proíbe inferir sequência por coordenadas. Usar qualquer resultado disto no app exige **ADR novo**, rótulo "estimado" na interface e, de preferência, validação ou entrega oficial da CMTC.

---

## 4. Veículos: qual trajeto o ônibus acompanhado está fazendo?

### O que a fonte em tempo real dá (código atual do Worker)
`/v1/vehicles/{n}/position?stopId=` → `routeId` (base, ex.: `003`), **`routeName`** (`LinhaItinerario`, texto), `destination` (`DestinoNome`), posição, pontualidade, ponto de referência e previsão. **Não há** variante, sentido, ID de viagem nem horário da viagem. O app hoje descarta `routeName`.

### Sinais disponíveis e força medida

| Sinal | Distingue | Evidência |
|---|---|---|
| `routeId` → base | linha (`003`) | mesma normalização da API (1–3 dígitos → 3) |
| **`routeName` = DENOMINAÇÃO do cadastro** | **variante** | amostra real: "T. Maranata / Eixo T-7 / T. Paulo Garcia" → só `003-1` casa (n = 1). Offline: denominação única em 376/426 variantes (142/192 nas linhas com 2+ variantes) |
| `destination` × extremos da DENOMINAÇÃO | **sentido** (destino no último trecho = ida; no primeiro = volta) | amostra: "T PAULO GARCIA" → `i`. Offline: 422/426 variantes têm extremos sem palavras em comum |
| Distância das posições ao trajeto | variantes com traçados diferentes | mediana 6–7 m na amostra para os trajetos plausíveis |
| Progresso ao longo do trajeto entre amostras | sentido, **se** os trajetos de ida e volta divergem no local | na amostra (perto do Terminal Garavelo) ida e volta da 003‑1 avançavam no mesmo sentido: **inconclusivo** só com geometria |
| Direção observada (`ObservedMovement` do app) | o mesmo que o progresso | já existe no app |

### Algoritmo proposto (em camadas, cada uma com motivo registrado)

```text
1. candidatos = trajetos da base routeId (KMZ)
2. se routeName casa com exatamente 1 variante do cadastro → restringe à variante   [forte, oficial]
3. se destination casa com o 1º ou o último trecho da denominação → restringe ao sentido  [forte, texto oficial]
4. com ≥ 2 posições distintas e deslocamento ≥ 15 m:
      descarta trajetos onde a posição anda para trás; mediana de distância ≤ 60 m  [geométrico]
5. resultado:
      1 trajeto restante com margem sobre o 2º → "identificado" (confiança + motivos)
      mais de 1 → "ambíguo": mostrar a linha, NÃO desenhar trajeto futuro
      0 (desvio, itinerário alterado, GPS ruim) → "fora do trajeto cadastrado"
```

Implementado em `matching.rank_patterns`, `variants_by_route_name` e `direction_by_destination`, com testes. Reanálise da amostra salva sem novas consultas: `python3 -I pipeline/vehicle_probe.py 30402 --reanalyze`.

### Próximo ponto e trajeto futuro
Com o trajeto identificado: projetar a posição atual (`along_m`) e listar os pontos da sequência com `along_m` maior. É sempre **estimado**, porque a sequência é inferida e a fonte não confirma a viagem. Mudança de itinerário (desvio, obra) aparece como "fora do trajeto cadastrado" por N amostras seguidas; o app deve então parar de mostrar o futuro em vez de forçar o casamento.

### Garantias que NÃO dá para prometer
- identificação perfeita: sem ID de viagem, variantes com o mesmo `routeName` (50 de 426) e trechos compartilhados ficam ambíguos;
- sentido logo na primeira amostra, perto de terminais;
- validade em itinerários alterados que não estão no KMZ.

---

## 5. Validação pendente (precisa de dados que não temos)

1. Amostra maior de veículos (dezenas, ao longo de dias, com baixo volume de consultas) para medir a taxa de identificação de variante/sentido por `routeName` + destino.
2. Conferência manual de 20–30 sequências inferidas, com quem conhece a rede ou com a CMTC.
3. Pedido à CMTC da relação ordenada oficial (item d) ou de GTFS `stop_times`, que torna tudo isto desnecessário.
