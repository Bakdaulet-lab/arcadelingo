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
const String wordsSpanishA1AssetPath = 'assets/words_es_a1.json';
const String wordsSpanishA2AssetPath = 'assets/words_es_a2.json';
const String wordsSpanishA1FromEnglishAssetPath = 'assets/words_es_a1_en.json';
const String wordsSpanishA2FromEnglishAssetPath = 'assets/words_es_a2_en.json';
const String wordsEnglishA1FromSpanishAssetPath = 'assets/words_en_a1_es.json';

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

Future<Result<List<ReviewItem>>> loadSpanishSeed({AssetBundle? bundle}) =>
    _loadSpanishSeed(wordsSpanishA1AssetPath, wordsSpanishA2AssetPath, bundle);

Future<Result<List<ReviewItem>>> loadEnglishA1FromSpanishSeed({
  AssetBundle? bundle,
}) => _loadLevelSeed(wordsEnglishA1FromSpanishAssetPath, CefrLevel.a1, bundle);

Future<Result<List<ReviewItem>>> loadSpanishFromEnglishSeed({
  AssetBundle? bundle,
}) => _loadSpanishSeed(
  wordsSpanishA1FromEnglishAssetPath,
  wordsSpanishA2FromEnglishAssetPath,
  bundle,
);

Future<Result<List<ReviewItem>>> _loadSpanishSeed(
  String a1Path,
  String a2Path,
  AssetBundle? bundle,
) async {
  final a1 = await _loadLevelSeed(a1Path, CefrLevel.a1, bundle);
  if (a1 is! Ok<List<ReviewItem>>) return a1;
  final a2 = await _loadLevelSeed(a2Path, CefrLevel.a2, bundle);
  if (a2 is! Ok<List<ReviewItem>>) return a2;

  final ids = <String>{};
  final items = [...a1.value, ...a2.value];
  for (final item in items) {
    if (!ids.add(item.word.id)) {
      return Err(Failure('$a1Path, $a2Path: повторяется id «${item.word.id}»'));
    }
  }
  return Ok(items);
}

Future<Result<List<ReviewItem>>> _loadLevelSeed(
  String path,
  CefrLevel level,
  AssetBundle? bundle,
) async {
  final source = await (bundle ?? rootBundle).loadString(path);
  final name = path.split('/').last;
  return switch (parseWordsSeed(source)) {
    Ok(:final value)
        when value.isNotEmpty &&
            value.every((item) => item.word.level == level) =>
      Ok(value),
    Ok() => Err(
      Failure('$name: ожидаются карточки ${level.name.toUpperCase()}'),
    ),
    Err(:final failure) => Err(Failure('$name: ${failure.message}')),
  };
}
