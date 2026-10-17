# ADR-0004 — Persistência local de favoritos e recentes

- **Status:** Aceito em 17/10/2026.
- **Escopo:** onde e como o app guarda pontos favoritos e recentes. Não cria conta, sincronização nem catálogo.

## Contexto

A navegação v2 (ADR-0001) tem a aba Favoritos e uma seção de Recentes em Pontos. O app já usa `shared_preferences` (só para o tema, com interface, implementação real, implementação em memória e queda para memória se o acesso falhar) e o plano da v2 prevê esses dados em JSON versionado nessa mesma API (`docs/v2/PLANO_BUSAOGYN_V2.md`, PR‑5, D‑9). Os dados são pequenos (até 50 favoritos e 10 recentes, só códigos e horas).

## Decisão

1. **Sem dependência nova.** Usa `shared_preferences`, que já está no app e funciona em Android, iOS e Web. Hive, Isar e SQLite não se justificam para algumas dezenas de códigos e trariam peso e mais uma superfície de manutenção. Se o volume crescer (por exemplo, catálogo local), isso se reavalia em outro ADR.
2. **Interface testável.** `SavedStopsStore` (`load`/`save`) com `SharedPreferencesSavedStopsStore` (real) e `MemorySavedStopsStore` (testes e queda quando o aparelho não guarda, marcada como `volatile` para a tela avisar).
3. **Um único documento versionado**, na chave `busaogyn.saved_stops.v1`: `{"schema":1,"favorites":[…],"recents":[…]}`. Favoritos e recentes são gravados juntos, então uma escrita nunca deixa uma lista num estado e a outra em outro.
4. **Metadados mínimos:** código do ponto, nome **só quando a fonte der um nome confiável** (hoje nenhuma dá, e o ADR‑0002 diz que o endereço não identifica o ponto), e a hora. Nenhuma previsão de chegada, posição ou texto livre é gravada.
5. **Código canônico:** os dígitos exatos, sem espaços nas pontas. Zeros à esquerda **não** são removidos, porque a equivalência entre `00294` e `294` ainda não foi validada na API (ADR‑0002, decisão 2). Sem duplicatas dentro de cada lista.
6. **Leitura tolerante:** JSON corrompido, versão desconhecida, itens inválidos e repetidos nunca derrubam o app. O app começa com o que for válido e avisa quando algo estava ilegível; a próxima gravação válida substitui o documento.
7. **Escrita serializada:** o estado em memória é a fonte da verdade e muda na hora; a gravação vem depois, uma por vez, sempre do estado mais novo. Operações rápidas em sequência não deixam estado inconsistente nem travam a tela. Falha de gravação mantém a lista, avisa e só tenta de novo na próxima operação (sem laço).
8. **Só com a flag.** Favoritos e recentes só são lidos e gravados com a navegação v2 ligada. Com a flag desligada o app publicado continua sem guardar histórico, como o `PRIVACY.md` descreve.
9. **Recentes só de consultas bem‑sucedidas:** código inválido, consulta com erro e atualização que falha nunca entram.
10. **Limites centralizados:** `defaultRecentStopsLimit = 10` e `defaultFavoriteStopsLimit = 50`. Passou do limite de favoritos, nada é removido sozinho: o app avisa.

## Consequências

- `PRIVACY.md` passa a descrever os dados guardados quando a flag estiver ligada; revisar as respostas das lojas antes de ligar a flag em release.
- Não há cache de chegadas: favoritos e recentes funcionam sem internet, mas a previsão sempre exige consulta nova.
- Mudar o formato exige novo `schema` e migração testada.

## Referências

ADR‑0001, ADR‑0002, ADR‑0003; `docs/PRIVACY.md`; `app/lib/src/features/saved_stops/`.
