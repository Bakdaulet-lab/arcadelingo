// Переигровка журнала: чистая функция, без хранилища.
//
// Здесь проверяется только арифметика восстановления — что журнал полон и
// что он согласован с настоящей сессией, доказывает отдельный тест через
// живую БД (`test/data/log/replay_through_storage_test.dart`).
//
// Ожидаемые значения посчитаны по таблице Лейтнера руками, а не вызовом
// schedule() в тесте: тест, который считает тем же кодом, что и реализация,
// подтвердит любую ошибку в нём.

import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/log/replay.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _t0 = DateTime.utc(2026, 8, 25, 10);

AnswerRecord _record(
  String wordId,
  ReviewGrade grade, {
  DateTime? at,
  bool? correct,
}) {
  final moment = at ?? _t0;
  return AnswerRecord(
    wordId: wordId,
    at: moment,
    localDay: StreakDay.of(moment),
    grade: grade,
    correct: correct ?? grade != ReviewGrade.again,
    responseTime: const Duration(seconds: 2),
    timeLimit: const Duration(seconds: 6),
    hintsUsed: 0,
    gameId: 'falling_words',
    sessionId: 'сессия-1',
  );
}

void main() {
  test('пустой журнал — пустое состояние', () {
    expect(replayCards(const []), isEmpty);
  });

  group('Новое слово', () {
    test('good из первой коробки — вторая, срок через сутки', () {
      final cards = replayCards([_record('w01', ReviewGrade.good)]);

      expect(cards['w01'], LeitnerCard(box: 2, due: _t0.add(_day(1))));
    });

    test('easy из первой — третья, срок через три дня', () {
      final cards = replayCards([_record('w01', ReviewGrade.easy)]);

      expect(cards['w01'], LeitnerCard(box: 3, due: _t0.add(_day(3))));
    });

    test('again — первая коробка со сроком «сейчас»', () {
      final cards = replayCards([_record('w01', ReviewGrade.again)]);

      expect(cards['w01'], LeitnerCard(box: 1, due: _t0));
    });

    test('hard на новом слове — та же первая, срок «сейчас»', () {
      final cards = replayCards([_record('w01', ReviewGrade.hard)]);

      expect(cards['w01'], LeitnerCard(box: 1, due: _t0));
    });
  });

  group('Порядок ответов', () {
    // Лейтнер не коммутативен: одни и те же оценки в разном порядке дают
    // разные коробки. Мутация «отсортировать журнал по слову» или «читать с
    // конца» ломается ровно здесь.
    test('easy потом again — первая коробка', () {
      final later = _t0.add(_day(5));
      final cards = replayCards([
        _record('w01', ReviewGrade.easy),
        _record('w01', ReviewGrade.again, at: later),
      ]);

      expect(cards['w01'], LeitnerCard(box: 1, due: later));
    });

    test('again потом easy — третья коробка', () {
      final later = _t0.add(_day(5));
      final cards = replayCards([
        _record('w01', ReviewGrade.again),
        _record('w01', ReviewGrade.easy, at: later),
      ]);

      expect(cards['w01'], LeitnerCard(box: 3, due: later.add(_day(3))));
    });

    test('серия good поднимает по одной коробке за ответ', () {
      final at1 = _t0;
      final at2 = _t0.add(_day(1));
      final at3 = _t0.add(_day(4));
      final at4 = _t0.add(_day(11));

      final cards = replayCards([
        _record('w01', ReviewGrade.good, at: at1),
        _record('w01', ReviewGrade.good, at: at2),
        _record('w01', ReviewGrade.good, at: at3),
        _record('w01', ReviewGrade.good, at: at4),
      ]);

      expect(cards['w01'], LeitnerCard(box: 5, due: at4.add(_day(21))));
    });

    test('потолок пятой коробки держится', () {
      final at2 = _t0.add(_day(30));
      final cards = replayCards([
        _record('w01', ReviewGrade.easy),
        _record('w01', ReviewGrade.easy, at: at2),
        _record('w01', ReviewGrade.easy, at: at2.add(_day(30))),
      ]);

      expect(cards['w01']!.box, LeitnerCard.maxBox);
    });
  });

  group('Слова независимы', () {
    test('ответ по одному слову не трогает другое', () {
      final cards = replayCards([
        _record('w01', ReviewGrade.easy),
        _record('w02', ReviewGrade.again),
      ]);

      expect(cards['w01'], LeitnerCard(box: 3, due: _t0.add(_day(3))));
      expect(cards['w02'], LeitnerCard(box: 1, due: _t0));
      expect(cards, hasLength(2));
    });

    test('слово без ответов в карте не появляется', () {
      final cards = replayCards([_record('w01', ReviewGrade.good)]);

      expect(cards.containsKey('w02'), isFalse);
    });
  });

  group('Время берётся из записи', () {
    // Мутация «считать от одного момента для всех записей» краснеет здесь:
    // два ответа по разным словам в разные дни дают разные сроки.
    test('срок отсчитывается от момента своего ответа', () {
      final late = _t0.add(_day(10));
      final cards = replayCards([
        _record('w01', ReviewGrade.good),
        _record('w02', ReviewGrade.good, at: late),
      ]);

      expect(cards['w01']!.due, _t0.add(_day(1)));
      expect(cards['w02']!.due, late.add(_day(1)));
    });

    test('микросекунды момента доезжают до срока', () {
      final precise = DateTime.utc(2026, 8, 25, 10, 0, 0, 123, 456);
      final cards = replayCards([
        _record('w01', ReviewGrade.good, at: precise),
      ]);

      expect(cards['w01']!.due, precise.add(_day(1)));
    });
  });
}

Duration _day(int days) => Duration(days: days);
