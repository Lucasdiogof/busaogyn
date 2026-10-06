# BusãoGyn — arquitetura base

## Princípio

O app Flutter nunca acessa RMTC/RedeMob diretamente. Toda integração externa fica atrás da API BusãoGyn no Cloudflare Worker.

```text
RMTC / RedeMob -> adapters Worker -> domínio BusãoGyn -> /v1 -> Flutter
```

## Fontes já mapeadas

- `pontoparada/previsaochegada`: ETA estruturado por ponto; validado ao vivo em 06/10/2026.
- `veiculo/recuperarposicao`: posição individual; validado ao vivo em 06/10/2026 usando `NumeroOnibus` do ETA como `qryIdVeiculo`.
- `cconaweb&linha=000`: contrato conhecido de frota/posição, porém o acesso server-to-server testado em GitHub Actions foi recusado pela RMTC com `Tipo de Acesso inválido`; não é dependência do MVP até nova validação/autorização.
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
- `GET /v1/vehicles` — experimental enquanto `cconaweb` estiver restrito server-to-server
- `GET /v1/routes/:routeId/vehicles` — experimental pela mesma razão
- `GET /v1/stops/:stopId/arrivals`
- `GET /v1/vehicles/:vehicleId/position?stopId=:stopId` — caminho validado via SiMRmtc

A rede estática e occupancy entram como módulos opcionais quando as respostas oficiais chegarem.


## Evidência operacional de IDs — 06/10/2026

Um probe de baixa frequência executado fora da rede da RMTC confirmou, em três amostras distintas, o fluxo:

```text
previsaochegada.NumeroOnibus
        ↓
qryIdVeiculo
        ↓
recuperarposicao.data[0].Numero
```

A chamada individual também retornou `LinhaNumero`, posição, destino, acessibilidade, situação e previsão. Isso confirma operacionalmente que `NumeroOnibus` pode ser usado como identificador de veículo no endpoint `recuperarposicao`. A equivalência desse identificador com `cconaweb.Numero` continua não medida porque o feed de frota recusou o contexto server-to-server.
