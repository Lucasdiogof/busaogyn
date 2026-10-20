<p align="center">
  <img src="app/assets/brand/logo-mark.png" width="112" alt="BusãoGyn">
</p>

<h1 align="center">BusãoGyn</h1>

<p align="center">
  Know where your bus is: arrivals by stop and live position on a map, for public transport in Goiânia, Brazil.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Cloudflare_Workers-F38020?logo=cloudflare&logoColor=white" alt="Cloudflare Workers">
  <img src="https://img.shields.io/badge/MapLibre-396CB2" alt="MapLibre">
  <img src="https://img.shields.io/badge/platforms-Android_·_iOS_·_Web-555555" alt="Platforms: Android, iOS and Web">
</p>

<p align="center">
  <b>English</b> · <a href="README.pt-BR.md">Português</a> · <a href="README.es.md">Español</a>
</p>

---

BusãoGyn shows the next arrivals of every line at a stop and follows, on a full-screen map, the bus that has a GPS position reported by the source. It covers the RMTC public transport of Goiânia and its metropolitan region. It is an independent app and is not affiliated with the transport operators.

## What it does

- **Arrivals:** type a stop code and see the next arrivals per line. Each arrival shows the data quality: **real time** (source GPS), **scheduled** (timetable) or **unconfirmed**.
- **My bus:** follows a bus with GPS. The position is refreshed every 15 s, the camera follows the bus, and direction and trail are computed from the observed positions. Old positions or an unstable source are shown as outdated, never as "live".
- **Map:** other real-time buses for the same stop also appear on the map and disappear when their position gets old.
- **Favorites and recents:** favorite stops and lines and recent stops, stored only on the device.
- **Languages:** Portuguese, English and Spanish, following the device language (Portuguese when the device language is not supported). Strings live in the ARB files in `app/lib/l10n/` (`app_pt.arb` is the template); `flutter gen-l10n` generates the committed classes, and `app/test/core/l10n_test.dart` checks that the three languages share the same keys and placeholders.
- **Settings:** light, dark or system theme (the map follows it), data sources, map, fonts and licenses.

## Privacy

There is no account, sign-in or sign-up. The app does not use your location, has no ads, analytics or crash reporting, and keeps its data only on the device. Privacy policy: [lucksrei.com/projects/busaogyn/privacy](https://lucksrei.com/projects/busaogyn/privacy/). Data deletion: [data-deletion](https://lucksrei.com/projects/busaogyn/data-deletion/). Support: [support](https://lucksrei.com/projects/busaogyn/support/) or marketing@lucksrei.com.

## Stack

- **App:** Flutter with Cubit and repositories, MapLibre (OpenFreeMap, no API key), Android, iOS and Web.
- **API:** Cloudflare Worker in TypeScript (`worker/`). The app talks only to this API, never to the transport sources directly.

## Run

```bash
cd app
flutter pub get
flutter run
```

```bash
cd worker
npm ci
npm test
npm run dev
```

The full technical documentation (architecture, deploy, release, map styles) is in [README.pt-BR.md](README.pt-BR.md) and [docs/](docs/).

---

Built by Lucas Diogo França. A [Lucksrei](https://lucksrei.com) product.
