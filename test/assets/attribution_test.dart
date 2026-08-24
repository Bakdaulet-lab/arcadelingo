// Цитирование источника — лицензионное условие, а не вежливость.
//
// CEFR-J разрешает коммерческое использование «provided that you cite the
// dataset properly», а уровни слов в `assets/words_seed.json` взяты именно
// оттуда. Значит цитата обязана ехать в бандле вместе с ассетом, а не лежать
// только в репозитории: пользователь продукта репозитория не видит.
//
// rootBundle, а не dart:io: заодно проверяет регистрацию ассета в pubspec.yaml
// — незарегистрированный файл в сборку не попадёт, и загрузка здесь упадёт.
//
// Экран «Источники», показывающий этот текст в приложении, — отдельная задача
// (нужен lib/). До неё условие выполнено наполовину: файл в бандле есть,
// показать его пока нечем.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _assetPath = 'assets/ATTRIBUTION.md';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String text;

  setUpAll(() async {
    text = await rootBundle.loadString(_assetPath);
  });

  test('цитата CEFR-J дословно, как требует источник', () {
    expect(text, contains('The CEFR-J Wordlist Version 1.5'));
    expect(text, contains('Yukio Tono'));
    expect(text, contains('Tokyo University of Foreign Studies'));
  });

  test('копирайт и разрешительная фраза на месте', () {
    expect(text, contains('Tono Laboratory'));
    expect(text, contains('research and commercial purposes with no charge'));
  });
}
