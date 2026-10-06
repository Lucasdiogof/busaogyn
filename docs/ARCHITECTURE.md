# BusãoGyn — arquitetura base

## Princípio

O app Flutter nunca acessa RMTC/RedeMob diretamente. Toda integração externa fica atrás da API BusãoGyn no Cloudflare Worker.

```text
RMTC / RedeMob -> adapters Worker -> domínio BusãoGyn -> /v1 -> Flutter
```

## Fontes já mapeadas

- `cconaweb&linha=000`: snapshot da frota/posição.
- `pontoparada/previsaochegada`: ETA estruturado por ponto.
- rede estática/GTFS: aguardando protocolo SIC `2026106554419306`.
- occupancy/SIRI/capacidade: aguardando protocolo SIC `2026106602705606`.

## Regras

- nenhum campo ausente é inventado;
- `fetchedAt` é o instante da coleta pelo BusãoGyn, não timestamp do GPS;
- realtime e programado são explicitamente distintos;
- último snapshot pode ser servido como `stale` apenas por janela curta;
- GPS cru não é persistido no Supabase no MVP;
- IDs externos são tratados como strings.

## API inicial

- `GET /v1/health`
- `GET /v1/version`
- `GET /v1/vehicles`
- `GET /v1/routes/:routeId/vehicles`
- `GET /v1/stops/:stopId/arrivals`

A rede estática e occupancy entram como módulos opcionais quando as respostas oficiais chegarem.
