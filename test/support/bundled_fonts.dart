// Шрифты приложения в тестовом движке: гарнитура Rubik и MaterialIcons.
//
// Вынесено из test/golden/flutter_test_config.dart, когда появился второй
// потребитель — test/peek/. Копия загрузчика однажды разошлась бы с
// оригиналом, и разошлась бы молча: обе версии продолжали бы «работать»,
// просто рисуя разные буквы.
//
// Иконки грузятся наравне с текстом: сердца, крест у промаха и галочка у
// верного варианта несут половину смысла экрана.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Загружает в тестовый движок все семейства из `FontManifest.json`.
///
/// Падает громко, если нет любого из двух обязательных семейств. Молчаливого
/// фолбэка нет намеренно: без шрифта `flutter test` рисует каждую букву
/// прямоугольником одинаковой ширины. Голдены при этом снялись бы, сравнились
/// сами с собой и остались бы зелёными, не говоря ни о чём, а peek выдал бы
/// человеку картинку, по которой ничего не решить.
Future<void> loadBundledFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  final families = <String>[];
  for (final entry in manifest) {
    final family = (entry as Map)['family'] as String;
    families.add(family);
    final loader = FontLoader(family);
    for (final font in entry['fonts'] as List) {
      loader.addFont(rootBundle.load((font as Map)['asset'] as String));
    }
    await loader.load();
  }
  for (final required in ['MaterialIcons', 'Rubik']) {
    if (!families.contains(required)) {
      throw StateError(
        'В FontManifest.json нет $required: ${families.join(', ')}.\n'
        'Текст или иконки нарисуются прямоугольниками, а картинка выйдет\n'
        'бессмысленной. Проверь секции fonts и uses-material-design в pubspec.',
      );
    }
  }
}
