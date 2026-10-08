#!/usr/bin/env python3
"""Gera ícones e imagens de splash a partir do BrandMark do app.

O BrandMark (lib/src/core/ui/busao_components.dart) é o selo BusãoGyn: um
quadrado arredondado #0B0A08 com o ícone Material `directions_bus_rounded`
em âmbar #FFC53D ocupando 56% do lado. Este script reproduz esse selo em
todos os tamanhos exigidos por Android, iOS e Web; não há arte nova.

Uso (a partir de app/):

    python3 tool/generate_brand_assets.py [--flutter-root CAMINHO]

Requer Pillow e o SDK Flutter (de onde vem a fonte MaterialIcons). Sem
--flutter-root, usa $FLUTTER_ROOT ou o `flutter` do PATH.
"""

from __future__ import annotations

import argparse
import os
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

TILE = (0x0B, 0x0A, 0x08, 255)
ACCENT = (0xFF, 0xC5, 0x3D, 255)
# Borda do selo no app: 0x24F6F6F6 com 1 px a cada 32 px de lado.
BORDER = (0xF6, 0xF6, 0xF6, 0x24)
BUS_CODEPOINT = 0xF6B1  # Icons.directions_bus_rounded
GLYPH_RATIO = 0.56  # Icon(size: size * 0.56) no BrandMark
CORNER_RATIO = 0.31  # BorderRadius.circular(size * 0.31)
SUPERSAMPLE = 4

APP = Path(__file__).resolve().parent.parent
ANDROID_RES = APP / 'android/app/src/main/res'
IOS_ASSETS = APP / 'ios/Runner/Assets.xcassets'
WEB = APP / 'web'

ANDROID_DENSITIES = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
}


def flutter_root(cli_value: str | None) -> Path:
    if cli_value:
        return Path(cli_value)
    if os.environ.get('FLUTTER_ROOT'):
        return Path(os.environ['FLUTTER_ROOT'])
    flutter = shutil.which('flutter')
    if flutter is None:
        raise SystemExit('Informe --flutter-root ou coloque o flutter no PATH.')
    return Path(flutter).resolve().parent.parent


class Painter:
    def __init__(self, font_path: Path) -> None:
        self.font_path = font_path

    def _glyph(self, canvas: Image.Image, em: float) -> None:
        font = ImageFont.truetype(str(self.font_path), max(1, round(em)))
        draw = ImageDraw.Draw(canvas)
        center = (canvas.width / 2, canvas.height / 2)
        draw.text(center, chr(BUS_CODEPOINT), font=font, fill=ACCENT, anchor='mm')

    def render(
        self,
        size: int,
        *,
        rounded: bool,
        glyph_ratio: float = GLYPH_RATIO,
        tile_ratio: float = 1.0,
        background: bool = True,
    ) -> Image.Image:
        """Selo em [size] px.

        - rounded: cantos do BrandMark e fundo transparente fora do selo;
          caso contrário o quadrado inteiro é preenchido (iOS e maskable
          aplicam a própria máscara).
        - tile_ratio: fração do canvas ocupada pelo selo (margem em volta).
        - background: False desenha só o ônibus (foreground adaptativo).
        """
        big = size * SUPERSAMPLE
        canvas = Image.new('RGBA', (big, big), (0, 0, 0, 0))
        tile = big * tile_ratio
        offset = (big - tile) / 2
        box = (offset, offset, offset + tile - 1, offset + tile - 1)
        draw = ImageDraw.Draw(canvas)
        if background and rounded:
            radius = tile * CORNER_RATIO
            draw.rounded_rectangle(box, radius=radius, fill=TILE)
            width = max(1, round(tile / 32))
            draw.rounded_rectangle(box, radius=radius, outline=BORDER, width=width)
        elif background:
            draw.rectangle((0, 0, big, big), fill=TILE)
        self._glyph(canvas, tile * glyph_ratio)
        return canvas.resize((size, size), Image.LANCZOS)


def save(image: Image.Image, path: Path, *, opaque: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if opaque:
        flat = Image.new('RGB', image.size, TILE[:3])
        flat.paste(image, mask=image.split()[3])
        flat.save(path, optimize=True)
    else:
        image.save(path, optimize=True)
    print(path.relative_to(APP))


def android(p: Painter) -> None:
    for name, scale in ANDROID_DENSITIES.items():
        mipmap = ANDROID_RES / f'mipmap-{name}'
        # Ícone legado (API < 26): selo arredondado em 48 dp, 2 dp de margem.
        save(
            p.render(round(48 * scale), rounded=True, tile_ratio=44 / 48),
            mipmap / 'ic_launcher.png',
        )
        # Foreground adaptativo (API 26+): 108 dp, área visível de ~72 dp; o
        # ônibus mantém a proporção do BrandMark sobre essa área.
        save(
            p.render(
                round(108 * scale),
                rounded=False,
                background=False,
                glyph_ratio=GLYPH_RATIO * 72 / 108,
            ),
            mipmap / f'ic_launcher_foreground.png',
        )
        # Selo do splash (API < 31), 96 dp.
        save(
            p.render(round(96 * scale), rounded=True),
            ANDROID_RES / f'drawable-{name}' / 'launch_mark.png',
        )


IOS_ICONS = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
}


def ios(p: Painter) -> None:
    # App Store exige ícones opacos; o iOS aplica os cantos.
    for name, size in IOS_ICONS.items():
        save(
            p.render(size, rounded=False),
            IOS_ASSETS / 'AppIcon.appiconset' / name,
            opaque=True,
        )
    for suffix, scale in (('', 1), ('@2x', 2), ('@3x', 3)):
        save(
            p.render(96 * scale, rounded=True),
            IOS_ASSETS / 'LaunchImage.imageset' / f'LaunchImage{suffix}.png',
        )


def web(p: Painter) -> None:
    save(p.render(32, rounded=True), WEB / 'favicon.png')
    for size in (192, 512):
        save(p.render(size, rounded=True), WEB / 'icons' / f'Icon-{size}.png')
        # Maskable: zona segura é o círculo central de 80%.
        save(
            p.render(size, rounded=False, glyph_ratio=0.45),
            WEB / 'icons' / f'Icon-maskable-{size}.png',
            opaque=True,
        )
    save(
        p.render(180, rounded=False),
        WEB / 'icons' / 'apple-touch-icon.png',
        opaque=True,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--flutter-root')
    args = parser.parse_args()
    font = (
        flutter_root(args.flutter_root)
        / 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
    )
    if not font.exists():
        raise SystemExit(f'Fonte não encontrada: {font} (rode `flutter precache`).')
    painter = Painter(font)
    android(painter)
    ios(painter)
    web(painter)


if __name__ == '__main__':
    main()
