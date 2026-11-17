/// Загрузка сида слов из бандла приложения.
///
/// Читает словари A1–B2 и C1 и объединяет карточки в памяти.
/// Отсутствие ассета — `FlutterError` из `loadString`: это дефект сборки
/// (файл не зарегистрирован в `pubspec.yaml`), а не битые данные, и в
/// [Failure] он не заворачивается.
library;

import 'package:arcadelingo/data/words/words_seed_codec.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter/services.dart';

/// Пути ассетов, зарегистрированные в `pubspec.yaml`.
const String wordsSeedAssetPath = 'assets/words_seed.json';
const String wordsC1AssetPath = 'assets/words_c1.json';

/// Сид из [bundle] (по умолчанию [rootBundle]) → единицы показа.
///
/// [bundle] подменяется в тестах и при смене источника контента (Трек К5).
Future<Result<List<ReviewItem>>> loadWordsSeed({AssetBundle? bundle}) async {
  final assets = bundle ?? rootBundle;
  final base = parseWordsSeed(await assets.loadString(wordsSeedAssetPath));
  if (base is! Ok<List<ReviewItem>>) return base;

  final List<ReviewItem> c1;
  switch (parseWordsSeed(await assets.loadString(wordsC1AssetPath))) {
    case Ok(:final value):
      c1 = value;
    case Err(:final failure):
      return Err(Failure('$wordsC1AssetPath: ${failure.message}'));
  }
  final ids = {for (final item in base.value) item.word.id};
  for (final item in c1) {
    final word = item.word;
    if (word.level != CefrLevel.c1) {
      return Err(
        Failure('$wordsC1AssetPath: уровень слова «${word.id}» не C1'),
      );
    }
    if (!ids.add(word.id)) {
      return Err(
        Failure('$wordsC1AssetPath: повторяется id слова «${word.id}»'),
      );
    }
  }

  return Ok([...base.value, ...c1]);
}
