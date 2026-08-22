/// Загрузка сида слов из бандла приложения.
///
/// Тонкая обёртка над [parseWordsSeed]: читает ассет и отдаёт его кодеку.
/// Отсутствие ассета — `FlutterError` из `loadString`: это дефект сборки
/// (файл не зарегистрирован в `pubspec.yaml`), а не битые данные, и в
/// [Failure] он не заворачивается.
library;

import 'package:arcadelingo/data/words/words_seed_codec.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter/services.dart';

/// Путь ассета — тот же, что зарегистрирован в `pubspec.yaml`.
const String wordsSeedAssetPath = 'assets/words_seed.json';

/// Сид из [bundle] (по умолчанию [rootBundle]) → единицы показа.
///
/// [bundle] подменяется в тестах и при смене источника контента (Трек К5).
Future<Result<List<ReviewItem>>> loadWordsSeed({AssetBundle? bundle}) async {
  final raw = await (bundle ?? rootBundle).loadString(wordsSeedAssetPath);
  return parseWordsSeed(raw);
}
