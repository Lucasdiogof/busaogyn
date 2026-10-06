# BusãoGyn

**BusãoGyn — saiba onde seu ônibus está.**

Projeto Flutter + Cloudflare Worker para transporte público da RMTC de Goiânia e Região Metropolitana.

## Estado atual

O backend está em `worker/` e publicado em produção no Cloudflare Workers. O app Flutter consome exclusivamente a API BusãoGyn; nenhuma tela deve consumir endpoints RMTC diretamente.

### Protocolos oficiais em andamento

- Rede estática / GTFS: `2026106554419306`
- Lotação / SIRI / capacidade: `2026106602705606`

## Worker

```bash
cd worker
npm install
npm run typecheck
npm test
npm run dev
```

Endpoints iniciais:

```text
GET /v1/health
GET /v1/version
GET /v1/vehicles
GET /v1/routes/020/vehicles
GET /v1/stops/{stopId}/arrivals
GET /v1/vehicles/{vehicleNumber}/position?stopId={stopId}
```

Veja [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Produção

API pública:

```text
https://busaogyn-api.lively-cloud-f009.workers.dev
```

O app Flutter usa essa URL por padrão. Para desenvolvimento local, sobrescreva com:

```bash
flutter run --dart-define=BUSAOGYN_API_BASE_URL=http://127.0.0.1:8787
```

O deploy do Worker executa um smoke de produção cobrindo health, ETA do ponto canário 30402, seleção de veículo realtime da linha 020, posição individual e cache.
