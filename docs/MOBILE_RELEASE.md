# BusãoGyn — release Android, iOS e Web

Atualizado em 08/10/2026.

Este documento reúne a configuração de release, o checklist de publicação e as regras de produto que valem para qualquer build distribuído. Ele não substitui a documentação oficial das plataformas; requisitos de loja mudam e precisam ser conferidos na data da submissão.

## Identidade

- Nome exibido: `BusãoGyn` (Android `android:label`, iOS `CFBundleDisplayName`/`CFBundleName`, Web `name`/`short_name`).
- Android applicationId e namespace: `com.lucksrei.busaogyn`.
- iOS Bundle Identifier: `com.lucksrei.busaogyn`.
- Ícone e splash: logo oficial (`docs/brand/source`), gerados por `app/tool/generate_brand_assets.py` (ver [Ícones e splash](#ícones-e-splash)).

Nenhum target novo deve usar IDs antigos ou alternativos.

## Baseline técnica

| Item | Valor |
| --- | --- |
| Flutter / Dart | 3.38.5 / 3.10.4 |
| JDK (Android) | 21 |
| AGP / Kotlin / Gradle | 8.11.1 / 2.2.20 / 8.14 |
| Android minSdk / targetSdk / compileSdk | 24 / 36 / 36 (padrões do Flutter 3.38.5) |
| Android NDK | 28.2.13676358 |
| iOS deployment target | 15.0 (projeto Xcode e `Podfile`) |
| Mapa | `maplibre_gl` 0.27.1, MapLibre Android 13.5.0, MapLibre iOS 6.28.0, MapLibre GL JS 6.4.1 (Web) |

## Versionamento

A versão vem de `version` em `app/pubspec.yaml` (`NOME+BUILD`):

| pubspec | Android | iOS |
| --- | --- | --- |
| `1.0.0` | `versionName` | `CFBundleShortVersionString` (`FLUTTER_BUILD_NAME`) |
| `+1` | `versionCode` | `CFBundleVersion` (`FLUTTER_BUILD_NUMBER`) |

- Primeira release: `1.0.0+1`. Antes dela o app estava em `0.1.0+1`, versão de desenvolvimento que nunca foi publicada.
- Todo upload para uma loja precisa de um número de build maior que o anterior. Ele pode ser sobrescrito sem editar o pubspec: `flutter build appbundle --build-number=2`.
- Siga SemVer no nome: correções em `1.0.x`, funcionalidades em `1.x.0`.

## Configuração de produção

| dart-define | Padrão em release | Uso |
| --- | --- | --- |
| `BUSAOGYN_API_BASE_URL` | `https://busaogyn-api.lively-cloud-f009.workers.dev` | API BusãoGyn |
| `MAP_STYLE_URL` | `https://tiles.openfreemap.org/styles/liberty` | Estilo diurno; com URL própria, vale para os dois temas |
| `MAP_STYLE_DARK_URL` | vazio (usa o Liberty noturno empacotado) | Estilo noturno opcional |

- Nenhuma dessas URLs é segredo.
- O padrão já é produção: builds de loja não precisam de `--dart-define`. `localhost` só entra por override explícito em desenvolvimento.
- O app Flutter acessa somente a API BusãoGyn. Nenhuma tela ou repository acessa endpoints RMTC/RedeMob diretamente.

## Ícones e splash

Fonte única: os masters da logo oficial em [`docs/brand/source`](brand/README.md). Para regenerar tudo depois de trocar um master:

```bash
cd app
python3 tool/generate_brand_assets.py          # gera
python3 tool/generate_brand_assets.py --check  # só confere se está em dia
```

O script só precisa de Python 3 com Pillow (não usa o SDK Flutter). Ele gera:

- **Android**:
  - `mipmap-*/ic_launcher.png`: ícone legado (API < 26), símbolo da logo.
  - `mipmap-*/ic_launcher_foreground.png`: foreground do ícone adaptativo (`mipmap-anydpi-v26/ic_launcher.xml`), a partir de `adaptive-foreground-1024.png` (símbolo dentro da zona segura de 66 dp).
  - `mipmap-*/ic_launcher_monochrome.png`: ícone temático (themed icon, Android 13+). É monocromático de verdade: preto com transparência derivada da arte (ring, pin, vidros, faixa verde e detalhes escuros ficam; o claro some).
  - `values/ic_launcher_background.xml`: cor do fundo adaptativo, lida de `adaptive-background-1024.png`.
  - `drawable-*/launch_mark.png`: logo do splash.
- **iOS**: `AppIcon.appiconset` completo, opaco (sem canal alfa) e sem cantos desenhados (o iOS aplica a máscara), mais o `LaunchImage` do LaunchScreen. Não há variantes escura/tinted: a marca é a mesma nos três modos.
- **Web**: `favicon.ico` (16/32/48), `favicon.png`, `Icon-192/512` ("any", fundo transparente), `Icon-maskable-192/512` (opacos, símbolo em 76% do lado, dentro da zona segura de 80%) e `apple-touch-icon.png` (180 px, opaco).
- **App**: `assets/brand/logo-mark.png` (1x/2x/3x), o símbolo usado pelo `BrandMark` no header.

Splash, igual nas três plataformas: fundo do tema do sistema (claro `#FFFFFF`, noturno `#0B0A08`) com a logo no centro, sem animação e sem rede.

- **Android < 12**: `launch_background.xml`. As cores ficam em `values/colors.xml` e `values-night/colors.xml`.
- **Android 12+**: SplashScreen do sistema com o ícone adaptativo (`values-v31`, `values-night-v31`).
- **iOS**: `LaunchScreen.storyboard`, com a cor nomeada `LaunchBackground` (claro/escuro).
- **Web**: `#splash` em `web/index.html`, removido por `web/flutter_bootstrap.js` depois do `runApp`.

## Android

### Permissões

Permissões efetivas do APK release (`aapt2 dump permissions`, CI de 08/10/2026):

| Permissão | Origem | Motivo |
| --- | --- | --- |
| `INTERNET` | App | API e mapa |
| `ACCESS_NETWORK_STATE` | MapLibre Android 13.5.0 | Detectar a conectividade (`ConnectivityReceiver`) |
| `ACCESS_WIFI_STATE` | MapLibre Android 13.5.0 | Declarada no manifest do SDK, mas nem as classes Java nem a `libmaplibre.so` usam APIs de Wi-Fi. É uma permissão normal (sem prompt). Candidata a `tools:node="remove"` depois de testar em aparelho |
| `com.lucksrei.busaogyn.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX Core | Permissão interna do próprio app, para receivers não exportados |

Ausentes no APK final: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `CAMERA`, `RECORD_AUDIO`, `READ_CONTACTS` e permissões de mídia ou armazenamento.

- `ACCESS_FINE_LOCATION` e `ACCESS_COARSE_LOCATION`, declaradas pelo MapLibre, são removidas no manifest com `tools:node="remove"`.
- O CI lista as permissões do APK release (`aapt2 dump permissions`) e falha se aparecer localização, câmera, microfone, contatos ou mídia.
- Localização só pode entrar junto com uma funcionalidade que a use, e nesse caso a declaração de dados da Play precisa ser revista.

Manifest:

- `usesCleartextTraffic` não é declarado: com targetSdk ≥ 28, HTTP sem TLS fica bloqueado. Toda a rede usa HTTPS.
- Só a `MainActivity` é exportada (launcher).
- O backup automático fica no padrão. O app guarda apenas a preferência de tema, então não há dado sensível no backup.

### Assinatura

O release procura a chave de upload, nesta ordem:

1. `app/android/key.properties`, local e fora do git:

   ```properties
   # storeFile é relativo a app/android/
   storeFile=../upload-keystore.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```

2. As variáveis de ambiente `BUSAOGYN_ANDROID_KEYSTORE_PATH`, `BUSAOGYN_ANDROID_KEYSTORE_PASSWORD`, `BUSAOGYN_ANDROID_KEY_ALIAS` e `BUSAOGYN_ANDROID_KEY_PASSWORD` (CI).

Build de loja e build de validação são separados de propósito:

| Situação | Resultado de `flutter build apk/appbundle --release` |
| --- | --- |
| Chave de upload configurada | Release assinado com a chave de upload: **o único publicável** |
| Sem chave de upload | **Falha**, com a mensagem "Release sem chave de upload…" |
| Sem chave e com `BUSAOGYN_ALLOW_DEBUG_SIGNED_RELEASE=true` | Release de **validação**, assinado com a chave de debug. O Gradle avisa que não é publicável. A Play Store o rejeitaria |
| Configuração parcial (por exemplo, senha faltando) | Falha |

O CI usa o modo de validação para conferir R8, manifest, AAB, permissões e bibliotecas nativas. Ele também tem um step que confere que, sem a variável, o release falha. Para testar um release localmente sem a chave:

```bash
BUSAOGYN_ALLOW_DEBUG_SIGNED_RELEASE=true flutter build apk --release
```

Criar a chave de upload (uma vez, fora do repositório):

```bash
keytool -genkey -v -keystore ~/busaogyn-upload.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```

- Use o **Play App Signing**: o Google guarda a chave do app e você só usa a de upload.
- Guarde o `.jks` e as senhas num cofre. Perder a chave de upload exige pedido de redefinição ao Google.
- `*.jks`, `*.keystore` e `key.properties` estão no `.gitignore`. Nunca versione esses arquivos.
- Para o CI publicar, adicione o keystore em base64 e as senhas como secrets do GitHub Actions. Isso ainda não existe.

### Build

```bash
cd app
flutter build appbundle --release   # build/app/outputs/bundle/release/app-release.aab
flutter build apk --release         # build/app/outputs/flutter-apk/app-release.apk
```

- R8 (minify e shrink de recursos) fica ligado pelo plugin Gradle do Flutter nos builds de release.
- As regras ProGuard do Flutter e as regras de consumidor das bibliotecas cobrem MapLibre, OkHttp e Play Services. Não há `proguard-rules.pro` próprio.

### Páginas de 16 KB

A Play exige suporte a páginas de 16 KB em apps com código nativo e targetSdk 35+. O CI confere isso a cada build:

- `zipalign -c -P 16 -v 4` no APK release;
- `python3 tool/check_android_release.py <apk> <aab>`: todo segmento `PT_LOAD` das `.so` de 64 bits (arm64-v8a, x86_64) precisa ter alinhamento ≥ 16 KB e, no APK, ficar sem compressão em offset múltiplo de 16 KB.

As bibliotecas nativas são `libflutter.so`, `libapp.so` (Flutter/NDK r28) e as do MapLibre Android 13.5.0. Depois do primeiro upload, confira também o aviso de compatibilidade com 16 KB no App Bundle Explorer da Play Console.

### Checklist Play Store

- [ ] `version` do pubspec com build number maior que o último upload.
- [ ] AAB release assinado com a chave de upload (não a de debug).
- [ ] `targetSdk` atende ao requisito vigente da Play (hoje 36; regra anual em <https://developer.android.com/google/play/requirements/target-sdk>).
- [ ] CI verde: permissões e páginas de 16 KB.
- [ ] Play Console: Play App Signing ativado, app criado com `com.lucksrei.busaogyn`.
- [ ] Ficha da loja: nome, descrição curta (80 caracteres), descrição completa, ícone de 512×512, gráfico de destaque e capturas de tela (ver [Assets de loja](#assets-de-loja)).
- [ ] Segurança dos dados e URL da política de privacidade (ver [PRIVACY.md](PRIVACY.md)).
- [ ] Classificação de conteúdo (questionário IARC), público-alvo e declaração de anúncios (não há anúncios).
- [ ] Teste interno ou fechado antes da produção, com aparelho físico (gestos do MapLibre).

## iOS

### Projeto

- Bundle ID `com.lucksrei.busaogyn`, deployment target 15.0, iPhone e iPad (`TARGETED_DEVICE_FAMILY = 1,2`).
- O `Podfile` está versionado com `platform :ios, '15.0'`.
  - O primeiro `pod install` num Mac integra os Pods ao `Runner.xcodeproj` e gera o `Podfile.lock`. Os dois devem ser commitados (o `.gitignore` já libera `app/ios/Podfile.lock`).
- `Info.plist`:
  - Sem chaves de permissão: nada de `NSLocation*`, câmera, fotos, microfone ou contatos.
  - `ITSAppUsesNonExemptEncryption = false`, porque o app só usa HTTPS do sistema, isento de documentação de exportação.
  - Orientações: retrato e paisagem no iPhone, todas no iPad.
- App Transport Security: sem exceções; toda a rede é HTTPS.
- Privacidade: o app não tem `PrivacyInfo.xcprivacy` próprio, porque o código do Runner não usa APIs que exijam justificativa. Flutter, `shared_preferences` e MapLibre trazem os manifestos deles. Detalhes em [PRIVACY.md](PRIVACY.md#4-manifestos-de-privacidade-de-sdks-ios).
- Ciclo de vida: `AppDelegate` igual ao template do Flutter 3.38.5, sem `UIScene`. A Apple anunciou que o ciclo de vida UIScene será obrigatório nos SDKs após o iOS 26. Migrar quando o Flutter estável e os plugins suportarem, seguindo o guia oficial do Flutter.

### Assinatura (sem nada no repositório)

1. Conta no Apple Developer Program e Team ID.
2. App ID `com.lucksrei.busaogyn` no portal de desenvolvedor.
3. No Xcode, abra `app/ios/Runner.xcworkspace` e, em Runner → Signing & Capabilities, escolha o Team. Assinatura automática é suficiente para TestFlight e App Store.
4. Para assinar no CI: certificado de distribuição (`.p12`), provisioning profile App Store e chave da App Store Connect API (`.p8`) como secrets. Isso ainda não existe.

Certificados, perfis e chaves (`*.p12`, `*.mobileprovision`, `*.p8`) estão no `.gitignore` e nunca vão para o repositório.

### Build

```bash
cd app
flutter build ios --simulator --no-codesign   # CI
flutter build ios --release --no-codesign     # CI: release sem assinatura
flutter build ipa --release                   # Mac com Team configurado: gera o .ipa para upload
```

O upload é feito pelo Xcode (Organizer → Distribute App) ou pelo Transporter. Use o Xcode e o SDK exigidos pela App Store na data do envio: <https://developer.apple.com/news/upcoming-requirements/>.

### Checklist App Store

- [ ] `version` do pubspec com build number maior que o último upload.
- [ ] `pod install` feito num Mac, com `Podfile.lock` e projeto integrado commitados.
- [ ] Team e assinatura configurados; archive gerado (`flutter build ipa`).
- [ ] Relatório de privacidade do Xcode revisado.
- [ ] App Store Connect: app criado com o bundle ID, categoria (Navegação ou Viagem), classificação etária.
- [ ] Privacidade do app ("Data Not Collected") e URL da política de privacidade.
- [ ] Capturas de iPhone 6.9" e de iPad 13", porque o app suporta iPad (ver [Assets de loja](#assets-de-loja)).
- [ ] TestFlight interno em aparelho físico antes de enviar para revisão.
- [ ] Notas para a revisão: o app não exige login. Indique um ponto de exemplo (30402) e explique que só ônibus com GPS informado pela RMTC aparecem em tempo real.

## Web / PWA

### Build e hospedagem

```bash
cd app
flutter build web --release   # build/web/
```

O `build/web/` pode ir para qualquer hospedagem estática com HTTPS (o service worker e a instalação do PWA exigem HTTPS fora de `localhost`):

- **Domínio**: o app precisa ser publicado na raiz do domínio, ou com `--base-href /caminho/`.
- **SPA**: o app não usa rotas de URL, então a raiz basta. Mesmo assim, redirecionar 404 para `index.html` é inofensivo.
- **Cache**:
  - `index.html`, `flutter_bootstrap.js`, `flutter_service_worker.js`, `manifest.json` e `version.json` com `Cache-Control: no-cache`.
  - `main.dart.js`, `canvaskit/` e `assets/` podem ter cache longo. O service worker invalida pelo hash.
- **CORS**: a API BusãoGyn só responde a origens listadas em `ALLOWED_ORIGINS` (`worker/wrangler.toml`). Hoje estão lá apenas `http://localhost:*` e `http://127.0.0.1:*`. **O domínio público do Web precisa ser adicionado, por correspondência exata, antes da publicação.**

### PWA

- `manifest.json`: `name`/`short_name` BusãoGyn, `lang` pt-BR, `start_url` `.`, `display` standalone, `theme_color` e `background_color` `#0B0A08`, ícones 192 e 512, normais e maskable.
- `index.html`:
  - `lang="pt-BR"`, descrição;
  - `theme-color` por esquema claro/escuro;
  - `apple-touch-icon` 180 px;
  - favicon;
  - splash;
  - `<noscript>`.
- O viewport é injetado pelo próprio Flutter.
- Service worker: gerado pelo Flutter (`flutter_service_worker.js`). Ele guarda o shell do app (HTML, JS, CanvasKit local, fontes, ícones), então o app abre sem rede.
- **Offline, só o shell.** Sem rede, o app abre a partir do cache do service worker: tela inicial, busca e navegação.
- **Não funcionam offline:** chegadas, posições em tempo real, tiles do mapa e o MapLibre GL JS (do unpkg). Sem conexão, a busca mostra "Sem conexão". O BusãoGyn não é um app de transporte offline.
- CanvasKit: servido pelo próprio site (`canvasKitBaseUrl: 'canvaskit/'` em `web/flutter_bootstrap.js`), não pelo `gstatic.com`.
- MapLibre GL JS 6 exige WebGL2. O plugin carrega o JS e o CSS automaticamente. Não adicione `maplibre-gl.js` manualmente no `index.html`.

### Checklist Web

- [ ] Domínio definido, com HTTPS.
- [ ] Domínio adicionado a `ALLOWED_ORIGINS` do Worker e Worker publicado.
- [ ] Cabeçalhos de cache configurados na hospedagem.
- [ ] Smoke em produção: abrir, buscar 30402, chegadas, Meu ônibus, mapa, recarregar a página, instalar como app (Chrome/Edge, Android e "Adicionar à Tela de Início" no iOS).
- [ ] Política de privacidade publicada no mesmo domínio.

## Tamanhos medidos

Medidos em 08/10/2026, versão `1.0.0+1`:

| Artefato | Tamanho | Observação |
| --- | --- | --- |
| APK release | 81,9 MB (81.861.609 bytes) | APK universal com 3 ABIs (arm64-v8a, armeabi-v7a, x86_64). Não é o que o usuário baixa da Play |
| AAB release | 55,1 MB (55.074.031 bytes) | A Play gera APKs por ABI e densidade. O download real aparece no App Bundle Explorer depois do upload |
| iOS `Runner.app` release (sem assinatura) | 26,4 MB | Saída do `flutter build ios --release --no-codesign`. O tamanho na App Store só aparece depois do processamento |
| Web `build/web` | 32 MB no disco | Cerca de 27 MB são as variantes do CanvasKit (`canvaskit/`); cada navegador baixa só uma |
| Web, primeiro carregamento (Chromium) | ~10,0 MB do próprio host (16 arquivos), ~3,65 MB se servido com gzip | Medido com cache vazio: `canvaskit/chromium/canvaskit.wasm` 5,7 MB, `main.dart.js` 3,1 MB, fontes Geist ~1,1 MB. MapLibre GL JS (unpkg) e tiles vêm à parte e não entraram na medição |

Não há asset desproporcional no app: os maiores são as fontes Geist (8 arquivos, ~1,1 MB) e os estilos do mapa empacotados (`busao-light.json` e `busao-dark.json`, ~54 KB cada). No Android, o grosso do tamanho vem das bibliotecas nativas `libmaplibre.so` e `libflutter.so`, multiplicadas pelas 3 ABIs do APK universal.

## Assets de loja

As capturas devem ser reais, tiradas do app. Não use mockups artificiais.

| Loja | Asset | Tamanho |
| --- | --- | --- |
| Google Play | Ícone | 512×512 PNG 32 bits (≤ 1 MB). Pode sair de `docs/brand/source/app-icon-master-1024.png` reduzido a 512×512 |
| Google Play | Gráfico de destaque | 1024×500 PNG/JPEG, sem transparência |
| Google Play | Capturas de celular | 2 a 8, lado entre 320 e 3840 px, proporção até 2:1. Recomendado: 1080×1920 ou mais, retrato |
| Google Play | Capturas de tablet 7" e 10" | Opcionais. Recomendadas, porque o app tem layout para telas largas |
| App Store | Capturas de iPhone 6.9" | 1320×2868 ou 1290×2796 (retrato), 1 a 10 |
| App Store | Capturas de iPad 13" | 2064×2752 ou 2048×2732 (retrato). Obrigatórias enquanto o app suportar iPad |
| App Store | Ícone | 1024×1024, já no `AppIcon.appiconset` |
| Web | Capturas no manifest | Opcionais (`screenshots`). Melhoram o diálogo de instalação no Chrome |

## CI

`.github/workflows/flutter-ci.yml` roda em PRs e em push para `main`, `feat/**`, `fix/**` e `chore/**`. Todos os steps usam `shell: bash`, com `pipefail`, então uma falha antes de um `|` não fica mascarada.

- **flutter**: `pub get --enforce-lockfile`, `dart format --set-exit-if-changed`, `analyze`, `test`.
- **build-android-web** (JDK 21):
  - confere que um release sem chave de upload falha;
  - APK release e AAB release em modo de validação (`BUSAOGYN_ALLOW_DEBUG_SIGNED_RELEASE=true`), não publicáveis;
  - permissões do APK;
  - páginas de 16 KB;
  - Web release;
  - tamanhos dos artefatos.
- **build-ios** (macOS): build para simulador e build de release para dispositivo, ambos sem assinatura.

## OpenFreeMap

O serviço público atual:

- permite uso comercial;
- não exige API key;
- exige atribuição;
- não oferece SLA.

A atribuição não pode ser removida. O controle nativo do MapLibre fica visível acima do painel.

## Regras do tracking

Os builds distribuídos só podem mostrar dados que as fontes reais suportam.

Permitido:

- ETA por ponto;
- realtime x programado;
- identidade do veículo realtime;
- posição individual do ônibus;
- direção e rastro observados, calculados somente a partir das posições recebidas na sessão de acompanhamento atual (não representam o trajeto oficial);
- acessibilidade e pontualidade, quando informadas;
- dados stale claramente identificados.

Não inventar:

- shapes, trajetos ou paradas (não há GTFS, KML nem geometria inferida);
- ocupação ou capacidade;
- localização do usuário;
- interpolação apresentada como posição real.

Comportamento esperado do tracking:

- Ao trocar o veículo acompanhado, a UI não pode continuar mostrando a posição do veículo anterior.
- Quando o usuário move o mapa manualmente, o auto-follow é suspenso; a ação "Centralizar" o reativa.

## Referências oficiais

- MapLibre Flutter: https://pub.dev/packages/maplibre_gl
- OpenFreeMap: https://openfreemap.org/
- Google Play target API: https://developer.android.com/google/play/requirements/target-sdk
- Android 16 KB page sizes: https://developer.android.com/guide/practices/page-sizes
- Play App Signing: https://support.google.com/googleplay/android-developer/answer/9842756
- Flutter deploy Android: https://docs.flutter.dev/deployment/android
- Flutter deploy iOS: https://docs.flutter.dev/deployment/ios
- Flutter deploy Web: https://docs.flutter.dev/deployment/web
- Apple upcoming requirements: https://developer.apple.com/news/upcoming-requirements/
- Apple privacy manifests: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
