# BusãoGyn

**BusãoGyn — saiba onde seu ônibus está.**

App Flutter (Android, iOS e Web) + Cloudflare Worker para o transporte público da RMTC de Goiânia e Região Metropolitana. Você digita o código do ponto, vê as próximas chegadas de cada linha e acompanha no mapa o ônibus que tem GPS informado pela fonte.

## Estado atual

- **App:** versão `1.0.0+1`, experiência map-first redesenhada (mapa em tela cheia, painéis flutuantes, tema claro e noturno) e acompanhamento em tempo real. Já roda em Android, iOS (já compilado em release num iPhone físico) e Web.
- **API:** o Worker em `worker/` está publicado no Cloudflare Workers. O app consome exclusivamente a API BusãoGyn; nenhuma tela chama endpoints da RMTC diretamente.
- **Sem dados estáticos oficiais ainda:** enquanto o GTFS não chega, o app não mostra trajeto, sentido, pontos próximos, favoritos nem ocupação, e não inventa esses dados.

### Protocolos oficiais em andamento

- Rede estática / GTFS: `2026106554419306`
- Lotação / SIRI / capacidade: `2026106602705606`

## Estrutura

```text
app/      App Flutter (Cubit + repositories, MapLibre)
worker/   Cloudflare Worker em TypeScript (API BusãoGyn)
docs/     Arquitetura, UX, deploy, publicação, privacidade e marca
```

## App Flutter

### O que o app faz

- **Chegadas:** busca pelo código do ponto (só dígitos, zeros à esquerda preservados) e lista as próximas chegadas por linha. Cada chegada traz a qualidade do dado: **tempo real** (GPS da fonte), **programado** (horário de tabela) ou **não confirmado**.
- **Meu ônibus:** acompanha um ônibus com GPS. A posição é consultada a cada 15 s, a câmera segue o ônibus (para de seguir quando você mexe no mapa; **Centralizar** volta a seguir), e direção e rastro aparecem calculados a partir das posições observadas. Posição antiga ou fonte instável aparecem como desatualizadas, nunca como "ao vivo".
- **Mapa:** outros ônibus em tempo real do mesmo ponto também aparecem no mapa, e somem quando a posição envelhece.
- **Ajustes:** tema (Sistema, Noturno ou Claro, com o mapa acompanhando) e informações sobre fontes de dados, mapa, fontes tipográficas e licenças.

O status do topo só diz **Ao vivo** quando há dado em tempo real recente. Uma resposta da API sem GPS aparece como programado, e um dado envelhecido aparece como desatualizado.

### Layout e visual

- Celular: mapa em tela cheia, cabeçalho e status flutuantes, bottom sheet e dock inferior (**Chegadas / Meu ônibus / Ajustes**).
- Tablet e desktop (≥ 720 px): mapa em tela cheia com uma coluna central flutuante, sem barra lateral fixa.
- Acento âmbar para a interface. O verde fica reservado a tempo real e estados positivos.
- Tipografia [Geist e Geist Mono](https://vercel.com/font) empacotadas em `app/assets/fonts/geist` (SIL Open Font License 1.1, texto em `OFL.txt`). Geist Mono é usada em números: linha, minutos, ônibus e idades.
- Marca oficial em `docs/brand/`; os PNGs do app são gerados por `app/tool/generate_brand_assets.py`.

### Mapa

O mapa usa [MapLibre](https://maplibre.org) (`maplibre_gl` 0.27.1) com dados do [OpenFreeMap](https://openfreemap.org), sem chave de API.

- Os estilos claro e escuro do BusãoGyn (`app/assets/map/busao-light.json` e `busao-dark.json`) são pré-gerados a partir do OpenFreeMap Liberty por `app/tool/build_map_styles.dart`. O app não processa estilo ao abrir.
- Os estilos mantêm as mesmas sources, fontes e sprites do Liberty. A atribuição (OpenFreeMap, OpenMapTiles, OpenStreetMap) vem das sources e aparece no controle nativo do MapLibre.
- Se um estilo empacotado não carregar, o mapa volta para o Liberty por URL.
- Para usar outro estilo:

```bash
flutter run --dart-define=MAP_STYLE_URL=https://exemplo.com/estilo.json
# opcional: estilo próprio para o tema noturno
flutter run --dart-define=MAP_STYLE_URL=https://exemplo.com/dia.json --dart-define=MAP_STYLE_DARK_URL=https://exemplo.com/noite.json
```

Para regenerar os estilos depois de uma mudança no Liberty:

```bash
cd app
dart run tool/build_map_styles.dart
```

### Plataformas e toolchain

- Identificador Android/iOS: `com.lucksrei.busaogyn`.
- Baseline: **Flutter 3.38.5** (Dart 3.10). Os arquivos de Android/iOS seguem o template dessa versão: AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14.
- Android: minSdk 24 (vem de `flutter.minSdkVersion`; o `maplibre_gl` exigiria só 21). O build exige **JDK 21**.
- iOS: deployment target **15.0** no Runner e em todos os pods (`app/ios/Podfile`). O Xcode atual recusa pods que declaram iOS 12/13.
- Web: o controle de atribuição do MapLibre fica acima do painel via a variável CSS `--busao-map-attribution-bottom` (`app/web/index.html`).

### Rodar e validar

```bash
cd app
flutter pub get
flutter run                      # usa a API de produção
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
flutter build web --release
```

Para apontar para um Worker local:

```bash
flutter run --dart-define=BUSAOGYN_API_BASE_URL=http://127.0.0.1:8787
```

Versão em `app/pubspec.yaml` (`version`), que define `versionName`/`versionCode` no Android e `CFBundleShortVersionString`/`CFBundleVersion` no iOS.

Publicação nas lojas e no Web, assinatura, ícones e checklist: [docs/MOBILE_RELEASE.md](docs/MOBILE_RELEASE.md). Privacidade (dados, rede e serviços externos): [docs/PRIVACY.md](docs/PRIVACY.md). Comportamento esperado das telas: [docs/MVP_UX.md](docs/MVP_UX.md).

## Worker

```bash
cd worker
npm ci
npm run typecheck
npm test
npm run dev
```

Endpoints:

```text
GET /v1/health
GET /v1/version
GET /v1/stops/{stopId}/arrivals
GET /v1/vehicles/{vehicleNumber}/position?stopId={stopId}
GET /v1/vehicles                  experimental (frota RMTC restrita server-to-server)
GET /v1/routes/{routeId}/vehicles experimental (mesma restrição)
```

As respostas trazem `meta` com `fetchedAt`, `stale` e `ageSeconds`. O app usa isso para nunca apresentar dado antigo como atual.

A busca direta por número do ônibus está **bloqueada**: a fonte exige o código do ponto e o app não envia ponto falso. Detalhes e o que destrava a busca: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Produção

API pública:

```text
https://busaogyn-api.lively-cloud-f009.workers.dev
```

O app usa essa URL por padrão. O deploy do Worker roda um smoke de produção: health, ETA do ponto canário 30402, seleção de veículo realtime da linha 020, posição individual e cache. Deploy e CI: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) e `.github/workflows/`.
