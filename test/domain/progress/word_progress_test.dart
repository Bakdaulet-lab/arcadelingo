// Группы слов: во что превращаются коробки Лейтнера на экране прогресса.
//
// Границы — из SPEC, и проверяются обе стороны каждой. Толкование тут не
// косметическое: коробка 1 значит «слово не даётся», коробка 5 — «человек
// его помнит», и сдвиг границы на единицу меняет то, что человек про себя
// узнаёт.

import 'package:arcadelingo/domain/progress/word_progress.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _due = DateTime.utc(2026, 9, 1);

LeitnerCard _card(int box) => LeitnerCard(box: box, due: _due);

Map<String, LeitnerCard> _cards(List<int> boxes) => {
  for (final (index, box) in boxes.indexed) 'w$index': _card(box),
};

void main() {
  group('Группа по коробке', () {
    test('коробка 1 — трудное', () {
      expect(stageOf(_card(1)), WordStage.hard);
    });

    test('обе стороны границы 1/2', () {
      expect(stageOf(_card(1)), WordStage.hard);
      expect(stageOf(_card(2)), WordStage.learning);
    });

    test('обе стороны границы 4/5', () {
      expect(stageOf(_card(4)), WordStage.learning);
      expect(stageOf(_card(5)), WordStage.learned);
    });

    test('вся середина — в работе', () {
      for (final box in [2, 3, 4]) {
        expect(stageOf(_card(box)), WordStage.learning, reason: 'коробка $box');
      }
    });
  });

  group('Подсчёт', () {
    test('пустая карта — три нуля', () {
      expect(countWords(const {}), WordCounts.empty);
      expect(countWords(const {}).total, 0);
    });

    test('все три группы разом', () {
      final counts = countWords(_cards([1, 1, 2, 3, 4, 5, 5, 5]));

      expect(counts.hard, 2);
      expect(counts.learning, 3);
      expect(counts.learned, 3);
      expect(counts.total, 8);
    });

    // Слово, которого нет в карте, не показывали ни разу, и прогресса по
    // нему нет: подсчёт идёт по карточкам, а не по сиду.
    test('считаются карточки, а не слова сида', () {
      expect(countWords(_cards([5])).total, 1);
    });

    test('равенство по полям', () {
      expect(countWords(_cards([1, 5])), countWords(_cards([5, 1])));
      expect(
        countWords(_cards([1, 5])).hashCode,
        countWords(_cards([5, 1])).hashCode,
      );
      expect(countWords(_cards([1])), isNot(countWords(_cards([5]))));
    });
  });

  group('Доля верных', () {
    test('целочисленное деление, а не округление вверх', () {
      // 2 из 3 — это 66%, а не 67: делим, а не округляем.
      expect(accuracyPercent(answers: 3, correct: 2), 66);
    });

    test('все верные — сто', () {
      expect(accuracyPercent(answers: 7, correct: 7), 100);
    });

    test('ни одного верного — ноль, и это правда', () {
      expect(accuracyPercent(answers: 4, correct: 0), 0);
    });

    // «0%» означает «всё неверно». Показывать это тому, кто ещё не играл, —
    // враньё, поэтому доли нет вовсе.
    test('ответов не было — доли нет', () {
      expect(accuracyPercent(answers: 0, correct: 0), isNull);
    });

    test('половина — пятьдесят', () {
      expect(accuracyPercent(answers: 200, correct: 100), 50);
    });
  });
}
