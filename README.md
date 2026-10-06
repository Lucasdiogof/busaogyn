# BusãoGyn

**BusãoGyn — saiba onde seu ônibus está.**

Projeto Flutter + Cloudflare Worker para transporte público da RMTC de Goiânia e Região Metropolitana.

## Estado atual

A fundação do backend está em `worker/`. O app Flutter será conectado exclusivamente à API BusãoGyn; nenhuma tela deve consumir endpoints RMTC diretamente.

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
```

Veja [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
