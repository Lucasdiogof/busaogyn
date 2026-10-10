# ADR-0002 — Dados confiáveis e não inferência

- **Status:** Aceito em 10/10/2026.
- **Escopo:** regras de dados para a nova arquitetura (catálogo, favoritos, UI). Não altera o código existente.

## Contexto

O que se sabe da fonte oficial, por investigação estática e leituras públicas pontuais (2026‑10‑10):

- O catálogo em massa da RMTC traz **pontos**, **linhas** (código + itinerário em texto livre) e a **relação ponto‑linha**. **Não traz** ordem de paradas, sentido (ida/volta), geometria nem horários.
- Há códigos de linha **não numéricos** (`MGP1…MGP8`, `NS1…NS5`) e **com zeros à esquerda** (`003`). O app oficial grava a linha num campo inteiro e, por isso, rejeita os alfanuméricos.
- O endereço do ponto é só o **nome da via** (muito repetido), então não identifica o ponto.
- Não há licença de redistribuição identificada (rodapé “todos os direitos reservados”; `robots.txt` do site restringe áreas). Protocolos de GTFS (`2026106554419306`) e de lotação (`2026106602705606`) estão **pendentes**.

No código atual, a regra “nada inventado” já vale (`docs/ARCHITECTURE.md`, `docs/MVP_UX.md`), por exemplo `ArrivalGroup.routeId` é `String`, `GeoPosition.tryFromJson` devolve `null` para coordenada inválida e `ObservedMovement` só usa posições reais.

## Decisão

1. **Código de linha é sempre `String` opaca**, preservada exatamente (`003`, `MGP1`, `NS1`). Nunca `int`, nunca reordenado, nunca derivado do itinerário. A normalização de casamento espelha a do Worker (`normalizeRouteId`: numérico de 1–3 dígitos vira 3 dígitos; o resto passa inalterado) e é coberta por vetores de teste compartilhados.
2. **ID de ponto é `String`.** Zeros à esquerda não são descartados nem convertidos para inteiro antes de a equivalência entre formas (`00294` × `294`) ser **validada** contra a API. O código atual já preserva o texto digitado (`StopArrivalsCubit.load` aceita `^\d+$`; o Worker usa `normalizeStopId`). A forma canônica será decidida depois dessa validação.
3. **Relação ponto‑linha é pertencimento, não percurso.** Ela não determina ordem de paradas.
4. **Proibido inferir** ida/volta, sequência de paradas, shapes ou horários por coordenadas, ID, código de linha, nome da via ou texto do itinerário. Isso inclui “ordenar por ID/latitude e ligar com uma linha no mapa”.
5. Campos de ordem, sentido, shape e horário ficam **ausentes (`null`)** nos modelos até existir **fonte oficial licenciada** (GTFS ou equivalente), e a UI só os exibe quando as capabilities do catálogo declararem que existem.
6. **O catálogo em massa da RMTC não é consumido nem redistribuído em produção** sem autorização verificável (identificador de licença/autorização registrado na versão do catálogo). Release sem essa referência não pode usar fonte real.
7. Enquanto a licença estiver pendente, **só dados sintéticos** em fixtures, testes e protótipos (nomes e IDs claramente fictícios; nada copiado do bulk real).
8. **Distinção rígida de qualidade do dado** em toda a UI e API:

| Tipo | Significado | Onde está hoje |
| --- | --- | --- |
| Realtime confirmado | a API marcou `realtime` **e** `quality == realtime` | `Arrival.isConfirmedRealtime` |
| Programado | horário de tabela/aproximado, nunca com aparência de tempo real | `ArrivalQuality.scheduled` |
| Desconhecido | não apresentado como realtime | `ArrivalQuality.unknown` |
| Observado | derivado de posições reais recebidas nesta sessão; não é sentido oficial nem rota | `ObservedMovement` |
| Oficial estático | vindo de catálogo/GTFS licenciado, com versão e proveniência | futuro (Gate B/C) |

9. Nenhum campo ausente é preenchido por suposição; `fetchedAt` continua sendo o instante da coleta pelo BusãoGyn, não do GPS.

## Consequências

- Os tipos do catálogo (PR‑1) tornam a regra verificável: sequência/sentido só existem com origem oficial; testes proíbem conversão para inteiro.
- “Pontos atendidos” de uma linha são listados **sem ordem de percurso** (por nome da via ou distância, rotulado como tal).
- Busca por nome de via precisa de desambiguação (nome não é único).
- Rotas e Horários ficam fora da v2 até haver GTFS licenciado.

## Referências

`docs/v2/PLANO_BUSAOGYN_V2.md` (§3, §5, §6), `docs/ARCHITECTURE.md`, `docs/MVP_UX.md`.
