# BusãoGyn 2.0 — Plano de integração dos dados da CMTC

- **Data:** 27/10/2026 · **Status:** plano. A Fase 1 (esta) não alterou app, Worker, API, deploy nem configuração.
- **Leitura prévia:** `BUSAOGYN_AUDITORIA_COMPLETA_2026.md` (estado do app), `CMTC_2026_INVENTARIO_DADOS.md`, `CMTC_2026_QUALIDADE_DADOS.md`, `CMTC_2026_MODELO_DADOS.md`, `CMTC_2026_MAP_MATCHING.md`.

---

## 1. Conclusões que orientam o plano

1. **O ID do PED do cadastro é o `stopId` da API em tempo real** (amostra 6/6). A base da linha do cadastro é o `routeId` da API (mesma normalização). O catálogo estático encaixa no realtime atual **sem mudar a API**.
2. Os dados oficiais cobrem bem: 99,7% dos pontos com coordenada; 96,5% das variantes com trajeto por sentido; 100% das linhas principais com planilha horária.
3. A **sequência de paradas não é oficial**. Pode ser inferida com ordem validada (483/483 trajetos), mas o sentido fica ambíguo em ~20% dos pares. O ADR‑0002 proíbe essa inferência hoje.
4. **Não há licença nem condição de uso** na resposta da CMTC. O ADR‑0002 item 6 exige autorização registrada antes de usar a base em produção.
5. O app já recebe o `routeName` da RMTC (e o descarta), e ele identifica a variante pela DENOMINAÇÃO do cadastro.

---

## 2. Arquitetura proposta (sem mudar o que existe)

```text
data/cmtc/pipeline  ──gera──►  catalog/<versão>/
  (offline, CI manual)            core.json.gz        (~0,44 MB gz: linhas, variantes, pontos, pertencimento, partidas)
                                  shapes/<variante>.json  (sob demanda; todos juntos ~0,34 MB gz a 3 m)
                                  manifest.json        (versão ativa, hashes, license_status)
        │
        ├── empacotado no app (snapshot da versão aprovada)  → funciona offline desde a instalação
        └── publicado como asset estático do Worker "busaogyn-web" (Workers Assets, sem custo por requisição)
                                                                → atualização sem nova versão nas lojas

Flutter
  features/catalog (NOVO)            features/transit (INALTERADO)        features/saved_stops (INALTERADO)
  CatalogRepository                   TransitRepository → API /v1/...       favoritos por stop_id
   ├─ asset empacotado                 StopArrivalsCubit / MapVehiclesCubit
   └─ manifest + core remoto (opcional)
  índices em memória                  junção só por stop_id / routeId / routeName

Worker busaogyn-api: nenhuma mudança obrigatória.
```

### Por que JSON compacto em memória e não SQLite/Drift (por ora)

Medido com os dados reais (`reports/inventory.json` › `tamanhos`):

| Opção | Tamanho | Android/iOS | Web | Atualização | Veredito |
|---|---|---|---|---|---|
| **JSON compacto + gzip, em memória** | core 1,94 MB → **0,44 MB gz** | trivial | trivial | troca do arquivo inteiro (barato nesse tamanho) | **recomendado** |
| SQLite (Drift/sqflite) | 4,9 MB → 1,2 MB gz | bom | precisa de sqlite3.wasm + worker; mais peso e mais pontos de falha | arquivo inteiro ou migrações | só se o volume crescer muito (ex.: horários por parada) |
| GeoJSON simplificado (trajetos) | 2,1 MB → 0,34 MB gz a 3 m; 1,3 MB → 0,21 MB gz a 8 m; 6,6 MB → 1,0 MB gz sem simplificar | MapLibre lê direto | idem | por variante | **para trajetos, sob demanda** |
| Binário próprio (protobuf/flatbuffers) | menor | ok | ok | — | complexidade sem ganho nesse volume |
| Supabase / banco remoto | — | — | — | — | **desnecessário** (dados estáticos, poucos MB) |

Memória estimada no app: ~7,4 mil pontos + 426 variantes + 17,4 mil partidas + pertencimentos cabem em poucos MB de objetos Dart. Trajetos ficam fora da memória até serem pedidos.

O ADR‑0004 já previa reavaliar `shared_preferences` para o catálogo. Ele continua só para favoritos. O catálogo vai em asset/arquivo próprio, e o cache baixado em arquivo (mobile) ou Cache Storage/IndexedDB (web). Isso pede um ADR novo.

---

## 3. Fases

### Fase 2 — Governança (bloqueia produção, não bloqueia desenvolvimento)
- Pedido complementar à CMTC citando o protocolo 2026106554419306: licença/condições de uso e redistribuição, dicionário de campos, periodicidade e canal de atualização, **relação ordenada linha→sentido→pontos (item d)**, sentido/local de partida das planilhas e significado de `VR`, `INTEGRAÇÃO` e das sub‑variantes `-21`/`-31` do KMZ.
- **ADR‑0005 — Uso das bases oficiais da CMTC:** o que pode ir a produção com `license_status = pendente`.
- **ADR‑0006 — Dados estimados:** revisa o ADR‑0002 para permitir sequência/trajeto futuro **estimados**, com rótulo e capability próprios; ou mantém a proibição até chegar a fonte oficial.
- Desenvolvimento com dados reais só em builds internos até a autorização (o ADR‑0002 item 7 permite sintéticos em testes).

### Fase 3 — Catálogo estático, sem mapa novo (baixo risco, maior ganho)
1. `pipeline/export_catalog.py`: gera `core.json.gz` + `manifest.json` a partir do `build.py` (só dados **oficiais**: linhas, variantes, pontos, pertencimento, partidas).
2. `features/catalog` no Flutter: domínio (`Line`, `Variant`, `Stop`, `ScheduledDeparture`), `CatalogRepository` (asset empacotado + atualização opcional), índices em memória, testes com fixtures sintéticas.
3. Usos imediatos, todos offline:
   - **nome/endereço do ponto** no cabeçalho de chegadas, favoritos e recentes. O `SavedStop.name` já existe e hoje é sempre `null`;
   - **busca de ponto por logradouro, referência ou bairro**, além do código;
   - **aba Linhas com o catálogo real** (substitui "linhas vistas"); detalhe da linha com variantes e pontos (sem ordem);
   - **próximas partidas programadas** por linha, rotuladas "Programado (planilha OSO de dd/mm/aaaa)". Avisar quando a planilha for anterior ao ano corrente.
4. Capabilities (ADR‑0001 item 9): `hasLines`, `hasStops`, `hasStopLine`, `hasSchedules` = sim; `hasStopSequence`, `hasDirections`, `hasShapes` continuam **não**.

### Fase 4 — Mapa estático
- Camada de pontos (GeoJSON source + symbol layer), seguindo o padrão já usado para rastro e secundários (recriada em `onStyleLoaded`, sem recriar o mapa — ADR‑0003). Zoom mínimo e/ou agrupamento para ~7 mil pontos; medir no Web.
- Tocar no ponto → `StopArrivalsCubit.load(stopId)` (fluxo existente).
- Trajeto da linha **oficial** (KMZ), por variante e sentido, baixado sob demanda; estilo distinto do rastro observado.

### Fase 5 — Acompanhamento com trajeto (depende do ADR‑0006)
- Usar `TrackedVehicle.routeName` (já parseado e sem uso) + `destination` + posições observadas para escolher o trajeto (`CMTC_2026_MAP_MATCHING.md` §4). Se ficar ambíguo, **não** mostrar trajeto futuro.
- Mostrar o trajeto oficial à frente e os **próximos pontos estimados** com rótulo explícito. Mudar o texto `trackingFootnote` e os testes que hoje garantem "sem rota futura" (`stop_arrivals_page_test.dart`) de forma consciente.
- Nenhuma mudança no Worker. Se a identificação precisar de mais contexto, avaliar devolver `referenceStop`/`prediction` (já vêm do Worker).

### Fase 6 — Atualização periódica
- Workflow manual (`workflow_dispatch`) que roda o pipeline sobre novos arquivos, compara com a versão anterior (`CMTC_2026_MODELO_DADOS.md` §4) e publica o catálogo como asset do `busaogyn-web` depois de revisão humana.
- Planejamento de viagens/baldeações: **fora do escopo** até haver sequência oficial e horários por parada.

---

## 4. Impacto estimado

| Área | Impacto |
|---|---|
| Tamanho do app | +~0,5 MB (core gz empacotado); trajetos fora do pacote |
| Memória | poucos MB para o core; trajetos só da linha aberta |
| Rede | download do core só quando o manifesto muda; trajeto ~1–10 KB gz por variante |
| Worker `busaogyn-api` | **nenhuma** mudança obrigatória; carga na RMTC inalterada |
| Hospedagem | assets estáticos no `busaogyn-web` (já existente); R2 só se o volume crescer |
| Permissões | nenhuma nova nas Fases 3–5. "Pontos perto de mim" exigiria localização: mudar manifestos, a checagem de permissões no CI, `_headers` e `PRIVACY.md` |
| Código existente | `features/transit` e o Worker ficam intactos nas Fases 3–4. Na Fase 5 mudam `tracking_card.dart`, `tracked_vehicle_map.dart` (camada nova) e testes de texto |
| CI | +job de testes do pipeline Python (`unittest`, sem dependências) |

---

## 5. Riscos

| Risco | Mitigação |
|---|---|
| Uso/redistribuição não autorizados | ADR‑0005; `license_status` no manifesto; produção só com autorização registrada |
| Base envelhece (planilhas de 2022–2025, KMZ sem data) | mostrar a data de cada informação; validar na atualização |
| Sequência inferida errada mostrada como fato | só com ADR‑0006, rótulo "estimado", capability separada e esconder quando ambígua |
| Variante errada no acompanhamento | camadas de evidência; "ambíguo" é um estado válido |
| Divergências cadastro × KMZ (249 pontos > 50 m) | coordenada do cadastro como padrão, KMZ como fallback; relatório para a CMTC |
| Web com 7 mil símbolos | zoom mínimo, simplificação, medir antes |
| Três versões de Flutter (auditoria) | unificar antes da Fase 3 |

---

## 6. Próxima fase recomendada

**Fase 2 (governança) em paralelo com a Fase 3 em build interno.** Primeira entrega concreta: nome e endereço do ponto + busca por logradouro, usando só dados oficiais. Não depende de inferência nem de mudança no Worker, e resolve a maior limitação de uso apontada na auditoria: exigir o código numérico do ponto.
