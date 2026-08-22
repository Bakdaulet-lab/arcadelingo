/// Состояние Лейтнера в `shared_preferences`: один ключ, один JSON-документ.
///
/// Реализации здесь ещё нет — только сигнатуры для тестов задачи 0.5.
library;

import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeitnerPrefsStore {
  LeitnerPrefsStore(SharedPreferences prefs);

  /// Ключ документа в prefs.
  static const String key = 'leitner_state';

  Result<Map<String, LeitnerCard>> load() =>
      throw UnimplementedError('стор Лейтнера не реализован — задача 0.5');

  Future<bool> save(Map<String, LeitnerCard> cards) =>
      throw UnimplementedError('стор Лейтнера не реализован — задача 0.5');
}
