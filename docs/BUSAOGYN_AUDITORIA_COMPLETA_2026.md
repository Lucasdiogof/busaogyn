# BusãoGyn — Auditoria técnica e funcional completa (2026)

- **Data da auditoria:** 27/10/2026
- **Repositório:** `busaogyn` (monorepo: `app/` Flutter, `worker/` Cloudflare Worker, `docs/`)
- **Branch / commit auditado:** `main` em `758adac` (24/10/2026), sincronizada com `origin/main`
- **Escopo:** somente leitura. Nenhum código de produção, configuração, banco, deploy ou commit foi alterado. O único arquivo criado é este documento.
- **Público-alvo:** quem (pessoa ou IA) vai planejar a evolução do app com as bases oficiais da CMTC/RMTC sem ter visto o projeto antes.

## Legenda de evidência

Cada afirmação relevante leva uma etiqueta:

| Etiqueta | Significado |
|---|---|
| **[CÓDIGO]** | CONFIRMADO NO CÓDIGO — lido no código-fonte executado (com caminho e linha). |
| **[TESTE]** | CONFIRMADO EM TESTE — confirmado por teste automatizado executado nesta auditoria **ou** por chamada real à API de produção feita em 27/10/2026. |
| **[DOC]** | DOCUMENTADO, MAS NÃO VERIFICADO — consta em `docs/`/README, não foi reproduzido aqui. |
| **[HIPÓTESE]** | Inferência razoável que precisa de verificação. |
| **[AUSENTE]** | NÃO IMPLEMENTADO — procurado e não encontrado no código. |

Caminhos são relativos à raiz do repositório. "`arquivo:N`" indica linha.

## Estado do Git no início da auditoria

- Branch `main`, em dia com `origin/main`. Branches extras: `backup/pre-rebase-busaogyn-617d209` (local), `origin/claude/charming-pascal-4rvfwo`, `origin/claude/eager-mendel-jpk57h`, `origin/web/custom-domain`.
- Alterações **não commitadas pré-existentes** (não feitas por esta auditoria e preservadas): `app/ios/Podfile.lock`, `app/ios/Runner.xcodeproj/project.pbxproj`, `app/pubspec.lock` (modificados) e as pastas `xcshareddata/swiftpm/` do Xcode (não rastreadas). São resíduos da migração iOS para Swift Package Manager (commit `afdad14`) e de um `pub get` feito com um Flutter mais novo que o do CI (ver §11).
- 59 commits, de 06/10/2026 a 24/10/2026.

---

## 1. Resumo executivo

O BusãoGyn é um app Flutter (Android, iOS e Web) **"map-first" de consulta de chegadas por código de ponto e acompanhamento de um ônibus em tempo real**, servido por uma API própria em um Cloudflare Worker que faz proxy, normalização e cache curto de **três endpoints não documentados publicamente da RMTC** (`simapp.rmtcgoiania.com.br` e `rmtcgoiania.com.br`).

O que existe e funciona de verdade:

1. Digitar o **código numérico** de um ponto → ver, por linha, o próximo e o seguinte ônibus (minutos, "Tempo real" × "Programado").
2. Tocar em uma chegada em tempo real → **acompanhar o ônibus** no mapa (consulta a cada 15 s), com marcador animado, **direção observada** e **rastro do caminho já percorrido** (últimas ~20 posições, só em memória).
3. Ver no mapa até 6 **outros ônibus em tempo real** do mesmo ponto (consulta a cada 30 s).
4. **Favoritos** de pontos e de pares ponto+linha, **recentes**, consulta sob demanda das chegadas dos favoritos — tudo local em `shared_preferences`.
5. Tema claro/escuro/sistema, idiomas pt/en/es (automático), layout responsivo (sheet no celular, coluna central ≥ 720 px).

O que **não existe** (por decisão explícita de arquitetura, ADR‑0002, e por falta de fonte):

- **Nenhum dado estático da rede**: não há catálogo de linhas, cadastro de pontos, nomes/endereços de pontos, coordenadas de pontos, geometria de trajetos, sequência de paradas, sentido (ida/volta) ou quadro de horários. A aba "Linhas" lista apenas linhas **vistas** nas consultas da sessão e nos favoritos.
- **Nenhuma busca por nome/endereço, nenhuma localização do usuário**, nenhum mapa de pontos, nenhum trajeto futuro, nenhum planejamento de viagem.
- **Nenhum armazenamento estruturado** (sem Supabase, SQLite, Hive, Isar, Firebase). Só `shared_preferences` no app e Cache API no Worker.
- **Offline**: só a interface, favoritos/recentes e o mapa base já em cache do motor de mapas. Nenhuma previsão é guardada.

**Qualidade:** `flutter analyze` sem problemas, `dart format` limpo, **460/460 testes Flutter passando** com o Flutter do CI (3.38.5), **26/26 testes do Worker** e `tsc` limpo. Com o Flutter local (master 3.50‑pre) 5 testes falham por incompatibilidade de shader do SDK, não por bug do app (§11).

**Conclusão para a próxima fase:** a arquitetura em camadas (Worker com adapters → domínio → `/v1` → repositório Flutter → Cubits) está limpa, muito bem testada e honesta sobre a qualidade dos dados, mas **foi deliberadamente construída sem nenhum modelo de rede estática**. Receber as bases da CMTC significa criar do zero: modelos de Linha/Ponto/Trajeto/Sequência/Horário, um armazenamento local adequado a milhares de registros (o ADR‑0004 já prevê reavaliar `shared_preferences`), um pipeline de ingestão/versão do catálogo e uma camada de mapa para pontos e trajetos. O realtime atual pode continuar intacto ao lado disso, e a principal chave de junção (código de linha e código de ponto como texto) já está padronizada.

---

## 2. Inventário das funcionalidades atuais

**Total identificado: 24 funcionalidades de usuário** no app (F1–F24) + **2 endpoints experimentais do Worker sem uso pelo app** (B1–B2). Estado: Funcional / Parcial / Experimental / Desativado / Legado.

### F1 — Busca de ponto por código numérico — **Funcional**
- **Acesso:** aba **Pontos** (destino inicial do dock) → campo "Código do ponto, ex.: 30402"; botão "Exemplo: 30402"; também a lupa no cabeçalho de um ponto já aberto.
- **Como funciona:** `StopArrivalsCubit.load` aceita apenas `^\d+$` (`app/lib/src/features/transit/presentation/cubit/stop_arrivals_cubit.dart:205-255`) [CÓDIGO]. Zeros à esquerda são preservados (ADR‑0002) [CÓDIGO][TESTE]. Repetir o ponto atual vira `refresh()`. Buscar outro ponto mantém o atual na tela até a nova busca dar certo; falha vira `SearchFeedback` (inválido, não encontrado, offline, timeout, fonte indisponível) sem apagar o que está na tela [CÓDIGO].
- **Arquivos:** `pages/stop_arrivals_page.dart:175-268`, `widgets/search_header.dart`, `formatters/search_feedback.dart`, `widgets/arrivals_panel.dart:10` (`exampleStopId = '30402'`).
- **Fonte:** `GET /v1/stops/:stopId/arrivals` → RMTC `previsaochegada`.
- **Local:** nada além de registrar o ponto nos recentes em caso de sucesso (F15).
- **Internet:** obrigatória.
- **Limitações:** **não há busca por nome, endereço, linha ou proximidade** [AUSENTE]; o usuário precisa saber o código impresso no ponto. O app não mostra nome nem endereço do ponto (nenhuma fonte usada entrega nome confiável; `SavedStop.name` é sempre `null`, `saved_stop.dart:73-76`).

### F2 — Chegadas por ponto — **Funcional**
- **Acesso:** resultado da busca, painel da aba Pontos.
- **Como funciona:** um cartão por linha (`ArrivalCard`, `widgets/arrival_card.dart`) com destino, **próximo** e **seguinte** (minutos), selo de qualidade. "Tempo real" só quando `realtime == true` **e** `quality == realtime` (`domain/entities/arrival.dart:51-52`) [CÓDIGO][TESTE]. Botão de acompanhar só para chegadas em tempo real com número de veículo (`formatters/transit_labels.dart:35`).
- **Fonte:** campos RMTC `Linha`, `Destino`, `Proximo`/`Seguinte` (`NumeroOnibus`, `PrevisaoChegada`, `HoraChegadaPlanejada`, `HoraChegadaPrevista`, `Qualidade`) (`worker/src/sources/rmtc/arrivals.source.ts:36-80`) [CÓDIGO].
- **Local:** nenhum (sem cache em disco, decisão BUS‑OFF‑001 em `docs/HANDOFF_VIAGEM_2026-10.md`).
- **Internet:** obrigatória.
- **Limitações:** só **2 chegadas por linha**; `plannedArrival`/`predictedArrival` (horários absolutos) são recebidos pelo app mas **não exibidos** (grep sem uso fora da entidade) [CÓDIGO]; não há nome do ponto, sentido nem lista completa de linhas que atendem o ponto (só as que têm previsão no momento).

### F3 — Atualização automática e manual das chegadas — **Funcional**
- Timer único de **30 s**, só com a aba Pontos visível e app em primeiro plano; falha automática é silenciosa, falha manual mostra aviso com a hora da consulta anterior (`stop_arrivals_cubit.dart:282-399`; intervalo em `app/lib/src/app.dart:21`) [CÓDIGO][TESTE].

### F4 — Acompanhamento de um ônibus ("Meu ônibus") — **Funcional**
- **Acesso:** botão de acompanhar numa chegada em tempo real, ou "Acompanhar" no callout de um ônibus secundário; aba **Meu ônibus** do dock.
- **Como funciona:** `StopArrivalsCubit.track(vehicleNumber)` consulta `GET /v1/vehicles/{n}/position?stopId={ponto}` imediatamente e depois a cada **15 s** (`stop_arrivals_cubit.dart:408-563`) [CÓDIGO]. Fases explícitas `searching/active/unavailable/failing` (`:36-50`). Respostas de um ônibus anterior são descartadas por geração (`_trackingGeneration`) [CÓDIGO][TESTE].
- **Fonte:** RMTC `veiculo/recuperarposicao` (exige o ponto, ver §8).
- **Local:** só memória.
- **Limitações:** só **um** ônibus acompanhado por vez; acompanhamento **sempre nasce de um ponto** (não existe "buscar ônibus pelo número"); some ao fechar o app; não há notificações nem execução em segundo plano.

### F5 — Mapa base — **Funcional**
- MapLibre (`maplibre_gl 0.27.1`) em tela cheia, criado **uma única vez** (índice 0 do `Stack`, `pages/stop_arrivals_page.dart:400-422`) [CÓDIGO][TESTE]. Estilos `busao-light.json`/`busao-dark.json` empacotados, derivados do OpenFreeMap Liberty (`app/lib/src/core/config/map_config.dart`, `app/tool/build_map_styles.dart`); tiles, sprites e glyphs vêm de `tiles.openfreemap.org` (online). Se o estilo não carrega em 12 s cai para o Liberty por URL (`widgets/tracked_vehicle_map.dart:55`). Câmera inicial fixa no centro de Goiânia (`-16.6869, -49.2648`, zoom 11.5, `tracked_vehicle_map.dart:124-127`) [CÓDIGO].
- **Limitações:** **nenhum ponto de ônibus, nenhum trajeto e nenhuma posição do usuário** são desenhados [AUSENTE].

### F6 — Marcador do ônibus acompanhado com animação e direção observada — **Funcional**
- Marcador âmbar maior com halo; seta de direção quando há `observedHeading`; transição visual entre duas posições reais (≈28 fps, sem animar saltos > 1 km ou ruído) (`tracked_vehicle_map.dart:135-160, 531-640`; `widgets/vehicle_motion.dart`; `domain/models/observed_movement.dart`) [CÓDIGO][TESTE].

### F7 — Rastro observado (trajeto percorrido) — **Funcional**
- Linha discreta ligando as **últimas 20 posições reais** recebidas nesta sessão (~5 min), recomeçando em saltos > 1 km (`observed_movement.dart:5-18, 97-152`; camada `busao-observed-trail-line` em `tracked_vehicle_map.dart:382-397`) [CÓDIGO][TESTE]. Rotulado como "Rastro baseado nas posições observadas. Trajeto oficial ainda não disponível." (`tracking_card.dart:422`).

### F8 — Câmera seguir / Centralizar — **Funcional**
- Segue o ônibus até o usuário mover o mapa; "Centralizar" retoma (`widgets/camera_follow.dart`, `widgets/map_follow_controller.dart`, `tracking_card.dart:650`). Detecção de gesto por "janela programática" porque o `maplibre_gl` não expõe `isGesture` (`camera_follow.dart:1-8`) [CÓDIGO][TESTE].

### F9 — Outros ônibus do ponto no mapa (secundários) — **Funcional**
- Até **6** veículos (menor ETA primeiro, só chegadas em tempo real confirmadas), máx. **3 requisições simultâneas**, timer único de **30 s**, retry mínimo de 10 s (`presentation/cubit/map_vehicles_cubit.dart:66-161`; `map_vehicles/secondary_vehicle_selector.dart:4`) [CÓDIGO][TESTE]. Toque abre callout com linha, destino e número e botão "Acompanhar" (`widgets/secondary_vehicle_callout.dart`).
- **Limitação:** usa N chamadas individuais de posição (uma por ônibus), não um feed de frota.

### F10 — Expiração de posição antiga (90 s) — **Funcional**
- Posição com idade (idade no Worker + tempo local) > 90 s sai do mapa; linha, destino e rastro ficam (`stop_arrivals_cubit.dart:587-654`; `map_vehicles_cubit.dart:329-411`) [CÓDIGO][TESTE] (fronteira 89/90/91 s testada).

### F11 — Ficha do ônibus — **Funcional**
- No painel Meu ônibus: linha, destino, número, pontualidade (No horário/Atrasado/Adiantado), acessibilidade, idade da posição, previsão até o ponto (`widgets/tracking_card.dart:155-200`) [CÓDIGO][TESTE].
- **Limitação:** `routeName` (itinerário em texto, `LinhaItinerario`) é recebido mas **não exibido**; `referenceStop` (id/endereço do ponto) é enviado pelo Worker mas **não é lido pelo app** [CÓDIGO].

### F12 — Pontos favoritos — **Funcional**
- Estrela no cabeçalho do ponto; limite 50, sem remoção automática (`saved_stops/domain/saved_stop.dart:8`; `presentation/cubit/saved_stops_cubit.dart:136-160`) [CÓDIGO][TESTE]. Aba **Favoritos** (`saved_stops_widgets.dart:431`).

### F13 — Linhas favoritas (par ponto + linha) — **Funcional**
- Botão no pé do cartão da linha (`saved_stops_widgets.dart:58-60`); limite 50; guarda só `stop`, `route`, `at` (`saved_stop.dart:40-69`) [CÓDIGO][TESTE].
- **Limitação:** é "linha **neste ponto**", não uma linha global (não há catálogo).

### F14 — Chegadas dos favoritos — **Funcional**
- Ao abrir a aba Favoritos ou tocar "Atualizar": consulta até **10 pontos**, 3 em paralelo, reaproveita se < 30 s; sem repetição automática e sem disco (`presentation/cubit/favorite_arrivals_cubit.dart:11-141`) [CÓDIGO][TESTE].

### F15 — Pontos recentes — **Funcional**
- Últimos **10** pontos consultados **com sucesso**, na aba Pontos; remover um / limpar (`saved_stops_cubit.dart:221-258`; `stop_arrivals_page.dart:228-250`; `saved_stops_widgets.dart:556`) [CÓDIGO][TESTE].

### F16 — Aba "Linhas" (linhas vistas) — **Parcial**
- Lista as linhas que apareceram no ponto atual, nas linhas favoritas e nas chegadas dos favoritos, com os pontos onde apareceram (`saved_stops_widgets.dart:904-994`) [CÓDIGO][TESTE]. Sem dados: "As linhas estarão disponíveis em breve." **Não é catálogo** (o próprio texto da UI diz que a lista completa depende de autorização da RMTC). Sem nomes de linha, sem sentidos, sem pontos da linha.

### F17 — Status "ao vivo" na TopBar — **Funcional**
- Pílula com o frescor do que está na tela; só é "Ao vivo" com dado realtime, não stale e consultado há ≤ 30 s (`formatters/transit_labels.dart:83, 202-206`; `widgets/home_chrome.dart:194, 313`) [CÓDIGO][TESTE].

### F18 — Tema (Sistema / Noturno / Claro) — **Funcional**
- `ThemeModeCubit`, persistido em `shared_preferences` chave `theme_mode` (`core/settings/theme_mode_cubit.dart:27, 50`); mapa troca de estilo junto [CÓDIGO][TESTE].

### F19 — Ajustes e informações — **Funcional**
- Aba aberta pela engrenagem da TopBar: tema, "Dados dos ônibus" (RMTC via API BusãoGyn), "Mapa" (OpenFreeMap/OpenMapTiles/OSM), tipografia, licenças (`widgets/settings_panel.dart:9-66`) [CÓDIGO].

### F20 — Idiomas pt / en / es — **Funcional (sem seletor)**
- 248 chaves em cada ARB (`app/lib/l10n/app_{pt,en,es}.arb`), resolução pelo idioma do aparelho com fallback pt (`core/l10n/l10n.dart:8-25`) [CÓDIGO][TESTE]. **Não há seletor de idioma em Ajustes** [AUSENTE].

### F21 — Tratamento de erros e estados vazios — **Funcional**
- Mapeamento de códigos da API para mensagens (`formatters/error_messages.dart:9-51`), aviso com "Tentar de novo" (uma consulta por toque), painel específico offline/fonte fora, "Nenhuma chegada prevista agora", "A fonte não informou a posição deste ônibus agora" [CÓDIGO][TESTE].

### F22 — Pausa/retomada por ciclo de vida — **Funcional**
- Em background todos os timers param; ao voltar, consulta imediata só se a última tentativa tem ≥ 10 s (tracking) / ≥ 30 s (chegadas) (`stop_arrivals_page.dart:142-161`; `stop_arrivals_cubit.dart:454-474`) [CÓDIGO][TESTE].

### F23 — Layout responsivo e fonte grande — **Funcional**
- < 720 px: bottom sheet arrastável (56 % / 100 % / mínimo 132 px); ≥ 720 px: coluna central de até 460 px (`core/theme/busao_tokens.dart:93-103`; `stop_arrivals_page.dart:44-92, 423-463`). Dock e cabeçalho crescem com a escala de texto [CÓDIGO][TESTE] (testes de overflow em 360/390/430/768/1366 px, 100–200 %).

### F24 — Web (SPA/PWA) e página de privacidade — **Funcional**
- `app/web/` com `manifest.json`, `_headers` de segurança, `privacidade.html`, deploy como Worker de assets estáticos com fallback SPA (`app/wrangler.jsonc`) [CÓDIGO]. **Rotas de URL não existem no app** (`MaterialApp(home: …)` sem router, `app/lib/src/app.dart:113`): `/ponto/30402` e `/linhas`, usados no smoke de deploy, só carregam a home [CÓDIGO].

### B1 — `GET /v1/vehicles` (frota inteira) — **Experimental, sem uso**
- Implementado no Worker (`worker/src/index.ts:33-41`, `services/vehicle.service.ts`, `sources/rmtc/cconaweb.source.ts`). A fonte `cconaweb` recusou acesso server-to-server ("Tipo de Acesso inválido", tratado como `SOURCE_ACCESS_RESTRICTED`) [DOC: `docs/ARCHITECTURE.md:15`]. **O app não chama** [CÓDIGO].

### B2 — `GET /v1/routes/:routeId/vehicles` — **Experimental, sem uso**
- Filtra B1 por linha (`index.ts:43-52`). Mesma restrição; o app não chama [CÓDIGO].

### Funcionalidades investigadas e **inexistentes** [AUSENTE]
Catálogo de linhas; cadastro/lista de pontos; busca de pontos por nome/endereço/proximidade; localização do usuário (as permissões de localização são **removidas** do manifesto Android, `app/android/app/src/main/AndroidManifest.xml:4-10`); pontos no mapa; trajeto oficial; trajeto futuro; sentido/itinerário estruturado; sequência e "próximo ponto"; quadro de horários programados; planejamento de viagens/baldeações; notificações/alertas; contas/sincronização; analytics/telemetria no app; seletor de idioma; deep links; widget de tela inicial.

### Itens "legado"/vestigiais
- Comentários sobre a "flag de navegação v2" (`app/lib/src/app.dart:72`, `stop_arrivals_page.dart:112, 129`, `busao_tokens.dart:78` "3 no dock atual, 4 na navegação v2") — **a flag não existe mais**; a navegação v2 de 4 destinos é o comportamento padrão (confirmado em ADR‑0004 item 8 e pela ausência de qualquer `fromEnvironment` de navegação) [CÓDIGO]. `docs/ARCHITECTURE.md:94` ("só a navegação existe, atrás de flag") está desatualizado.
- `_DockItem` mantém caminho de "dock de três destinos" (`home_chrome.dart:31-33`), não usado (o dock é montado com 4).
- `docs/ARCHITECTURE.md:24` menciona Supabase ("GPS cru não é persistido no Supabase no MVP"); **não há Supabase no projeto** [CÓDIGO].

---

## 3. Arquitetura técnica

### 3.1 Estrutura de diretórios

```text
busaogyn/
├── .github/workflows/        # 7 workflows (CI Flutter, CI/deploy Worker, deploy/rollback web, probes)
├── app/                      # Flutter (Android, iOS, Web)
│   ├── lib/
│   │   ├── main.dart         # composição: ApiClient, repositório, stores
│   │   ├── l10n/             # ARB pt/en/es + gerados
│   │   └── src/
│   │       ├── app.dart      # MaterialApp + providers (5 Cubits)
│   │       ├── core/         # config, network, theme, ui, map style, l10n, settings, platform
│   │       └── features/
│   │           ├── transit/        # domínio, dados e UI de chegadas/mapa/tracking
│   │           └── saved_stops/    # favoritos, recentes, linhas favoritas
│   ├── test/                 # 29 arquivos *_test.dart, 460 testes
│   ├── assets/               # estilos de mapa, logo, fontes Geist
│   ├── tool/                 # geração de estilos de mapa e ícones, checagem de APK
│   ├── scripts/              # build/deploy web, smoke, verificação de segredos no bundle
│   ├── web/                  # index.html, _headers, manifest, privacidade.html
│   └── wrangler.jsonc        # Worker de assets estáticos (site)
├── worker/                   # API BusãoGyn (TypeScript, Cloudflare Workers)
│   ├── src/{index.ts, cache, domain, infra, services, sources/rmtc, types, utils}
│   ├── test/                 # 5 arquivos, 26 testes (vitest)
│   ├── scripts/              # probe-rmtc.mjs, smoke-local-api.mjs
│   └── wrangler.toml
└── docs/                     # arquitetura, ADRs 0001–0004, plano v2, release, privacidade, handoff
```

Tamanho: ~11,4 mil linhas Dart em `app/lib/src` e `main.dart`; ~1,0 mil linhas TS em `worker/src`.

### 3.2 Framework e versões

| Item | Valor | Fonte |
|---|---|---|
| Versão do app | `1.0.0+1` | `app/pubspec.yaml:4` |
| Dart SDK | `>=3.10.0 <4.0.0` | `app/pubspec.yaml:7` |
| Flutter no CI | **3.38.5** stable | `.github/workflows/flutter-ci.yml:19` |
| Flutter no deploy web | **3.47.4** stable | `.github/workflows/deploy-web.yml:16` |
| Flutter local (máquina auditada) | 3.50.0‑0.2.pre (master) | `flutter --version` |
| Node (CI Worker) | 22 | `worker-ci.yml` |
| Worker | TypeScript 5.8, wrangler 4, vitest 5, `compatibility_date = 2026-10-06` | `worker/package.json`, `worker/wrangler.toml` |
| Android | `applicationId com.lucksrei.busaogyn`, Java/Kotlin 17, min/target/compile SDK do Flutter (comentário: 24/36/36) | `app/android/app/build.gradle.kts` |
| iOS | bundle `com.lucksrei.busaogyn`, deployment target 15.0, UIScene + Swift Package Manager | `project.pbxproj`, commit `afdad14` |

**Atenção:** três versões de Flutter diferentes convivem (CI 3.38.5, deploy web 3.47.4, máquina local master). O build publicado na web não é o mesmo SDK que roda os testes (§12).

### 3.3 Camadas Flutter

```text
presentation  (pages, widgets, cubits, formatters)
     │  BlocProvider / context.read
domain        (entities, models, repository interfaces)   ← puro Dart
     │
data          (HttpTransitRepository, SavedStops stores, codec)
     │
core          (ApiClient, ApiException, config, theme, l10n, ui, map style)
```

- Feature `transit`: `domain/entities` (`Arrival`, `ArrivalGroup`, `TrackedVehicle`, `GeoPosition`, `MapVehicle`), `domain/models` (`TransitSnapshot`, `ObservedMovement`), `domain/repositories/transit_repository.dart` (2 métodos), `data/repositories/http_transit_repository.dart`.
- Feature `saved_stops`: `domain` (`SavedStop`, `SavedLine`, `SavedStopsData`, `SavedStopsStore`), `data` (codec JSON versionado, store `shared_preferences`, store memória).
- Composição manual em `main.dart` (sem injeção de dependência por pacote).

### 3.4 Gerenciamento de estado

`flutter_bloc 9` com **5 Cubits** globais criados em `app/lib/src/app.dart:58-90`:

| Cubit | Responsabilidade |
|---|---|
| `ThemeModeCubit` | tema |
| `StopArrivalsCubit` | ponto atual, chegadas, refresh automático, tracking, expiração |
| `SavedStopsCubit` | favoritos, recentes, linhas favoritas, gravação serializada |
| `FavoriteArrivalsCubit` | chegadas dos favoritos (sob demanda) |
| `MapVehiclesCubit` | ônibus secundários, fila de consultas, expiração |

Coordenação: a página escuta `StopArrivalsCubit` e chama `MapVehiclesCubit.sync(...)` a cada mudança (`stop_arrivals_page.dart:341-362`). Estado de UI local (aba, sheet, callout) fica no `State` da página.

### 3.5 Navegação e rotas

- **Uma única página** (`StopArrivalsPage`) com `enum HomeTab { lines, stop, favorites, tracking, settings }` (`widgets/home_chrome.dart:11`). Dock flutuante com 4 destinos (Linhas, Pontos, Favoritos, Meu ônibus); Ajustes na TopBar.
- **Sem `Navigator` de rotas nomeadas, sem `go_router`, sem deep links** [CÓDIGO]. Único push é `showLicensePage`.

### 3.6 Modelos de dados — ver §7.

### 3.7 Repositórios e serviços

- App: `TransitRepository` → `HttpTransitRepository` (2 endpoints), `SavedStopsStore` → `SharedPreferencesSavedStopsStore`/`MemorySavedStopsStore`, `ThemePreferenceStore`.
- Worker: `ArrivalService`, `VehiclePositionService`, `VehicleService` (cada um com cache stale-while-error) → sources `RmtcArrivalSource`, `RmtcVehiclePositionSource`, `RmtcCconawebSource`.

### 3.8 Dependências principais

App (`app/pubspec.yaml`): `flutter_bloc ^9.1.1`, `maplibre_gl ^0.27.1`, `http ^1.5.0`, `shared_preferences ^2.5.3`, `intl`, `flutter_localizations`. Dev: `flutter_lints ^6`, `fake_async`. **Só 4 dependências de terceiros em runtime.**
Worker: sem dependências de runtime (só devDependencies).

### 3.9 Configuração por ambiente (`--dart-define`)

| Variável | Padrão | Arquivo |
|---|---|---|
| `BUSAOGYN_API_BASE_URL` | `https://busaogyn-api.lively-cloud-f009.workers.dev` | `core/config/api_config.dart:2-5` |
| `MAP_STYLE_URL` | OpenFreeMap Liberty (usa estilos empacotados) | `core/config/map_config.dart:13-16` |
| `MAP_STYLE_DARK_URL` | vazio | `map_config.dart:19` |

Nenhum workflow passa `--dart-define`: produção usa os padrões [CÓDIGO].
Worker (`worker/wrangler.toml` `[vars]`): `ENVIRONMENT=production`, `API_VERSION=1`, `RMTC_VEHICLES_TIMEOUT_MS=5000`, `RMTC_ARRIVALS_TIMEOUT_MS=6000`, `ALLOWED_ORIGINS` (localhost, `busaogyn.lucksrei.com`, `busaogyn-web.lucasdiogo1234.workers.dev`); `BUILD_SHA` injetado no deploy.

### 3.10 Feature flags

**Nenhuma feature flag ativa no código** [CÓDIGO]. A flag `BUSAOGYN_V2_NAV` proposta no ADR‑0001 foi removida (ADR‑0004 item 8). As "capabilities" do catálogo descritas em ADR‑0001 item 9 e no plano v2 **não foram implementadas** [AUSENTE]. Únicos interruptores: variável de repositório `AUTO_DEPLOY` para o deploy web e `BUSAOGYN_ALLOW_DEBUG_SIGNED_RELEASE` para builds Android de validação.

### 3.11 Tratamento de erros

- Worker: `AppError(code, status, retryable)` com códigos `INVALID_STOP`, `INVALID_VEHICLE`, `ROUTE_NOT_FOUND` (declarado, não usado), `SOURCE_TIMEOUT`, `SOURCE_UNAVAILABLE`, `SOURCE_ACCESS_RESTRICTED`, `SOURCE_INVALID_RESPONSE`, `INTERNAL_ERROR` (`worker/src/infra/errors.ts`); resposta `{"error":{code,message,retryable}}` (`index.ts:108-117`).
- App: `ApiClient` converte timeout (20 s) → `CLIENT_TIMEOUT`, `ClientException` → `NETWORK_ERROR`, JSON inválido → `INVALID_RESPONSE`, erro HTTP → código do Worker (`core/network/api_client.dart:26-94`). Parsing tolerante: tipo inesperado vira `null`, grupo malformado é descartado (`json_fields.dart`, `http_transit_repository.dart:38-53`).

### 3.12 Cache e armazenamento local — ver §7.3 e §5.4.

### 3.13 Testes — ver §11.

### 3.14 Diagrama textual

```text
 ┌──────────────────── Flutter app (Android / iOS / Web) ────────────────────┐
 │  StopArrivalsPage (única tela, 5 destinos)                                │
 │   ├─ TransitMap (MapLibre, criado 1x) ── tiles/sprites/glyphs ──► OpenFreeMap
 │   ├─ ArrivalsPanel / TrackingCard / Favorites / SeenLines / Settings       │
 │  Cubits: StopArrivals ─sync─► MapVehicles   SavedStops   FavoriteArrivals  │
 │          Theme                                                            │
 │  HttpTransitRepository ─► ApiClient (http, timeout 20 s)                  │
 │  SharedPreferences: theme_mode, busaogyn.saved_stops.v1                   │
 └───────────────────────────────┬───────────────────────────────────────────┘
                                 │ HTTPS GET /v1/...
 ┌───────────────── Cloudflare Worker "busaogyn-api" ────────────────────────┐
 │ index.ts (router, CORS, X-Request-ID, log JSON)                           │
 │ services (Cache API: fresh/stale) ─► sources/rmtc (fetch, timeout, 1 retry)│
 └───────┬─────────────────────────────┬─────────────────────────┬───────────┘
         │ POST form                   │ POST form               │ GET (restrito)
  simapp…/pontoparada/          simapp…/veiculo/          rmtcgoiania.com.br/index.php
  previsaochegada               recuperarposicao          ?view=cconaweb (frota)
```

---

## 4. Mapa de telas e fluxos

### 4.1 Estrutura da tela única

Sobre o mapa em tela cheia flutuam: **TopBar** (marca, pílula de status, engrenagem de Ajustes) → **cabeçalho de contexto** (busca / ponto atual / ônibus / título da aba) → **callout** de ônibus secundário (quando tocado) → **painel** (bottom sheet no celular, coluna central em telas ≥ 720 px) → **dock** (Linhas · Pontos · Favoritos · Meu ônibus).

| Destino | Conteúdo do painel | Cabeçalho |
|---|---|---|
| Pontos (`HomeTab.stop`, inicial) | sem ponto: exemplo + Recentes; com ponto: `ArrivalsPanel` (cartões por linha) | campo de busca ou código do ponto + nº de linhas + estrela favorito + lupa |
| Linhas | `SeenLinesPanel` ou estado vazio | "Linhas" |
| Favoritos | `FavoritesPanel` (pontos e linhas favoritas com chegadas) | "Favoritos" + contagem |
| Meu ônibus | `TrackingCard` ou vazio ("acompanhe a partir de uma chegada") | linha/destino/número + parar |
| Ajustes | `SettingsPanel` | "Ajustes" + fechar |

### 4.2 Fluxos principais

1. **Consultar ponto:** Pontos → digitar código → Enviar → chegadas → (sucesso) entra nos recentes.
2. **Acompanhar:** chegada em tempo real → ícone acompanhar → Meu ônibus (consulta 15 s) → mapa segue → "Centralizar" após gesto → parar.
3. **Trocar de ônibus pelo mapa:** tocar ônibus secundário → callout → Acompanhar.
4. **Favoritar:** estrela do ponto / botão no cartão da linha → Favoritos → toque reabre o ponto.
5. **Tema:** engrenagem → Ajustes → segmento.

### 4.3 Estados

- **Vazios:** Pontos sem consulta (exemplo 30402, recentes vazios explicados); "Nenhuma chegada prevista agora"; Linhas vazia ("estarão disponíveis em breve"); Favoritos vazio; Meu ônibus vazio.
- **Carregando:** `StopArrivalsLoading`, `searchingStopId` (mantém o ponto anterior), `refreshing`, linhas de skeleton nos favoritos (`_LoadingRows`), fase `searching` do tracking.
- **Erro:** borda de erro só para código inválido/ponto não encontrado; aviso + "Tentar de novo" para offline/timeout/fonte; aviso de armazenamento (não guarda / ilegível / falha ao gravar, `saved_stops_widgets.dart:181-207`); posição indisponível × conexão instável × posição antiga.

### 4.4 Responsividade e plataformas

- Breakpoint único `720 px` (`busao_tokens.dart:101-103`). Tablet e Web largos usam coluna central; não há layout de duas colunas lado a lado nem uso específico de teclado/mouse.
- Web: mapa MapLibre GL JS, ajuste de posição da atribuição (`core/platform/map_attribution_offset_web.dart`), CSS em `web/index.html:54-60`.

### 4.5 Acessibilidade (no código)

`Semantics` com rótulos dedicados em cartões, chegadas, linhas vistas, cabeçalho de tracking e alça do sheet; alvos de toque ≥ 48 dp testados; estados distinguidos por forma e não só por cor (estrela, selos); escala de texto até 200 % testada sem overflow; dígitos tabulares Geist Mono.

### 4.6 Problemas de usabilidade identificáveis (sem propor redesenho)

1. Exige o **código numérico** do ponto: sem nome, endereço, mapa de pontos ou "perto de mim" a descoberta depende do usuário estar no ponto.
2. A aba **Linhas** ocupa um dos 4 destinos do dock com conteúdo derivado e, na primeira abertura, vazio.
3. O ponto aparece só como número (nunca com nome/endereço), inclusive em favoritos e recentes.
4. Horários absolutos (`plannedArrival`/`predictedArrival`) existem na resposta e não são mostrados.
5. Acompanhamento perde o rastro ao fechar o app e não há aviso de chegada.
6. URLs da web não refletem o estado (não dá para compartilhar um ponto por link).
7. Sem seletor de idioma.
8. O itinerário textual (`routeName`) que a fonte manda não é exibido.

---

## 5. APIs e fontes de dados

### 5.1 API BusãoGyn (Cloudflare Worker `busaogyn-api`)

- **URL base:** `https://busaogyn-api.lively-cloud-f009.workers.dev` (padrão do app) [CÓDIGO]. Em 27/10/2026: `/v1/health` → `{"status":"ok","environment":"production","apiVersion":"1"}`; `/v1/version` → `build 275c942…` [TESTE]. O código do Worker não mudou entre `275c942` e `HEAD` (`git diff --stat` vazio para `worker/`) [CÓDIGO].
- **Métodos:** só `GET` (e `OPTIONS` → 204); outros → 405 `METHOD_NOT_ALLOWED` (`index.ts:22-23`).
- **Cabeçalhos de resposta:** `X-Request-ID`, `X-BusaoGyn-Cache: HIT|MISS|STALE`, `X-BusaoGyn-Stale`, CORS para origens permitidas.
- **Sem autenticação, sem rate limiting** [CÓDIGO] (nenhuma lógica de limite no Worker; a proteção é cache + limites de concorrência no app).

| Endpoint | Parâmetros | Resposta `data` | Fonte RMTC | Cache (fresh/stale) | Usado pelo app |
|---|---|---|---|---|---|
| `GET /v1/health` | — | `{status, environment, apiVersion}` | — | — | não |
| `GET /v1/version` | — | `{api, build}` | — | — | não |
| `GET /v1/stops/{stopId}/arrivals` | `stopId` só dígitos | `ArrivalGroup[]` | `previsaochegada` | 15 s / 60 s | **sim** |
| `GET /v1/vehicles/{vehicleId}/position?stopId=` | `vehicleId` = `123` ou `rmtc:123`; `stopId` obrigatório | `TrackedVehicle \| null` | `recuperarposicao` | 5 s / 45 s | **sim** (tracking 15 s, secundários 30 s) |
| `GET /v1/vehicles` | — | `Vehicle[]` (sem `interval`/`out_of_service`) | `cconaweb` | 10 s / 90 s | não |
| `GET /v1/routes/{routeId}/vehicles` | `routeId` | `Vehicle[]` filtrado | `cconaweb` | idem | não |

Envelope: `{ "data": …, "meta": { stopId|vehicleId|routeId, count?, fetchedAt, stale, ageSeconds } }`.

**`ArrivalGroup`** (`worker/src/domain/arrival.ts`): `routeId`, `destination`, `next: Arrival`, `following: Arrival|null`. **`Arrival`**: `vehicleId` (`rmtc:N`|null), `vehicleNumber`, `minutes`, `plannedArrival`, `predictedArrival`, `realtime`, `quality` (`realtime|scheduled|unknown`), `sourceQuality` (texto bruto). Exemplo real (27/10/2026, ponto 30402): 14 grupos; `{"routeId":"003","destination":"T MARANATA","next":{"vehicleNumber":null,"minutes":2,"plannedArrival":"2026-10-27T18:45:37-03:00","quality":"scheduled","sourceQuality":"Tabela Horária",…}}` [TESTE].

**`TrackedVehicle`** (`worker/src/domain/tracked-vehicle.ts`): `id`, `vehicleNumber`, `routeId`, `routeName`, `destination`, `position {latitude, longitude}|null`, `accessible`, `punctuality {status: on_time|delayed|early|unknown, sourceStatus}`, `referenceStop {sourceStopId, address}|null`, `prediction {predictedArrival, minutes}|null`.

**`Vehicle`** (`worker/src/domain/vehicle.ts`): `id`, `vehicleNumber`, `routeId`, `destination`, `position`, `accessible`, `status (in_service|interval|out_of_service|unknown)`, `sourceStatus`.

### 5.2 Fontes RMTC (terceiros, sem contrato formal no repositório)

| Fonte | URL | Método/corpo | Campos lidos |
|---|---|---|---|
| Previsão por ponto | `https://simapp.rmtcgoiania.com.br/pontoparada/previsaochegada` | `POST` form `qryIdPontoParada` | `data[].Linha, Destino, Proximo/Seguinte.{NumeroOnibus, PrevisaoChegada, HoraChegadaPlanejada, HoraChegadaPrevista, Qualidade}` (`arrivals.source.ts:36-112`) |
| Posição individual | `https://simapp.rmtcgoiania.com.br/veiculo/recuperarposicao` | `POST` form `qryIdVeiculo`, `qryIdPontoParada` | `data[0].Numero, Linha.{LinhaNumero, LinhaItinerario}, Destino.DestinoNome, Posicao.{Latitude, Longitude}, Acessivel, Situacao, PontoParada.{PontoId, PontoEndereco}, Previsao.{HoraChegadaPrevista, PrevisaoChegada}` (`vehicle-position.source.ts:33-135`) |
| Frota | `https://rmtcgoiania.com.br/index.php?option=com_rmtclinhas&view=cconaweb&format=json&linha=000` | `GET` | `onibus[].Numero, Linha.LinhaNumero, Destino.DestinoCurto, Latitude, Longitude, Acessivel, Situacao` (`cconaweb.source.ts:33-129`) |

Política HTTP comum (`worker/src/infra/http-client.ts`): timeout por tentativa (5 s veículos / 6 s chegadas), **1 retry** em 502/503/504, erro de rede ou timeout, backoff 200 ms × tentativa.

"RedeMob" aparece só como rótulo nos docs (`docs/ARCHITECTURE.md:5`); **não há integração com outro host** além dos dois domínios RMTC acima [CÓDIGO].

Dependências externas adicionais: **OpenFreeMap** (`tiles.openfreemap.org`: tiles vetoriais `planet`, sprites, fontes) para o mapa [CÓDIGO]; **Cloudflare** (Workers, Cache API, hosting web).

### 5.3 Frequência de consultas (por aparelho)

| O quê | Intervalo | Condição |
|---|---|---|
| Chegadas do ponto atual | 30 s | aba Pontos visível + app em foreground |
| Posição do ônibus acompanhado | 15 s | tracking ativo + foreground |
| Posição de secundários | 30 s, ≤ 6 veículos, ≤ 3 simultâneas | ponto carregado + foreground |
| Chegadas dos favoritos | sob demanda, ≤ 10 pontos, ≤ 3 simultâneas, reuso 30 s | aba Favoritos |

### 5.4 Cache e TTL no Worker

`worker/src/cache/cache.ts`: Cache API (`caches.default`) com chave sintética `https://cache.busaogyn.internal/<chave>`; valor guarda `freshUntil`/`staleUntil`. Fresco → `HIT`; fonte falhou e há valor dentro da janela stale → `STALE` (`stale: true`); senão o erro sobe. Chaves: `arrivals:stop:{id}`, `vehicle-position:{n}:stop:{id}`, `vehicles:all`. Confirmado em produção: 1ª chamada `MISS`, 2ª `HIT` [TESTE]. A Cache API é por data center da Cloudflare, não global [HIPÓTESE, comportamento da plataforma].

### 5.5 Origem de cada dado

| Dado | Origem | Classificação |
|---|---|---|
| 1. Código da linha | `Linha` (chegadas) / `Linha.LinhaNumero` (posição, frota), normalizado: 1–3 dígitos → 3 dígitos com zeros (`worker/src/utils/normalize.ts:12-17`) | oficial em tempo real (da fonte operacional), normalizado |
| Nome da linha | **não existe**; `LinhaItinerario` (texto livre) só no tracking, não exibido | — |
| 2. Código do ponto | **digitado pelo usuário**; validado só como dígitos | entrada do usuário |
| Endereço do ponto | `PontoParada.PontoEndereco` vem na posição; app ignora | oficial, não usado |
| 3. Previsões de chegada | `PrevisaoChegada` (minutos) + `Qualidade` ("Tempo real", "Tabela Horária"/aprox.) | tempo real **ou** programado da fonte, cache 15–60 s |
| 4. Posições dos ônibus | `Posicao.Latitude/Longitude` de `recuperarposicao`, validadas por faixa | tempo real, cache 5–45 s |
| 5. Identificador do veículo | `NumeroOnibus` (chegadas) = `qryIdVeiculo` = `Numero` (posição); id interno `rmtc:{n}`; só zeros = ausência (`json_fields.dart:10-18`) | oficial; equivalência validada [DOC `ARCHITECTURE.md:41-52`] |
| 6. Itinerário/sentido | só `Destino`/`DestinoNome` em texto ("T BIBLIA"); sem sentido estruturado | oficial textual; sentido **ausente** |
| Direção no mapa | azimute entre posições observadas (`observed_movement.dart:38-48, 134-144`) | **inferido** localmente, rotulado "observado" |
| Rastro | posições recebidas na sessão | **observado** em memória |
| 7. Coordenadas do mapa | só posições de veículos + centro fixo de Goiânia; tiles OSM | sem coordenadas de pontos/trajetos |
| `fetchedAt` | instante da coleta pelo Worker, **não** do GPS | metadado do cache |

---

## 6. Backend e infraestrutura

### 6.1 Cloudflare Workers

| Worker | Papel | Config |
|---|---|---|
| `busaogyn-api` | API `/v1` | `worker/wrangler.toml`; deploy manual (`worker-deploy.yml`, `workflow_dispatch`, environment `production`) com typecheck, testes, `BUILD_SHA` e smoke de produção |
| `busaogyn-web` | site Flutter Web (assets estáticos, SPA fallback, sem script) | `app/wrangler.jsonc`; deploy em push na `main` **somente se** `vars.AUTO_DEPLOY == 'true'`, ou manual; rollback manual (`rollback-web.yml`) |

Observação: `app/wrangler.jsonc` tem a rota de domínio próprio **ativa** (`"routes": [{"pattern": "busaogyn.lucksrei.com", "custom_domain": true}]`), enquanto o comentário logo abaixo ainda diz para descomentar só após autorização — o comentário está desatualizado (commit `2d4df69 enableBusaoGynCustomDomain`) [CÓDIGO].

### 6.2 Domínios

- API: `busaogyn-api.lively-cloud-f009.workers.dev`.
- Web: `busaogyn.lucksrei.com` e `busaogyn-web.lucasdiogo1234.workers.dev` (smoke em `deploy-web.yml:20`).
- Política de privacidade: `app/web/privacidade.html` publicada com o site.
- Contas Cloudflare diferentes para API e web (subdomínios `workers.dev` distintos) [HIPÓTESE; o comentário de `deploy-web.yml:2` diz que o web usa os secrets do repositório e a API os do environment `production`].

### 6.3 CI/CD (`.github/workflows/`)

| Workflow | Gatilho | Faz |
|---|---|---|
| `flutter-ci.yml` | push/PR em `app/**` | format, analyze, test (3.38.5); build APK/AAB release com chave de debug, checagem de **permissões do APK**, páginas de 16 KB, build web, tamanhos; build iOS sem assinatura (macOS) |
| `worker-ci.yml` | push/PR em `worker/**` | `npm ci`, typecheck, testes, `node --check` do smoke |
| `worker-deploy.yml` | manual | idem + `wrangler deploy` + smoke de produção |
| `worker-integration-smoke.yml` | manual/paths | sobe Worker local e valida ETA → tracking contra a RMTC real |
| `rmtc-probe.yml` | manual/paths | sonda as 3 fontes RMTC uma vez |
| `deploy-web.yml` | push `main` (com `AUTO_DEPLOY`) / manual | build web 3.47.4, varredura de segredos no bundle, deploy, smoke |
| `rollback-web.yml` | manual | volta versão do Worker web |

Secrets referenciados (nomes apenas): `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`; variáveis de assinatura Android `BUSAOGYN_ANDROID_*` (lidas pelo Gradle). Assinatura iOS no CI **não existe** [DOC `MOBILE_RELEASE.md:203`].

### 6.4 Android

- Permissões: só `INTERNET`; `ACCESS_COARSE/FINE_LOCATION` declaradas pelo plugin MapLibre são **removidas** com `tools:node="remove"` (`AndroidManifest.xml:3-10`) [CÓDIGO]; o CI falha se o APK pedir permissões extras [DOC/CÓDIGO no workflow].
- Release exige chave de upload (`key.properties` local, fora do git, ou env); falha explícita sem ela (`build.gradle.kts:10-108`).

### 6.5 iOS

- Display name "BusãoGyn", deployment target 15.0, UIScene, SPM. **Nenhuma `NS…UsageDescription`** (não pede localização) [CÓDIGO]. `Podfile` e `Podfile.lock` ainda existem junto da migração para SPM; há alterações locais não commitadas nesses arquivos.

### 6.6 Web

`web/_headers`: `X-Content-Type-Options`, `X-Frame-Options: DENY`, `Referrer-Policy`, `Permissions-Policy` (geolocalização negada), HSTS, `Cache-Control: no-cache` no geral. **Sem Content-Security-Policy** [CÓDIGO]. `scripts/check-bundle-secrets.sh` varre o bundle antes do deploy.

### 6.7 Privacidade e publicação

- O app não tem conta, login, analytics ou SDK de telemetria [CÓDIGO]. Logs do Worker registram `requestId`, método, **caminho** (inclui código do ponto e número do veículo), status e duração (`worker/src/infra/logger.ts`, `index.ts:106,112`) — não incluem IP explicitamente [CÓDIGO]; o que a Cloudflare registra por padrão não foi verificado.
- `docs/PRIVACY.md` e `privacidade.html` descrevem o tratamento [DOC].
- **Bloqueios de publicação nas lojas** [DOC `MOBILE_RELEASE.md`]: checklists de Play Console e App Store Connect ainda abertos (`[ ]`), sem assinatura iOS no CI, TestFlight não feito. Risco adicional: o app consome endpoints não documentados de terceiro sem autorização registrada no repositório (§15).

---

## 7. Modelos e persistência

### 7.1 Modelos do app (Dart)

| Modelo | Arquivo | Campos | Relações |
|---|---|---|---|
| `ArrivalGroup` | `transit/domain/entities/arrival.dart:55-85` | `routeId: String`, `destination: String?`, `next: Arrival`, `following: Arrival?` | 1 grupo = 1 linha num ponto |
| `Arrival` | `arrival.dart:17-53` | `vehicleId?`, `vehicleNumber?`, `minutes: int?`, `plannedArrival: String?`, `predictedArrival: String?`, `realtime: bool`, `quality: ArrivalQuality` | → veículo por `vehicleNumber` |
| `TrackedVehicle` | `tracked_vehicle.dart:41-85` | `id`, `vehicleNumber`, `routeId?`, `routeName?`, `destination?`, `position: GeoPosition?`, `accessible: bool?`, `punctuality` | **não lê** `referenceStop` nem `prediction` |
| `GeoPosition` | `tracked_vehicle.dart:19-39` | `latitude`, `longitude` (validados) | — |
| `MapVehicle` / `VehicleVisualProfile` | `map_vehicle.dart` | número, linha, destino, posição, `isTracked`, `stale`, `ageSeconds`; operador/família/classe sempre `null` | visual |
| `TransitSnapshot<T>` | `models/transit_snapshot.dart` | `data`, `fetchedAt`, `stale`, `ageSeconds` | envelope de toda resposta |
| `ObservedMovement` | `models/observed_movement.dart` | `observedHeading?`, `observedTrail: List<GeoPosition>` (≤ 20), `anchor`, `lastSampleAt` | só memória |
| `SavedStop` | `saved_stops/domain/saved_stop.dart:77-106` | `code`, `name?` (sempre null hoje), `at` | favoritos e recentes |
| `SavedLine` | `saved_stop.dart:42-69` | `stopCode`, `routeId`, `at` | par ponto+linha |
| `SavedStopsData` | `saved_stop.dart:110-125` | `favorites`, `recents`, `lines` | documento único |

**Modelos inexistentes** [AUSENTE]: Linha (catálogo), Ponto (catálogo com nome/coordenada), Trajeto/Shape, Sequência de paradas, Sentido/Variante, Viagem/Horário programado, Terminal, Calendário.

### 7.2 Persistência local

| Solução | Presente? | Uso |
|---|---|---|
| `shared_preferences` | **sim** | `theme_mode` (string) e `busaogyn.saved_stops.v1` (JSON) |
| Supabase | **não** (citado só em doc antiga) | — |
| SQLite / sqflite / drift | **não** | — |
| Hive / Isar | **não** | — |
| Arquivos / path_provider | **não** | — |
| Cache de tiles do mapa | implícito no SDK MapLibre nativo / navegador | não controlado pelo app |

Documento de favoritos (`saved_stops_codec.dart:14-33`):
```json
{"schema":2,"favorites":[{"code":"30402","name":null,"at":"…Z"}],"recents":[…],"lines":[{"stop":"30402","route":"020","at":"…Z"}]}
```
Leitura tolerante (versão desconhecida/corrompido → vazio + aviso), schema 1 legível, escrita serializada do estado mais novo (`saved_stops_cubit.dart:260-298`) [CÓDIGO][TESTE]. Se `SharedPreferences.getInstance()` falha, cai para memória volátil e a UI avisa (`main.dart:34-46`).

### 7.3 Cache

- App: **nenhum cache de dados de transporte** — chegadas e posições vivem só nos Cubits.
- Worker: Cache API (§5.4). Nenhum KV, D1, R2 ou Durable Object [CÓDIGO]; `docs/ARCHITECTURE.md:105` registra que um catálogo exigiria armazenamento durável.

---

## 8. Acompanhamento de veículos

Respostas com base no código:

| Pergunta | Resposta |
|---|---|
| Como um ônibus é selecionado? | Tocando o botão de acompanhar numa chegada **em tempo real confirmada** com número de veículo (`arrival_card.dart:221-235, 414-426`), ou "Acompanhar" no callout de um secundário (`stop_arrivals_page.dart:291-294`). |
| Como é identificado? | Pelo `vehicleNumber` (`NumeroOnibus` da RMTC); id `rmtc:{n}`. Sempre em conjunto com o **ponto consultado** (`_trackedStopId`). |
| Como a posição é atualizada? | Polling `GET /v1/vehicles/{n}/position?stopId={ponto}`; uma requisição por vez (`_positionRequestInFlight`), geração descarta respostas antigas (`stop_arrivals_cubit.dart:486-563`). |
| Intervalo? | **15 s** (acompanhado), **30 s** (secundários); Worker cacheia 5 s fresco. |
| Como o mapa é renderizado? | MapLibre; GeoJSON sources + layers: rastro (line), secundários (symbol), acompanhado (halo circle + symbol com `iconRotate` = heading). Sources atualizadas no lugar, recriadas a cada `onStyleLoaded` (`tracked_vehicle_map.dart:338-480, 589-600`). |
| Guarda posições anteriores? | Sim, **só em memória**: até 20 no `ObservedMovement` do acompanhado; secundários guardam só a última. Nada em disco, nada no servidor. |
| Desenha o trajeto percorrido? | Sim, o **rastro observado** (≥ 2 posições), descontinuado em saltos > 1 km. |
| Existe trajeto futuro? | **Não** [AUSENTE]. A UI diz explicitamente que não mostra percurso futuro (`trackingFootnote`, `tracking_card.dart:155`). |
| Existem coordenadas de rotas cadastradas? | **Não** [AUSENTE]. |
| É possível identificar o sentido? | Só o **destino em texto** (`DestinoNome`) e a **direção observada** (azimute). Não há ida/volta estruturado. |
| É possível determinar o próximo ponto? | **Não**. Só a previsão até o **ponto consultado** (`prediction.minutes`, nem lida pelo app). |
| GPS para de atualizar? | Resposta sem posição → fase `unavailable` mantendo a última posição; falha de rede → `failing`; a posição envelhece (idade Worker + local) e **sai do mapa após 90 s**; o rastro e a direção são mantidos; posições `stale` ou repetidas (mesmo `fetchedAt`) não entram no rastro (`observed_movement.dart:97-104`). |
| Mudança de itinerário? | Não é tratada: `routeId`/`destination` são substituídos pelo que a fonte manda a cada consulta; não há detecção de troca de linha/viagem. Um salto > 1 km reinicia o rastro. |

**Restrição da fonte:** `recuperarposicao` exige `qryIdPontoParada`; sem ele responde recusa. Com um ponto sem relação devolve a mesma posição e previsão `null` [DOC `ARCHITECTURE.md:76-90`]. Por isso não há "buscar ônibus por número" sem ponto.

### Dados que faltam para rota futura completa com próximos pontos

1. **Geometria do trajeto por linha e por sentido** (shape: lista ordenada de coordenadas).
2. **Sequência ordenada de paradas por linha e sentido**, com código do ponto compatível com o `qryIdPontoParada`.
3. **Coordenadas (e nome) de cada ponto.**
4. **Identificação do sentido/variante que o veículo está executando agora** — a fonte realtime só dá `LinhaNumero` + `DestinoNome`. É preciso uma regra oficial de correspondência destino → sentido (ou um campo de viagem/sentido no realtime).
5. **Regra de projeção** do GPS no shape (map matching) para saber onde o ônibus está ao longo do trajeto e quais paradas ainda faltam.
6. Opcional: **horários programados por parada** (para ETA em pontos além do consultado) e calendário.

Os arquivos KMZ (trajetos e pontos) e os cadastros da CMTC potencialmente cobrem 1–3; 4 depende de como os KMZ/cadastros nomeiam sentidos e se casam com os destinos textuais do realtime [HIPÓTESE — os arquivos não estão no repositório].

---

## 9. Mapa e rotas

- **Motor:** `maplibre_gl 0.27.1` (Android/iOS nativo, Web via MapLibre GL JS).
- **Estilo:** `assets/map/busao-{light,dark}.json`, derivados do Liberty por `tool/build_map_styles.dart`; fallback por URL; atribuição pelo controle nativo.
- **Camadas do app:** `busao-observed-trail` (linha), `busao-map-vehicles` (secundários), `tracked-vehicle-source` + halo + símbolo (`widgets/vehicle_map_data.dart:4-28`). Imagens dos marcadores geradas em runtime (`vehicle_marker_image.dart`).
- **Câmera:** inicial fixa em Goiânia; segue o ônibus com padding calculado para o espaço visível (sheet/coluna); não ajusta para enquadrar ponto + ônibus.
- **Invariantes protegidos** (ADR‑0003): mapa nunca recriado; estilo e camadas recriados no mesmo controller; testes `transit_map_style_test.dart`, "o mapa é criado uma vez e o tracking sobrevive a tudo" [TESTE].
- **Ausentes:** camada de pontos, camada de trajeto, clustering, seleção de ponto no mapa, localização do usuário, mapa offline.
- **Ponto de extensão natural:** o padrão "GeoJSON source + layer recriados em `onStyleLoaded`, atualizados com `setGeoJsonSource`" já usado para rastro e secundários serve para pontos e shapes. O ADR‑0002 exige traço visual diferente para futuro × passado.

---

## 10. Funcionamento offline

| Funcionalidade | Classificação | Motivo |
|---|---|---|
| Abrir o app, navegação, Ajustes, tema, licenças | **Totalmente offline** | tudo local; tema em `shared_preferences` |
| Listas de favoritos, linhas favoritas e recentes | **Totalmente offline** (listas) | `shared_preferences` |
| Aba Linhas (linhas vistas) | **Parcial** | deriva de favoritos (local) + consultas da sessão (precisam de rede) |
| Mapa base | **Parcial** | tiles/sprites/glyphs online (OpenFreeMap); só o que o SDK já tiver em cache aparece [HIPÓTESE quanto ao volume em cache] |
| Busca de ponto / chegadas | **Depende de internet** | só API; sem cache local por decisão (BUS‑OFF‑001) |
| Chegadas dos favoritos | **Depende de internet** | idem; status `offline` explícito por ponto |
| Acompanhamento e secundários | **Depende de internet** | polling da API |
| Web | **Depende de internet** para carregar; não há service worker de PWA offline configurado pelo projeto [HIPÓTESE: o `flutter_bootstrap.js` padrão pode registrar SW conforme a versão do Flutter] |

**Viabilidade de dados estáticos offline sem afetar o realtime:** alta. O realtime é isolado em `TransitRepository` + `StopArrivalsCubit`/`MapVehiclesCubit`, que só recebem códigos (`stopId`, `vehicleNumber`, `routeId` como texto). Um catálogo local (linhas, pontos, shapes, horários) entraria como **repositório separado** consultado pela UI e pelo mapa, juntando-se ao realtime por `routeId` e `stopId`. Pré-requisitos: (a) armazenamento adequado a volume (o próprio ADR‑0004 diz que `shared_preferences` não serve para catálogo); (b) confirmar que os códigos dos cadastros da CMTC batem com `Linha`/`qryIdPontoParada` da fonte realtime (incluindo zeros à esquerda — ADR‑0002 item 2 deixa isso **pendente**); (c) no Web, avaliar tamanho do pacote e IndexedDB; (d) tiles offline exigiriam pacote de mapa próprio (fora do escopo atual).

---

## 11. Estado dos testes e builds

Executado nesta auditoria em 27/10/2026, macOS, sem alterar código:

| Comando | SDK | Resultado |
|---|---|---|
| `flutter pub get --enforce-lockfile` | master 3.50‑pre | ok |
| `flutter analyze` | master 3.50‑pre | **No issues found** |
| `dart format --output=none --set-exit-if-changed lib test` | master 3.50‑pre | **limpo** (exit 0) |
| `flutter test` | master 3.50‑pre | **455 passaram, 5 falharam** — todas com `Asset 'shaders/ink_sparkle.frag' … Unsupported runtime stages format version. Expected 2, got 0` (incompatibilidade do SDK master local, não do app) |
| `flutter analyze` | **3.38.5** (versão do CI, via cache FVM) | **No issues found** |
| `flutter test` | **3.38.5** | **460/460 passaram** (`All tests passed!`) |
| `npm ci` (worker) | Node 26.8.2 | ok (dependências só em `worker/node_modules`, ignorado pelo git) |
| `npx tsc --noEmit` (worker) | TS 5.8 | **sem erros** |
| `npx vitest run` (worker) | vitest 5.0.3 | **5 arquivos, 26/26 passaram** |
| `curl /v1/health`, `/v1/version`, `/v1/stops/30402/arrivals` ×2 | produção | ok; `MISS` → `HIT` |

Os 5 testes que falharam no SDK local: `secondary_vehicle_callout_test` ("mostra só linha, destino e número…"), `saved_stops_ui_test` ("favorita e desfavorita pelo cabeçalho do ponto"), `stop_arrivals_page_test` ("aceita só dígitos e preserva zeros à esquerda"), `home_shell_v2_test` ("alterna Linhas, Favoritos, Meu ônibus…"), `large_text_layout_test` ("dock sem corte… 390 px"). Todos passam no 3.38.5.

Efeito colateral controlado: o `pub get` com 3.38.5 reescreveu `app/pubspec.lock` para as versões fixadas por esse SDK (iguais às do `HEAD`); o arquivo foi **restaurado** a partir de cópia feita antes dos testes, preservando a modificação local pré-existente. Isso indica que a modificação não commitada do `pubspec.lock` veio de um SDK mais novo que o do CI.

**Não executados:** builds Android (APK/AAB), iOS e Web — exigem tempo/assinatura e não foram rodados; o CI os cobre [DOC]. Nenhum teste em aparelho físico.

**Cobertura por área (arquivos de teste):** API client, cubits (`stop_arrivals`, `map_vehicles` + expiração, `saved_stops`), repositório HTTP, entidades, movimento observado, câmera, movimento do marcador, estilo do mapa, layout (fonte grande, 4 larguras, 2 temas), l10n, codec/stores de favoritos, UI da home. Worker: parsers das 3 fontes, roteamento, CORS. **Sem teste**: `ArrivalService`/`VehicleService`/`VehiclePositionService` + `cache.ts` (Cache API) isoladamente, `http-client.ts` (retry/timeout), integração real Flutter ↔ Worker fora dos smokes manuais.

---

## 12. Limitações e problemas atuais

1. **Sem rede estática:** nenhum catálogo de linhas/pontos/trajetos/horários; o produto depende do usuário saber o código do ponto.
2. **Dependência de endpoints não documentados da RMTC**, sem SLA, sem autenticação e sem autorização registrada; mudança de formato quebra o app (parsers tolerantes reduzem, mas não eliminam). O feed de frota já está bloqueado server-to-server.
3. **Tracking acoplado a um ponto** e sem persistência; sem trajeto futuro, sentido estruturado ou próximo ponto.
4. **Carga por usuário na fonte**: N chamadas individuais de posição (até 7 ônibus por aparelho em 15–30 s), mitigadas por cache de 5 s por par veículo+ponto. Sem rate limit no Worker.
5. **Versões de Flutter divergentes** (CI 3.38.5 × deploy web 3.47.4 × local master) — o artefato web publicado não é o testado; o `pubspec.lock` local já divergiu.
6. Dados úteis recebidos e descartados pela UI: `plannedArrival`, `predictedArrival`, `routeName`, `referenceStop.address`, `prediction`.
7. Web sem rotas/deep links; smoke testa `/ponto/30402` que só renderiza a home.
8. Sem seletor de idioma; sem CSP no web.
9. Documentação parcialmente desatualizada (flag v2, Supabase, comentário do domínio próprio).
10. Publicação nas lojas ainda com pendências (assinatura iOS no CI, consoles).

---

## 13. Capacidade de integração das bases oficiais

Itens avaliados sem supor formato dos arquivos CMTC (não estão no repositório).

### 13.1 Cadastro completo de linhas
- **Reaproveitável:** convenção `routeId` como `String` opaca e `normalizeRouteId` (Worker) / `canonicalRouteCode` (app, até 8 alfanuméricos); `RoutePlate`; aba Linhas e `SeenLinesPanel` como ponto de entrada; `SavedLine`.
- **Criar:** modelo `Line` (código, nome, operador?, tipos), repositório de catálogo, busca/filtro, tela de detalhe.
- **Módulos afetados:** `features/saved_stops` (aba Linhas), `home_chrome`, l10n, novo `features/catalog`.
- **Dependências técnicas:** armazenamento local estruturado; casamento do código CMTC com `Linha` do realtime (zeros, sufixos tipo `MGP1`).
- **Riscos:** códigos divergentes entre base e realtime; ADR‑0002 item 6 exige autorização registrada antes de uso em produção (agora recebida da CMTC — precisa ser formalizada no repositório).

### 13.2 Cadastro completo de pontos
- **Reaproveitável:** `canonicalStopCode` (dígitos, até 12), `SavedStop.name` (campo já existe, hoje sempre `null`), favoritos/recentes, fluxo `load(stopId)`.
- **Criar:** modelo `Stop` (código, nome/endereço, coordenada, terminal?), busca textual, "perto de mim" (exigiria permissão de localização — hoje removida e bloqueada pelo CI).
- **Afetados:** `search_header`, `arrivals_panel`, `saved_stops`, `AndroidManifest`/`Info.plist`/`_headers` se houver localização, workflow de permissões.
- **Riscos:** equivalência `00294` × `294` ainda não validada; mudança de permissões impacta lojas e privacidade.

### 13.3 Coordenadas de pontos
- **Reaproveitável:** `GeoPosition`, padrão GeoJSON source/layer, `geoDistanceMeters`.
- **Criar:** camada de pontos (provavelmente com clustering/zoom mínimo), toque no ponto → `load`, enquadramento ponto + ônibus.
- **Afetados:** `tracked_vehicle_map.dart`, `vehicle_map_data.dart`, `stop_arrivals_page.dart`.
- **Riscos:** desempenho com milhares de símbolos no Web; ADR‑0003 (não recriar o mapa).

### 13.4 Geometrias de trajetos por sentido (KMZ)
- **Reaproveitável:** camada de linha do rastro como modelo; `ObservedMovement` continua para o passado.
- **Criar:** conversão KMZ/KML → formato interno (no pipeline, não no app), modelo `Shape`/`Pattern` por linha+sentido, camada "trajeto" com estilo distinto do rastro, seleção do sentido.
- **Afetados:** mapa, `tracking_card` (texto que hoje nega trajeto futuro), testes que verificam ausência de "rota" na UI (`stop_arrivals_page_test.dart`).
- **Riscos:** associar o veículo ao sentido certo só com `DestinoNome`; tamanho dos shapes; precisão/atualidade do KMZ.

### 13.5 Horários programados (planilhas por terminal)
- **Reaproveitável:** distinção `ArrivalQuality.scheduled` ("Tabela Horária") e cores semânticas já separam programado de tempo real; `plannedArrival` já vem da fonte para as 2 próximas.
- **Criar:** modelo de viagem/horário por linha+sentido+terminal(+dia), consulta "próximas partidas", calendário (dias úteis/sábado/domingo/feriado).
- **Afetados:** painel de ponto/linha, l10n, formatação de horas.
- **Riscos:** planilhas por terminal podem não cobrir pontos intermediários; conflito visual entre horário de tabela e previsão realtime; atualização frequente das grades.

### 13.6 Sequência de paradas
- **Reaproveitável:** nada específico (ADR‑0002 proíbe inferir; `SeenLinesPanel` é pertencimento, não ordem).
- **Criar:** relação ordenada linha+sentido → pontos; "próximo ponto" via projeção no shape.
- **Riscos:** se a CMTC não entregar sequência explícita, derivá-la de KMZ violaria o ADR‑0002 sem uma decisão nova.

### 13.7 Dados estáticos offline
- **Reaproveitável:** padrão de store com interface (`SavedStopsStore`), codec versionado com `schema`, leitura tolerante.
- **Criar:** pacote de catálogo versionado (empacotado no app e/ou baixado), armazenamento estruturado (SQLite/drift ou equivalente com suporte Web — decisão nova, ADR‑0004 prevê reavaliar), verificação de integridade.
- **Riscos:** tamanho do app; suporte Web; migrações de schema.

### 13.8 Atualizações periódicas das bases
- **Reaproveitável:** CI com workflows manuais e smokes; `docs/v2/PLANO_BUSAOGYN_V2.md` §6 já descreve pipeline (staging, validação, troca atômica, remoções, favoritos órfãos) [DOC].
- **Criar:** pipeline de ingestão (fora do app), versionamento do catálogo, distribuição (Worker hoje só tem Cache API — exigiria R2/KV/D1 ou assets estáticos), tratamento de favoritos de pontos/linhas removidos.
- **Riscos:** custo/limites Cloudflare; consistência entre versão do catálogo e realtime.

### 13.9 Planejamento de viagens e baldeações
- **Reaproveitável:** praticamente nada além de modelos básicos e mapa.
- **Criar:** grafo de rede (paradas, sequências, horários), algoritmo (ex.: RAPTOR/CSA) local ou no servidor, geocodificação de origem/destino, localização do usuário.
- **Dependências:** 13.1–13.6 completos e consistentes.
- **Riscos:** maior esforço do conjunto; qualidade dos horários; necessidade de backend com computação.

---

## 14. Oportunidades de evolução

(Sem implementar — apenas oportunidades identificadas no código.)

1. Exibir nome/endereço do ponto a partir do cadastro oficial (campo `SavedStop.name` já previsto).
2. Busca de ponto por nome/endereço/linha e seleção no mapa.
3. Camada de pontos no mapa e enquadramento ponto ↔ ônibus.
4. Trajeto oficial da linha acompanhada (sentido escolhido por regra oficial), com traço distinto do rastro observado.
5. Usar `plannedArrival`/`predictedArrival` e quadro de horários para "próximas partidas" quando não houver realtime.
6. Catálogo real na aba Linhas (substitui "linhas vistas").
7. Unificar versão do Flutter entre CI, deploy web e desenvolvimento.
8. Rotas/deep links na web (`/ponto/{código}`).
9. Rate limiting/cotas no Worker antes de crescer o uso.
10. Avaliar feed de frota (`cconaweb`) ou GTFS‑RT oficial para reduzir chamadas individuais.

---

## 15. Riscos e dependências

| Dependência | Tipo | Risco |
|---|---|---|
| `simapp.rmtcgoiania.com.br` (`previsaochegada`, `recuperarposicao`) | terceiro, não documentado | mudança de contrato, bloqueio de acesso (já ocorreu com `cconaweb`), indisponibilidade; sem SLA |
| `rmtcgoiania.com.br` `cconaweb` | terceiro | **restrito** server-to-server |
| Autorização de uso das bases (ADR‑0002 item 6; protocolos SIC `2026106554419306` e `2026106602705606` no README/ARCHITECTURE) | jurídica | a base recebida da CMTC precisa ter a autorização registrada no repositório antes de ir a produção, conforme a própria regra do projeto |
| OpenFreeMap | terceiro gratuito | disponibilidade/limites do serviço de tiles |
| Cloudflare Workers/Cache API | plataforma | limites do plano; sem armazenamento durável hoje |
| `maplibre_gl 0.27.1` | pacote | limitações conhecidas (sem `isGesture`), atualização de plugin afeta 3 plataformas |
| Versões de Flutter divergentes | build | artefato publicado ≠ testado |
| Ausência de rate limit | operação | abuso da API repassado à RMTC |
| Assinatura iOS/consoles | publicação | bloqueia lojas |

---

## 16. Matriz de funcionalidades

| Área | Existente | Parcial | Ausente |
|---|---|---|---|
| Busca de ponto por código | ✅ F1 | | |
| Busca por nome/endereço/proximidade | | | ❌ |
| Chegadas (próximo + seguinte) | ✅ F2–F3 | | |
| Horário absoluto das chegadas | | ⚠️ recebido, não exibido | |
| Quadro de horários programados | | | ❌ |
| Catálogo de linhas | | ⚠️ F16 "linhas vistas" | ❌ catálogo |
| Cadastro/nome/endereço de pontos | | ⚠️ endereço recebido no tracking, não usado | ❌ |
| Favoritos de pontos | ✅ F12 | | |
| Favoritos de linhas | | ⚠️ F13 só por ponto | |
| Recentes | ✅ F15 | | |
| Chegadas dos favoritos | ✅ F14 | | |
| Mapa base | ✅ F5 | | |
| Pontos no mapa | | | ❌ |
| Acompanhar ônibus | ✅ F4 | | |
| Outros ônibus do ponto | ✅ F9 | | |
| Frota inteira / ônibus por linha | | ⚠️ B1–B2 no Worker, fonte restrita, sem uso | |
| Trajeto percorrido | ✅ F7 (observado, memória) | | |
| Trajeto futuro / shape oficial | | | ❌ |
| Sentido / itinerário estruturado | | ⚠️ destino em texto + direção observada | ❌ ida/volta |
| Sequência / próximo ponto | | | ❌ |
| Localização do usuário | | | ❌ (permissão removida) |
| Planejamento de viagem | | | ❌ |
| Offline | | ⚠️ UI + favoritos + mapa em cache | ❌ dados de transporte |
| Tema | ✅ F18 | | |
| Idiomas | | ⚠️ F20 automático, sem seletor | |
| Responsividade/acessibilidade | ✅ F23 | | |
| Web | | ⚠️ F24 sem rotas | |
| Notificações | | | ❌ |
| Contas/sincronização | | | ❌ |
| Telemetria/analytics | | | ❌ (por decisão) |

---

## 17. Perguntas técnicas em aberto

1. Os códigos de linha dos cadastros CMTC são idênticos ao `Linha`/`LinhaNumero` da fonte realtime (incluindo zeros à esquerda e códigos alfanuméricos)?
2. Os códigos de ponto dos cadastros/KMZ são os mesmos aceitos por `qryIdPontoParada`? `00294` e `294` são o mesmo ponto?
3. Os KMZ de trajeto trazem sentido (ida/volta/variante) explícito e um identificador que case com a linha do cadastro?
4. Como associar o destino textual do realtime (`DestinoNome`, `Destino`, ex.: "T BIBLIA") a um sentido/variante oficial?
5. A base traz a **sequência ordenada** de paradas por linha e sentido, ou só a geometria e os pontos separadamente? (Se só geometria, derivar sequência exige nova decisão sobre o ADR‑0002.)
6. As planilhas de horários por terminal cobrem quais tipos de dia e com que vigência? Há horários por ponto intermediário?
7. Qual é a frequência de atualização prevista das bases e por qual canal chegam?
8. A entrega da CMTC constitui a autorização exigida pelo ADR‑0002 item 6? Qual identificador/licença deve ser registrado e permite redistribuição dentro do app?
9. Onde o catálogo deve morar: empacotado no app, baixado de R2/KV, servido pelo Worker, ou combinação? Qual tamanho máximo aceitável no Web?
10. Qual armazenamento local adotar para catálogo (com suporte Web)? Isso substitui ou convive com `shared_preferences`?
11. Haverá localização do usuário ("pontos perto de mim")? Isso muda permissões, CI de permissões e política de privacidade.
12. O feed de frota (`cconaweb`) ou um GTFS‑RT oficial pode ser liberado para o Worker, permitindo posição sem ponto e menos chamadas?
13. Qual versão de Flutter é a oficial do projeto (3.38.5 do CI ou 3.47.4 do deploy web)?
14. O protocolo SIC de occupancy (`2026106602705606`) tem previsão de resposta?

---

## Apêndice A — Arquivos e módulos centrais para a próxima fase

- App, realtime (não quebrar; ADR‑0003): `app/lib/src/features/transit/presentation/cubit/stop_arrivals_cubit.dart`, `map_vehicles_cubit.dart`, `domain/repositories/transit_repository.dart`, `data/repositories/http_transit_repository.dart`.
- App, mapa: `features/transit/presentation/widgets/tracked_vehicle_map.dart`, `vehicle_map_data.dart`, `camera_follow.dart`, `core/config/map_config.dart`, `core/map/busao_style.dart`.
- App, telas: `features/transit/presentation/pages/stop_arrivals_page.dart`, `widgets/home_chrome.dart`, `search_header.dart`, `arrivals_panel.dart`, `arrival_card.dart`, `tracking_card.dart`, `features/saved_stops/presentation/widgets/saved_stops_widgets.dart` (`SeenLinesPanel`).
- App, persistência: `features/saved_stops/domain/saved_stop.dart`, `data/saved_stops_codec.dart`, `data/shared_preferences_saved_stops_store.dart`, `app/lib/main.dart`.
- App, textos: `app/lib/l10n/app_{pt,en,es}.arb` (inclusive `trackingFootnote`, `trailNote`, `linesSoon*`, `seenLinesNote`).
- Worker: `worker/src/index.ts`, `services/*`, `sources/rmtc/*`, `cache/cache.ts`, `utils/normalize.ts`, `wrangler.toml`.
- Regras: `docs/adr/0001…0004`, `docs/v2/PLANO_BUSAOGYN_V2.md` (§5 modelo de domínio e §6 pipeline de catálogo propostos), `docs/ARCHITECTURE.md`, `docs/PRIVACY.md`.
- Infra: `.github/workflows/flutter-ci.yml` (checagem de permissões), `deploy-web.yml`, `app/android/app/src/main/AndroidManifest.xml`, `app/ios/Runner/Info.plist`, `app/web/_headers`.
- Testes que codificam a ausência de rota/trajeto e precisarão de revisão consciente: `app/test/features/transit/stop_arrivals_page_test.dart` ("Meu ônibus diz o que o rastro mostra e que não há rota futura" e o teste que garante que nenhum texto contém "rota").
