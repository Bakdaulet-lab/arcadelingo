/// Серия дней в `shared_preferences`: один ключ, один JSON-документ.
///
/// Устройство скопировано с `LeitnerPrefsStore` до мелочей, и это не лень:
/// два документа в одном хранилище должны вести себя одинаково, иначе
/// «прогресс не читается» будет значить разное в зависимости от того, какой
/// именно документ побился.
///
/// Второй документ, а не поле в первом: у них разная природа и разный ритм
/// записи. Карточки пишутся на каждый ответ, серия — раз в день; и битая
/// серия не должна утаскивать за собой карточки, которые читаются нормально.
/// Цена решения названа честно — окно рассинхрона между двумя записями при
/// убийстве приложения, худшее последствие «серия не продлилась сегодня»
/// (`docs/dev/context.md`).
library;

import 'package:arcadelingo/data/streak/streak_codec.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/ports/streak_store.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreakPrefsStore implements StreakStore {
  StreakPrefsStore(this._prefs);

  final SharedPreferences _prefs;

  /// Ключ документа в prefs. Переименование — потеря серии у пользователей;
  /// тест держит это имя литералом именно поэтому.
  static const String key = 'streak_state';

  @override
  Result<StreakState> load() {
    throw UnimplementedError();
  }

  @override
  Future<bool> save(StreakState state) {
    throw UnimplementedError();
  }

  @override
  Future<bool> reset() {
    throw UnimplementedError();
  }
}
