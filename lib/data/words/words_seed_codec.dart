/// Разбор сида слов `assets/words_seed.json` в единицы показа.
///
/// Запись сида — слово плюс готовые дистракторы, то есть ровно [ReviewItem]
/// из контракта игры; отдельного типа «слово из ассета» нет намеренно.
///
/// Контракт ошибок тот же, что у кодека Лейтнера (`leitner_codec.dart`):
/// битая запись — [Err] с id слова, без исключений, без `as`/`.cast()` на
/// данных из JSON, единственный `catch` — `FormatException` из `jsonDecode`.
///
/// Здесь проверяется только форма: наличие и типы полей. Содержание —
/// закрытый набор `part_of_speech`, ровно три дистрактора, кириллица,
/// уникальность id — валидируют контент-тесты
/// `test/assets/words_seed_test.dart` на самом ассете: это свойства
/// конкретного сида, а не формата.
library;

import 'dart:convert';

import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';

/// Версия формата сида. Другая версия — [Err]: читать её некому.
const int _formatVersion = 1;

/// JSON сида → единицы показа в порядке записей; битые данные — [Err].
Result<List<ReviewItem>> parseWordsSeed(String json) {
  final Object? root;
  try {
    root = jsonDecode(json);
  } on FormatException catch (e) {
    return Err(Failure('сид слов: невалидный JSON: ${e.message}'));
  }
  if (root is! Map<String, Object?>) {
    return const Err(Failure('сид слов: корень не объект'));
  }
  if (root['version'] != _formatVersion) {
    return Err(
      Failure('сид слов: неизвестная версия формата ${root['version']}'),
    );
  }
  final rawWords = root['words'];
  if (rawWords is! List<Object?>) {
    return const Err(Failure('сид слов: поле words отсутствует или не список'));
  }
  final items = <ReviewItem>[];
  for (final (index, raw) in rawWords.indexed) {
    switch (_parseItem(index, raw)) {
      case Ok(:final value):
        items.add(value);
      case Err(:final failure):
        return Err(failure);
    }
  }
  return Ok(items);
}

/// Одна запись сида → [ReviewItem]. В сообщении об ошибке — id записи,
/// а если его нет или он битый — порядковый номер.
Result<ReviewItem> _parseItem(int index, Object? raw) {
  if (raw is! Map<String, Object?>) {
    return Err(Failure('сид слов: запись #$index не объект'));
  }
  final id = _nonEmptyString(raw['id']);
  if (id == null) {
    return Err(
      Failure('сид слов: запись #$index: id отсутствует или не строка'),
    );
  }
  final text = _nonEmptyString(raw['text']);
  if (text == null) {
    return Err(Failure('сид слов: слово "$id": text отсутствует или пуст'));
  }
  final translation = _nonEmptyString(raw['translation']);
  if (translation == null) {
    return Err(
      Failure('сид слов: слово "$id": translation отсутствует или пуст'),
    );
  }
  final partOfSpeech = raw['part_of_speech'];
  if (partOfSpeech is! String?) {
    return Err(
      Failure('сид слов: слово "$id": part_of_speech не строка: $partOfSpeech'),
    );
  }
  final rawDistractors = raw['distractors'];
  if (rawDistractors is! List<Object?>) {
    return Err(
      Failure('сид слов: слово "$id": distractors отсутствует или не список'),
    );
  }
  final distractors = <String>[];
  for (final distractor in rawDistractors) {
    if (distractor is! String) {
      return Err(
        Failure('сид слов: слово "$id": дистрактор не строка: $distractor'),
      );
    }
    distractors.add(distractor);
  }
  return Ok(
    ReviewItem(
      word: Word(
        id: id,
        text: text,
        translation: translation,
        partOfSpeech: partOfSpeech,
      ),
      distractors: distractors,
    ),
  );
}

/// Непустая строка или `null`, если поля нет, оно не строка или пустое.
String? _nonEmptyString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
