/// Загрузка сида слов из бандла приложения.
///
/// Читает словари A1–B2, C1 и C2 и объединяет карточки в памяти.
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
const String wordsC2AssetPath = 'assets/words_c2.json';

/// Сид из [bundle] (по умолчанию [rootBundle]) → единицы показа.
///
/// [bundle] подменяется в тестах и при смене источника контента (Трек К5).
Future<Result<List<ReviewItem>>> loadWordsSeed({AssetBundle? bundle}) async {
  final assets = bundle ?? rootBundle;
  final base = parseWordsSeed(await assets.loadString(wordsSeedAssetPath));
  if (base is! Ok<List<ReviewItem>>) return base;

  final items = [...base.value];
  final ids = {for (final item in base.value) item.word.id};
  for (final (path, level) in const [
    (wordsC1AssetPath, CefrLevel.c1),
    (wordsC2AssetPath, CefrLevel.c2),
  ]) {
    switch (parseWordsSeed(await assets.loadString(path))) {
      case Ok(:final value):
        for (final item in value) {
          final word = item.word;
          if (word.level != level) {
            return Err(
              Failure(
                '$path: уровень слова «${word.id}» не ${level.name.toUpperCase()}',
              ),
            );
          }
          if (!ids.add(word.id)) {
            return Err(Failure('$path: повторяется id слова «${word.id}»'));
          }
        }
        items.addAll(value);
      case Err(:final failure):
        return Err(Failure('$path: ${failure.message}'));
    }
  }

  return Ok(items);
}
