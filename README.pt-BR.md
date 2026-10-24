<p align="center">
  <img src="app/assets/brand/logo-mark.png" width="112" alt="BusãoGyn">
</p>

<h1 align="center">BusãoGyn</h1>

<p align="center">
  Saiba onde seu ônibus está: chegadas por ponto e posição ao vivo no mapa, no transporte coletivo de Goiânia.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/TypeScript-3178C6?logo=typescript&logoColor=white" alt="TypeScript">
  <img src="https://img.shields.io/badge/Cloudflare_Workers-F38020?logo=cloudflare&logoColor=white" alt="Cloudflare Workers">
  <img src="https://img.shields.io/badge/MapLibre-396CB2" alt="MapLibre">
  <img src="https://img.shields.io/badge/platforms-Android_·_iOS_·_Web-555555" alt="Plataformas: Android, iOS e Web">
</p>

<p align="center">
  <a href="README.md">English</a> · <b>Português</b> · <a href="README.es.md">Español</a>
</p>

---

O BusãoGyn mostra as próximas chegadas de cada linha num ponto e acompanha, num mapa em tela cheia, o ônibus que tem GPS informado pela fonte. Cobre o transporte coletivo da RMTC de Goiânia e Região Metropolitana. É um app independente, sem vínculo com as operadoras.

**Web:** [busaogyn.lucksrei.com](https://busaogyn.lucksrei.com)

## Índice

- [Estado atual](#estado-atual)
- [O que o app faz](#o-que-o-app-faz)
- [Arquitetura](#arquitetura)
- [Mapa](#mapa)
- [Rodar e validar](#rodar-e-validar)
- [API (Worker)](#api-worker)
- [Deploy e CI](#deploy-e-ci)
- [Documentação](#documentação)
- [Privacidade e suporte](#privacidade-e-suporte)

## Estado atual

- **App** `1.0.0+1`: experiência map-first (mapa em tela cheia, painéis flutuantes, tema claro e noturno) com acompanhamento em tempo real. Roda em Android, iOS (release já testado em iPhone físico) e Web.
- **Navegação v2** é a padrão: **Linhas, Pontos, Favoritos e Meu ônibus** no dock, com **Ajustes** na barra de topo ([ADR-0001](docs/adr/0001-navegacao-e-catalogo-v2.md)).
- **API** publicada no Cloudflare Workers. O app consome só a API BusãoGyn; nenhuma tela chama a RMTC diretamente.
- **Sem dados estáticos oficiais ainda.** Enquanto o GTFS não chega, o app não mostra trajeto, sentido, pontos próximos nem ocupação, e não inventa esses dados ([ADR-0002](docs/adr/0002-dados-confiaveis-e-nao-inferencia.md)).

Protocolos oficiais em andamento:

| Pedido | Protocolo |
| --- | --- |
| Rede estática / GTFS | `2026106554419306` |
| Lotação / SIRI / capacidade | `2026106602705606` |

Escopo, backlog e riscos da v2: [`docs/v2/PLANO_BUSAOGYN_V2.md`](docs/v2/PLANO_BUSAOGYN_V2.md).

## O que o app faz

- **Pontos (chegadas):** busca pelo código do ponto (só dígitos, zeros à esquerda preservados) e lista as próximas chegadas por linha. Cada chegada traz a qualidade do dado: **tempo real** (GPS da fonte), **programado** (horário de tabela) ou **não confirmado**.
- **Meu ônibus:** acompanha um ônibus com GPS. A posição é consultada a cada 15 s e a câmera segue o ônibus (para de seguir quando você mexe no mapa; **Centralizar** volta a seguir). Direção e rastro são calculados a partir das posições observadas. Posição antiga ou fonte instável aparecem como desatualizadas, nunca como "ao vivo".
- **Mapa:** outros ônibus em tempo real do mesmo ponto também aparecem, e somem quando a posição envelhece.
- **Favoritos e recentes:** pontos e linhas favoritos (com as próximas chegadas de cada um) e pontos recentes, guardados só no aparelho ([ADR-0004](docs/adr/0004-persistencia-local-de-pontos.md)).
- **Linhas:** por enquanto mostra as **linhas vistas** nas consultas da sessão e nos favoritos. A lista completa depende de autorização da RMTC.
- **Idiomas:** português, inglês e espanhol, pelo idioma do aparelho (português quando o do aparelho não é atendido).
- **Ajustes:** tema (Sistema, Noturno ou Claro, com o mapa acompanhando) e informações sobre fontes de dados, mapa, tipografia e licenças.

O status do topo só diz **Ao vivo** quando há dado em tempo real recente. Uma resposta sem GPS aparece como programado, e um dado envelhecido aparece como desatualizado.

### Layout e visual

- **Celular:** mapa em tela cheia, cabeçalho e status flutuantes, bottom sheet e dock inferior.
- **Tablet e desktop (≥ 720 px):** mapa em tela cheia com uma coluna central flutuante, sem barra lateral fixa.
- Acento âmbar na interface; o verde fica reservado a tempo real e estados positivos.
- Tipografia [Geist e Geist Mono](https://vercel.com/font), empacotadas em `app/assets/fonts/geist` (SIL OFL 1.1). Geist Mono nos números: linha, minutos, ônibus e idades.
- Marca oficial em `docs/brand/`; os PNGs do app são gerados por `app/tool/generate_brand_assets.py`.

## Arquitetura

```text
app/      App Flutter (Cubit + repositories, MapLibre)
worker/   Cloudflare Worker em TypeScript (API BusãoGyn)
docs/     Arquitetura, ADRs, UX, deploy, publicação, privacidade e marca
```

- **App:** camadas por feature (`app/lib/src/features/{transit,saved_stops}` com `domain/data/presentation`) e `core/` para config, rede, mapa, tema e l10n. Estado com `flutter_bloc` (Cubit); `StopArrivalsCubit` e `MapVehiclesCubit` são os donos de ETA e posição.
- **API:** Worker em TypeScript que normaliza as respostas da fonte, usa a Cache API como único armazenamento e marca cada resposta com a idade do dado.
- **i18n:** ARB em `app/lib/l10n/` (`app_pt.arb` é o modelo); `flutter gen-l10n` gera as classes, que são versionadas. `app/test/core/l10n_test.dart` confere que as três línguas têm as mesmas chaves e placeholders.

Detalhes: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Mapa

[MapLibre](https://maplibre.org) (`maplibre_gl` 0.27.1) com dados do [OpenFreeMap](https://openfreemap.org), sem chave de API.

- Os estilos claro e escuro (`app/assets/map/busao-light.json` e `busao-dark.json`) são pré-gerados a partir do OpenFreeMap Liberty por `app/tool/build_map_styles.dart`. O app não processa estilo ao abrir.
- Os estilos mantêm as sources, fontes e sprites do Liberty. A atribuição (OpenFreeMap, OpenMapTiles, OpenStreetMap) aparece no controle nativo do MapLibre.
- Se um estilo empacotado não carregar, o mapa volta para o Liberty por URL.

```bash
# outro estilo (opcional: um próprio para o tema noturno)
flutter run --dart-define=MAP_STYLE_URL=https://exemplo.com/dia.json --dart-define=MAP_STYLE_DARK_URL=https://exemplo.com/noite.json

# regenerar os estilos depois de uma mudança no Liberty
cd app && dart run tool/build_map_styles.dart
```

## Rodar e validar

Requisitos: **Flutter 3.38.5** (Dart 3.10), **JDK 21** para Android, Xcode atual para iOS, Node.js para o Worker.

```bash
cd app
flutter pub get
flutter run                      # usa a API de produção
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Apontar para um Worker local:

```bash
flutter run --dart-define=BUSAOGYN_API_BASE_URL=http://127.0.0.1:8787
```

### Plataformas

| | |
| --- | --- |
| Identificador | `com.lucksrei.busaogyn` |
| Android | minSdk 24, AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14 |
| iOS | deployment target 15.0 (Runner e pods), ciclo de vida UIScene |
| Web | controle de atribuição posicionado pela variável CSS `--busao-map-attribution-bottom` (`app/web/index.html`) |

A versão fica em `app/pubspec.yaml` (`version`) e define `versionName`/`versionCode` no Android e `CFBundleShortVersionString`/`CFBundleVersion` no iOS.

## API (Worker)

```bash
cd worker
npm ci
npm run typecheck
npm test
npm run dev
```

```text
GET /v1/health
GET /v1/version
GET /v1/stops/{stopId}/arrivals
GET /v1/vehicles/{vehicleNumber}/position?stopId={stopId}
GET /v1/vehicles                  experimental (frota RMTC restrita server-to-server)
GET /v1/routes/{routeId}/vehicles experimental (mesma restrição)
```

As respostas trazem `meta` com `fetchedAt`, `stale` e `ageSeconds`; o app usa isso para nunca apresentar dado antigo como atual.

A busca direta por número do ônibus está **bloqueada**: a fonte exige o código do ponto e o app não envia ponto falso. O que destrava a busca está em [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

Produção: `https://busaogyn-api.lively-cloud-f009.workers.dev` (padrão do app).

## Deploy e CI

| Workflow | O que faz |
| --- | --- |
| `flutter-ci` | format, analyze e testes do app |
| `worker-ci` | typecheck e testes do Worker |
| `worker-deploy` | deploy da API + smoke de produção (health, ETA do ponto canário 30402, veículo realtime da linha 020, posição e cache) |
| `worker-integration-smoke` | sobe o Worker local (`wrangler dev`) e roda o smoke da API contra a fonte real (manual) |
| `deploy-web` / `rollback-web` | publica ou reverte o app Web, com smoke nas rotas `/ponto/30402` e `/linhas` |
| `rmtc-probe` | sonda única das fontes da RMTC (manual) |

## Documentação

- [ARCHITECTURE.md](docs/ARCHITECTURE.md): camadas, contrato da API e limitações da fonte
- [adr/](docs/adr/README.md): decisões de navegação, dados, mapa e persistência
- [MVP_UX.md](docs/MVP_UX.md): comportamento esperado das telas
- [DEPLOYMENT.md](docs/DEPLOYMENT.md) e [WEB.md](docs/WEB.md): deploy da API e do Web
- [MOBILE_RELEASE.md](docs/MOBILE_RELEASE.md): lojas, assinatura, ícones e checklist
- [PRIVACY.md](docs/PRIVACY.md): dados, rede e serviços externos

## Privacidade e suporte

O app não tem conta e não usa localização. Não tem anúncios, analytics nem relatório de falhas, e guarda os dados só no aparelho. [Política de privacidade](https://lucksrei.com/projects/busaogyn/privacy/), [exclusão de dados](https://lucksrei.com/projects/busaogyn/data-deletion/) e [suporte](https://lucksrei.com/projects/busaogyn/support/). Contato: marketing@lucksrei.com.

---

Criado por Lucas Diogo França, um produto [Lucksrei](https://lucksrei.com).
