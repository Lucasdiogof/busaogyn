# Plano de implementação — BusãoGyn v2

> **Status (10/10/2026):** documento de planejamento da v2, versionado no PR‑0. **Nada aqui está implementado.** A decisão **D‑1** (navegação com quatro destinos e Ajustes na TopBar) foi **aprovada** pelo proprietário e está registrada em [ADR‑0001](../adr/0001-navegacao-e-catalogo-v2.md); as regras de dados estão no [ADR‑0002](../adr/0002-dados-confiaveis-e-nao-inferencia.md) e os invariantes do mapa/realtime no [ADR‑0003](../adr/0003-protecao-do-mapa-e-do-realtime.md). As demais decisões do §11 continuam pendentes. O contrato de aceite do PR‑6 está em [PR-6-home-shell-aceite.md](PR-6-home-shell-aceite.md).

Data do plano: 2026-10-10. Foi produzido por leitura do repositório (sem alterações) e não implementa nada. Nenhum código do SiMRmtc foi copiado.

Base de evidências: as investigações sobre a rede e o catálogo da RMTC (relatórios locais, fora deste repositório, não versionados) + leitura de `README.md`, `docs/*`, `app/lib/**`, `app/test/**`, `worker/src/**`, `.github/workflows/*`. Contagens vêm de leitura estática (não rodei `flutter test`/`npm test`). Referências a “branch `docs/readme-current-state`” descrevem o estado do repositório no momento da leitura.

Legenda: **[EXISTE]** · **[INCOMPLETO]** · **[AUSENTE]** · **[DECISÃO]** (exige sua aprovação, §11).

---

## 0. Resumo e decisões estruturantes

1. **O v2 se constrói em três camadas de liberação**, para entregar valor sem depender de licença:
   - **Gate A (sem dependência externa):** Favoritos e Recentes (por código de ponto e por par ponto‑linha, tudo local), nova navegação, base de domínio/catálogo com **fixtures sintéticas**, validação/troca atômica testadas, observabilidade. Reaproveita 100% do realtime atual.
   - **Gate B (exige autorização/licença do catálogo RMTC):** Linhas e Pontos navegáveis com o bulk oficial, busca, “perto de mim”, atualização de catálogo em produção.
   - **Gate C (exige GTFS ou fonte equivalente licenciada):** Rotas, sequência de paradas, ida/volta, shapes, horários. **Fora do escopo de implementação** deste plano; só deixamos pontos de extensão tipados.
2. **Catálogo sempre atrás de interface e de *capabilities*.** O app nunca assume que existe ordem, sentido, shape ou horário; a UI só exibe o que o `CatalogCapabilities` declara.
3. **Código de linha é `String` opaca em todo lugar** (`003`, `MGP1`, `NS1`); nunca `int`, nunca reordenado, nunca derivado de itinerário. O Worker já normaliza `^\d{1,3}$` para 3 dígitos (`worker/src/utils/normalize.ts:normalizeRouteId`); a mesma regra será espelhada no Dart com vetores de teste compartilhados.
4. **Sem bulk RMTC em produção até autorização.** Fixtures sintéticas em testes/protótipos; flag de build que **proíbe fonte `fixture` em release**.
5. **O realtime atual não é refatorado.** `StopArrivalsCubit`/`MapVehiclesCubit`/`TransitRepository` permanecem donos de ETA e posição; o v2 adiciona cubits/repositórios novos ao lado.
6. **Atualização de catálogo = snapshot completo + staging + validação + troca atômica + diff com remoções**; favoritos guardam só a intenção do usuário e **sobrevivem** a qualquer troca.

---

## 1. Auditoria do estado atual

### 1.1 Estrutura do repositório (leitura)
```
app/      Flutter 3.38.5 / Dart ≥3.10; flutter_bloc, http, maplibre_gl 0.27.1, shared_preferences
worker/   Cloudflare Worker (TS, vitest); Cache API como único armazenamento
docs/     ARCHITECTURE, MVP_UX, PRIVACY, DEPLOYMENT, MOBILE_RELEASE, brand
.github/  flutter-ci, worker-ci, worker-deploy, worker-integration-smoke, rmtc-probe
```
Estado do working tree no momento da leitura: branch **`docs/readme-current-state`** (não `main`), `app/pubspec.lock` **modificado e não commitado**, `.idea/` não rastreado. Nada disso foi tocado (ver risco R‑14).

### 1.2 Flutter — arquitetura
- **Camadas** por feature (`app/lib/src/features/transit/{domain,data,presentation}`) + `core/{config,network,map,theme,ui,settings,platform}`.
- **Injeção:** `main.dart` cria `ApiClient` → `HttpTransitRepository`; `BusaoGynApp` (`app.dart`) expõe `RepositoryProvider<TransitRepository>` e `MultiBlocProvider` com `ThemeModeCubit`, `StopArrivalsCubit`, `MapVehiclesCubit`. Parâmetros de intervalo e relógio injetáveis (testabilidade).
- **Domínio:** `Arrival`/`ArrivalGroup`/`ArrivalQuality` (`entities/arrival.dart`; `isConfirmedRealtime` é a única regra de “Tempo real”), `TrackedVehicle`/`GeoPosition` (coordenada inválida → `null`, nunca inventada), `MapVehicle`/`MarkerVariant`, `TransitSnapshot<T>` (`fetchedAt`, `stale`, `ageSeconds`), `ObservedMovement` (direção e rastro **observados**, não oficiais).
- **Repositório:** `TransitRepository` expõe só `getArrivals(stopId)` e `getVehiclePosition(vehicleNumber, stopId)`. `HttpTransitRepository` descarta grupos malformados sem derrubar os demais.
- **Rede:** `ApiClient.getJson` com timeout 20 s, mapeia erros para `ApiException` (`CLIENT_TIMEOUT`, `NETWORK_ERROR`, `INVALID_RESPONSE`), só GET.
- **Estado de tela (monólito a respeitar):** `StopArrivalsPage` (931 linhas) concentra shell, geometria responsiva, abas (`HomeTab { stop, tracking, settings }`), cabeçalho, painel (bottom sheet no celular, coluna em ≥720 px) e mapa. `AppDock` (`home_chrome.dart`) tem **3 itens**.
- **Maior risco de regressão:** `stop_arrivals_cubit.dart` (679 linhas) com gerações/tokens para descartar respostas atrasadas, timers únicos, pausa/retomada, expiração de posição (90 s). Cobertura: `stop_arrivals_cubit_test.dart` (1.210 linhas), `stop_arrivals_page_test.dart` (953), `map_vehicles_cubit_test.dart` (524) etc.

### 1.3 Mapa
- MapLibre (`maplibre_gl` 0.27.1) + OpenFreeMap; estilos claro/escuro empacotados (`assets/map/busao-{light,dark}.json`, `core/map/busao_style.dart`, `core/config/map_config.dart`); fallback para Liberty por URL.
- `TrackedVehicleMap` (857 linhas) recebe `VehicleMapBuilder` injetável (testes sem platform view), cria fontes/camadas de símbolo no `onStyleLoaded`, recria tudo a cada troca de estilo, câmera inicial no centro de Goiânia (`-16.6869, -49.2648`), `CameraFollow`/`MapFollowController`.
- **Invariante forte:** o mapa fica no índice 0 do `Stack` e **nunca é recriado** por estado/aba/sheet/tema (`stop_arrivals_page.dart`, comentário em `build`).
- **Não existe** camada de pontos de parada nem de linhas no mapa **[AUSENTE]**.

### 1.4 Localização
**[AUSENTE] por decisão documentada:** nenhuma permissão Android/iOS, sem pacote de geolocalização; o CI **falha** se o APK release tiver `LOCATION|CAMERA|…` (`flutter-ci.yml`, passo “Permissões do APK release”); `docs/PRIVACY.md` afirma “não usa a localização”; `MVP_UX.md` proíbe botão “perto de mim” sem catálogo + função real.

### 1.5 Realtime / Meu ônibus
- **[EXISTE]** acompanhamento por `vehicleNumber` + `stopId` (a fonte exige o ponto), consulta a cada 15 s, rastro/direção observados, expiração em 90 s, estados `searching/active/unavailable/failing`, `Centralizar`, secundários no mapa (até N, 3 requisições concorrentes, 30 s).
- **[INCOMPLETO]** busca por ônibus sem ponto está **bloqueada** pela fonte (`ARCHITECTURE.md`); `GET /v1/vehicles` e `/v1/routes/:id/vehicles` são **experimentais** (RMTC recusa `cconaweb` server‑to‑server: “Tipo de Acesso inválido”).

### 1.6 Previsões de chegada (ETA)
- **[EXISTE]** `GET /v1/stops/:stopId/arrivals` → grupos por linha com `next`/`following`, qualidade `realtime|scheduled|unknown`, `meta.{fetchedAt,stale,ageSeconds}`; atualização automática a cada 30 s com a aba visível; código de ponto só dígitos, zeros preservados; erros de busca sem apagar o ponto atual.

### 1.7 Favoritos / recentes
**[AUSENTE]** (nenhuma ocorrência em `app/lib`). `MVP_UX.md` prevê “pontos recentes/favoritos, persistência local, sem conta”. `shared_preferences` hoje só guarda `theme_mode` (`SharedPreferencesThemeStore`). **Implicação de privacidade:** `PRIVACY.md` diz “não guarda histórico de buscas ou de pontos consultados” → precisa ser atualizado.

### 1.8 Worker
- Rotas (`worker/src/index.ts`): `/v1/health`, `/v1/version`, `/v1/stops/:id/arrivals`, `/v1/vehicles/:n/position?stopId=`, `/v1/vehicles`, `/v1/routes/:id/vehicles`. Só GET/OPTIONS; CORS por `ALLOWED_ORIGINS`.
- Camadas: `sources/rmtc/*` (POST em `simapp…/pontoparada/previsaochegada` e `…/veiculo/recuperarposicao`; GET `rmtcgoiania.com.br/index.php?option=com_rmtclinhas&view=cconaweb&format=json`) → `services/*` (cache fresh/stale com Cache API: ETA 15 s/60 s, posição 5 s/45 s) → `index.ts`.
- `infra/http-client.ts`: timeout por tentativa + 1 retry; `logger.ts` loga método/caminho/status/duração.
- **Sem armazenamento durável:** só `caches.default` (por colo, evictável). Não há KV/R2/D1/Supabase **nem no repositório** (`wrangler.toml` só tem `[vars]`). **O catálogo precisará de armazenamento novo** **[DECISÃO]**.
- **Testes:** 15 casos (parsers + CORS); **roteamento e serviços não têm teste unitário** (só o smoke de CI) → lacuna a cobrir antes de mexer no `index.ts`.

### 1.9 CI/CD e docs
`flutter-ci` (format, analyze, test, build APK/AAB/web/iOS, guarda de permissões, páginas 16 KB), `worker-ci`, `worker-deploy` (manual, smoke de produção no ponto canário 30402), `rmtc-probe` (manual). Docs refletem decisões (“nada inventado”, realtime ≠ programado).

---

## 2. Matriz: existente × incompleto × ausente

| Capacidade | Estado | Referência real |
|---|---|---|
| Busca de ponto por código | EXISTE | `StopArrivalsCubit.load`, `search_header.dart`, `search_feedback.dart` |
| Chegadas por linha (realtime/programado) | EXISTE | `arrival.dart`, `arrivals_panel.dart`, `arrival_card.dart`, Worker `arrival.service.ts` |
| Meu ônibus (posição, rastro, follow) | EXISTE | `stop_arrivals_cubit.dart`, `tracking_card.dart`, `tracked_vehicle_map.dart`, `observed_movement.dart` |
| Outros ônibus do ponto no mapa | EXISTE | `map_vehicles_cubit.dart`, `secondary_vehicle_selector.dart` |
| Tema claro/noturno, a11y/large text | EXISTE | `theme_mode_cubit.dart`, `large_text_layout_test.dart` |
| Busca de ônibus sem ponto | INCOMPLETO (bloqueado pela fonte) | `docs/ARCHITECTURE.md` |
| Frota/linha em massa | INCOMPLETO (experimental, acesso recusado) | `vehicle.service.ts`, `cconaweb.source.ts` |
| Catálogo de linhas/pontos | AUSENTE | — |
| Favoritos / recentes | AUSENTE | — |
| Localização / pontos próximos | AUSENTE | — |
| Pontos no mapa / detalhe de linha | AUSENTE | — |
| Rotas, sequência, sentido, shape | AUSENTE (sem fonte) | `docs/MVP_UX.md` “Não fazer” |
| Horários programados | AUSENTE (sem fonte) | — |
| Persistência durável no Worker | AUSENTE | `wrangler.toml` |
| Telemetria/crash | AUSENTE por política | `docs/PRIVACY.md` |

---

## 3. Invariantes a preservar (contrato de regressão)

1. Mapa no índice 0 do `Stack`; nunca recriado por estado/aba/tema/sheet.
2. “Tempo real” só com `isConfirmedRealtime`; programado nunca parece realtime; `stale` nunca aparece como “ao vivo”.
3. Posição some do mapa com idade > 90 s; coordenada inválida → sem marcador.
4. Respostas atrasadas são descartadas por geração; atualização manual preserva o tracking; buscar outro ponto encerra o tracking.
5. Código de ponto: só dígitos, zeros à esquerda preservados (como digitado).
6. Direção/rastro são **observados**, jamais “sentido oficial”.
7. Sem coordenadas cruas na UI; mensagens técnicas do Worker nunca vão para a tela.
8. App Flutter só fala com a API BusãoGyn, nunca com RMTC.
9. Sem login, sem analytics/SDK de rastreamento, sem GPS persistido.
10. Worker: só GET; `meta.fetchedAt/stale/ageSeconds` em toda resposta; CORS restritivo.
11. CI atual verde (format, analyze, test, builds, guarda de permissões) em **todo** PR.

---

## 4. Experiência v2

### 4.1 Navegação (**[DECISÃO]** D‑1)
Dock de 4 destinos: **Linhas · Pontos · Favoritos · Meu ônibus**. “Chegadas” vira o **detalhe do ponto** dentro de **Pontos** (mesmo `ArrivalsPanel`). **Ajustes** sai do dock para um ícone na `TopBar`.
Alternativa conservadora: 5 destinos (mantém Ajustes) — pior para `large_text_layout_test` (dock já cresce com “Meu ônibus”).

### 4.2 Fluxos
- **Pontos**
  - *Gate A:* campo de código (comportamento atual), recentes, ação “favoritar”.
  - *Gate B:* busca por **nome de via** (o dado oficial é só o nome da via, ~1.252 textos repetidos em ~6.351 pontos ⇒ lista com **desambiguação** por distância e linhas atendidas, nunca “único”), pontos no mapa (círculos agrupados por zoom), “Perto de mim” (**permissão sob demanda**, PR‑10).
  - Detalhe do ponto: chegadas (existente) + “Linhas que atendem este ponto” (pertencimento, **sem ordem**).
- **Linhas**
  - *Gate A:* “Linhas vistas” derivadas das chegadas/recentes (nenhum dado novo inventado) + estado vazio explicando que o catálogo oficial depende de autorização.
  - *Gate B:* lista/busca por código ou texto do itinerário; detalhe: **itinerário como texto livre**, “Pontos atendidos” (ordenados por **nome da via** ou **distância**, rotulado “sem ordem de percurso”), mapa com **pontos** (sem linha ligando-os), ação “favoritar par ponto‑linha”.
- **Favoritos**
  - *Gate A:* favoritos de **ponto** e de **par (ponto, linha)**; painel “próximas chegadas” por favorito (reuso de `getArrivals`, fila com concorrência limitada, mesma política dos secundários); “Acompanhar” leva ao Meu ônibus existente; recentes.
- **Meu ônibus:** inalterado; novos pontos de entrada (a partir de Favoritos). Continua exigindo ponto (limitação da fonte).
- **Fora do v2:** Rotas, Horários, planejador, ocupação, “frequência indicativa” (depende de licença e tem dados defasados — ver investigação).

### 4.3 Degradação por capability
`CatalogCapabilities { hasLines, hasStops, hasMembership, hasStopSequence, hasDirections, hasShapes, hasSchedules }`. Telas sem a capability mostram **estado explicativo**, não botão morto. Em produção hoje todas = `false`; com bulk autorizado: `hasLines/hasStops/hasMembership = true`; as demais continuam `false` até o GTFS.

---

## 5. Modelo de domínio

Local: `app/lib/src/features/catalog/domain/` (nova feature, **sem** importar nada de `presentation`/`data`).

### 5.1 Tipos de valor
```dart
/// Código opaco de linha. Nunca int. Preserva exatamente o texto ('003','MGP1','NS1').
extension type const LineCode(String value) { /* validação: trim; não vazio; sem alterar */ }
/// Código de ponto: só dígitos. Forma canônica = sem zeros à esquerda para chave interna;
/// o texto digitado é preservado para chamadas à API (ver D-7).
extension type const StopId(String value) {}
```
`LineCode.normalize(String raw)` espelha `normalizeRouteId` do Worker: se `^\d{1,3}$` → `padStart(3,'0')`; senão mantém. **Vetores de teste compartilhados** (`contracts/line-code-vectors.json`): `3→003`, `03→003`, `003→003`, `1000→1000`, `MGP1→MGP1`, `NS1→NS1`, `' 020 '→020`, `''→inválido`.

### 5.2 Entidades
```dart
class TransitLine {
  final LineCode code;
  final String? itinerary;     // texto livre oficial; NUNCA parseado para inferir sentido/ordem
  final String? name;          // só se a fonte der; não derivar do itinerário
}

class TransitStop {
  final StopId id;
  final double latitude, longitude;   // validados; fora do intervalo => entidade rejeitada
  final String? streetName;           // dado oficial é só o nome da via (não identifica o ponto)
}

enum LineStopSource { membershipOnly, officialSequence }
class LineStop {                       // relação linha↔ponto
  final LineCode line;
  final StopId stop;
  final LineStopSource source;
  final int? sequence;                 // null enquanto source == membershipOnly
  final int? directionId;              // null idem
  // invariante: sequence/directionId != null  <=>  source == officialSequence
}

class CatalogVersion {
  final String versionId;              // sha256 canônico do conteúdo (lines+stops+links)
  final int schemaVersion;             // do formato interno (começa em 1)
  final CatalogSourceKind sourceKind;  // fixture | workerSnapshot | gtfs
  final String licenseRef;             // identificador da autorização/licença; vazio => proibido em release
  final DateTime fetchedAt;            // quando o BusãoGyn obteve
  final DateTime? generatedAt;         // da fonte, se existir (o bulk atual não tem)
  final CatalogCounts counts;          // stops, lines, links
  final CatalogCapabilities capabilities;
  final String? previousVersionId;
  final ValidationReport validation;   // avisos/erros resumidos
}
```
**Ligação com realtime:** `ArrivalGroup.routeId` (String) ↔ `TransitLine.code` por **igualdade de string** após `LineCode.normalize`. `stopId` das chegadas ↔ `TransitStop.id` pela forma canônica (D‑7).

### 5.3 Regras que o tipo impõe
- Nenhum construtor aceita `int` para linha; teste de reflexão/lint de revisão proíbe `int.parse` em `LineCode`.
- `LineStop.sequence` só pode existir com `officialSequence`; nenhum código de UI ordena `LineStop` “como percurso” — a lista de “pontos atendidos” usa um `StopSort` explícito (`byStreetName`, `byDistance`) e o rótulo “sem ordem de percurso”.
- **Proibido** inferir ordem/sentido/shape por coordenada, ID, nome ou texto do itinerário (regra de revisão + teste que falha se `LineStop.sequence != null` com fonte `fixture/workerSnapshot`).

### 5.4 Formato interno do snapshot (`busaogyn.catalog/1`, compacto)
```json
{ "schema": 1, "versionId": "<sha256>", "sourceKind": "fixture", "licenseRef": "TEST-ONLY",
  "capabilities": { "hasLines": true, "hasStops": true, "hasMembership": true,
                    "hasStopSequence": false, "hasDirections": false, "hasShapes": false, "hasSchedules": false },
  "lines": [ { "code": "003", "itinerary": "TERMINAL A / EIXO X / TERMINAL B" } ],
  "stops": [ { "id": "1001", "lat": -16.68, "lon": -49.25, "street": "RUA FICTICIA 1" } ],
  "links": [ [0, 0] ] }
```
`links` = pares `[índice do ponto, índice da linha]` (compacto; ~16,9 mil pares na escala real). `versionId` calculado sobre serialização canônica (ordenada por `id`/`code`).

---

## 6. Atualização de catálogo (staging, validação, troca atômica, remoções, favoritos)

### 6.1 Pipeline
```
CatalogSource.fetch()  ──► bytes + metadata (etag/data/fonte)
        │ falha => mantém versão atual; registra tentativa; backoff
        ▼
parse (em isolate: compute) ──► CatalogDraft
        ▼
STAGING: grava em  catalog/staging/<tentativaId>/…  (nunca toca current)
        ▼
VALIDATE (CatalogValidator) ──► ValidationReport
        │ erro bloqueante => descarta staging; mantém current
        ▼
DIFF vs current (CatalogDiff): adicionados / removidos / alterados (linhas, pontos, vínculos)
        │ guarda de queda: remoções > limiar => rejeita (precisa revisão)   [D-8]
        ▼
PROMOTE (troca atômica): escrever catalog/versions/<versionId>/ (completo)
        → escrever ponteiro  catalog/current.json.tmp  → rename atômico → current.json
        → manter versão anterior (rollback) → GC de versões > N (=2)
        ▼
RECONCILE favoritos (somente leitura de intenção; ver 6.3)
        ▼
EMITIR CatalogVersion nova (cubit) – UI troca índice em memória de uma vez
```
**Atomicidade:** o app só “enxerga” uma versão por vez, via `current.json` (rename no mesmo diretório = atômico em Android/iOS). Falha em qualquer etapa antes do rename deixa `current` intacto; limpeza de `staging/` na inicialização. Web: `MemoryCatalogStore` (sem persistência de 2 MB em `localStorage`) **[DECISÃO D‑2]**.

### 6.2 Regras de validação (derivadas da auditoria de 2026‑10‑10)
Bloqueantes: `id` de ponto duplicado ou vazio; `code` de linha vazio; vínculo duplicado `(stop,line)`; vínculo apontando para ponto/linha inexistente; lat/lon fora de [-90,90]/[-180,180] ou não numérico; **fora da caixa regional configurável** (heurística; hoje lat −17,20…−16,20, lon −49,80…−48,80); `schema` desconhecido; `licenseRef` vazio em build release; contagens zeradas.
Avisos (não bloqueiam, entram no relatório): ponto sem linhas; textos com U+FFFD ou espaços duplicados (normalizados **sem** alterar `code`/`id`); coordenadas idênticas em IDs distintos; endereço muito curto; códigos não numéricos/zeros à esquerda (informativo — **esperados**).
Guarda de regressão: queda >X % em pontos/linhas/vínculos vs versão atual ⇒ rejeita (X é **[DECISÃO D‑8]**, sugestão 15 %). `versionId` igual ao atual ⇒ no‑op.

### 6.3 Favoritos e remoções
- Favoritos guardam **intenção** (`stopId`, ou `stopId+lineCode`), não cópia do catálogo, em `busaogyn.favorites.v1` (JSON versionado em `shared_preferences`; pequeno).
- Troca de catálogo **nunca escreve** em favoritos. Após a troca, `FavoritesCubit` calcula o estado **derivado**: `available` (existe no catálogo) ou `notInCatalog` (“não consta no catálogo atual”). Favorito `notInCatalog` **continua funcional** para chegadas (a API de ETA aceita o código do ponto independentemente do catálogo) e é restaurado automaticamente se voltar.
- Nenhuma remoção automática; o usuário remove. Limite de favoritos (ex.: 50) **[DECISÃO D‑9]**.
- Isso desacopla Favoritos do catálogo e permite entregá‑los no **Gate A**.

### 6.4 Origem dos dados (interface)
```dart
abstract interface class CatalogSource {
  Future<CatalogFetchResult> fetch({String? ifNoneMatch});
}
```
Implementações: `AssetCatalogSource` (fixtures sintéticas, **somente debug/teste**), `WorkerCatalogSource` (futuro, PR‑13), `GtfsCatalogSource` (futuro, Gate C).

---

## 7. Arquitetura proposta

### 7.1 Flutter
```
features/
  transit/        (existente — não refatorar o núcleo realtime)
  catalog/
    domain/       entities, value types, CatalogValidator, CatalogDiff, CatalogIndex (queries), CatalogRepository (interface)
    data/         CatalogStore (interface) + Memory/File, AssetCatalogSource, WorkerCatalogSource, catalog_codec
    presentation/ CatalogCubit (status/versão/capabilities), LinesCubit, StopsCubit, páginas/painéis
  favorites/
    domain/       FavoriteStop, FavoriteLine(Pair), FavoritesRepository
    data/         SharedPreferencesFavoritesStore (schema v1, migrações)
    presentation/ FavoritesCubit, FavoritesDashboardCubit (chegadas dos favoritos)
  shell/          HomeShell (abas), TopBar/ícone de ajustes (extraído de StopArrivalsPage de forma incremental)
core/
  platform/location/ (somente PR-10)
  diagnostics/       DiagnosticsLog (buffer local, sem rede)
```
- `CatalogIndex` (em memória, construído em isolate): `stopsById`, `linesByCode`, `linesByStop`, `stopsByLine`, grade espacial (células ~0,005°) para “próximos”, índice de texto normalizado (sem acento, caixa baixa). Sem pacote novo.
- **Mapa:** camada de pontos como **GeoJSON source + circle layer** (não 7 mil símbolos), `minzoom` + filtro por viewport + limite de feições; recriada no `onStyleLoaded` como as camadas atuais; **sem** linhas entre pontos. A criação segue a invariante do mapa no índice 0.
- **Concorrência:** parse/index em `compute`; fila de ETA dos favoritos com no máximo 3 em paralelo (padrão de `MapVehiclesCubit`).
- **Navegação:** `HomeShell` mantém um único `Stack` com o mapa; troca só painel/cabeçalho (padrão atual de `_panelContent`/`_header`).

### 7.2 Worker (todo opt‑in, desligado em produção até o Gate B)
- Interface `CatalogStorage` (`get(versionId)`, `getCurrentPointer()`, `put(...)`); implementação de dev em memória/fixture; produção em **R2 ou KV** **[DECISÃO D‑3]** (a Cache API **não** serve: é por colo e evictável).
- Rotas novas, **GET apenas**:
  - `GET /v1/catalog/version` → `{ data:{versionId,schemaVersion,counts,capabilities,licenseRef,generatedAt?,fetchedAt}, meta }`
  - `GET /v1/catalog` → snapshot `busaogyn.catalog/1` gzip; `ETag: "<versionId>"`, `If-None-Match` ⇒ `304`; `Cache-Control` curto; `stale` quando servindo versão anterior.
  - Erros: `CATALOG_DISABLED` (503, `retryable:false`), `CATALOG_NOT_READY` (503, `retryable:true`).
- Ingestão (futura, **só após autorização**): job agendado (Cron Trigger) que busca a fonte autorizada, valida com **as mesmas regras do §6.2** (porta TS das regras, testada com os mesmos vetores), grava `versions/<id>` e **só então** move o ponteiro `current`. Sem sucesso ⇒ ponteiro intocado.
- Variáveis: `CATALOG_SOURCE=disabled|fixture|rmtc-bulk` (padrão `disabled`; `rmtc-bulk` exige `CATALOG_LICENSE_REF` não vazio ou o Worker se recusa a iniciar a ingestão).
- Reuso: `fetchWithPolicy`, `logEvent`, `json`/`serviceHeaders`, estilo `ServiceResult` (cache/stale) — mesmo vocabulário `fetchedAt/stale/ageSeconds`.

### 7.3 Contratos compartilhados
`contracts/` (novo, na raiz): `catalog.schema.json`, `line-code-vectors.json`, `catalog-fixture-small.json` (**sintético**). App e Worker testam contra os mesmos arquivos; CI verifica que não há cópia divergente.

---

## 8. Backlog incremental por PR

Estimativa **relativa**: S=1, M=3, L=5, XL=8. Cada PR parte de `main`, é pequeno o bastante para revisão, mantém CI verde e **não altera comportamento visível** até a flag correspondente ser ligada. Todas as novas funcionalidades nascem atrás de flags de build (`--dart-define`), com padrão **desligado em release** até o gate correspondente.

| PR | Escopo | Depende | Gate | Est. |
|---|---|---|---|---|
| **PR‑0** | ADR + docs: decisões D‑1…, guardas de “não inferir”, `PRIVACY`/`MVP_UX`/`ARCHITECTURE` rascunhos de v2; correção do estado do repo (R‑14) | aprovações | A | S |
| **PR‑1** | Domínio do catálogo: `LineCode`, `StopId`, `TransitLine`, `TransitStop`, `LineStop`, `CatalogVersion`, `CatalogCapabilities`, codec JSON `busaogyn.catalog/1`, `contracts/line-code-vectors.json` | PR‑0 | A | M |
| **PR‑2** | `CatalogValidator` + `CatalogDiff` + `ValidationReport` (puro Dart), regras do §6.2, fixtures sintéticas de mutação | PR‑1 | A | M |
| **PR‑3** | `CatalogStore` (Memory + File), staging/promote/rollback/GC com ponteiro atômico; injeção de falha; (dependência `path_provider` e `crypto` — D‑4) | PR‑2 | A | L |
| **PR‑4** | `AssetCatalogSource` + fixtures sintéticas (~300 pontos, ~25 linhas incl. `003`, `MGP1`, `NS1`; nomes fictícios) + `CatalogRepository`/`CatalogCubit` + `CatalogIndex`; guarda “fixture proibida em release” | PR‑3 | A | M |
| **PR‑5** | Favoritos e Recentes: domínio, `SharedPreferencesFavoritesStore` (schema v1 + migração), `FavoritesCubit`, estado derivado `available/notInCatalog` | PR‑1 | A | M |
| **PR‑6** | `HomeShell`: dock de 4 destinos + Ajustes na TopBar, extraído de `StopArrivalsPage` sem mudar o mapa nem o cubit de ETA | PR‑0 | A | L |
| **PR‑7** | Favoritos UI: lista, favoritar a partir de chegadas, par ponto‑linha, dashboard de próximas chegadas (concorrência limitada), “Acompanhar” | PR‑5, PR‑6 | A | M |
| **PR‑8** | Observabilidade: logs estruturados no Worker, cobertura de testes do roteamento/serviços, diagnóstico local no app (sem rede) | — | A | M |
| **PR‑9** | Pontos (UI): busca por nome (catálogo), detalhe com “linhas que atendem”, camada de pontos no mapa (circle layer) — **com fixture**, flag | PR‑4, PR‑6 | B (liga) | L |
| **PR‑10** | Linhas (UI): lista/busca, detalhe (itinerário texto + pontos atendidos sem ordem), favoritar par — **com fixture**, flag | PR‑4, PR‑6, PR‑5 | B (liga) | L |
| **PR‑11** | “Perto de mim”: permissão sob demanda, ordenação por distância; atualiza guarda de CI, PRIVACY, manifests iOS/Android | PR‑9, D‑5 | B | L |
| **PR‑12** | Worker: `CatalogStorage`, `/v1/catalog{,/version}` com ETag, `CATALOG_SOURCE=disabled` por padrão, testes de contrato; **sem ingestão real** | PR‑2 (regras), D‑3 | B | L |
| **PR‑13** | App: `WorkerCatalogSource` (GET condicional, gzip, verificação de `versionId`, backoff) + agendamento de checagem; fluxo completo staging→swap | PR‑3, PR‑12 | B | M |
| **PR‑14** | Ingestão no Worker (cron) **somente com autorização/licença** + runbook + alertas | licença, PR‑12 | B | L |
| **PR‑15** | Endurecimento: teste de integração app↔Worker local, desempenho (≈8 mil pontos), a11y, README/PRIVACY/stores | todos | A/B | M |
| **Futuro (bloqueado)** | G‑1 ingestão GTFS (`stop_times`→`LineStop.sequence`, `direction_id`) · G‑2 shapes no mapa · G‑3 horários | GTFS licenciado | C | — |

**Caminho crítico (Gate A):** PR‑0 → PR‑1 → PR‑5 → PR‑6 → PR‑7 (≈ 1+3+3+5+3 = 15 u). Em paralelo: PR‑2→PR‑3→PR‑4 (≈ 3+5+3 = 11 u) e PR‑8 (3 u). Gate A completo ≈ 29 u de esforço relativo. Gate B soma PR‑9…PR‑14 (≈ 5+5+5+5+3+5 = 28 u) mais dependências externas.

### 8.1 Escopo e critérios de aceite por PR

**PR‑0 — ADR/guardas/docs** (S)
- Escopo: `docs/adr/0001-catalog-and-capabilities.md`, `0002-no-inference.md`, atualizações de texto em `MVP_UX.md`/`ARCHITECTURE.md`/`PRIVACY.md` (favoritos locais, catálogo, localização futura).
- Aceite: ADRs aprovados; `PRIVACY.md` descreve favoritos/recentes locais e continua afirmando “sem conta/analytics”; checklist de revisão “não inferir” anexado ao template de PR; nenhum código.

**PR‑1 — Domínio** (M)
- Aceite: testes de unidade cobrem os vetores `003/3/03/MGP1/NS1/' 020 '/1000/''`; `LineStop` rejeita `sequence` com `membershipOnly`; JSON round‑trip estável (mesmo `versionId`); `TransitStop` rejeita coordenada inválida; zero dependência de Flutter no domínio; `dart analyze` limpo; sem mudança de comportamento do app.

**PR‑2 — Validação e diff** (M)
- Aceite: cada regra do §6.2 tem ≥1 teste positivo e negativo; fixtures de mutação (id duplicado, vínculo órfão, lat/lon trocadas, U+FFFD, queda >limiar); diff determinístico (ordem de entrada irrelevante); relatório serializável; 100 % das regras bloqueantes impedem promoção (teste de unidade do orquestrador).

**PR‑3 — Store + troca atômica** (L)
- Aceite: com *fake file system* e injeção de falha em cada passo (antes/depois de gravar versão, antes/depois do rename, durante GC) o estado após “reinício” é sempre `current` válido (antigo ou novo, nunca misto); `staging/` órfão é removido na inicialização; rollback restaura a versão anterior; leitura concorrente durante a promoção nunca vê versão parcial; testes em Android/iOS não são exigidos em unidade, mas há teste de integração com diretório temporário real.

**PR‑4 — Fixtures + Source + Repository/Cubit + Index** (M)
- Aceite: fixtures **100 % sintéticas** (checagem automática: nenhum `IdPontoParada` real conhecido, nomes marcados `FICTICIA`); `CatalogIndex` responde `linesByStop/stopsByLine/nearby/search` com testes (inclui busca sem acento e nomes de via repetidos ⇒ lista com desambiguação); build release com `CATALOG_SOURCE=fixture` **falha** (job de CI); parse+index de 8 mil pontos fora da thread de UI (teste mede que o isolate é usado).

**PR‑5 — Favoritos/Recentes (dados)** (M)
- Aceite: persistência com `schema:1`, migração testada (v0 vazio→v1); duplicatas ignoradas; limite aplicado; estado `available/notInCatalog` derivado **sem escrever** no store; troca simulada de catálogo (removendo o ponto favorito) **não altera** o JSON salvo; recentes limitados e sem texto livre do usuário além do código; falha de `SharedPreferences` degrada para memória (como `_themeStore`).

**PR‑6 — HomeShell (navegação)** (L)
- Aceite: dock com 4 destinos acessível (Semantics com `selected`, rótulos longos testados em `textScaler` grande, estendendo `large_text_layout_test.dart`); Ajustes acessível pela TopBar; **todos os testes existentes de `stop_arrivals_page_test.dart` passam sem alteração semântica** (ajuste mínimo de seletores permitido e listado no PR); mapa continua no índice 0 e não é recriado ao trocar de destino (teste); `dart format/analyze/test` e builds do CI verdes.

**PR‑7 — Favoritos (UI + chegadas)** (M)
- Aceite: favoritar ponto e par (ponto, linha) a partir das chegadas existentes; lista mostra próximas chegadas com **no máx. 3 requisições simultâneas** e respeitando `stale`; “Acompanhar” abre o Meu ônibus existente via `StopArrivalsCubit.track`; estados vazios/erro com texto em PT‑BR; sem coordenadas na UI; teste de widget para ponto indisponível no catálogo (continua funcionando).

**PR‑8 — Observabilidade/testes do Worker** (M)
- Aceite: testes de `index.ts` (rotas, 400/404/405, CORS, `meta`), `ArrivalService`/`VehiclePositionService` (HIT/MISS/STALE, erro com e sem stale) com `fetch` simulado; `logEvent` ganha `cache`, `upstreamStatus`, `upstreamDurationMs` (sem PII e sem IP); app ganha `DiagnosticsLog` local (buffer circular, copiável em Ajustes, **sem rede**); `PRIVACY.md` inalterado quanto a “sem telemetria”.

**PR‑9 — Pontos (UI) com fixture** (L)
- Aceite: busca por código (inalterada) e por nome (com fixture); desambiguação visível quando >1 ponto; detalhe do ponto reutiliza `ArrivalsPanel`; camada de pontos: máx. N feições (ex.: 1.500) por viewport, sem recriar o mapa, sobrevive à troca de tema/estilo (`onStyleLoaded`); com `hasStops=false` mostra estado explicativo; nenhuma linha desenhada ligando pontos.

**PR‑10 — Linhas (UI) com fixture** (L)
- Aceite: códigos `003/MGP1/NS1` listados e buscáveis exatamente; detalhe mostra itinerário **como texto**; “Pontos atendidos” ordenado por nome ou distância com rótulo “sem ordem de percurso”; testes provam que nenhuma tela ordena por ID/coordenada como percurso; com `hasStopSequence=false` não há controles de “sentido”.

**PR‑11 — Localização** (L) — **[DECISÃO D‑5]**
- Aceite: permissão só ao tocar “Perto de mim”; negada ⇒ fluxo funcional sem localização; nenhuma coordenada do usuário sai do aparelho (teste de rede/mocks); CI atualizado para permitir **somente** `ACCESS_COARSE/FINE_LOCATION` e nada mais; `PRIVACY.md` e formulários das lojas revisados; iOS `NSLocationWhenInUseUsageDescription`.

**PR‑12 — Worker: endpoints de catálogo (desligados)** (L)
- Aceite: `CATALOG_SOURCE=disabled` ⇒ `503 CATALOG_DISABLED` e **nenhum** acesso à RMTC; com fixture em dev ⇒ `ETag`/`304`; testes de contrato com os mesmos arquivos de `contracts/`; as 6 rotas atuais permanecem idênticas (teste de regressão por snapshot de resposta); smoke de deploy continua passando.

**PR‑13 — `WorkerCatalogSource`** (M)
- Aceite: GET condicional; `versionId` anunciado × calculado diferente ⇒ rejeita; corrupção (gzip/JSON) ⇒ mantém versão atual; backoff exponencial limitado; checagem ≤1/dia e ao abrir após >24 h (sem polling agressivo); testes com servidor HTTP local.

**PR‑14 — Ingestão real** (L) — **bloqueado por licença**
- Aceite: só habilita com `CATALOG_LICENSE_REF` válido; respeita `robots.txt`/termos; usa User‑Agent identificável; no máx. 1 busca/12 h; falha de validação nunca move o ponteiro; runbook de rollback manual; alerta quando `versionId` não muda há >N dias ou quando a validação falha.

**PR‑15 — Endurecimento** (M)
- Aceite: teste de integração app↔Worker local (fixture) cobrindo catálogo → favorito → chegadas → acompanhar; orçamento de desempenho (parse+index de 8 mil pontos/17 mil vínculos < alvo definido em dispositivo médio; sem jank no mapa com camada de pontos); auditoria de acessibilidade das novas telas; README/PRIVACY/MOBILE_RELEASE atualizados.

---

## 9. Estratégia de testes, observabilidade e critérios globais

### 9.1 Pirâmide
- **Unitário (maioria):** domínio, validador, diff, índice, store (fake FS), favoritos, normalizadores, cubits com relógio injetável (padrão atual).
- **Widget:** shell/dock (large text), listas, estados vazios por capability, favoritos, camada de pontos com `VehicleMapBuilder` análogo (`mapBuilder` falso) — sem platform view.
- **Integração:** app↔Worker local (`wrangler dev --local`) com fixtures; estende `scripts/smoke-local-api.mjs`.
- **Contrato:** `contracts/*` consumidos por Dart e TS.
- **Não‑regressão:** os 252 casos Dart e 15 do Worker (contagem estática) continuam passando em **todo** PR.

### 9.2 Observabilidade (compatível com `PRIVACY.md`)
- Worker: `logEvent` com `requestId`, rota, status, duração, `cache`(HIT/MISS/STALE), `upstreamStatus`, `catalogVersionId` (sem IP/PII). Métricas a acompanhar: taxa de `stale`, p95 de ETA, taxa de `SOURCE_*`, idade do catálogo, falhas de validação.
- App: `DiagnosticsLog` local (últimos ~200 eventos: troca de versão, erro de validação, tentativa de sync), exibido/copiado em Ajustes, **sem envio automático**. Qualquer SDK de telemetria/crash exige **[DECISÃO D‑6]** e atualização de privacidade.

### 9.3 Definição de pronto (todo PR)
`dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`, `npm run typecheck && npm test` (quando tocar o Worker), builds do CI, nenhuma permissão nova (exceto PR‑11), documentação e flags atualizadas, plano de rollback (desligar flag), checklist “não inferir” marcado, testes de regressão do §3 verdes.

---

## 10. Riscos

### 10.1 Técnicos
| ID | Risco | Mitigação |
|---|---|---|
| R‑1 | `StopArrivalsPage` monolítica (931 linhas) e testes acoplados | PR‑6 isolado, extração incremental, sem mexer em `StopArrivalsCubit`; manter chaves/Keys usadas pelos testes |
| R‑2 | Camada de ~7 mil pontos degrada o mapa | circle layer + `minzoom` + limite por viewport; recriar só em `onStyleLoaded`; medir (PR‑15) |
| R‑3 | Armazenamento de catálogo no Web (2 MB) | `MemoryCatalogStore` no Web (D‑2); sem `localStorage` para o snapshot |
| R‑4 | Worker sem persistência durável (Cache API é evictável) | `CatalogStorage` com R2/KV (D‑3); nunca depender de `caches.default` |
| R‑5 | **API RMTC não documentada** (ETA/posição) pode mudar, bloquear ou ser contestada; já há recusa de `cconaweb` por “tipo de acesso” | manter parsers tolerantes (já existem), testes com payloads reais anonimizados, feature degradada com mensagem clara, contrato com a RMTC (protocolos 2026106554419306 / 2026106602705606) |
| R‑6 | Casamento de IDs de ponto: bulk traz **inteiros**, a API/usuário usam texto com zeros (`00294`) | decisão D‑7; função única `StopId.canonical` + testes; experimento controlado com a API para confirmar equivalência |
| R‑7 | Casamento linha↔ETA: ETA usa `Linha` normalizada; catálogo tem `MGP*`/`NS*` | igualdade de string pós‑`normalize`; vetores compartilhados; teste com ETA fictício para esses códigos |
| R‑8 | Nome de via repetido ⇒ busca ambígua | UI de desambiguação (distância/linhas); nunca resultado “único” |
| R‑9 | Catálogo trocado enquanto um ponto está aberto/acompanhando | troca só atualiza índice; `StopArrivalsCubit` não depende do catálogo; testes de corrida |
| R‑10 | Dock com 4 itens + fonte grande | PR‑6 estende `large_text_layout_test.dart`; alternativa de 2 linhas já suportada |
| R‑11 | Gerenciar estado de refresh dos favoritos (rajada de ETA) | fila com 3 concorrentes, cache do Worker (15 s), pausa em background, limite de favoritos visíveis |
| R‑12 | Qualidade de dado herdada (textos com U+FFFD, `DistanciaKM` sem sentido, itinerários divergentes entre fontes) | normalização só de apresentação; nunca chave; ignorar campos sem semântica |

### 10.2 Legais / de produto
| ID | Risco | Mitigação |
|---|---|---|
| L‑1 | **Sem licença de redistribuição do catálogo** (© “todos os direitos reservados”; robots.txt do site restringe áreas) | Gate B só com autorização escrita; `licenseRef` obrigatório; fixtures sintéticas; nada de bulk real no repositório, no Worker ou em testes |
| L‑2 | Uso de endpoints de app de terceiros (ETA/posição) sem termos | já mitigado parcialmente por baixa frequência/cache; formalizar com RMTC; estar pronto para desligar por flag/Worker |
| L‑3 | LGPD ao introduzir localização | permissão sob demanda, processamento local, sem envio, política publicada (pendente em `PRIVACY.md`) |
| L‑4 | Rotas/horários inventados | tipos impedem (`sequence/directionId` nulos), revisão e testes; UI só por capability |
| L‑5 | Atribuição de mapas (OSM/OpenFreeMap) e licenças | já atendidas; manter ao adicionar camadas |
| L‑6 | Páginas de “frequência” RMTC defasadas (2020–2023) | **fora do v2**; só reavaliar com licença e política de defasagem |

### 10.3 Regressão
| ID | Risco | Mitigação |
|---|---|---|
| G‑1 | Quebrar o realtime atual | não refatorar cubits de ETA/tracking; PRs de UI só ao redor; suites existentes obrigatórias |
| G‑2 | Mudar contratos da API | rotas atuais congeladas por teste de snapshot (PR‑12); só adicionar |
| G‑3 | Perder o princípio “nada inventado” | ADR‑0002, checklist de PR, testes de tipo |
| G‑4 | Privacidade divergente do declarado | PR‑0 atualiza `PRIVACY.md` antes de persistir qualquer coisa nova |
| R‑14 | Árvore de trabalho atual: branch `docs/readme-current-state` com `pubspec.lock` modificado e `.idea/` não rastreado | decidir (D‑12) o que fazer antes do primeiro PR; não alterado nesta etapa |

---

## 11. Pontos que exigem sua aprovação

| # | Decisão | Recomendação |
|---|---|---|
| D‑1 | Navegação: 4 destinos (Linhas, Pontos, Favoritos, Meu ônibus) com Ajustes na TopBar | Aprovar; “Chegadas” vira detalhe de Pontos |
| D‑2 | Persistência do catálogo: arquivo (mobile) + memória (Web) | Aprovar; evitar SQLite/Drift (suporte Web e peso) |
| D‑3 | Armazenamento do snapshot no Worker (**R2** recomendado, KV alternativa) e Cron Trigger | Aprovar só no Gate B; envolve `wrangler.toml` e conta Cloudflare |
| D‑4 | Novas dependências: `path_provider`, `crypto` (SHA‑256); avaliar `geolocator` apenas no PR‑11 | Aprovar as duas primeiras; terceira separada |
| D‑5 | Localização (“Perto de mim”): permissão, ajuste do guarda de CI, PRIVACY e lojas | Adiar para depois do Gate B; decidir `COARSE` vs `FINE` |
| D‑6 | Telemetria/crash externos | **Não** adotar; manter diagnóstico local |
| D‑7 | Forma canônica de `StopId` (bulk = inteiro; API/usuário = texto com zeros) e autorização para um teste controlado de equivalência (`00294` × `294`) na API de ETA | Chave interna sem zeros; preservar o texto digitado nas chamadas; confirmar com 1–2 consultas |
| D‑8 | Limiares de validação (caixa regional, queda máxima aceitável do catálogo) | Caixa configurável; queda >15 % exige revisão manual |
| D‑9 | Semântica/limites de favoritos (ponto e par; máx. 50; sem remoção automática) | Aprovar |
| D‑10 | Manter ou remover `/v1/vehicles` e `/v1/routes/:id/vehicles` (experimentais) | Manter, sem consumo no v2 |
| D‑11 | Política de fixtures sintéticas (nomes `FICTICIA`, IDs fora da faixa real, checagem automática) | Aprovar |
| D‑12 | Base dos PRs: `main` atual e destino do `pubspec.lock` modificado / `.idea/` não rastreado | Resolver antes do PR‑0 |
| D‑13 | Autorização/licença do catálogo (quem assina, escopo de redistribuição via Worker) e GTFS | Pré‑requisito do Gate B/C; acompanhar protocolo 2026106554419306 |
| D‑14 | Escopo explícito de **fora** do v2: Rotas, Horários, “frequência indicativa”, planejador, ocupação | Confirmar |

---

## 12. Anexos

### 12.1 Esboço de contratos do Worker (rascunho, não implementado)
```
GET /v1/catalog/version
200 { "data": { "versionId": "…", "schemaVersion": 1, "counts": {"stops":N,"lines":N,"links":N},
                 "capabilities": {…}, "licenseRef": "…", "fetchedAt": "ISO", "generatedAt": null },
      "meta": { "fetchedAt": "ISO", "stale": false, "ageSeconds": 0 } }
GET /v1/catalog        (Accept-Encoding: gzip) → 200 + ETag | 304 | 503 CATALOG_DISABLED/CATALOG_NOT_READY
```

### 12.2 Vetores de teste obrigatórios (linhas)
`003`, `3`, `03`, `010`, `1000`, `MGP1`, `MGP8`, `NS1`, `NS5`, `' 020 '`, `''`. Resultado esperado documentado em `contracts/line-code-vectors.json` e consumido por Dart e TS.

### 12.3 O que explicitamente NÃO será feito
Inferir ordem/sentido/shape por coordenada, ID, nome ou itinerário; usar o bulk real em teste/produção sem autorização; persistir GPS; adicionar login ou telemetria; chamar RMTC direto do app; refatorar o núcleo realtime; tocar `main`, Supabase ou banco.
