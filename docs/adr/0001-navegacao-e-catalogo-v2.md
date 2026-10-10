# ADR-0001 — Navegação e catálogo da v2

- **Status:** Aceito em 10/10/2026 (decisão do proprietário do projeto).
- **Escopo desta decisão:** navegação e comportamento do catálogo. **Não implementa nada**; a implementação da navegação é o PR‑6 (HomeShell), em PR separado.

## Contexto

Hoje o app tem três destinos no dock (`AppDock` em `app/lib/src/features/transit/presentation/widgets/home_chrome.dart`, enum `HomeTab { stop, tracking, settings }`): **Chegadas**, **Meu ônibus** e **Ajustes**. A página é `StopArrivalsPage` e o fluxo é “código do ponto → chegadas → acompanhar”.

Não há catálogo de linhas/pontos, favoritos, recentes nem localização (ver `docs/MVP_UX.md` e `docs/PRIVACY.md`). O catálogo oficial depende de autorização/licença e de GTFS (protocolos `2026106554419306` e `2026106602705606`, pendentes). O contrato do upstream obriga a informar um **ponto** para consultar a posição de um ônibus (`docs/ARCHITECTURE.md`, “Busca direta por número do ônibus — bloqueada”).

## Decisão

1. A navegação da v2 terá **quatro destinos**: **Linhas**, **Pontos**, **Favoritos** e **Meu ônibus**.
2. **Ajustes** passa a ser acessível pela **TopBar**, fora do dock.
3. A tela de **Chegadas** passa a ser o **detalhe de um ponto**, dentro de **Pontos**. O painel de chegadas existente (`ArrivalsPanel`) é reaproveitado, não reescrito.
4. **Meu ônibus** continua exigindo um ponto, como no contrato atual: o acompanhamento nasce de uma chegada em tempo real de um ponto consultado.
5. A mudança é **gradual e protegida por feature flag** de compilação (proposta: `--dart-define=BUSAOGYN_V2_NAV=true`, padrão `false`, mesmo estilo de `BUSAOGYN_API_BASE_URL` e `MAP_STYLE_URL`). O nome final é definido no PR‑6. Com a flag desligada, o app é **idêntico** ao atual.
6. A flag fica **desligada em builds de release** até a validação do PR‑6 (ver `docs/v2/PR-6-home-shell-aceite.md`).
7. **Enquanto o catálogo não estiver autorizado**, Linhas e Pontos mostram **apenas funcionalidades reais** e **estados explicativos**:
   - Pontos: busca por código e chegadas (já existentes), recentes/favoritos quando existirem.
   - Linhas: sem lista oficial; estado vazio dizendo que o catálogo oficial depende de autorização. Pode haver “linhas vistas” derivadas de chegadas reais, se e quando implementado, sem criar dado novo.
8. **Nenhuma tela finge ter dados operacionais indisponíveis**: sem lista falsa de linhas, sem pontos desenhados, sem trajeto, sentido, ordem de paradas ou horários. Botão sem comportamento real não entra.
9. A UI decide o que mostrar por **capabilities** do catálogo (existe lista de linhas? de pontos? relação? sequência? sentido? shape? horários?). Em produção, hoje, todas são “não”.

## Consequências

- O mapa e o núcleo realtime não mudam (ver ADR‑0003); o PR‑6 só reorganiza o shell ao redor deles.
- O dock passa de 3 para 4 itens: o PR‑6 precisa estender os testes de fonte grande (`large_text_layout_test.dart`).
- Favoritos e recentes (PR‑5/PR‑7) podem ser entregues antes do catálogo, porque guardam só códigos digitados/vistos.
- Fica explícito que “Chegadas” deixa de ser destino de primeiro nível somente quando a flag for ativada.

## Alternativas consideradas

- Dock com 5 destinos (mantendo Ajustes): rejeitada; piora o layout com fonte grande.
- Ativar a v2 sem flag: rejeitada; risco de regressão no realtime atual.

## Referências

`docs/v2/PLANO_BUSAOGYN_V2.md` (§4, §8), `docs/MVP_UX.md`, `docs/ARCHITECTURE.md`.
