# BusãoGyn — baseline mobile e release

Atualizado em 06/10/2026.

Este documento registra requisitos técnicos já decididos para Android, iOS e Web. Ele não substitui a documentação oficial das plataformas.

## Identidade

- Nome: `BusãoGyn`
- Android applicationId: `com.lucksrei.busaogyn`
- Android namespace: `com.lucksrei.busaogyn`
- iOS Bundle Identifier: `com.lucksrei.busaogyn`

Nenhum target novo deve usar IDs antigos ou alternativos.

## API

Produção:

```text
https://busaogyn-api.lively-cloud-f009.workers.dev
```

O app Flutter acessa somente a API BusãoGyn. Nenhuma tela ou repository Flutter deve acessar endpoints RMTC/RedeMob diretamente.

## Mapa

Stack definida para esta fase:

- `maplibre_gl ^0.27.1`
- OpenFreeMap
- estilo padrão: `https://tiles.openfreemap.org/styles/liberty`

Requisitos atuais do plugin:

- Flutter 3.29+
- Dart 3.7+
- JDK 21 para Android
- Android API 21+
- iOS 13+
- Web com WebGL2

No Web, o plugin 0.27.x carrega MapLibre GL JS automaticamente. Não adicionar `maplibre-gl.js` ou CSS manualmente no `web/index.html`.

Conteúdo de style, images, sources e layers que precisa sobreviver a recriação da Activity deve ser criado no `onStyleLoadedCallback`, porque ele é chamado novamente após recriação do mapa.

A URL do style deve permanecer configurável via `--dart-define` para permitir trocar provider/self-host no futuro.

## OpenFreeMap

O serviço público atual:

- permite uso comercial;
- não exige API key;
- exige atribuição;
- não oferece SLA.

A atribuição não deve ser removida.

## Android

Baseline:

- `minSdk >= 21`
- `targetSdk 36` para publicação atual no Google Play
- JDK 21
- AGP moderno e compatível com o Flutter utilizado
- validar compatibilidade com page size de 16 KB antes da publicação

Permissões:

- Internet: necessária.
- Localização: não adicionar enquanto o produto não usar localização do usuário.
- Evitar qualquer permissão que não tenha funcionalidade correspondente.

Validações mínimas:

```bash
flutter analyze
flutter test
flutter build apk --debug
```

Antes de release, validar também AAB release e signing.

## iOS

Baseline:

- Bundle ID `com.lucksrei.busaogyn`
- deployment target mínimo iOS 13
- build de distribuição usando Xcode/SDK aceito pela App Store no momento da submissão

Enquanto o app não usar localização do usuário, não adicionar `NSLocationWhenInUseUsageDescription` ou permissões equivalentes.

Validação mínima em runner macOS:

```bash
flutter build ios --simulator --no-codesign
```

Antes da submissão, revisar também o relatório de privacidade do Xcode e os manifests dos SDKs de terceiros.

## Web

O build Web deve continuar suportado.

Validação mínima:

```bash
flutter build web --release
```

MapLibre GL JS 6 exige WebGL2. Não manter cópia manual/pinada do JS no HTML sem motivo concreto.

A API BusãoGyn precisa devolver CORS somente para origens explicitamente permitidas. Desenvolvimento local pode usar os wildcards controlados `http://localhost:*` e `http://127.0.0.1:*`; domínio público deve ser adicionado por correspondência exata quando definido.

## Regras do tracking

O MVP só pode mostrar dados suportados pelas fontes reais.

Permitido nesta fase:

- ETA por ponto;
- realtime x programado;
- identidade do veículo realtime;
- posição individual do ônibus;
- acessibilidade quando fornecida;
- pontualidade quando fornecida;
- dados stale claramente identificados.

Não inventar:

- shapes;
- trajetos;
- paradas;
- direção/bearing;
- ocupação;
- capacidade;
- localização do usuário;
- interpolação apresentada como posição real.

Ao trocar o veículo acompanhado, a UI não deve continuar mostrando a posição do veículo anterior.

Quando o usuário mover manualmente o mapa, o auto-follow deve poder ser suspenso; a ação de centralizar pode reativá-lo.

## CI

A pipeline Flutter deve cobrir, no mínimo:

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- build Android
- build Web

iOS deve ser validado em runner macOS sem exigir signing nesta fase.

## Referências oficiais

- MapLibre Flutter: https://pub.dev/packages/maplibre_gl
- MapLibre Flutter releases: https://github.com/maplibre/flutter-maplibre-gl/releases
- OpenFreeMap: https://openfreemap.org/
- Google Play target API: https://developer.android.com/google/play/requirements/target-sdk
- Android 16 KB page sizes: https://developer.android.com/guide/practices/page-sizes
- Apple upcoming requirements: https://developer.apple.com/news/upcoming-requirements/
- Apple third-party SDK requirements: https://developer.apple.com/support/third-party-SDK-requirements/
