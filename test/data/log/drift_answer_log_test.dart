// Журнал ответов на настоящем sqlite: запись, чтение и две запросные модели.
//
// `test()`, а не `testWidgets()`, и без `ensureInitialized()` намеренно —
// весь смысл в том, что хранилищу истории Flutter-рантайм не нужен, и
// проверяется оно как чистый Dart. Это же был вопрос спайка Этапа 2.3.
//
// Первый тест — канарейка. Он ничего не утверждает о нашем коде и стоит
// здесь ровно для того, чтобы на чужой машине отличить «журнал сломан» от
// «sqlite не нашёлся»: без него оба случая выглядят как груда красных тестов
// про перевод строк. Тегом `golden` не помечен и в отдельный скрипт не
// вынесен — ответ «sqlite не приехал» нужен на каждом прогоне.

import 'package:arcadelingo/data/log/answer_database.dart';
import 'package:arcadelingo/data/log/drift_answer_log.dart';
import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/sqlite_for_tests.dart';

final DateTime _t0 = DateTime.utc(2026, 8, 25, 10);

AnswerRecord _record({
  String wordId = 'w01',
  DateTime? at,
  StreakDay? day,
  ReviewGrade grade = ReviewGrade.good,
  bool correct = true,
  Duration responseTime = const Duration(seconds: 2),
  Duration timeLimit = const Duration(seconds: 6),
  int hintsUsed = 0,
  String gameId = 'falling_words',
  String sessionId = 'сессия-1',
}) {
  final moment = at ?? _t0;
  return AnswerRecord(
    wordId: wordId,
    at: moment,
    localDay: day ?? StreakDay.of(moment),
    grade: grade,
    correct: correct,
    responseTime: responseTime,
    timeLimit: timeLimit,
    hintsUsed: hintsUsed,
    gameId: gameId,
    sessionId: sessionId,
  );
}

void main() {
  setUpAll(useTestSqlite);

  late AnswerDatabase db;
  late DriftAnswerLog log;

  setUp(() {
    db = AnswerDatabase(NativeDatabase.memory());
    log = DriftAnswerLog(db);
  });

  tearDown(() => db.close());

  test('канарейка: sqlite на месте и таблица создаётся', () async {
    final rows = await db.select(db.answers).get();

    expect(
      rows,
      isEmpty,
      reason: 'если тут не пусто, а красно — sqlite не тот',
    );
  });

  group('Запись и чтение', () {
    test('строка возвращается той же записью', () async {
      final record = _record(
        wordId: 'w07',
        grade: ReviewGrade.easy,
        correct: false,
        responseTime: const Duration(milliseconds: 4321),
        timeLimit: const Duration(seconds: 5),
        hintsUsed: 2,
        gameId: 'ninja_slash',
        sessionId: 'сессия-42',
      );

      await log.append(record);

      expect(await log.all(), [record]);
    });

    test('микросекунды момента переживают запись', () async {
      final precise = DateTime.utc(2026, 8, 25, 10, 0, 0, 123, 456);

      await log.append(_record(at: precise));

      final read = (await log.all()).single.at;
      expect(read.microsecondsSinceEpoch, precise.microsecondsSinceEpoch);
    });

    // Момент один, зона у него — свойство смотрящего. Прочитанный из
    // хранилища всегда UTC: колонка хранит микросекунды с эпохи, а зону
    // записать в неё нечем.
    test('прочитанный момент — в UTC и тот же самый', () async {
      final local = DateTime(2026, 8, 25, 10);

      await log.append(_record(at: local, day: StreakDay(2026, 8, 25)));

      final read = (await log.all()).single.at;
      expect(read.isUtc, isTrue);
      expect(read.isAtSameMomentAs(local), isTrue);
    });

    // День записан отдельной колонкой и из момента не пересчитывается —
    // иначе локальная полночь превращалась бы во вчера. Мутация «считать
    // день из atUtcMicros» краснеет здесь и только здесь.
    test('день хранится сам по себе, а не выводится из момента', () async {
      await log.append(
        _record(at: DateTime.utc(2026, 8, 25, 21), day: StreakDay(2026, 8, 26)),
      );

      expect((await log.all()).single.localDay, StreakDay(2026, 8, 26));
    });

    // Все четыре значения в одной БД, по слову на каждое: четыре
    // отдельные базы дали бы то же самое плюс предупреждение drift о
    // нескольких открытых экземплярах, то есть шум без пользы.
    test('оценки возвращаются теми же значениями перечисления', () async {
      for (final (index, grade) in ReviewGrade.values.indexed) {
        await log.append(
          _record(wordId: 'w0$index', grade: grade, at: _t0.add(_min(index))),
        );
      }

      expect((await log.all()).map((r) => r.grade), ReviewGrade.values);
    });

    test('журнал только дописывается: прошлые строки на месте', () async {
      await log.append(_record(wordId: 'w01', grade: ReviewGrade.again));
      await log.append(
        _record(wordId: 'w01', grade: ReviewGrade.good, at: _t0.add(_min(1))),
      );

      final all = await log.all();
      expect(all, hasLength(2));
      expect(all.map((r) => r.grade), [ReviewGrade.again, ReviewGrade.good]);
    });
  });

  group('Порядок', () {
    test(
      'всё читается в хронологическом порядке, а не в порядке записи',
      () async {
        await log.append(_record(wordId: 'w03', at: _t0.add(_min(30))));
        await log.append(_record(wordId: 'w01', at: _t0));
        await log.append(_record(wordId: 'w02', at: _t0.add(_min(10))));

        expect((await log.all()).map((r) => r.wordId), ['w01', 'w02', 'w03']);
      },
    );

    // На живых часах невозможно, на подставленных — обычное дело: партия в
    // тесте идёт на одном моменте. Порядок обязан остаться тем, в котором
    // отвечали, иначе переигровка получит не ту историю.
    test('при равных моментах — в порядке записи', () async {
      await log.append(_record(wordId: 'w03'));
      await log.append(_record(wordId: 'w01'));
      await log.append(_record(wordId: 'w02'));

      expect((await log.all()).map((r) => r.wordId), ['w03', 'w01', 'w02']);
    });
  });

  group('История одного слова', () {
    test('только это слово, в хронологическом порядке', () async {
      await log.append(_record(wordId: 'w02', at: _t0));
      await log.append(_record(wordId: 'w01', at: _t0.add(_min(5))));
      await log.append(_record(wordId: 'w01', at: _t0.add(_min(1))));

      final history = await log.forWord('w01');
      expect(history, hasLength(2));
      expect(history.map((r) => r.at), [_t0.add(_min(1)), _t0.add(_min(5))]);
    });

    test('неизвестное слово — пусто, а не ошибка', () async {
      await log.append(_record(wordId: 'w01'));

      expect(await log.forWord('w99'), isEmpty);
    });
  });

  group('Сводка по дням', () {
    Future<void> answer(StreakDay day, {required bool correct}) => log.append(
      _record(
        at: DateTime.utc(day.year, day.month, day.day, 12),
        day: day,
        correct: correct,
      ),
    );

    test('считает ответы и верные отдельно', () async {
      final day = StreakDay(2026, 8, 25);
      await answer(day, correct: true);
      await answer(day, correct: false);
      await answer(day, correct: true);

      expect(await log.perDay(from: day, to: day), [
        DayTally(day: day, answers: 3, correct: 2),
      ]);
    });

    test('дни без ответов в результат не попадают', () async {
      await answer(StreakDay(2026, 8, 25), correct: true);
      await answer(StreakDay(2026, 8, 27), correct: false);

      final tally = await log.perDay(
        from: StreakDay(2026, 8, 24),
        to: StreakDay(2026, 8, 28),
      );

      expect(tally.map((t) => t.day), [
        StreakDay(2026, 8, 25),
        StreakDay(2026, 8, 27),
      ]);
    });

    test('границы отрезка включаются', () async {
      await answer(StreakDay(2026, 8, 24), correct: true);
      await answer(StreakDay(2026, 8, 25), correct: true);
      await answer(StreakDay(2026, 8, 26), correct: true);

      final tally = await log.perDay(
        from: StreakDay(2026, 8, 25),
        to: StreakDay(2026, 8, 26),
      );

      expect(tally.map((t) => t.day), [
        StreakDay(2026, 8, 25),
        StreakDay(2026, 8, 26),
      ]);
    });

    test('за отрезок ничего не отвечали — пустой список', () async {
      await answer(StreakDay(2026, 8, 25), correct: true);

      expect(
        await log.perDay(
          from: StreakDay(2026, 9, 1),
          to: StreakDay(2026, 9, 30),
        ),
        isEmpty,
      );
    });

    // Отрезок выбирается лексикографическим сравнением строк `ГГГГ-ММ-ДД`.
    // Оно совпадает с календарным только при ведущих нулях — вот проверка
    // того, что нули на месте: без них '2026-9-1' попал бы левее '2026-10-1'.
    test('месяцы и дни с ведущим нулём не путают порядок', () async {
      await answer(StreakDay(2026, 9, 1), correct: true);
      await answer(StreakDay(2026, 10, 1), correct: true);

      final tally = await log.perDay(
        from: StreakDay(2026, 9, 15),
        to: StreakDay(2026, 12, 31),
      );

      expect(tally.map((t) => t.day), [StreakDay(2026, 10, 1)]);
    });

    test('дни идут по возрастанию', () async {
      await answer(StreakDay(2026, 8, 27), correct: true);
      await answer(StreakDay(2026, 8, 25), correct: true);
      await answer(StreakDay(2026, 8, 26), correct: true);

      final tally = await log.perDay(
        from: StreakDay(2026, 8, 1),
        to: StreakDay(2026, 8, 31),
      );

      expect(tally.map((t) => t.day.day), [25, 26, 27]);
    });
  });
}

Duration _min(int minutes) => Duration(minutes: minutes);
