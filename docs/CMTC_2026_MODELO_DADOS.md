# CMTC 2026 — Modelo de dados proposto (catálogo estático do BusãoGyn)

- **Data:** 27/10/2026 · **Status:** proposta. Nada foi alterado no app nem no Worker.
- **Base:** estrutura real dos arquivos da CMTC (`CMTC_2026_INVENTARIO_DADOS.md`) e protótipo `data/cmtc/processed/catalog_prototype.sqlite`, gerado por `build.py` para medir tamanho e consultas.
- **Princípios** (herdados do ADR‑0002 e mantidos): identificadores como **texto**, preservados como vieram; ausência = `null`, nunca suposição; todo valor carrega **proveniência** (oficial × derivado × inferido) e **versão** do catálogo.

---

## 1. Diagrama

```text
CatalogVersion 1───* SourceFile
      │ (todas as entidades têm catalog_version)
      │
Operator *───* Variant *───1 Line *───* Municipality
                  │  1
                  │  *
              Pattern (trajeto: variante + sentido + geometria)
                  │  1
                  │  *
              PatternStop (seq, along_m, provenance, confidence) *───1 Stop
                                                                      │ *
Line *───────────────── StopLine (pertencimento oficial, sem ordem) ──┘
Variant 1───* ScheduledDeparture *───1 ServiceDay
ScheduleSheet 1───* ScheduledDeparture
Terminal (derivado)   ExternalId (crosswalk entre sistemas)
```

---

## 2. Entidades

### CatalogVersion
| Campo | Tipo | Obrig. | Observação |
|---|---|---|---|
| `version_id` | text PK | sim | ex.: `cmtc-2026-10-28` (data mais recente entre os arquivos) |
| `generated_at` | timestamp | sim | |
| `reference_dates` | json | sim | por arquivo: data do nome, datas internas |
| `license_status` | enum | sim | `pendente` / `autorizado` / `restrito`; **hoje `pendente`** |
| `license_ref` | text | não | número do documento que autorizar (ADR‑0002 item 6) |
| `pipeline_commit`, `tolerance_m` | text, real | sim | reprodutibilidade |

### SourceFile (proveniência)
`file_id` PK, `version_id` FK, `name`, `sha256`, `kind` (`xlsx`/`kmz`/`pdf`), `received_at`, `document_ref` (Ofício 728/2026, Parecer 226/2026). Cada registro de outra entidade aponta para `source_file_id` + `source_locator` (aba e linha, ou nome do Placemark).

### Municipality
`municipality_id` PK (slug sem acento: `goiania`), `name` (como no cadastro). Os nomes variam entre os arquivos ("ABADIA DE GOIÁS " com espaço, "Nova Neneza"): a tabela guarda os aliases.

### Operator
| Campo | Observação |
|---|---|
| `operator_code` PK | sigla das planilhas: `RA`, `HP`, `RE`, `CO`, `MB`, `VR` |
| `name` | do cadastro: Rápido Araguaia, HP Transportes, Reunidas, Cootego, Metrobus; **`VR` sem nome confirmado** (fica `null`) |
| `provenance` | `oficial` (sigla) / `derivado` (nome casado por semelhança) |

### Line (linha comercial)
| Campo | Tipo | Obrig. | Origem |
|---|---|---|---|
| `line_id` PK | text | sim | base: `003`, `NS1`, `MGP-07`; mesma chave do `routeId` da API em tempo real |
| `display_name` | text | sim | DENOMINAÇÃO da variante Principal (ou da primeira) |
| `type`, `form`, `subsystem`, `area`, `city` | text | não | Cadastro de Linhas (podem faltar) |
| `vehicle_type` | text | não | idem |

### Variant (registro do Cadastro de Linhas)
| Campo | Tipo | Obrig. | Origem |
|---|---|---|---|
| `variant_id` PK | text | sim | `003-1` (NÚMERO original) |
| `line_id` FK | text | sim | base |
| `name` | text | sim | DENOMINAÇÃO — também chave de junção com `routeName` da RMTC |
| `characteristic` | enum | sim | Principal / Sublinha / Especial |
| `origin`, `destination` | text | não | ORIGEM/DESTINO |
| `km_outbound`, `km_inbound` | real | não | |
| `streets_outbound[]`, `streets_inbound[]` | text[] | não | itinerário descritivo oficial |
| `valid_from` | date | não | Data de Vigência (início) |
| `status` | text | sim | OPERAÇÃO (as canceladas não vieram) |
| `operator_codes[]` | text[] | não | Empresa 1/2 |

Variantes que só existem no KMZ (55) entram com `in_registry = false`, sem nome oficial.

### Pattern (trajeto por sentido)
| Campo | Tipo | Obrig. | Origem |
|---|---|---|---|
| `pattern_id` PK | text | sim | nome original do Placemark (sufixo `#n` se repetido) |
| `variant_id` FK | text | não | `null` se a variante não estiver no cadastro |
| `direction` | enum | não | `i` / `v` / `null` |
| `direction_source` | enum | sim | `sufixo` / `texto` / `ausente` |
| `description` | text | sim | texto do nome |
| `geometry` | polyline | sim | KMZ; distribuída simplificada (3 m) com polyline encoding |
| `length_m` | real | sim | derivado |
| `geometry_hash` | text | sim | detecta trajetos idênticos (15 grupos) |

### Stop (PED / estação)
| Campo | Tipo | Obrig. | Origem |
|---|---|---|---|
| `stop_id` PK | text | sim | ID do PED = `stopId` da API |
| `kind` | enum | sim | `ped` (cadastro) / `estacao` (só KMZ, 40000+) |
| `street_type`, `street`, `reference`, `number`, `district`, `locality`, `city` | text | não | cadastro |
| `direction_label` | text | não | SENTIDO (texto livre, 94 variações; não usar como regra) |
| `lat`, `lon` | real | não | cadastro (DMS → decimal); se ausente/inválido, KMZ; `null` se nenhum |
| `coord_source` | enum | sim | `cadastro` / `kmz` / `nenhuma` |
| `coord_divergence_m` | real | não | distância cadastro × KMZ (249 > 50 m) |
| `label` | text | não | nome do Placemark (estações) |

### StopLine (pertencimento oficial)
`(stop_id, line_id)` PK. Origem: LINHA 01..27 do Cadastro de Pontos. **Sem ordem e sem sentido.** É a única relação ponto↔linha oficial disponível hoje.

### PatternStop (sequência)
| Campo | Tipo | Obrig. | Observação |
|---|---|---|---|
| `pattern_id`, `seq` | PK | sim | |
| `stop_id` FK | text | sim | |
| `along_m` | real | sim | posição ao longo do trajeto |
| `provenance` | enum | sim | `inferido` (hoje, 100%) / `oficial` (se a CMTC entregar o item d ou GTFS) |
| `confidence` | real | sim | 0–1 (`sequence.py`) |
| `direction_level` | enum | sim | `alta` / `média` / `baixa` / `ambíguo` |
| `distance_m`, `passes` | real, int | sim | evidência |

### ScheduleSheet
`sheet_id` PK (`arquivo:aba`), `line_id`, `oso`, `sheet_number`, `sheet_date`, `terminal_file` (nome do arquivo = terminal), `vehicle_type`, `operational` (json por tipo de dia: intervalos, frota, tempos de viagem, extensão, início/fim), `hidden` (aba oculta → excluída), `validity` (`vigente_declarado` / `incerta`).

### ScheduledDeparture
| Campo | Tipo | Obrig. | Observação |
|---|---|---|---|
| `sheet_id` FK, `row` | | sim | rastreio |
| `variant_id` | text | sim | "Nº da Linha" (`032-1`) |
| `day_type` | enum | sim | `weekday` / `saturday` / `sunday_holiday` |
| `time` | text `HH:MM` | sim | pode passar de `24:00` |
| `trip_kind` | text | não | `VG` / `MVGI` / `MVGV` (meia viagem) |
| `operator_code` | text | não | |
| `order` | int | não | Nº de Ordem |
| `quality` | enum | sim | `programado_oficial`; **sentido e local de partida: `null`** (não informados) |

### ServiceDay / CalendarException
Os três tipos de dia das planilhas. **Feriados não vieram**: `CalendarException` fica vazia até haver fonte oficial (lista municipal/estadual + regra da CMTC).

### Terminal (derivado)
`terminal_id`, `name`, `aliases[]` (T. Maranata / Term. Maranata / Maranata_.xlsx). Derivado por texto: **não oficial** como entidade; útil para busca e agrupamento.

### ExternalId (crosswalk)
`(entity, local_id, system, external_value)` PK + `confidence` + `evidence`. Sistemas: `cmtc_cadastro`, `cmtc_kmz`, `cmtc_planilha`, `rmtc_realtime`. Conteúdo inicial = `reports/id_crosswalk.csv`.

---

## 3. Índices e consultas que o app precisa

| Consulta | Índice |
|---|---|
| ponto por código (busca atual) | PK `stop.stop_id` |
| pontos por texto (logradouro, bairro, referência) | índice de prefixo normalizado (sem acento) em memória |
| pontos visíveis no mapa | grade espacial simples (células de ~500 m) ou R‑tree se SQLite |
| linhas de um ponto | `stop_line(stop_id)` |
| pontos de uma linha | `stop_line(line_id)` |
| trajetos de uma linha / variante | `pattern(variant_id)`, `variant(line_id)` |
| próximos pontos do ônibus | `pattern_stop(pattern_id, seq)` + `along_m` |
| próximas partidas | `departure(variant_id, day_type, time)` |
| variante por `routeName` | índice da DENOMINAÇÃO normalizada |

---

## 4. Atualização entre versões

1. O pipeline gera a versão nova completa, com `version_id`, hashes e relatório de diferenças: entidades novas, removidas e alteradas, e pontos que se moveram mais de X m.
2. Validações bloqueantes: queda abrupta de contagens (ex.: −10% de pontos), IDs duplicados, coordenadas fora da RMTC acima de um limiar, `license_status`.
3. Publicação atômica: o manifesto aponta a versão ativa e a anterior continua disponível para rollback.
4. **Favoritos:** são chaveados por `stop_id` e `(stop_id, line_id)`, que são estáveis entre versões. Ponto removido do catálogo continua no favorito, marcado como "não está no cadastro atual" (nunca apagado sozinho). Isso segue o ADR‑0004.
5. Variante ou trajeto removido: dados inferidos são recalculados a cada versão; nada inferido é migrado.

---

## 5. O que o modelo deliberadamente NÃO tem
- Viagem (`trip`) com horários por parada: as planilhas só dão a partida; horários intermediários seriam **calculados**.
- Sentido da partida programada: não informado.
- Frequências como entidade separada: os intervalos estão em `ScheduleSheet.operational` (informativo).
- Qualquer dado pessoal.
