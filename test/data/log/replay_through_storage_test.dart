// Главный проверяемый результат Этапа 2.3: переигровка.
//
// Партия играется по-настоящему — через `StartSession`, живую
// `LeitnerReviewSession` и журнал на настоящем sqlite. Потом журнал
// вычитывается из БД и прогоняется через `replayCards` с чистого состояния.
// Совпадение карт доказывает сразу две вещи, и ни одну из них нельзя
// доказать по отдельности дешевле:
//
//   1. журнал полон — ни один `report()` не потерян, иначе карта не сойдётся;
//   2. журнал согласован с расписанием — в нём лежат те самые оценки в том
//      самом порядке, на которых стоит планировщик, а не похожие данные.
//
// Ровно этот тест с `sm2.schedule` вместо `schedule` станет инструментом
// оценки SM-2: прогнать прожитую историю через нового планировщика и
// посмотреть, где он разойдётся.
//
// Часы подставленные и шагают вручную между ответами. Это не удобство:
// сессия берёт `now()` для расписания, наблюдатель — для события, и это два
// разных вызова. На живых часах между ними проходят микросекунды, и `due`
// разошёлся бы на столько же — коробка при этом та же самая всегда. Предел
// записан в `domain/log/replay.dart` и в `docs/dev/context.md`.

import 'package:arcadelingo/data/log/answer_database.dart';
import 'package:arcadelingo/data/log/drift_answer_log.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/log/replay.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/domain/usecases/start_session.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_stores.dart';
import '../../support/review_items.dart';
import '../../support/sqlite_for_tests.dart';

/// Часы, которые стоят на месте, пока их не двинут.
///
/// Внутри одного `report()` оба чтения обязаны дать один момент — на этом
/// держится буквальное совпадение карт.
class _Clock {
  _Clock(this._at);

  DateTime _at;

  DateTime call() => _at;

  void advance(Duration d) => _at = _at.add(d);
}

/// Ответ, который игра доложила бы: верный и быстрый, верный и медленный,
/// неверный. Разные оценки нужны, чтобы переигровка проходила по всем
/// ветвям таблицы Лейтнера, а не по одной.
ReviewOutcome _fast() => const ReviewOutcome(
  correct: true,
  responseTime: Duration(seconds: 1),
  timeLimit: Duration(seconds: 6),
);

ReviewOutcome _slow() => const ReviewOutcome(
  correct: true,
  responseTime: Duration(milliseconds: 5000),
  timeLimit: Duration(seconds: 6),
);

ReviewOutcome _wrong() => const ReviewOutcome(
  correct: false,
  responseTime: Duration(seconds: 3),
  timeLimit: Duration(seconds: 6),
);

void main() {
  setUpAll(useTestSqlite);

  late AnswerDatabase db;
  late DriftAnswerLog log;
  late InMemoryCardStore cards;
  late InMemoryStreakStore streaks;

  setUp(() {
    db = AnswerDatabase(NativeDatabase.memory());
    log = DriftAnswerLog(db);
    cards = InMemoryCardStore();
    streaks = InMemoryStreakStore();
  });

  tearDown(() => db.close());

  /// Играет партию целиком, чередуя исходы. Возвращает число ответов.
  int playRound(_Clock clock, {int words = 8}) {
    final started = StartSession(
      cards: cards,
      streaks: streaks,
      now: clock.call,
      target: 15,
      answerLog: log,
    )(items: wordItems(words), gameId: 'falling_words');
    final session = (started as Ok<ReviewSession>).value;

    var answered = 0;
    while (true) {
      final item = session.nextItem();
      if (item == null) break;
      // Чередование по счётчику, а не случайно: тест обязан быть
      // воспроизводимым, а Random без seed запрещён и в тестах тоже.
      final outcome = switch (answered % 3) {
        0 => _fast(),
        1 => _wrong(),
        _ => _slow(),
      };
      session.report(outcome);
      answered++;
      // Между ответами время идёт — внутри одного не идёт.
      clock.advance(const Duration(seconds: 7));
    }
    return answered;
  }

  test('журнал, переигранный с нуля, даёт то же состояние карточек', () async {
    final clock = _Clock(DateTime.utc(2026, 8, 25, 10));

    final answered = playRound(clock);
    expect(answered, greaterThan(0), reason: 'партия обязана быть непустой');

    await pumpEventQueue();
    final replayed = replayCards(await log.all());
    final saved = (cards.load() as Ok<Map<String, LeitnerCard>>).value;

    expect(saved, isNotEmpty);
    expect(replayed, saved);
  });

  test('несколько партий подряд переигрываются так же', () async {
    final clock = _Clock(DateTime.utc(2026, 8, 25, 10));

    var answered = playRound(clock);
    clock.advance(const Duration(days: 1));
    answered += playRound(clock);
    clock.advance(const Duration(days: 3));
    answered += playRound(clock);

    expect(answered, greaterThan(8), reason: 'три партии, а не одна пустая');

    await pumpEventQueue();
    final replayed = replayCards(await log.all());
    final saved = (cards.load() as Ok<Map<String, LeitnerCard>>).value;

    expect(replayed, saved);
  });

  test('в журнале ровно столько строк, сколько было ответов', () async {
    final clock = _Clock(DateTime.utc(2026, 8, 25, 10));

    final answered = playRound(clock);

    await pumpEventQueue();
    expect(await log.all(), hasLength(answered));
  });

  test('повтор слова в одной партии — две строки, не одна', () async {
    final clock = _Clock(DateTime.utc(2026, 8, 25, 10));

    playRound(clock);

    await pumpEventQueue();
    final byWord = <String, int>{};
    for (final record in await log.all()) {
      byWord[record.wordId] = (byWord[record.wordId] ?? 0) + 1;
    }

    expect(
      byWord.values.any((count) => count > 1),
      isTrue,
      reason:
          'промах возвращает слово в ту же партию, и второй ответ по нему — '
          'отдельная строка истории',
    );
  });

  test('все строки партии несут её sessionId и id игры', () async {
    final clock = _Clock(DateTime.utc(2026, 8, 25, 10));

    playRound(clock);

    await pumpEventQueue();
    final all = await log.all();
    expect(all.map((r) => r.sessionId).toSet(), hasLength(1));
    expect(all.map((r) => r.gameId).toSet(), {'falling_words'});
  });

  // Проверка-здоровье, а не вывод: серия остаётся собственным состоянием
  // (заморозка Фазы 3 из журнала не выводится). Но противоречить журналу она
  // не имеет права — длиннее, чем было дней с ответами, серия быть не может.
  test('серия не длиннее числа дней с ответами в журнале', () async {
    final clock = _Clock(DateTime.utc(2026, 8, 25, 10));

    playRound(clock);
    clock.advance(const Duration(days: 1));
    playRound(clock);
    clock.advance(const Duration(days: 1));
    playRound(clock);

    await pumpEventQueue();
    final days = <StreakDay>{for (final r in await log.all()) r.localDay};

    expect(days, hasLength(3));
    expect(streaks.state.current, lessThanOrEqualTo(days.length));
    expect(streaks.state.current, 3, reason: 'три дня подряд — серия из трёх');
  });

  test('сводка по дням совпадает с тем, что записано', () async {
    final clock = _Clock(DateTime.utc(2026, 8, 25, 10));

    final first = playRound(clock);
    clock.advance(const Duration(days: 1));
    final second = playRound(clock);

    await pumpEventQueue();
    final tally = await log.perDay(
      from: StreakDay(2026, 8, 25),
      to: StreakDay(2026, 8, 26),
    );

    expect(tally.map((t) => t.answers), [first, second]);
    expect(tally.map((t) => t.day), [
      StreakDay(2026, 8, 25),
      StreakDay(2026, 8, 26),
    ]);
  });
}
