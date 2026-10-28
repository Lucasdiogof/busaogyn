# ADR-0006 — Posições dos ônibus secundários em lote

- **Status:** Aceito em 28/10/2026. Implementado na `feat/ux-redesign`; **o Worker ainda não foi publicado** (deploy depende de autorização).
- **Escopo:** API BusãoGyn (`worker/src/index.ts`) e mapa do app (`MapVehiclesCubit`).

## Contexto

- Parado num ponto, o app consulta a posição de até 6 "outros ônibus", cada um a cada 30 s, com um pedido por ônibus. Medido no Web de produção: cerca de 15 requisições por minuto por pessoa.
- O Cloudflare Workers gratuito aceita 100 mil requisições por dia. No ritmo acima, isso dá umas 100 horas de uso por dia (risco E-8 da Etapa E). O projeto não usa serviço pago.
- A RMTC só responde por par (ônibus, ponto): o trabalho na fonte não diminui, mas os pedidos ao Worker podem diminuir.

## Decisão

1. Novo endpoint `GET /v1/stops/{stopId}/vehicle-positions?vehicles=a,b,c`:
   - de 1 a 8 números de ônibus, sem repetição, só dígitos;
   - responde a lista na ordem pedida, cada ônibus com `data` e `meta` próprios (`fetchedAt`, `stale`, `ageSeconds`) ou com `error` (`code`, `retryable`), sem detalhe interno;
   - um ônibus que falha não derruba os outros.
2. O lote usa o **mesmo** `VehiclePositionService` da rota individual:
   - mesmo cache por ônibus (5 s fresco, 45 s antigo);
   - no máximo 3 consultas simultâneas à RMTC, como o app já fazia.
   - Precisão, idade e regras de antigo não mudam.
3. O app usa o lote quando o repositório o oferece (`BatchVehiclePositions`): uma rodada a cada 30 s vira um pedido. Intervalo, limite de 6, expiração em 90 s e pausa em segundo plano não mudam.
4. Compatibilidade: se a API responder `404 NOT_FOUND` (Worker anterior), o app volta de vez, na sessão, à consulta por ônibus. Assim o app novo funciona com o Worker publicado hoje.
5. O ônibus acompanhado continua com a rota individual a cada 15 s.

## Consequências

- Medido ao mesmo tempo, mesmo ponto, mesmos 6 ônibus no mapa, Worker local com o lote:
  - antes, 15 requisições por minuto;
  - depois, 4,5 (−70%).
  - Ver `docs/BUSAOGYN_2_0_ETAPA_E_PUBLICACAO.md`, seção 16.
- A carga na RMTC não muda: mesmas consultas, mesmo cache.
- Só vale em produção depois do deploy manual do Worker, quando autorizado. Até lá, o app publicado segue com a consulta por ônibus.
- Testes: `worker/test/routing.test.ts` (lote, isolamento de falha, validação, concorrência ≤ 3); `app/test/features/transit/map_vehicles_cubit_test.dart` e `http_transit_repository_test.dart` (um pedido por rodada, falha isolada, 404 → consulta por ônibus).
