# BusãoGyn

**BusãoGyn — saiba onde seu ônibus está.**

Projeto Flutter + Cloudflare Worker para transporte público da RMTC de Goiânia e Região Metropolitana.

## Estado atual

O backend está em `worker/` e publicado em produção no Cloudflare Workers. O app Flutter consome exclusivamente a API BusãoGyn; nenhuma tela deve consumir endpoints RMTC diretamente.

### Protocolos oficiais em andamento

- Rede estática / GTFS: `2026106554419306`
- Lotação / SIRI / capacidade: `2026106602705606`

## Worker

```bash
cd worker
npm ci
npm run typecheck
npm test
npm run dev
```

Endpoints iniciais:

```text
GET /v1/health
GET /v1/version
GET /v1/vehicles
GET /v1/routes/020/vehicles
GET /v1/stops/{stopId}/arrivals
GET /v1/vehicles/{vehicleNumber}/position?stopId={stopId}
```

Veja [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Produção

API pública:

```text
https://busaogyn-api.lively-cloud-f009.workers.dev
```

O app Flutter usa essa URL por padrão. Para desenvolvimento local, sobrescreva com:

```bash
flutter run --dart-define=BUSAOGYN_API_BASE_URL=http://127.0.0.1:8787
```

O deploy do Worker executa um smoke de produção cobrindo health, ETA do ponto canário 30402, seleção de veículo realtime da linha 020, posição individual e cache.

## App Flutter

Identificador Android/iOS: `com.lucksrei.busaogyn`. Alvos: Android (minSdk 24), iOS (13+ exigido pelo MapLibre; projeto em 15.0) e Web.

A baseline é o Flutter 3.38.5: os arquivos de Android/iOS seguem o template dessa versão (AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14). O minSdk 24 vem de `flutter.minSdkVersion` do Flutter 3.38.5; o `maplibre_gl` 0.27.1 exige só 21, então o piso é do Flutter.

O mapa usa [MapLibre](https://maplibre.org) (`maplibre_gl`) com o estilo [OpenFreeMap Liberty](https://openfreemap.org), sem chave de API. Para trocar o estilo:

```bash
flutter run --dart-define=MAP_STYLE_URL=https://tiles.openfreemap.org/styles/liberty
```

O build Android exige JDK 21.

Versão atual: `1.0.0+1` (`version` em `app/pubspec.yaml`, que define `versionName`/`versionCode` no Android e `CFBundleShortVersionString`/`CFBundleVersion` no iOS).

Publicação nas lojas e no Web, assinatura, ícones e checklist: [docs/MOBILE_RELEASE.md](docs/MOBILE_RELEASE.md). Comportamento de privacidade (dados, rede e serviços externos): [docs/PRIVACY.md](docs/PRIVACY.md).

