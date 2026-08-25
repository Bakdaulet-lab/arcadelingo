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
import 'package:arcadelingo/domain/ports/card_store.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Реализация порта [CardStore]. Тело класса при подключении порта не
/// менялось: интерфейс списан с уже существовавших методов, а не наоборот.
class LeitnerPrefsStore implements CardStore {
  LeitnerPrefsStore(this._prefs);

  final SharedPreferences _prefs;

  /// Ключ документа в prefs. Переименование — потеря прогресса у
  /// пользователей; тест стора держит это имя литералом именно поэтому.
  static const String key = 'leitner_state';

  /// Сохранённое состояние: карточки по id слова.
  ///
  /// Ключа нет — первый запуск, не ошибка: пустая карта. Ключ есть, но
  /// документ битый — [Err]; стор при этом ничего не пишет и не сбрасывает.
  /// Что делать с битыми данными, решено в 0.6: хост показывает экран ошибки
  /// с текстом [Failure] и явной кнопкой сброса — [reset] нажимает
  /// пользователь, автосброса в коде нет, молчаливый сброс уничтожил бы
  /// улики (экран — задача 0.8). Под ключом не строка — `TypeError` из
  /// самого пакета: туда пишем только мы, и ловить это было бы глушением.
  ///
  /// Карта всегда новая и изменяемая — закреплено тестом. Сессия (0.6) её
  /// копирует и владеет копией, так что ловушка `const {}` (упал бы с
  /// `UnsupportedError`, и только на первом запуске) сюда больше не
  /// дотягивается; гарантия остаётся, она дешёвая.
  @override
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
  /// Кодирование — синхронно, до первого `await`. Хост вызывает
  /// `unawaited(save(cards))` на живой карте сессии, и следующий `report()`
  /// не должен успеть изменить её до записи: `encodeLeitnerState` стоит в
  /// аргументе `setString` именно поэтому. При рефакторинге в `async` держи
  /// кодирование первой строкой — это закреплено тестом стора.
  ///
  /// Возвращает ответ платформы: `false` — запись не удалась.
  @override
  Future<bool> save(Map<String, LeitnerCard> cards) =>
      _prefs.setString(key, encodeLeitnerState(cards));

  /// Удаляет документ состояния: следующий [load] — первый запуск.
  ///
  /// Единственный способ избавиться от битого документа, и вызывает его
  /// только пользователь — кнопкой на экране ошибки состояния (задача 0.8).
  /// Код приложения сам сюда не ходит: молчаливый сброс уничтожил бы улики.
  @override
  Future<bool> reset() => _prefs.remove(key);
}
