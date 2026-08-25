// Ход партии в ниндзя-слэш без дерева виджетов: протокол с ядром, жизни,
// комбо, время полёта, состав волны.
//
// Здесь проверяется всё, для чего не нужны кадры и рисование, — и только
// это. Сам полёт, жест, пауза при сворачивании и «один report() на вторую
// точку того же свайпа» живут в тестах виджета: там нужен tester.pump.
//
// Файл — зеркало falling_words_run_test.dart: те же семь групп, числа
// полёта вместо чисел падения. Зеркало, а не общий помощник: игры —
// острова (правило 5).
//
// Литералы, а не константы из lib/: тест обязан быть независимой сверкой
// со SPEC.md, иначе переименованная константа подтвердит сама себя.

import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';
import '../../../support/review_items.dart';

/// Партия на [session]: первая волна уже поднята.
NinjaRun _started(ReviewSession session, {int seed = 1}) =>
    NinjaRun(session: session, random: Random(seed))..start();

/// Индекс заведомо неверного объекта.
int _wrongIndex(NinjaRun run) => run.correctIndex == 0 ? 1 : 0;

/// Верный рез за [elapsed] и промотанная подсветка.
void _correct(NinjaRun run, [Duration elapsed = const Duration(seconds: 1)]) {
  run.slice(run.correctIndex, elapsed);
  run.advance();
}

/// Промах за [elapsed] и промотанная подсветка.
void _miss(NinjaRun run, [Duration elapsed = const Duration(seconds: 1)]) {
  run.slice(_wrongIndex(run), elapsed);
  run.advance();
}

void main() {
  group('Протокол с сессией', () {
    test('start() → одно слово запрошено, докладов нет', () {
      final session = FakeReviewSession(wordItems(3));

      final run = _started(session);

      expect(run.phase, NinjaPhase.flying);
      expect(run.item!.word.id, 'w01');
      expect(session.nextItemCalls, 1);
      expect(session.reports, isEmpty, reason: 'волна поднята — ещё не ответ');
    });

    test('верный рез → ровно один report(correct: true)', () {
      final session = FakeReviewSession(wordItems(3));
      final run = _started(session);

      final accepted = run.slice(run.correctIndex, const Duration(seconds: 2));

      expect(accepted, isTrue);
      expect(session.reports, hasLength(1));
      final outcome = session.reports.single.outcome;
      expect(outcome.correct, isTrue);
      expect(outcome.responseTime, const Duration(seconds: 2));
      expect(outcome.timeLimit, const Duration(milliseconds: 3500));
      expect(outcome.hintsUsed, 0, reason: 'подсказок в этой игре нет');
      expect(run.phase, NinjaPhase.reveal);
      expect(run.verdict, Verdict.correct);
      expect(run.slicedIndex, run.correctIndex);
      expect(
        session.nextItemCalls,
        1,
        reason: 'следующее слово берётся только в advance()',
      );
    });

    test('неверный рез → report(correct: false), подсветка 800 мс', () {
      final session = FakeReviewSession(wordItems(3));
      final run = _started(session);

      run.slice(_wrongIndex(run), const Duration(seconds: 2));

      expect(session.reports.single.outcome.correct, isFalse);
      expect(
        session.reports.single.outcome.responseTime,
        const Duration(seconds: 2),
        reason: 'разрезали не то быстро — это не таймаут',
      );
      expect(run.verdict, Verdict.wrong);
      expect(run.revealTime, const Duration(milliseconds: 800));
    });

    test('верный рез разлетается 300 мс', () {
      final run = _started(FakeReviewSession(wordItems(3)));

      run.slice(run.correctIndex, const Duration(seconds: 2));

      expect(run.revealTime, const Duration(milliseconds: 300));
    });

    test('advance() → следующее слово, фаза полёта', () {
      final session = FakeReviewSession(wordItems(3));
      final run = _started(session);

      _correct(run);

      expect(run.phase, NinjaPhase.flying);
      expect(run.item!.word.id, 'w02');
      expect(session.nextItemCalls, 2);
    });

    test('slice() в фазе подсветки → false, второго доклада нет', () {
      final session = FakeReviewSession(wordItems(3));
      final run = _started(session);

      run.slice(run.correctIndex, const Duration(seconds: 2));
      final second = run.slice(_wrongIndex(run), const Duration(seconds: 3));

      expect(second, isFalse, reason: 'страж «ровно один report() на слово»');
      expect(session.reports, hasLength(1));
    });

    test('timeout() в фазе подсветки → false, второго доклада нет', () {
      final session = FakeReviewSession(wordItems(3));
      final run = _started(session);

      run.slice(run.correctIndex, const Duration(seconds: 2));

      expect(run.timeout(), isFalse);
      expect(session.reports, hasLength(1));
    });

    test('сессия не дала ни одного слова → «на сегодня всё», без докладов', () {
      final session = FakeReviewSession(const []);

      final run = _started(session);

      expect(run.phase, NinjaPhase.nothingToday);
      expect(run.item, isNull);
      expect(session.nextItemCalls, 1);
      expect(session.reports, isEmpty);
    });

    test('слова кончились → итоги, лишних докладов нет', () {
      final session = FakeReviewSession(wordItems(2));
      final run = _started(session);

      _correct(run);
      _correct(run);

      expect(run.phase, NinjaPhase.over);
      expect(session.reports, hasLength(2));
      expect(session.nextItemCalls, 3, reason: 'третий вызов вернул null');
    });

    test('выход в фазе полёта → доложен неответ за прожитое время', () {
      final session = FakeReviewSession(wordItems(3));
      final run = _started(session);

      run.abandon(const Duration(seconds: 2));

      expect(session.reports, hasLength(1));
      expect(session.reports.single.outcome.correct, isFalse);
      expect(
        session.reports.single.outcome.responseTime,
        const Duration(seconds: 2),
        reason: 'game-contract: либо доложи неответ, либо не бери item',
      );
      expect(run.phase, NinjaPhase.over);
    });

    test('выход вне фазы полёта → ничего не докладывается', () {
      final session = FakeReviewSession(wordItems(3));
      final run = _started(session);

      run.slice(run.correctIndex, const Duration(seconds: 2));
      run.abandon(const Duration(seconds: 1));

      expect(session.reports, hasLength(1), reason: 'ответ уже доложен');

      run.advance();
      run.abandon(const Duration(seconds: 1));
      run.abandon(const Duration(seconds: 1));

      expect(session.reports, hasLength(2), reason: 'второй выход — не доклад');
    });
  });

  group('Время полёта', () {
    test('первая волна летит 3.5 секунды', () {
      final run = _started(FakeReviewSession(wordItems(3)));

      expect(run.timeLimit, const Duration(milliseconds: 3500));
    });

    test('каждый уровень комбо снимает 0.2 с', () {
      final run = _started(FakeReviewSession(wordItems(5)));

      _correct(run);
      expect(run.timeLimit, const Duration(milliseconds: 3300));

      _correct(run);
      expect(run.timeLimit, const Duration(milliseconds: 3100));

      _correct(run);
      expect(run.timeLimit, const Duration(milliseconds: 2900));
    });

    test('быстрее 2 секунд волна не летит', () {
      final run = _started(FakeReviewSession(wordItems(20)));

      for (var i = 0; i < 7; i++) {
        _correct(run);
      }
      expect(
        run.timeLimit,
        const Duration(milliseconds: 2100),
        reason: '3.5 − 7 × 0.2',
      );

      _correct(run);
      expect(
        run.timeLimit,
        const Duration(seconds: 2),
        reason: '3.5 − 8 × 0.2 = 1.9, но пол держит',
      );

      _correct(run);
      expect(run.timeLimit, const Duration(seconds: 2), reason: 'пол держится');
    });

    test('промах сбрасывает комбо, лимит возвращается к 3.5 с', () {
      final run = _started(FakeReviewSession(wordItems(5)));

      _correct(run);
      _correct(run);
      _miss(run);

      expect(run.combo, 0);
      expect(run.timeLimit, const Duration(milliseconds: 3500));
    });

    test('таймаут → responseTime равен лимиту этой волны', () {
      final session = FakeReviewSession(wordItems(3));
      final run = _started(session);

      _correct(run);
      final accepted = run.timeout();

      expect(accepted, isTrue);
      final outcome = session.reports.last.outcome;
      expect(outcome.correct, isFalse);
      expect(outcome.timeLimit, const Duration(milliseconds: 3300));
      expect(outcome.responseTime, outcome.timeLimit);
      expect(run.verdict, Verdict.timeout);
      expect(run.slicedIndex, isNull, reason: 'ничего не разрезали');
      expect(
        run.revealTime,
        const Duration(milliseconds: 800),
        reason: 'таймаут — это промах',
      );
    });
  });

  group('Жизни', () {
    test('партия начинается с трёх жизней', () {
      final run = _started(FakeReviewSession(wordItems(3)));

      expect(run.lives, 3);
    });

    test('промах и таймаут стоят по жизни, верный рез — ничего', () {
      final run = _started(FakeReviewSession(wordItems(5)));

      _correct(run);
      expect(run.lives, 3, reason: 'верный рез жизнь не тратит');

      _miss(run);
      expect(run.lives, 2);

      run.timeout();
      run.advance();
      expect(run.lives, 1);
    });

    test('жизни кончились → итоги немедленно, новых слов не берём', () {
      final session = FakeReviewSession(wordItems(8));
      final run = _started(session);

      _miss(run);
      _miss(run);
      _miss(run);

      expect(run.phase, NinjaPhase.over);
      expect(run.lives, 0);
      expect(session.reports, hasLength(3));
      expect(
        session.nextItemCalls,
        3,
        reason: 'четвёртое слово не запрашивается',
      );
    });
  });

  group('Очки и серия', () {
    test('очки — 10 за рез, множитель растёт с серией', () {
      final run = _started(FakeReviewSession(wordItems(5)));

      _correct(run);
      expect(run.score, 10, reason: 'первый верный: множитель 1');
      expect(run.combo, 1);

      _correct(run);
      expect(run.score, 30, reason: '10 + 20');

      _correct(run);
      expect(run.score, 60, reason: '30 + 30');
    });

    test('промах сбрасывает множитель, но не счёт', () {
      final run = _started(FakeReviewSession(wordItems(5)));

      _correct(run);
      _correct(run);
      _miss(run);
      _correct(run);

      expect(run.score, 40, reason: '10 + 20, промах, снова 10');
      expect(run.combo, 1);
      expect(run.bestCombo, 2, reason: 'лучшая серия помнит максимум');
    });

    test('счётчики ответов: верные и все', () {
      final run = _started(FakeReviewSession(wordItems(5)));

      _correct(run);
      _miss(run);
      _correct(run);

      expect(run.correctCount, 2);
      expect(run.answeredCount, 3);
    });
  });

  group('Состав волны', () {
    test('три объекта: верный и две обманки из трёх', () {
      final run = _started(FakeReviewSession(wordItems(1)));

      expect(run.options, hasLength(3));
      expect(run.options[run.correctIndex], wordTranslation(1));

      final decoys = [...run.options]..removeAt(run.correctIndex);
      expect(decoys.toSet(), hasLength(2), reason: 'две разные обманки');
      for (final decoy in decoys) {
        expect(
          decoy,
          isIn([
            wordDistractor(1, 1),
            wordDistractor(1, 2),
            wordDistractor(1, 3),
          ]),
        );
      }
    });

    test('третья обманка невостребована — и не всегда одна и та же', () {
      final run = _started(FakeReviewSession(wordItems(12)));
      final unused = <String>{};

      for (var i = 1; i <= 12; i++) {
        final shown = run.options.toSet();
        for (var d = 1; d <= 3; d++) {
          if (!shown.contains(wordDistractor(i, d))) unused.add('d$d');
        }
        if (i < 12) _correct(run);
      }

      expect(
        unused,
        hasLength(greaterThan(1)),
        reason:
            'иначе третья обманка не участвует в игре никогда, и её место в '
            'контенте — отдельный вопрос',
      );
    });

    test('две обманки → три объекта', () {
      final run = _started(FakeReviewSession([wordItem(1, distractors: 2)]));

      expect(run.options, hasLength(3));
      expect(run.options[run.correctIndex], wordTranslation(1));
    });

    test('одна обманка → два объекта', () {
      final run = _started(FakeReviewSession([wordItem(1, distractors: 1)]));

      expect(run.options, hasLength(2));
      expect(run.options[run.correctIndex], wordTranslation(1));
    });

    test('обманок нет → один объект, игра не падает', () {
      final run = _started(FakeReviewSession([wordItem(1, distractors: 0)]));

      expect(
        run.options,
        [wordTranslation(1)],
        reason: 'второй объект игре взять неоткуда: выдумывать обманки нельзя',
      );
      expect(run.correctIndex, 0);
    });

    test('дубликаты среди обманок не вычищаются — это забота контента', () {
      const item = ReviewItem(
        word: Word(id: 'w01', text: 'w01', translation: 'перевод'),
        distractors: ['обманка', 'обманка'],
      );

      final run = _started(FakeReviewSession(const [item]));

      expect(run.options, hasLength(3));
      expect(run.options.where((o) => o == 'обманка'), hasLength(2));
    });

    test('одинаковый seed → одинаковый состав и порядок', () {
      final first = _started(FakeReviewSession(wordItems(1)), seed: 7);
      final second = _started(FakeReviewSession(wordItems(1)), seed: 7);

      expect(first.options, second.options);
      expect(first.correctIndex, second.correctIndex);
    });

    test('верный объект не всегда на одной дорожке', () {
      final run = _started(FakeReviewSession(wordItems(10)));
      final positions = <int>{run.correctIndex};

      for (var i = 0; i < 9; i++) {
        _correct(run);
        positions.add(run.correctIndex);
      }

      expect(
        positions.length,
        greaterThan(1),
        reason: 'иначе игрок запоминает дорожку, а не слово',
      );
    });
  });

  group('Стражи: игра не строит битый ReviewOutcome', () {
    test('отрицательное время реза → ArgumentError, доклада нет', () {
      final session = FakeReviewSession(wordItems(3));
      final run = _started(session);

      expect(
        () => run.slice(run.correctIndex, const Duration(seconds: -1)),
        throwsArgumentError,
        reason: 'domain это не сторожит: шапка grade_outcome.dart',
      );
      expect(session.reports, isEmpty);
    });

    test('время реза больше лимита → ArgumentError, доклада нет', () {
      final session = FakeReviewSession(wordItems(3));
      final run = _started(session);

      expect(
        () => run.slice(run.correctIndex, const Duration(seconds: 4)),
        throwsArgumentError,
        reason: 'дольше лимита объекты уже упали — это таймаут, не рез',
      );
      expect(session.reports, isEmpty);
    });

    test('время реза ровно по лимиту принимается', () {
      final session = FakeReviewSession(wordItems(3));
      final run = _started(session);

      run.slice(run.correctIndex, const Duration(milliseconds: 3500));

      expect(session.reports.single.outcome.responseTime, run.timeLimit);
    });

    test('индекс вне волны → ArgumentError, доклада нет', () {
      final session = FakeReviewSession(wordItems(3));
      final run = _started(session);

      expect(
        () => run.slice(3, const Duration(seconds: 1)),
        throwsArgumentError,
      );
      expect(
        () => run.slice(-1, const Duration(seconds: 1)),
        throwsArgumentError,
      );
      expect(session.reports, isEmpty);
    });

    test('отрицательное время при выходе → ArgumentError, доклада нет', () {
      final session = FakeReviewSession(wordItems(3));
      final run = _started(session);

      expect(
        () => run.abandon(const Duration(seconds: -1)),
        throwsArgumentError,
      );
      expect(session.reports, isEmpty);
    });
  });

  group('Бонус «в последний момент»', () {
    test('до первого реза бонуса нет и очков не начислено', () {
      final run = _started(FakeReviewSession(wordItems(3)));

      expect(run.nearMiss, isFalse);
      expect(run.lastPoints, 0);
    });

    test('рез ровно на 85% полёта даёт полуторные очки', () {
      final run = _started(FakeReviewSession(wordItems(3)));

      run.slice(run.correctIndex, const Duration(microseconds: 2975000));

      expect(run.nearMiss, isTrue);
      expect(run.lastPoints, 15, reason: '10 × 1 × 3 ~/ 2');
      expect(run.score, 15);
    });

    test('микросекундой раньше — обычные очки', () {
      final run = _started(FakeReviewSession(wordItems(3)));

      run.slice(run.correctIndex, const Duration(microseconds: 2974999));

      expect(run.nearMiss, isFalse);
      expect(run.lastPoints, 10);
      expect(run.score, 10);
    });

    test('бонус считается от очков с множителем, а не от базовых десяти', () {
      final run = _started(FakeReviewSession(wordItems(6)));

      _correct(run);
      _correct(run);
      _correct(run);
      expect(run.score, 60, reason: '10 + 20 + 30');
      expect(run.timeLimit, const Duration(milliseconds: 2900));

      // 90% от 2.9 с — уверенно в окне, но не на самой границе.
      run.slice(run.correctIndex, const Duration(microseconds: 2610000));

      expect(run.lastPoints, 60, reason: '10 × 4 × 3 ~/ 2, а не 10 × 3 ~/ 2');
      expect(run.score, 120);
    });

    test('бонус не трогает ни серию, ни жизни, ни лимит следующей волны', () {
      final run = _started(FakeReviewSession(wordItems(3)));

      run.slice(run.correctIndex, const Duration(microseconds: 2975000));
      run.advance();

      expect(run.combo, 1, reason: 'один верный рез — серия один, не полтора');
      expect(run.lives, 3);
      expect(
        run.timeLimit,
        const Duration(milliseconds: 3300),
        reason: 'ускорение считает серию, а не награду',
      );
    });

    test('промах в последний момент бонуса не даёт', () {
      final run = _started(FakeReviewSession(wordItems(3)));

      run.slice(_wrongIndex(run), const Duration(microseconds: 3465000));

      expect(
        run.nearMiss,
        isFalse,
        reason: 'бонус — награда за верный рез, а не за поздний',
      );
      expect(run.lastPoints, 0);
      expect(run.score, 0);
    });

    test('таймаут бонуса не даёт, хотя позднее некуда', () {
      final run = _started(FakeReviewSession(wordItems(3)));

      run.timeout();

      expect(run.nearMiss, isFalse);
      expect(run.lastPoints, 0);
      expect(run.score, 0);
    });

    test('на следующей волне бонус и прирост обнулены', () {
      final run = _started(FakeReviewSession(wordItems(3)));

      run.slice(run.correctIndex, const Duration(microseconds: 2975000));
      run.advance();

      expect(run.nearMiss, isFalse, reason: 'это факт о прошлом резе');
      expect(run.lastPoints, 0);
      expect(run.score, 15, reason: 'а вот счёт обнулять нечему');
    });

    test('бонус не виден ядру: ReviewOutcome тот же, что и без бонуса', () {
      final session = FakeReviewSession(wordItems(3));
      final run = _started(session);

      run.slice(run.correctIndex, const Duration(microseconds: 2975000));

      expect(
        run.lastPoints,
        15,
        reason: 'бонус начислен — без этого остальные ассерты ничего не значат',
      );
      final outcome = session.reports.single.outcome;
      expect(outcome.correct, isTrue);
      expect(
        outcome.responseTime,
        const Duration(microseconds: 2975000),
        reason: 'ровно прожитое время, без надбавки за удачу',
      );
      expect(
        outcome.timeLimit,
        const Duration(milliseconds: 3500),
        reason: 'лимит этой волны, а не окно бонуса',
      );
      expect(outcome.hintsUsed, 0);
    });
  });

  group('Числа из SPEC', () {
    test('время: 3.5 с, шаг 0.2 с, пол 2 с, взвод 700 мс', () {
      expect(NinjaRun.baseFlightTime, const Duration(milliseconds: 3500));
      expect(NinjaRun.flightTimeStep, const Duration(milliseconds: 200));
      expect(NinjaRun.minFlightTime, const Duration(seconds: 2));
      expect(NinjaRun.windUpTime, const Duration(milliseconds: 700));
    });

    test('экономика — один в один с падающими словами', () {
      expect(NinjaRun.startLives, 3);
      expect(NinjaRun.pointsPerCombo, 10);
      expect(NinjaRun.wrongReveal, const Duration(milliseconds: 800));
      expect(NinjaRun.correctReveal, const Duration(milliseconds: 300));
    });

    test('объектов в волне — три', () {
      expect(NinjaRun.maxObjects, 3);
    });
  });
}
