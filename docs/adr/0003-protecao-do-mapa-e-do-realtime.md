# ADR-0003 — Proteção do mapa e do realtime

- **Status:** Aceito em 10/10/2026.
- **Escopo:** invariantes que a v2 não pode quebrar. Registra o comportamento **atual** (commit base `670d98d`).

## Contexto

O núcleo realtime e o mapa já passaram por várias correções de corrida, expiração e acessibilidade. A v2 adiciona navegação, catálogo e favoritos **ao redor** desse núcleo.

## Invariantes (com referência ao código)

1. **O mapa fica no índice 0 do `Stack` e nunca é recriado** por estado do Cubit, aba, arrastar o sheet, tema ou redimensionar (`app/lib/src/features/transit/presentation/pages/stop_arrivals_page.dart`, comentário “Índice 0 fixo em ambos os layouts”, ~linha 297). Estilo e camadas são recriados **dentro** da mesma instância em `onStyleLoaded` (`widgets/tracked_vehicle_map.dart`), coberto por `transit_map_style_test.dart`.
   - **Lacuna conhecida:** nenhum teste existente conta criações da instância do mapa; a garantia hoje é por construção e comentário. O PR‑6 deve **adicionar** esse teste (ver `docs/v2/PR-6-home-shell-aceite.md`).
2. **A instância MapLibre não pode ser recriada** ao trocar abas, tema, painel ou estado. O app usa `VehicleMapBuilder` injetável para testes sem platform view.
3. **`StopArrivalsCubit`, `MapVehiclesCubit` e `TransitRepository` não são refatorados** no PR‑0 nem como parte do HomeShell (PR‑6). Mudança futura nesses arquivos exige PR/ADR próprio com a suíte existente **inalterada** (`stop_arrivals_cubit_test.dart`, `map_vehicles_cubit_test.dart`, `map_vehicles_cubit_expiry_test.dart`, `stop_arrivals_page_test.dart`).
4. **Atualizações atrasadas são descartadas por geração:** `_arrivalsGeneration` e `_trackingGeneration` no `StopArrivalsCubit`; `_generation` no `MapVehiclesCubit`. Testes: “resposta atrasada de um ponto anterior é descartada”, “resposta atrasada do ônibus anterior é descartada”, “geração antiga não ressuscita nem remove”.
5. **A posição do veículo expira após 90 segundos:** `positionMaxAge` (`StopArrivalsCubit`) e `maxStaleAge` (`MapVehiclesCubit`), ambos 90 s. Fronteira testada (89 s e 90 s aparecem; 91 s some). Só a coordenada sai; linha, destino e rastro ficam.
6. **Rastreamento, pausa/retomada, atualização manual e troca de ponto mantêm o comportamento atual:**
   - consulta de posição a cada ~15 s; chegadas a cada ~30 s só com a aba Chegadas à vista;
   - `pause()`/`resume()` (segundo plano) param/religam timers, sem rajada ao retomar (`resumeRefreshAfter` = 10 s);
   - atualizar chegadas **preserva** o tracking; buscar **outro ponto** encerra o tracking; acompanhar outro ônibus troca o tracking e limpa a posição anterior.
7. **Direção e rastro são “observados”**: vêm de posições reais recebidas na sessão (`ObservedMovement`), nunca são “sentido oficial” e não são rota/itinerário. A UI mantém esses rótulos.
8. **O Flutter acessa exclusivamente a API BusãoGyn** (`ApiConfig.baseUrl`, `ApiClient`); nunca a RMTC diretamente. Integrações externas ficam no Worker.
9. **A tela é honesta sobre frescor:** “Tempo real” só com `isConfirmedRealtime`; dado antigo aparece como desatualizado, nunca como “ao vivo”; sem coordenadas cruas como informação principal.
10. **Sem novas permissões, SDKs de telemetria ou dependências** como efeito colateral da navegação (o CI falha se o APK release pedir localização, câmera etc.).

## Decisão

Os invariantes acima são o **contrato de regressão** da v2. Todo PR da v2 deve mantê‑los e provar isso com a suíte existente verde. Se um PR precisar tocar um invariante, ele abre um ADR novo antes.

## Consequências

- O HomeShell (PR‑6) só reorganiza painel, cabeçalho e dock; o mapa e os cubits de realtime permanecem como estão.
- Novos cubits (catálogo, favoritos) ficam **ao lado** dos existentes, sem depender do catálogo para chegadas ou tracking.

## Referências

`docs/v2/PLANO_BUSAOGYN_V2.md` (§3, §7), `docs/MVP_UX.md`, `docs/ARCHITECTURE.md`.
