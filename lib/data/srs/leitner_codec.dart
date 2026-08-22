/// Кодек состояния Лейтнера: JSON-документ хранилища ↔ карточки по id слова.
///
/// Формат v1 — один документ на всё состояние:
/// ```json
/// {"version":1,"cards":{"apple":{"box":2,"due":"2026-03-09T12:00:00.000Z"}}}
/// ```
///
/// Контракт (docs/dev/tasks.md, 0.5): битые данные дают [Err], а не
/// исключение, и НЕ доходят до конструктора [LeitnerCard] — его
/// `ArgumentError` сторожит инвариант типа, разбор хранилища — работа этого
/// файла. Отсюда два правила:
///
/// - ни одного `as` и `.cast()` на данных из JSON: они кидают `TypeError`,
///   который не является ошибкой формата и не ловится; только `is` и паттерны;
/// - единственный `catch` — `FormatException` из `jsonDecode`: другого
///   способа узнать «это не JSON» в Dart нет. `on ArgumentError` вокруг
///   конструктора был бы глушением: до него битое значение не доходит.
///
/// `due` пишется как есть через `toIso8601String()`: конструктор гарантирует
/// UTC, значит в строке будет `Z`. Читается строго: строку без обозначения
/// зоны Dart разбирает как локальное время устройства — момент зависит от
/// того, где читают, и такая запись считается битой. Явное смещение
/// (`+05:00`) допустимо: момент однозначен, Dart сам приводит его к UTC.
///
/// Одна битая карточка — [Err] на весь документ, с id слова в сообщении.
/// Частичное восстановление прятало бы проблему.
library;

import 'dart:convert';

import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';

/// Версия формата документа. Другая версия — [Err]: читать её некому.
const int _formatVersion = 1;

/// Состояние → JSON-документ для хранилища.
String encodeLeitnerState(Map<String, LeitnerCard> cards) => jsonEncode({
  'version': _formatVersion,
  'cards': {
    for (final MapEntry(key: id, value: card) in cards.entries)
      id: {'box': card.box, 'due': card.due.toIso8601String()},
  },
});

/// JSON-документ хранилища → состояние; битые данные — [Err].
///
/// Карта в [Ok] — новая и изменяемая: вызывающий будет дописывать в неё
/// карточки по ходу сессии.
Result<Map<String, LeitnerCard>> decodeLeitnerState(String json) {
  final Object? root;
  try {
    root = jsonDecode(json);
  } on FormatException catch (e) {
    return Err(Failure('состояние Лейтнера: невалидный JSON: ${e.message}'));
  }
  if (root is! Map<String, Object?>) {
    return const Err(Failure('состояние Лейтнера: корень не объект'));
  }
  if (root['version'] != _formatVersion) {
    return Err(
      Failure(
        'состояние Лейтнера: неизвестная версия формата ${root['version']}',
      ),
    );
  }
  final rawCards = root['cards'];
  if (rawCards is! Map<String, Object?>) {
    return const Err(
      Failure('состояние Лейтнера: поле cards отсутствует или не объект'),
    );
  }
  final cards = <String, LeitnerCard>{};
  for (final MapEntry(key: id, value: raw) in rawCards.entries) {
    switch (_decodeCard(id, raw)) {
      case Ok(:final value):
        cards[id] = value;
      case Err(:final failure):
        return Err(failure);
    }
  }
  return Ok(cards);
}

/// Одна запись документа → карточка. Проверки идут в порядке «тип поля →
/// диапазон → конструктор», чтобы до [LeitnerCard] доходили только значения,
/// которые он гарантированно примет.
Result<LeitnerCard> _decodeCard(String id, Object? raw) {
  if (raw is! Map<String, Object?>) {
    return Err(Failure('карточка "$id": запись не объект'));
  }
  final box = raw['box'];
  if (box is! int) {
    return Err(Failure('карточка "$id": box отсутствует или не целое: $box'));
  }
  if (box < LeitnerCard.minBox || box > LeitnerCard.maxBox) {
    return Err(
      Failure(
        'карточка "$id": box $box вне '
        '${LeitnerCard.minBox}..${LeitnerCard.maxBox}',
      ),
    );
  }
  final rawDue = raw['due'];
  if (rawDue is! String) {
    return Err(
      Failure('карточка "$id": due отсутствует или не строка: $rawDue'),
    );
  }
  final due = DateTime.tryParse(rawDue);
  if (due == null) {
    return Err(Failure('карточка "$id": due не парсится: "$rawDue"'));
  }
  if (!due.isUtc) {
    return Err(
      Failure(
        'карточка "$id": due без обозначения зоны, момент неоднозначен: '
        '"$rawDue"',
      ),
    );
  }
  return Ok(LeitnerCard(box: box, due: due));
}
