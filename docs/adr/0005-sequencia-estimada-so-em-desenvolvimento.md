# ADR-0005 — Sequência estimada e horários CMTC só em desenvolvimento

- **Status:** Aceito em 28/10/2026.
- **Escopo:** exceção **limitada e explícita** ao ADR‑0002, itens 4 e 5, válida **apenas** no build interno de desenvolvimento (`app/dev_catalog/main.dart`, gerado localmente e fora do Git). A regra de produção do ADR‑0002 **não muda**.

## Contexto

- A CMTC entregou (Ofício 728/2026, Parecer 226/2026) cadastros, trajetos KMZ e planilhas horárias OSO, mas **não** a sequência oficial de paradas nem autorização de redistribuição.
- O ADR‑0002 proíbe inferir sequência e sentido. A Fase 4 precisa avaliar, internamente, se uma sequência reconstruída pela geometria oficial é útil e segura antes de qualquer pedido formal à CMTC.
- As planilhas OSO são fonte oficial de **partidas**, mas a vigência não foi confirmada e elas não informam sentido nem local de partida.

## Decisão

1. **Só em desenvolvimento.** Sequência estimada e horários existem apenas no payload gerado por `data/cmtc/pipeline/export_catalog.py` em `app/dev_catalog/` (ignorado pelo Git). `lib/main.dart` não o importa; `loadDevCatalog` devolve `null` em release. Builds de produção são verificados por `app/scripts/check-no-official-catalog.sh` (marcadores do payload, inclusive `"trips"`, `"sequences"` e o id do método).
2. **Nunca "oficial".** A sequência é rotulada como *estimada* em toda a interface e no payload (`sequenceMethod.official = false`). Não existe nível "confirmada por relação oficial" preenchido: só existiria com fonte explícita.
3. **Ordem só com confiança.** Um trajeto só ganha ordem exibível (`estimated`) com pelo menos 5 pontos, ≥ 70 % deles de confiança alta, ≤ 15 % ambíguos e, quando houver logradouros oficiais suficientes, correlação de Spearman ≥ 0,5 com a ordem dos logradouros do cadastro. Fora disso: lista sem ordem (`partial`) ou nada (`none`). Ambíguos nunca são forçados.
4. **Próximos pontos** do Meu ônibus só com associação confirmada (variante, sentido, posição atual e projeção coerente) **e** sequência `estimated`. Nunca há horário de chegada por ponto.
5. **Horários**: só partidas, com validade explícita (`confirmed` / `recent` / `old` / `insufficient`). Data de 2026 não confirma vigência; `old` só aparece após aviso; `insufficient` não aparece. Horários de partida nunca viram horários de passagem.
6. **Promoção para produção** exige outro ADR e: autorização de redistribuição registrada na versão do catálogo, decisão da CMTC sobre vigência e, para a sequência, validação com dados oficiais ou com amostra real ampla.

## Consequências

- O ADR‑0002 continua valendo integralmente para produção.
- Os testes cobrem os dois lados: com catálogo (positivos) e sem catálogo (negativos; o build público não tem as telas nem os dados).
- Referências: `docs/BUSAOGYN_2_0_FASE_4_HORARIOS_E_PARADAS.md`, `data/cmtc/pipeline/cmtc/{timetables,stop_sequences,tracking}.py`, `app/lib/src/features/catalog/domain/{timetable,stop_sequence,route_match}.dart`.
