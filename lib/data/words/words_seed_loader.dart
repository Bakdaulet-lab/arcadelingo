/// Загрузка сида слов из бандла приложения.
///
/// Реализации здесь ещё нет — только сигнатура для тестов задачи 0.5.
library;

import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter/services.dart';

/// Путь ассета — тот же, что зарегистрирован в `pubspec.yaml`.
const String wordsSeedAssetPath = 'assets/words_seed.json';

Future<Result<List<ReviewItem>>> loadWordsSeed({AssetBundle? bundle}) =>
    throw UnimplementedError('загрузчик сида не реализован — задача 0.5');
