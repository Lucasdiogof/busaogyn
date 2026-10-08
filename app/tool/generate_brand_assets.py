#!/usr/bin/env python3
"""Gera ícones, splash e favicons a partir dos masters oficiais da logo.

Fonte única: `docs/brand/source/` (ver docs/brand/README.md). Este script só
adapta tamanhos e formatos; não desenha arte nova.

Uso (a partir de app/):

    python3 tool/generate_brand_assets.py          # gera os assets
    python3 tool/generate_brand_assets.py --check  # só confere se estão em dia

Requer apenas Pillow.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageChops

APP = Path(__file__).resolve().parent.parent
ROOT = APP.parent
SRC = ROOT / 'docs/brand/source'
ANDROID_RES = APP / 'android/app/src/main/res'
IOS_ASSETS = APP / 'ios/Runner/Assets.xcassets'
WEB = APP / 'web'
APP_BRAND = APP / 'assets/brand'

ANDROID_DENSITIES = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
}

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

# Ícone monocromático (themed icon): preto com a transparência derivada da
# arte. Três critérios, combinados pelo máximo:
# - escuridão acima de MONO_FLOOR (vidros e frisos escuros; o claro some: disco,
#   brilho e sombra do chão, carroceria branca), com rampa suave até
#   MONO_DARK_SPAN para o vidro ficar semitransparente e deixar ver divisória,
#   limpadores e letreiro;
# - verde saturado (ring, pin e faixa verde do ônibus), quase opaco;
# - o resto (âmbar) entra pela escuridão.
MONO_FLOOR = 0.14
MONO_DARK_SPAN = 0.85
MONO_GREEN_OFFSET = 20  # canal G acima de max(R, B)
MONO_GREEN_SPAN = 70
MONO_GREEN_ALPHA = 0.95
# Maskable: o círculo seguro é 80% do lado; o símbolo ocupa 76%.
MASKABLE_RATIO = 0.76
# Splash. A logo precisa de presença, mas sem ocupar a tela.
# - iOS (LaunchImage, em pt) e Android < 12 (launch_mark, em dp): mesmo tamanho.
# - Android 12+: o sistema desenha o splash_icon num canvas de 288 dp e só mostra
#   o círculo central de 192 dp (a arte fora dele é cortada). O símbolo fica
#   dentro desse círculo, com folga, e centrado no ring.
SPLASH_MARK_SIZE = 144
SPLASH_A12_CANVAS_DP = 288
SPLASH_A12_SAFE_CIRCLE_DP = 192
SPLASH_A12_SYMBOL_DP = 160
APP_MARK_BASE = 64  # lado em px a 1x do logo-mark do BrandMark (2x e 3x derivam)


class Writer:
    """Grava os arquivos ou, com --check, só compara com o que existe."""

    def __init__(self, check: bool) -> None:
        self.check = check
        self.stale: list[str] = []
        self.count = 0

    def _rel(self, path: Path) -> str:
        return str(path.relative_to(ROOT))

    def _mark(self, path: Path, same: bool) -> None:
        self.count += 1
        if not same:
            self.stale.append(self._rel(path))
        if not self.check:
            print(self._rel(path))

    def png(self, image: Image.Image, path: Path, *, opaque: bool = False) -> None:
        image = image.convert('RGB' if opaque else 'RGBA')
        if self.check:
            same = False
            if path.exists():
                current = Image.open(path)
                current = current.convert(image.mode)
                same = current.size == image.size and ImageChops.difference(
                    current, image
                ).getbbox() is None
            self._mark(path, same)
            return
        path.parent.mkdir(parents=True, exist_ok=True)
        image.save(path, optimize=True)
        self._mark(path, True)

    def ico(self, frames: list[Image.Image], path: Path) -> None:
        sizes = [(f.width, f.height) for f in frames]
        if self.check:
            same = False
            if path.exists():
                current = Image.open(path)
                same = set(current.info.get('sizes', [])) == set(sizes) and all(
                    ImageChops.difference(
                        current.ico.getimage(s).convert('RGBA'),
                        f.convert('RGBA'),
                    ).getbbox()
                    is None
                    for s, f in zip(sizes, frames)
                )
            self._mark(path, same)
            return
        path.parent.mkdir(parents=True, exist_ok=True)
        biggest = max(frames, key=lambda f: f.width)
        biggest.save(path, format='ICO', sizes=sizes, append_images=frames)
        self._mark(path, True)

    def text(self, content: str, path: Path) -> None:
        if self.check:
            self._mark(path, path.exists() and path.read_text() == content)
            return
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        self._mark(path, True)


class Masters:
    def __init__(self) -> None:
        self.symbol_full = Image.open(SRC / 'logo-master-transparent.png').convert('RGBA')
        bbox = self.symbol_full.getchannel('A').point(lambda v: 255 if v > 5 else 0).getbbox()
        # Recorte justo do símbolo (ring + pin), sem a folga do canvas.
        self.symbol = self.symbol_full.crop(bbox)
        self.app_icon = Image.open(SRC / 'app-icon-master-1024.png').convert('RGB')
        self.adaptive_fg = Image.open(SRC / 'adaptive-foreground-1024.png').convert('RGBA')
        bg = Image.open(SRC / 'adaptive-background-1024.png').convert('RGB')
        colors = bg.getcolors(16)
        if colors is None or len(colors) != 1:
            raise SystemExit('adaptive-background-1024.png deve ser uma cor chapada.')
        self.background_rgb = colors[0][1]

    def background_hex(self) -> str:
        return '#%02X%02X%02X' % self.background_rgb


def fit_symbol(m: Masters, size: int, margin: float = 0.0) -> Image.Image:
    """Símbolo centralizado num canvas quadrado transparente de [size] px."""
    diameter = size * (1 - 2 * margin)
    scale = diameter / max(m.symbol.size)
    logo = m.symbol.resize(
        (max(1, round(m.symbol.width * scale)), max(1, round(m.symbol.height * scale))),
        Image.LANCZOS,
    )
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(
        logo, ((size - logo.width) // 2, (size - logo.height) // 2)
    )
    return canvas


def symbol_geometry(m: Masters) -> tuple[float, float, float]:
    """Centro do ring (cx, cy) e raio que envolve todo o símbolo (pin incluso).

    O centro é a linha mais larga do símbolo (equador do ring); o raio é a maior
    distância dali até a borda do recorte (pin no topo, base do ring embaixo,
    lados do ring).
    """
    mask = m.symbol.getchannel('A').point(lambda v: 255 if v > 5 else 0)
    width, height = mask.size
    widths = []
    for y in range(height):
        box = mask.crop((0, y, width, y + 1)).getbbox()
        widths.append(0 if box is None else box[2] - box[0])
    widest = max(widths)
    rows = [y for y, w in enumerate(widths) if w >= widest - 2]
    cy = sum(rows) / len(rows) + 0.5
    cx = width / 2
    return cx, cy, max(cy, height - cy, width / 2)


def fit_in_circle(m: Masters, canvas: int, diameter: float) -> Image.Image:
    """Símbolo num canvas quadrado, com todo o desenho dentro de um círculo de
    [diameter] px centrado no canvas (o ring fica no centro exato)."""
    cx, cy, radius = symbol_geometry(m)
    scale = (diameter / 2) / radius
    logo = m.symbol.resize(
        (round(m.symbol.width * scale), round(m.symbol.height * scale)),
        Image.LANCZOS,
    )
    out = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
    out.alpha_composite(
        logo, (round(canvas / 2 - cx * scale), round(canvas / 2 - cy * scale))
    )
    return out


def monochrome(foreground: Image.Image) -> Image.Image:
    """Versão monocromática: preto com alfa derivado da arte (ver MONO_*)."""
    r, g, b, a = foreground.split()
    luma = foreground.convert('RGB').convert('L')
    dark = luma.point(
        lambda v: round(
            255 * min(1.0, max(0.0, ((255 - v) / 255 - MONO_FLOOR) / MONO_DARK_SPAN))
        )
    )
    green = ImageChops.subtract(g, ImageChops.lighter(r, b)).point(
        lambda v: round(
            255
            * MONO_GREEN_ALPHA
            * min(1.0, max(0.0, (v - MONO_GREEN_OFFSET) / MONO_GREEN_SPAN))
        )
    )
    alpha = ImageChops.multiply(ImageChops.lighter(dark, green), a)
    out = Image.new('RGBA', foreground.size, (0, 0, 0, 0))
    out.putalpha(alpha)
    return out


def android(m: Masters, w: Writer) -> None:
    for name, scale in ANDROID_DENSITIES.items():
        mipmap = ANDROID_RES / f'mipmap-{name}'
        # Ícone legado (API < 26): símbolo em 48 dp, 2 dp de margem.
        w.png(fit_symbol(m, round(48 * scale), margin=2 / 48), mipmap / 'ic_launcher.png')
        # Adaptativo (API 26+): 108 dp, o master já respeita a zona segura.
        size = round(108 * scale)
        foreground = m.adaptive_fg.resize((size, size), Image.LANCZOS)
        w.png(foreground, mipmap / 'ic_launcher_foreground.png')
        w.png(monochrome(foreground), mipmap / 'ic_launcher_monochrome.png')
        # Splash (API < 31): mesma presença do iOS.
        w.png(
            fit_symbol(m, round(SPLASH_MARK_SIZE * scale)),
            ANDROID_RES / f'drawable-{name}' / 'launch_mark.png',
        )
        # Splash do Android 12+ (windowSplashScreenAnimatedIcon): canvas de
        # 288 dp, símbolo dentro do círculo seguro de 192 dp.
        w.png(
            fit_in_circle(
                m,
                round(SPLASH_A12_CANVAS_DP * scale),
                SPLASH_A12_SYMBOL_DP * scale,
            ),
            ANDROID_RES / f'drawable-{name}' / 'splash_icon.png',
        )
    w.text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        '    <!-- Fundo do ícone adaptativo: cor de adaptive-background-1024.png.\n'
        '         Gerado por tool/generate_brand_assets.py. -->\n'
        f'    <color name="ic_launcher_background">{m.background_hex()}</color>\n'
        '</resources>\n',
        ANDROID_RES / 'values/ic_launcher_background.xml',
    )


def ios(m: Masters, w: Writer) -> None:
    # App Store exige ícones opacos; o iOS aplica os cantos.
    for name, size in IOS_ICONS.items():
        image = m.app_icon if size == 1024 else m.app_icon.resize((size, size), Image.LANCZOS)
        w.png(image, IOS_ASSETS / 'AppIcon.appiconset' / name, opaque=True)
    for suffix, scale in (('', 1), ('@2x', 2), ('@3x', 3)):
        w.png(
            fit_symbol(m, SPLASH_MARK_SIZE * scale),
            IOS_ASSETS / 'LaunchImage.imageset' / f'LaunchImage{suffix}.png',
        )


def web(m: Masters, w: Writer) -> None:
    w.png(fit_symbol(m, 32, 0.04), WEB / 'favicon.png')
    w.ico([fit_symbol(m, s, 0.02) for s in (16, 32, 48)], WEB / 'favicon.ico')
    for size in (192, 512):
        w.png(fit_symbol(m, size, 0.04), WEB / 'icons' / f'Icon-{size}.png')
        maskable = Image.new('RGB', (size, size), m.background_rgb).convert('RGBA')
        maskable.alpha_composite(fit_symbol(m, size, (1 - MASKABLE_RATIO) / 2))
        w.png(maskable, WEB / 'icons' / f'Icon-maskable-{size}.png', opaque=True)
    w.png(
        m.app_icon.resize((180, 180), Image.LANCZOS),
        WEB / 'icons' / 'apple-touch-icon.png',
        opaque=True,
    )


def app(m: Masters, w: Writer) -> None:
    """Símbolo do BrandMark em 1x/2x/3x (Image.asset escolhe a densidade)."""
    for scale, folder in ((1, ''), (2, '2.0x'), (3, '3.0x')):
        path = APP_BRAND / folder / 'logo-mark.png'
        w.png(fit_symbol(m, APP_MARK_BASE * scale), path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        '--check',
        action='store_true',
        help='não grava nada; sai com erro se algum asset estiver fora de data',
    )
    args = parser.parse_args()
    writer = Writer(args.check)
    masters = Masters()
    android(masters, writer)
    ios(masters, writer)
    web(masters, writer)
    app(masters, writer)
    if args.check:
        if writer.stale:
            print('Assets fora de data (rode tool/generate_brand_assets.py):')
            for path in writer.stale:
                print(f'  {path}')
            return 1
        print(f'OK: {writer.count} assets em dia com docs/brand/source.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
