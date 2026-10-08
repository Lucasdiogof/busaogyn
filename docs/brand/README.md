# Marca BusãoGyn

Fontes oficiais da logo (arte aprovada). Tudo que é ícone, splash e favicon do
app é **derivado** destes arquivos por `app/tool/generate_brand_assets.py`.
Não edite os PNGs gerados à mão: troque o master e rode o script.

## Masters (`source/`)

| Arquivo | Uso |
| --- | --- |
| `logo-master-transparent.png` | 1254×1254, RGBA, fundo transparente. Símbolo completo (ônibus, letreiro, ring e pin). Fonte do ícone legado Android, splash, web, favicon, monocromático e `BrandMark` do app. |
| `app-icon-master-1024.png` | 1024×1024, RGB, opaco, sem cantos arredondados. Fonte do `AppIcon` do iOS e do `apple-touch-icon`. |
| `adaptive-foreground-1024.png` | 1024×1024, RGBA. Foreground do ícone adaptativo Android (canvas de 108 dp; símbolo dentro da zona segura de 66 dp). |
| `adaptive-background-1024.png` | 1024×1024, cor chapada `#F3F7EF`. Fundo do ícone adaptativo Android. |

O letreiro (`BUSÃO GYN`) é uma matriz de LEDs desenhada na própria arte; ele
fica ilegível abaixo de ~128 px, o que é esperado.

## Regenerar os assets

```bash
cd app
python3 tool/generate_brand_assets.py          # gera Android, iOS, Web e o BrandMark
python3 tool/generate_brand_assets.py --check  # só confere se os arquivos estão em dia
```

Requer Python 3 com Pillow. Não precisa do SDK Flutter.

## O que é gerado

- **Android** (`app/android/app/src/main/res`): `mipmap-*/ic_launcher.png` (legado),
  `ic_launcher_foreground.png` e `ic_launcher_monochrome.png` (adaptativo e
  themed icon), `drawable-*/launch_mark.png` e `drawable-*/splash_icon.png` (splash) e
  `values/ic_launcher_background.xml`.
- **iOS** (`app/ios/Runner/Assets.xcassets`): `AppIcon.appiconset` completo,
  opaco e sem cantos arredondados, e `LaunchImage.imageset`.
- **Web** (`app/web`): `favicon.ico`, `favicon.png`, `icons/Icon-192|512.png`,
  `icons/Icon-maskable-192|512.png` e `icons/apple-touch-icon.png`.
- **App** (`app/assets/brand`): `logo-mark.png` em 1x/2x/3x, usado pelo `BrandMark`.

Não há SVG: a arte é raster e um traçado vetorial não seria fiel.
