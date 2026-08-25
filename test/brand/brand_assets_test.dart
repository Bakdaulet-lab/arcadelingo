// Бренд живёт не в Dart, а в XML, plist и PNG — то есть там, куда не смотрит
// ни один другой тест этого проекта. Сборка с белым сплешем и подписью
// «arcadelingo» под иконкой соберётся зелёной, установится и запустится: узнать
// об этом можно только глазами на телефоне, и то если посмотреть в нужную
// секунду.
//
// Поэтому здесь читаются файлы платформ, а не виджеты. Три вещи, за которые
// тест отвечает:
//
//   имя      — подпись под иконкой и в списке задач, на обеих платформах;
//   цвет     — числа в XML и plist равны `surface` из lib/app/theme.dart,
//              потому что скопированное число расходится молча;
//   иконки   — файлы на месте, ровно того размера, что обещает манифест
//              плотностей, и без альфы там, где альфа запрещена.
//
// applicationId проверяется отдельно и намеренно: менять его после первой
// публикации нельзя вообще, а «заодно причесать» его может кто угодно.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:arcadelingo/app/theme.dart';
import 'package:flutter_test/flutter_test.dart';

/// Имя, утверждённое автором. Одно на обе платформы.
const String appName = 'Arcadelingo';

const String androidRes = 'android/app/src/main/res';
const String iosIconDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

/// Плотности легаси-иконки: 48 dp × множитель плотности.
const Map<String, int> legacyDensities = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

/// Плотности слоёв адаптивной иконки: холст 108 dp.
const Map<String, int> adaptiveDensities = {
  'mdpi': 108,
  'hdpi': 162,
  'xhdpi': 216,
  'xxhdpi': 324,
  'xxxhdpi': 432,
};

void main() {
  group('имя приложения', () {
    test('Android берёт подпись из strings.xml, а не из манифеста', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      expect(
        manifest,
        contains('android:label="@string/app_name"'),
        reason: 'строка прямо в манифесте не переводится и не видна магазину',
      );
      expect(
        _read('$androidRes/values/strings.xml'),
        contains('<string name="app_name">$appName</string>'),
      );
    });

    test('iOS показывает то же имя', () {
      final plist = _read('ios/Runner/Info.plist');
      expect(_plistString(plist, 'CFBundleDisplayName'), appName);
      // CFBundleName — запасное имя: его берут те места, куда DisplayName не
      // доезжает, например Settings. Разъехавшись, они дают два разных
      // приложения в глазах пользователя.
      expect(_plistString(plist, 'CFBundleName'), appName);
    });

    test('список недавних задач подписан так же', () {
      expect(_read('lib/app/app.dart'), contains("title: '$appName',"));
    });
  });

  group('сплеш без белой вспышки', () {
    final surface = wordarcadeColors.surface.toARGB32();

    test('brand_surface в ресурсах равен surface из темы', () {
      final hex = RegExp(
        r'<color name="brand_surface">#([0-9A-Fa-f]{8})</color>',
      ).firstMatch(_read('$androidRes/values/colors.xml'))?.group(1);
      expect(hex, isNotNull, reason: 'цвета brand_surface нет в colors.xml');
      expect(
        int.parse(hex!, radix: 16),
        surface,
        reason:
            'XML не умеет читать Dart, поэтому число скопировано. Разойдясь с '
            'темой, оно даст вспышку чужого цвета между сплешем и первым кадром.',
      );
    });

    test('обе темы окна тёмные и красятся brand_surface', () {
      final styles = _code('$androidRes/values/styles.xml');
      expect(
        RegExp(r'parent="@android:style/Theme\.Light').hasMatch(styles),
        isFalse,
        reason: 'Theme.Light даёт белое окно — ровно ту вспышку, что убираем',
      );
      for (final item in const [
        'android:windowBackground',
        'android:statusBarColor',
        'android:navigationBarColor',
      ]) {
        expect(
          '<item name="$item">'.allMatches(styles).length,
          2,
          reason: '$item обязан быть задан и в LaunchTheme, и в NormalTheme',
        );
      }
      // Android 12+ рисует сплеш сам и windowBackground для него не читает.
      expect(styles, contains('android:windowSplashScreenBackground'));
      expect(
        File('$androidRes/values-night/styles.xml').existsSync(),
        isFalse,
        reason:
            'приложение тёмное всегда; вторая копия тех же стилей разъедется '
            'с первой, и узнают об этом по вспышке на чьём-то телефоне',
      );
    });

    test('фон сплеша назван цветом, а не атрибутом темы', () {
      final background = _code('$androidRes/drawable/launch_background.xml');
      expect(background, contains('@color/brand_surface'));
      expect(background, isNot(contains('@android:color/white')));
      expect(
        background,
        isNot(contains('?android:colorBackground')),
        reason: 'ссылка на атрибут темы — это «какой цвет решит платформа»',
      );
    });

    test('стартовый экран iOS того же цвета', () {
      final storyboard = _read('ios/Runner/Base.lproj/LaunchScreen.storyboard');
      final match = RegExp(
        r'<color key="backgroundColor" red="([\d.]+)" green="([\d.]+)" '
        r'blue="([\d.]+)"',
      ).firstMatch(storyboard);
      expect(match, isNotNull, reason: 'в сториборде нет цвета фона');
      final channels = [
        wordarcadeColors.surface.r,
        wordarcadeColors.surface.g,
        wordarcadeColors.surface.b,
      ];
      for (var i = 0; i < 3; i++) {
        expect(
          double.parse(match!.group(i + 1)!),
          closeTo(channels[i], 1 / 255),
          reason: 'канал ${'rgb'[i]} стартового экрана iOS разошёлся с темой',
        );
      }
    });
  });

  group('иконка лаунчера', () {
    test('легаси-иконка: все плотности, точный размер, без альфы', () {
      for (final entry in legacyDensities.entries) {
        final png = _png('$androidRes/mipmap-${entry.key}/ic_launcher.png');
        expect(png.width, entry.value, reason: 'mipmap-${entry.key}');
        expect(png.height, entry.value, reason: 'mipmap-${entry.key}');
        expect(
          png.colorType,
          2,
          reason:
              'mipmap-${entry.key}: иконка обязана быть непрозрачной, тип 6 '
              'означает альфу, а с ней приложение не принимает App Store',
        );
      }
    });

    test('слои адаптивной иконки: холст 108 dp и альфа на месте', () {
      for (final entry in adaptiveDensities.entries) {
        for (final layer in const ['foreground', 'monochrome']) {
          final png = _png(
            '$androidRes/drawable-${entry.key}/ic_launcher_$layer.png',
          );
          expect(
            png.width,
            entry.value,
            reason: 'drawable-${entry.key}/$layer',
          );
          expect(
            png.colorType,
            6,
            reason:
                '$layer без альфы закрыл бы фон адаптивной иконки сплошным '
                'прямоугольником',
          );
        }
      }
    });

    test('adaptive-icon описывает все три слоя', () {
      final xml = _code('$androidRes/mipmap-anydpi-v26/ic_launcher.xml');
      expect(
        xml,
        contains('<background android:drawable="@color/brand_surface"'),
      );
      expect(xml, contains('@drawable/ic_launcher_foreground'));
      expect(
        xml,
        contains('@drawable/ic_launcher_monochrome'),
        reason:
            'без monochrome тематические иконки Android 13 покажут заглушку',
      );
    });

    test(
      'iOS: каждый файл из Contents.json существует и совпадает размером',
      () {
        final catalog =
            json.decode(_read('$iosIconDir/Contents.json'))
                as Map<String, dynamic>;
        final images = (catalog['images'] as List).cast<Map<String, dynamic>>();
        expect(images, isNotEmpty);
        for (final image in images) {
          final name = image['filename'] as String;
          final side = double.parse((image['size'] as String).split('x').first);
          final scale = int.parse(
            (image['scale'] as String).replaceAll('x', ''),
          );
          final expected = (side * scale).round();
          final png = _png('$iosIconDir/$name');
          expect(png.width, expected, reason: name);
          expect(png.height, expected, reason: name);
          expect(
            png.colorType,
            2,
            reason: '$name: альфа в иконке iOS запрещена',
          );
        }
      },
    );

    test('иконка нарисована фоном темы, а не чем-то похожим', () {
      // Угловой пиксель легаси-иконки — чистый фон: рисунок занимает 86%
      // квадрата и до угла не достаёт.
      final bytes =
          File('$androidRes/mipmap-xxxhdpi/ic_launcher.png').readAsBytesSync();
      final png = _pngOf(bytes);
      expect(png.colorType, 2);
      final surface = wordarcadeColors.surface;
      final corner = _firstPixelRgb(bytes);
      expect(corner, [
        (surface.r * 255).round(),
        (surface.g * 255).round(),
        (surface.b * 255).round(),
      ]);
    });
  });

  test('applicationId не тронут', () {
    // Идентификатор — единственное, что нельзя поменять после публикации:
    // сменённый applicationId это другое приложение, без обновления и без
    // отзывов. Пин здесь для того, чтобы «причесать заодно» стоило красного
    // теста, а не разговора задним числом.
    expect(
      _read('android/app/build.gradle.kts'),
      contains('applicationId = "com.baks.arcadelingo"'),
    );
  });
}

/// XML без комментариев.
///
/// Тот же приём, что во втором `grep` из `scripts/arch_check.sh`: правило,
/// названное словами в комментарии, не должно считаться его нарушением. Без
/// этого фильтра запрет на `?android:colorBackground` краснел от собственного
/// объяснения, почему этот атрибут здесь не годится.
String _code(String path) =>
    _read(path).replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) fail('нет файла $path');
  return file.readAsStringSync();
}

String? _plistString(String plist, String key) => RegExp(
  '<key>$key</key>\\s*<string>([^<]*)</string>',
).firstMatch(plist)?.group(1);

/// Заголовок IHDR: он идёт первым чанком и всегда по одним и тем же смещениям.
typedef _Png = ({int width, int height, int colorType});

_Png _png(String path) => _pngOf(
  File(path).existsSync()
      ? File(path).readAsBytesSync()
      : fail('нет файла $path'),
);

_Png _pngOf(Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  expect(bytes.sublist(0, 8), signature, reason: 'это не PNG');
  expect(String.fromCharCodes(bytes.sublist(12, 16)), 'IHDR');
  final data = ByteData.sublistView(bytes);
  return (
    width: data.getUint32(16),
    height: data.getUint32(20),
    colorType: bytes[25],
  );
}

/// Первый пиксель распакованной картинки — левый верхний угол.
List<int> _firstPixelRgb(Uint8List bytes) {
  var offset = 8;
  while (offset < bytes.length) {
    final length = ByteData.sublistView(bytes).getUint32(offset);
    final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
    if (type == 'IDAT') {
      final raw = ZLibCodec().decode(
        bytes.sublist(offset + 8, offset + 8 + length),
      );
      // Первый байт строки — код фильтра; для наших PNG он всегда 0.
      expect(raw.first, 0, reason: 'ожидался фильтр None');
      return [raw[1], raw[2], raw[3]];
    }
    offset += 12 + length;
  }
  fail('в PNG нет чанка IDAT');
}
