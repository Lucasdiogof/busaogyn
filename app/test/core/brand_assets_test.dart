import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Cabeçalho de um PNG: lado e se tem canal alfa.
({int width, int height, bool alpha}) _png(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'não existe: $path');
  final bytes = file.readAsBytesSync();
  expect(bytes.sublist(0, 8), [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ], reason: '$path não é PNG');
  final data = ByteData.sublistView(bytes);
  final colorType = bytes[25];
  return (
    width: data.getUint32(16),
    height: data.getUint32(20),
    // 4 = cinza+alfa, 6 = RGBA.
    alpha: colorType == 4 || colorType == 6,
  );
}

void _expectSquare(String path, int size, {bool? alpha}) {
  final png = _png(path);
  expect(png.width, size, reason: '$path: largura');
  expect(png.height, size, reason: '$path: altura');
  if (alpha != null) {
    expect(png.alpha, alpha, reason: '$path: canal alfa');
  }
}

const _densities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

void main() {
  group('masters oficiais', () {
    const src = '../docs/brand/source';

    test('logo transparente, ícone iOS opaco e camadas adaptativas', () {
      _expectSquare('$src/logo-master-transparent.png', 1254, alpha: true);
      _expectSquare('$src/app-icon-master-1024.png', 1024, alpha: false);
      _expectSquare('$src/adaptive-foreground-1024.png', 1024, alpha: true);
      _expectSquare('$src/adaptive-background-1024.png', 1024, alpha: false);
    });
  });

  group('Android', () {
    const res = 'android/app/src/main/res';

    test('ícone adaptativo referencia fundo, foreground e monochrome', () {
      final xml = File(
        '$res/mipmap-anydpi-v26/ic_launcher.xml',
      ).readAsStringSync();
      expect(xml, contains('@color/ic_launcher_background'));
      expect(
        xml,
        contains(
          '<foreground android:drawable="@mipmap/ic_launcher_foreground"',
        ),
      );
      expect(
        xml,
        contains(
          '<monochrome android:drawable="@mipmap/ic_launcher_monochrome"',
        ),
      );

      final colors = File(
        '$res/values/ic_launcher_background.xml',
      ).readAsStringSync();
      expect(
        RegExp(
          r'<color name="ic_launcher_background">#[0-9A-Fa-f]{6}</color>',
        ).hasMatch(colors),
        isTrue,
      );
    });

    test('ícones por densidade: legado, adaptativo, monochrome e splash', () {
      _densities.forEach((name, scale) {
        _expectSquare(
          '$res/mipmap-$name/ic_launcher.png',
          (48 * scale).round(),
          alpha: true,
        );
        final adaptive = (108 * scale).round();
        _expectSquare(
          '$res/mipmap-$name/ic_launcher_foreground.png',
          adaptive,
          alpha: true,
        );
        _expectSquare(
          '$res/mipmap-$name/ic_launcher_monochrome.png',
          adaptive,
          alpha: true,
        );
        _expectSquare(
          '$res/drawable-$name/launch_mark.png',
          (144 * scale).round(),
          alpha: true,
        );
        // Android 12+: canvas de 288 dp.
        _expectSquare(
          '$res/drawable-$name/splash_icon.png',
          (288 * scale).round(),
          alpha: true,
        );
      });
    });

    test(
      'splash do Android 12+ usa o splash_icon nos temas claro e escuro',
      () {
        for (final dir in const ['values-v31', 'values-night-v31']) {
          final xml = File('$res/$dir/styles.xml').readAsStringSync();
          expect(
            xml,
            contains(
              'android:windowSplashScreenAnimatedIcon">@drawable/splash_icon',
            ),
          );
          expect(
            xml,
            contains(
              'android:windowSplashScreenBackground">@color/launch_background',
            ),
          );
        }
      },
    );

    test('applicationId preservado', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('com.lucksrei.busaogyn'));
    });
  });

  group('iOS', () {
    const set = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

    test('AppIcon completo, opaco e na dimensão declarada', () {
      final contents =
          jsonDecode(File('$set/Contents.json').readAsStringSync()) as Map;
      final images = (contents['images'] as List).cast<Map>();
      expect(images, isNotEmpty);
      var marketing = false;
      for (final image in images) {
        final name = image['filename'] as String?;
        expect(name, isNotNull, reason: 'entrada sem arquivo: $image');
        final points = double.parse((image['size'] as String).split('x').first);
        final scale = int.parse((image['scale'] as String).replaceAll('x', ''));
        final pixels = (points * scale).round();
        // A App Store e o iOS rejeitam alfa; o sistema aplica os cantos.
        _expectSquare('$set/$name', pixels, alpha: false);
        if (pixels == 1024) marketing = true;
      }
      expect(marketing, isTrue, reason: 'falta o ícone 1024×1024 da App Store');
    });

    test('LaunchImage 1x/2x/3x com alfa e tamanho declarado no storyboard', () {
      const launch = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
      _expectSquare('$launch/LaunchImage.png', 144, alpha: true);
      _expectSquare('$launch/LaunchImage@2x.png', 288, alpha: true);
      _expectSquare('$launch/LaunchImage@3x.png', 432, alpha: true);
      final storyboard = File(
        'ios/Runner/Base.lproj/LaunchScreen.storyboard',
      ).readAsStringSync();
      expect(
        storyboard,
        contains('<image name="LaunchImage" width="144" height="144"/>'),
      );
    });

    test('bundle id preservado', () {
      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      expect(project, contains('com.lucksrei.busaogyn'));
    });
  });

  group('Web', () {
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync()) as Map;
    final icons = (manifest['icons'] as List).cast<Map>();

    test('manifest: 192 e 512, any e maskable, arquivos existentes', () {
      for (final purpose in const [null, 'maskable']) {
        for (final size in const [192, 512]) {
          final match = icons.where(
            (i) => i['sizes'] == '${size}x$size' && i['purpose'] == purpose,
          );
          expect(match, hasLength(1), reason: '$purpose $size');
          final path = 'web/${match.single['src']}';
          // Maskable é opaco (sangria total); "any" mantém o fundo transparente.
          _expectSquare(path, size, alpha: purpose == null);
          expect(match.single['type'], 'image/png');
        }
      }
    });

    test('index.html referencia favicon e apple-touch-icon existentes', () {
      final html = File('web/index.html').readAsStringSync();
      for (final href in const [
        'favicon.ico',
        'favicon.png',
        'icons/apple-touch-icon.png',
        'manifest.json',
      ]) {
        expect(html, contains('href="$href"'));
        expect(File('web/$href').existsSync(), isTrue, reason: href);
      }
      _expectSquare('web/favicon.png', 32, alpha: true);
      _expectSquare('web/icons/apple-touch-icon.png', 180, alpha: false);
      expect(File('web/icons/Icon-192.png').existsSync(), isTrue); // splash
    });
  });

  group('app', () {
    test('logo-mark declarado e com variantes 1x/2x/3x', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/brand/logo-mark.png'));
      _expectSquare('assets/brand/logo-mark.png', 64, alpha: true);
      _expectSquare('assets/brand/2.0x/logo-mark.png', 128, alpha: true);
      _expectSquare('assets/brand/3.0x/logo-mark.png', 192, alpha: true);
    });
  });
}
