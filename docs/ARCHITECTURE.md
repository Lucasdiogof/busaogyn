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


## Canary MVP — linha 020

Em 06/10/2026, o smoke end-to-end do Worker foi executado com o ponto oficial RMTC `30402` (Terminal Garavelo - Saída Tropical), que atende a linha 020.

Resultado da execução:

- 16 grupos de chegadas no ponto;
- chegada em tempo real da linha `020`;
- `vehicleNumber = 50462`;
- consulta pelo endpoint BusãoGyn de posição retornou `routeId = 020`;
- destino `T BIBLIA`;
- coordenadas válidas;
- acessibilidade `true`;
- situação de pontualidade `Adiantado`;
- primeira consulta ETA: cache `MISS`;
- segunda consulta ETA: cache `HIT`;
- stale: `false`.

Portanto, o fluxo mínimo `ponto -> ETA realtime -> identidade do veículo -> posição individual` da linha 020 está validado de ponta a ponta.

## Busca direta por número do ônibus — bloqueada (07/10/2026)

O app não oferece busca de ônibus sem um ponto, porque a fonte exige o ponto.

Medido pelo Worker rodando localmente contra `simapp.rmtcgoiania.com.br/veiculo/recuperarposicao`, com um veículo em operação:

| `qryIdPontoParada` | Resposta da RMTC |
|---|---|
| ponto da chegada (30402) | posição + previsão para o ponto |
| ponto sem relação (00294) | mesma posição, previsão `null` |
| ausente | `{"status":"false","mensagem":"Informe o número do ponto de parada para pesquisa de tempo."}` |
| vazio | mesma recusa |

Ou seja, o ponto é obrigatório no contrato da fonte, embora a posição não dependa dele. Enviar um ponto qualquer só para destravar a consulta seria um ponto falso e não é usado. `cconaweb` (frota) segue restrito server-to-server.

Destrava quando houver: endpoint/autorização da RMTC para posição por veículo, feed de frota (`cconaweb`) liberado, ou GTFS-RT.

O rastro de posições observadas ("Posições recentes") fica para depois. Ele depende só do tracking existente, não da busca por ônibus.

## Direção da v2 (planejada — nada implementado)

Decisões registradas em [`docs/adr/`](adr/README.md); escopo e backlog em [`docs/v2/PLANO_BUSAOGYN_V2.md`](v2/PLANO_BUSAOGYN_V2.md). Esta seção descreve intenção, não o estado atual do código.

- **Navegação:** Linhas, Pontos, Favoritos e Meu ônibus, com Ajustes na TopBar e Chegadas como detalhe do ponto ([ADR‑0001](adr/0001-navegacao-e-catalogo-v2.md)). Entra por feature flag de compilação, desligada em release até a validação.
- **Dados confiáveis:** código de linha sempre `String` (`003`, `MGP1`, `NS1`); relação ponto‑linha não é ordem de percurso; sem inferir sentido, sequência, shape ou horário; sem usar o catálogo em massa da RMTC em produção sem autorização verificável; fixtures apenas sintéticas ([ADR‑0002](adr/0002-dados-confiaveis-e-nao-inferencia.md)).
- **Preservação do realtime:** o mapa (índice 0 do `Stack`, nunca recriado), `StopArrivalsCubit`, `MapVehiclesCubit` e `TransitRepository` não são refatorados pela navegação; descarte por geração, expiração em 90 s e rótulos de “observado” seguem como hoje ([ADR‑0003](adr/0003-protecao-do-mapa-e-do-realtime.md)). O Flutter continua falando só com a API BusãoGyn.
- **Gates de liberação:**
  - **A** (sem dependência externa): navegação, favoritos/recentes locais, base do catálogo com dados sintéticos, observabilidade.
  - **B** (depende de autorização/licença do catálogo): Linhas e Pontos navegáveis, busca, localização, atualização de catálogo em produção.
  - **C** (depende de GTFS ou fonte equivalente licenciada): rotas, sequência de paradas, ida/volta, shapes e horários.
- **Worker:** hoje só tem a Cache API como armazenamento; qualquer catálogo servido pelo Worker exige armazenamento durável e decisão própria (ver plano, D‑3).
