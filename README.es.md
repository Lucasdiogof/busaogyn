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
  <img src="https://img.shields.io/badge/Cloudflare_Workers-F38020?logo=cloudflare&logoColor=white" alt="Cloudflare Workers">
  <img src="https://img.shields.io/badge/MapLibre-396CB2" alt="MapLibre">
  <img src="https://img.shields.io/badge/platforms-Android_·_iOS_·_Web-555555" alt="Platforms: Android, iOS and Web">
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.pt-BR.md">Português</a> · <b>Español</b>
</p>

---

BusãoGyn muestra las próximas llegadas de cada línea en una parada y sigue, en un mapa a pantalla completa, el autobús con posición GPS informada por la fuente. Cubre el transporte colectivo de la RMTC de Goiânia y su región metropolitana. Es una app independiente y no está afiliada a los operadores de transporte.

## Qué hace

- **Llegadas:** escribe el código de una parada y ve las próximas llegadas por línea. Cada llegada indica la calidad del dato: **tiempo real** (GPS de la fuente), **programado** (horario de tabla) o **no confirmado**.
- **Mi autobús:** sigue un autobús con GPS. La posición se actualiza cada 15 s, la cámara sigue al autobús, y la dirección y el rastro se calculan a partir de las posiciones observadas. Una posición antigua o una fuente inestable se muestran como desactualizadas, nunca como "en vivo".
- **Mapa:** otros autobuses en tiempo real de la misma parada también aparecen en el mapa y desaparecen cuando su posición envejece.
- **Favoritos y recientes:** paradas y líneas favoritas y paradas recientes, guardadas solo en el dispositivo.
- **Ajustes:** tema claro, nocturno o del sistema (el mapa lo acompaña), fuentes de datos, mapa, tipografías y licencias.

## Privacidad

No hay cuenta, inicio de sesión ni registro. La app no usa tu ubicación, no tiene anuncios, analytics ni reporte de fallos, y guarda sus datos solo en el dispositivo. Política de privacidad: [lucksrei.com/projects/busaogyn/privacy](https://lucksrei.com/projects/busaogyn/privacy/). Eliminación de datos: [data-deletion](https://lucksrei.com/projects/busaogyn/data-deletion/). Soporte: [support](https://lucksrei.com/projects/busaogyn/support/) o marketing@lucksrei.com.

## Stack

- **App:** Flutter con Cubit y repositorios, MapLibre (OpenFreeMap, sin clave de API), Android, iOS y Web.
- **API:** Cloudflare Worker en TypeScript (`worker/`). La app habla solo con esta API, nunca directamente con las fuentes de transporte.

## Ejecutar

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

La documentación técnica completa (arquitectura, deploy, publicación, estilos de mapa) está en [README.pt-BR.md](README.pt-BR.md) y en [docs/](docs/).

---

Creado por Lucas Diogo França. Un producto de [Lucksrei](https://lucksrei.com).
