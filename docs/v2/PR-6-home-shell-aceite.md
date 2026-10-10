# PR‑6 — HomeShell: contrato de aceite

- **Status:** contrato aprovado como referência; **o PR‑6 ainda não foi implementado** e não faz parte do PR‑0.
- **Decisões base:** [ADR‑0001](../adr/0001-navegacao-e-catalogo-v2.md) (navegação), [ADR‑0002](../adr/0002-dados-confiaveis-e-nao-inferencia.md) (dados), [ADR‑0003](../adr/0003-protecao-do-mapa-e-do-realtime.md) (mapa e realtime).
- **Escopo do PR‑6:** trocar o dock de três destinos (Chegadas, Meu ônibus, Ajustes) por **Linhas, Pontos, Favoritos e Meu ônibus**, com **Ajustes na TopBar**, atrás de feature flag. Reaproveita as telas existentes; **não** implementa catálogo, favoritos persistentes nem localização.
- **Implementação:** em PR separado, a partir da `main`. O PR‑6 não pode ser antecipado neste PR.

## Estado de referência (antes do PR‑6)

`StopArrivalsPage` (`app/lib/src/features/transit/presentation/pages/stop_arrivals_page.dart`) monta o `Stack` com o mapa no índice 0, o painel (bottom sheet no celular, coluna central em ≥720 px), a `TopBar`, o cabeçalho e o `AppDock` (`widgets/home_chrome.dart`, `HomeTab { stop, tracking, settings }`). Cabeçalho e painel trocam por aba (`_header()`/`_panelContent()`).

## Critérios de aceite

Cada item é verificável por teste ou por checagem manual descrita.

### 1. Quatro destinos navegáveis
- O dock mostra **Linhas, Pontos, Favoritos e Meu ônibus**, nessa ordem, com ícone e rótulo; um destino selecionado por vez, com `Semantics(selected: true)`.
- Trocar de destino atualiza cabeçalho e painel sem perder o estado dos demais (ponto carregado, tracking ativo, texto digitado).
- Teste de widget cobre a navegação entre os quatro destinos e o retorno.

### 2. Ajustes na TopBar
- Ajustes abre pelo ícone na `TopBar`, com `tooltip`/`Semantics` (“Ajustes”), alvo de toque ≥ 48 dp, e **volta ao destino anterior** ao fechar.
- O painel de Ajustes (`SettingsPanel`) é reaproveitado: tema, fontes de dados e licenças continuam funcionando.
- Teste mantém “Ajustes troca o tema e o mapa acompanha” (adaptado só no seletor de abertura).

### 3. Mapa único e persistente
- Existe **uma** instância do mapa, no índice 0 do `Stack`, em celular e em tela larga.
- Trocar de destino, abrir/fechar Ajustes, mudar tema, arrastar o sheet ou redimensionar **não recria** o mapa.

### 4. Nenhuma recriação de MapLibre durante troca de abas
- **Novo teste obrigatório** (hoje não existe, ver ADR‑0003): usando o `mapBuilder` falso, contar criações/`dispose` do widget do mapa e provar `1` criação após percorrer os quatro destinos, Ajustes e a troca de tema.
- Os testes de estilo existentes (`transit_map_style_test.dart`) continuam passando sem alteração.

### 5. Fonte grande, acessibilidade e responsividade
- `large_text_layout_test.dart` é **estendido** para o dock de quatro destinos: sem corte de rótulo (“Meu ônibus” em duas linhas quando necessário), alvos de toque ≥ 48 dp, `Chrome.dockLayout` medindo corretamente.
- Verificado em tamanhos de celular pequeno e grande, e em largura ≥ 720 px (coluna central), com `textScaler` normal e ampliado.
- Todos os controles novos têm `Semantics`/`tooltip`; estado selecionado não depende só de cor.
- O teste de ordem de foco/leitor de tela cobre dock e TopBar.

### 6. Reaproveitamento de Chegadas e Meu ônibus
- Chegadas aparece como **detalhe do ponto** dentro de **Pontos**, usando o `ArrivalsPanel`, `SearchHeader` e `ContextHeader` existentes.
- Meu ônibus usa `TrackingCard` e o cabeçalho de tracking existentes, com o mesmo comportamento (follow, centralizar, detalhes).
- `StopArrivalsCubit`, `MapVehiclesCubit` e `TransitRepository` **não são modificados**. Os testes `stop_arrivals_cubit_test.dart`, `map_vehicles_cubit_test.dart`, `map_vehicles_cubit_expiry_test.dart` passam **sem alteração**. Em `stop_arrivals_page_test.dart` só são aceitos ajustes de seletor de navegação, listados no PR.

### 7. Nenhum botão sem comportamento real
- Todo controle visível faz algo real. Itens ainda sem backend (Linhas e Favoritos antes dos PRs de dados) aparecem como **estado explicativo**, nunca como botão que não faz nada.
- Revisão manual + teste de widget verificam que não há `onPressed: null` indevido nem “em breve” disfarçado de função.

### 8. Estados vazios claros para catálogo indisponível
- **Linhas:** texto explicando que a lista oficial depende de autorização do catálogo; sem lista inventada.
- **Pontos:** busca por código funciona como hoje; sem catálogo, não há busca por nome nem pontos desenhados no mapa.
- **Favoritos:** estado vazio explicando que favoritos locais virão com o PR de favoritos (ou, se o PR‑5/PR‑7 já estiver integrado, o fluxo real).
- Os textos estão em português, sem jargão técnico, com `Semantics` adequada.

### 9. Nenhum impacto nos endpoints ou contratos do Worker
- Zero mudança em `worker/`, em rotas `/v1/*`, em `ApiClient`, em `HttpTransitRepository` ou em `ApiConfig`.
- Nenhuma chamada nova à API; o Flutter continua só falando com a API BusãoGyn.
- O smoke de deploy continua válido sem alteração.

### 10. Feature flag desligada em release até validação
- Flag de compilação (proposta `BUSAOGYN_V2_NAV`, padrão `false`). Com `false`, o app é **idêntico** ao atual (testes existentes verdes sem a flag).
- Os testes do shell novo rodam com a flag `true` por injeção no widget, não dependendo de `--dart-define` global.
- O CI ganha uma verificação que **falha** se um build release for gerado com a flag `true` antes da validação (a validação é registrada em ADR ou nota de release).

## Critérios gerais (todo PR)

- `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test` e os builds do `flutter-ci.yml` verdes.
- Nenhuma dependência, permissão ou SDK novo.
- `pubspec.lock` **não** alterado.
- Documentação (`MVP_UX.md`, `README.md`) atualizada somente no que passar a existir.

## Fora do escopo do PR‑6

Catálogo, `LineCode`/`TransitStop`, favoritos persistentes, recentes, localização, camada de pontos no mapa, qualquer mudança no Worker, Rotas e Horários.

## Pendências para iniciar o PR‑6

1. PR‑0 revisado e integrado na `main`.
2. Confirmar o nome final da flag e o texto dos estados vazios.
3. Decidir o destino padrão ao abrir o app com a flag ligada (proposta: **Pontos**).
4. Resolver a base dos PRs (ver D‑12 do plano) e a divergência de `README.md` entre `main` e `docs/readme-current-state`.
