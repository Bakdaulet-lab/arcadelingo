// Слова, на которых гоняются тесты игры.
//
// Один набор на всех, потому что копий уже три: два теста «падающих слов» и
// голдены. Разъехавшиеся фикстуры — это когда голден показывает одно слово, а
// упавший рядом виджет-тест говорит про другое, и человек сверяет картинку с
// текстом ошибки вручную.
//
// Тексты уникальны по слову и по обманке намеренно: так «нажали не ту кнопку»
// видно прямо в сообщении теста, а не угадывается по индексу.

import 'package:arcadelingo/domain/review/review_contract.dart';

/// id слова по номеру: w01, w02, … Он же текст падающего слова.
String wordId(int i) => 'w${i.toString().padLeft(2, '0')}';

/// Верный вариант слова [i].
String wordTranslation(int i) => 'перевод ${wordId(i)}';

/// Обманка номер [d] у слова [i].
String wordDistractor(int i, int d) => 'обманка $d к ${wordId(i)}';

/// Слово с [distractors] обманками.
ReviewItem wordItem(int i, {int distractors = 3}) => ReviewItem(
  word: Word(id: wordId(i), text: wordId(i), translation: wordTranslation(i)),
  distractors: [for (var d = 1; d <= distractors; d++) wordDistractor(i, d)],
);

/// Сид из [n] слов по три обманки.
List<ReviewItem> wordItems(int n) => [for (var i = 1; i <= n; i++) wordItem(i)];
