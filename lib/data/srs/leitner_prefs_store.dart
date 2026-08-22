/// Состояние Лейтнера в `shared_preferences`: один ключ, один JSON-документ
/// ([encodeLeitnerState]).
///
/// Гейт-0: без репозитория и абстракции над хранилищем (ROADMAP.md). Фаза 2
/// переносит состояние в Drift, и этот класс становится кодом миграции.
///
/// Legacy-API `SharedPreferences`, а не `SharedPreferencesAsync`: у него есть
/// штатный in-memory фейк для тестов (`setMockInitialValues`), а для
/// async-варианта пришлось бы тянуть `shared_preferences_platform_interface`
/// отдельной зависимостью. Экземпляр приходит снаружи: `getInstance()`
/// асинхронен и вызывается один раз при старте приложения.
library;

import 'package:arcadelingo/data/srs/leitner_codec.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeitnerPrefsStore {
  LeitnerPrefsStore(this._prefs);

  final SharedPreferences _prefs;

  /// Ключ документа в prefs. Переименование — потеря прогресса у
  /// пользователей; тест стора держит это имя литералом именно поэтому.
  static const String key = 'leitner_state';

  /// Сохранённое состояние: карточки по id слова.
  ///
  /// Ключа нет — первый запуск, не ошибка: пустая карта. Ключ есть, но
  /// документ битый — [Err]; стор при этом ничего не пишет и не сбрасывает.
  /// Что делать с битыми данными (сброс, экран ошибки) — решает вызывающий
  /// слой (задача 0.6): молчаливый сброс уничтожил бы улики. Под ключом
  /// не строка — `TypeError` из самого пакета: туда пишем только мы, и ловить
  /// это было бы глушением.
  ///
  /// Карта всегда новая и изменяемая: вызывающий дописывает в неё карточки
  /// по ходу сессии. `const {}` здесь упал бы с `UnsupportedError` — и только
  /// на первом запуске, после первого сохранения уже нет.
  Result<Map<String, LeitnerCard>> load() {
    final raw = _prefs.getString(key);
    if (raw == null) {
      final empty = <String, LeitnerCard>{};
      return Ok(empty);
    }
    return decodeLeitnerState(raw);
  }

  /// Записывает [cards] как полное состояние: документ **заменяется**, не
  /// сливается с прежним. Передавай все карточки, не только изменённые —
  /// частичная карта молча потеряет остальные слова.
  ///
  /// Возвращает ответ платформы: `false` — запись не удалась.
  Future<bool> save(Map<String, LeitnerCard> cards) =>
      _prefs.setString(key, encodeLeitnerState(cards));

  /// Удаляет документ состояния: следующий [load] — первый запуск.
  Future<bool> reset() =>
      throw UnimplementedError('сброс состояния не реализован — задача 0.6');
}
