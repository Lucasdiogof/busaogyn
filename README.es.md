<p align="center">
  <img src="app/assets/brand/logo-mark.png" width="112" alt="BusãoGyn">
</p>

<h1 align="center">BusãoGyn</h1>

<p align="center">
  Sepa dónde está su autobús: llegadas por parada y posición en vivo en el mapa, para el transporte colectivo de Goiânia, Brasil.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/TypeScript-3178C6?logo=typescript&logoColor=white" alt="TypeScript">
  <img src="https://img.shields.io/badge/Cloudflare_Workers-F38020?logo=cloudflare&logoColor=white" alt="Cloudflare Workers">
  <img src="https://img.shields.io/badge/MapLibre-396CB2" alt="MapLibre">
  <img src="https://img.shields.io/badge/platforms-Android_·_iOS_·_Web-555555" alt="Plataformas: Android, iOS y Web">
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.pt-BR.md">Português</a> · <b>Español</b>
</p>

---

BusãoGyn muestra las próximas llegadas de cada línea en una parada y sigue, en un mapa a pantalla completa, el autobús con posición GPS informada por la fuente. Cubre el transporte colectivo de la RMTC de Goiânia y su región metropolitana. Es una app independiente, sin vínculo con los operadores.

**Web:** [busaogyn.lucksrei.com](https://busaogyn.lucksrei.com)

## Índice

- [Estado actual](#estado-actual)
- [Qué hace](#qué-hace)
- [Arquitectura](#arquitectura)
- [Mapa](#mapa)
- [Ejecutar y validar](#ejecutar-y-validar)
- [API (Worker)](#api-worker)
- [Deploy y CI](#deploy-y-ci)
- [Documentación](#documentación)
- [Privacidad y soporte](#privacidad-y-soporte)

## Estado actual

- **App** `1.0.0+1`: experiencia map-first (mapa a pantalla completa, paneles flotantes, tema claro y nocturno) con seguimiento en tiempo real. Funciona en Android, iOS (build de release probado en un iPhone físico) y Web.
- **Navegación v2** por defecto: **Líneas, Paradas, Favoritos y Mi autobús** en el dock, con **Ajustes** en la barra superior ([ADR-0001](docs/adr/0001-navegacao-e-catalogo-v2.md)).
- **API** publicada en Cloudflare Workers. La app consume solo la API de BusãoGyn; ninguna pantalla llama a la RMTC directamente.
- **Aún sin datos estáticos oficiales.** Hasta que llegue el GTFS, la app no muestra trayecto, sentido, paradas cercanas ni ocupación, y no inventa esos datos ([ADR-0002](docs/adr/0002-dados-confiaveis-e-nao-inferencia.md)).

Solicitudes oficiales en curso:

| Solicitud | Protocolo |
| --- | --- |
| Red estática / GTFS | `2026106554419306` |
| Ocupación / SIRI / capacidad | `2026106602705606` |

Alcance, backlog y riesgos de la v2: [`docs/v2/PLANO_BUSAOGYN_V2.md`](docs/v2/PLANO_BUSAOGYN_V2.md) (en portugués).

## Qué hace

- **Paradas (llegadas):** busca por el código de la parada (solo dígitos, ceros a la izquierda conservados) y lista las próximas llegadas por línea. Cada llegada indica la calidad del dato: **tiempo real** (GPS de la fuente), **programado** (horario de tabla) o **no confirmado**.
- **Mi autobús:** sigue un autobús con GPS. La posición se consulta cada 15 s y la cámara sigue al autobús (deja de seguirlo cuando mueves el mapa; **Centrar** lo retoma). La dirección y el rastro se calculan a partir de las posiciones observadas. Una posición antigua o una fuente inestable se muestran como desactualizadas, nunca como "en vivo".
- **Mapa:** otros autobuses en tiempo real de la misma parada también aparecen, y desaparecen cuando su posición envejece.
- **Favoritos y recientes:** paradas y líneas favoritas (con las próximas llegadas de cada una) y paradas recientes, guardadas solo en el dispositivo ([ADR-0004](docs/adr/0004-persistencia-local-de-pontos.md)).
- **Líneas:** por ahora muestra las **líneas vistas** en las consultas de la sesión y en los favoritos. La lista completa depende de la autorización de la RMTC.
- **Idiomas:** portugués, inglés y español, según el idioma del dispositivo (portugués cuando el del dispositivo no está disponible).
- **Ajustes:** tema (Sistema, Nocturno o Claro, con el mapa acompañando) e información sobre fuentes de datos, mapa, tipografía y licencias.

El estado superior solo dice **En vivo** cuando hay datos recientes en tiempo real. Una respuesta sin GPS aparece como programada, y un dato envejecido aparece como desactualizado.

### Diseño y visual

- **Móvil:** mapa a pantalla completa, cabecera y estado flotantes, bottom sheet y dock inferior.
- **Tablet y escritorio (≥ 720 px):** mapa a pantalla completa con una columna central flotante, sin barra lateral fija.
- Acento ámbar en la interfaz; el verde queda reservado al tiempo real y a los estados positivos.
- Tipografías [Geist y Geist Mono](https://vercel.com/font), incluidas en `app/assets/fonts/geist` (SIL OFL 1.1). Geist Mono se usa en los números: línea, minutos, autobús y antigüedad.
- Marca oficial en `docs/brand/`; los PNG de la app se generan con `app/tool/generate_brand_assets.py`.

## Arquitectura

```text
app/      App Flutter (Cubit + repositories, MapLibre)
worker/   Cloudflare Worker en TypeScript (API BusãoGyn)
docs/     Arquitectura, ADRs, UX, deploy, publicación, privacidad y marca
```

- **App:** capas por feature (`app/lib/src/features/{transit,saved_stops}` con `domain/data/presentation`) y `core/` para config, red, mapa, tema y l10n. Estado con `flutter_bloc` (Cubit); `StopArrivalsCubit` y `MapVehiclesCubit` son los dueños de ETA y posición.
- **API:** Worker en TypeScript que normaliza las respuestas de la fuente, usa la Cache API como único almacenamiento y marca cada respuesta con la antigüedad del dato.
- **i18n:** ARB en `app/lib/l10n/` (`app_pt.arb` es la plantilla); `flutter gen-l10n` genera las clases, que se versionan. `app/test/core/l10n_test.dart` comprueba que los tres idiomas tengan las mismas claves y placeholders.

Detalles: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Mapa

[MapLibre](https://maplibre.org) (`maplibre_gl` 0.27.1) con datos de [OpenFreeMap](https://openfreemap.org), sin clave de API.

- Los estilos claro y oscuro (`app/assets/map/busao-light.json` y `busao-dark.json`) se generan previamente a partir de OpenFreeMap Liberty con `app/tool/build_map_styles.dart`. La app no procesa estilos al abrir.
- Los estilos mantienen las sources, fuentes y sprites de Liberty. La atribución (OpenFreeMap, OpenMapTiles, OpenStreetMap) aparece en el control nativo de MapLibre.
- Si un estilo incluido no carga, el mapa vuelve a Liberty por URL.

```bash
# otro estilo (opcional: uno propio para el tema nocturno)
flutter run --dart-define=MAP_STYLE_URL=https://ejemplo.com/dia.json --dart-define=MAP_STYLE_DARK_URL=https://ejemplo.com/noche.json

# regenerar los estilos tras un cambio en Liberty
cd app && dart run tool/build_map_styles.dart
```

## Ejecutar y validar

Requisitos: **Flutter 3.38.5** (Dart 3.10), **JDK 21** para Android, Xcode actual para iOS, Node.js para el Worker.

```bash
cd app
flutter pub get
flutter run                      # usa la API de producción
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Apuntar a un Worker local:

```bash
flutter run --dart-define=BUSAOGYN_API_BASE_URL=http://127.0.0.1:8787
```

### Plataformas

| | |
| --- | --- |
| Identificador | `com.lucksrei.busaogyn` |
| Android | minSdk 24, AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14 |
| iOS | deployment target 15.0 (Runner y pods), ciclo de vida UIScene |
| Web | control de atribución posicionado por la variable CSS `--busao-map-attribution-bottom` (`app/web/index.html`) |

La versión está en `app/pubspec.yaml` (`version`) y define `versionName`/`versionCode` en Android y `CFBundleShortVersionString`/`CFBundleVersion` en iOS.

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
GET /v1/vehicles                  experimental (flota RMTC restringida a server-to-server)
GET /v1/routes/{routeId}/vehicles experimental (misma restricción)
```

Las respuestas incluyen `meta` con `fetchedAt`, `stale` y `ageSeconds`; la app lo usa para nunca presentar un dato antiguo como actual.

La búsqueda directa por número de autobús está **bloqueada**: la fuente exige el código de la parada y la app no envía una parada falsa. Lo que la desbloquearía está en [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

Producción: `https://busaogyn-api.lively-cloud-f009.workers.dev` (por defecto en la app).

## Deploy y CI

| Workflow | Qué hace |
| --- | --- |
| `flutter-ci` | format, analyze y tests de la app |
| `worker-ci` | typecheck y tests del Worker |
| `worker-deploy` | deploy de la API + smoke de producción (health, ETA en la parada canaria 30402, vehículo en tiempo real de la línea 020, posición y caché) |
| `worker-integration-smoke` | levanta el Worker en local (`wrangler dev`) y ejecuta el smoke de la API contra la fuente real (manual) |
| `deploy-web` / `rollback-web` | publica o revierte la app Web, con smoke en `/ponto/30402` y `/linhas` |
| `rmtc-probe` | sondeo puntual de las fuentes de la RMTC (manual) |

## Documentación

La documentación está en portugués.

- [ARCHITECTURE.md](docs/ARCHITECTURE.md): capas, contrato de la API y limitaciones de la fuente
- [adr/](docs/adr/README.md): decisiones de navegación, datos, mapa y persistencia
- [MVP_UX.md](docs/MVP_UX.md): comportamiento esperado de las pantallas
- [DEPLOYMENT.md](docs/DEPLOYMENT.md) y [WEB.md](docs/WEB.md): deploy de la API y de la Web
- [MOBILE_RELEASE.md](docs/MOBILE_RELEASE.md): tiendas, firma, iconos y checklist
- [PRIVACY.md](docs/PRIVACY.md): datos, red y servicios externos

## Privacidad y soporte

No hay cuenta y la app no usa tu ubicación. No tiene anuncios, analytics ni reporte de fallos, y guarda sus datos solo en el dispositivo. [Política de privacidad](https://lucksrei.com/projects/busaogyn/privacy/), [eliminación de datos](https://lucksrei.com/projects/busaogyn/data-deletion/) y [soporte](https://lucksrei.com/projects/busaogyn/support/). Contacto: marketing@lucksrei.com.

---

Creado por Lucas Diogo França, un producto de [Lucksrei](https://lucksrei.com).
