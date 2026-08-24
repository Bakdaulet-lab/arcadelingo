// Ход игры «падающие слова» без дерева виджетов: протокол с ядром, жизни,
// комбо, лимит времени, варианты ответа.
//
// Здесь проверяется всё, для чего не нужны кадры и рисование, — и только
// это. Само падение, пауза при сворачивании и «один report() на двойной
// тап» живут в falling_words_game_test.dart: там нужен tester.pump.
//
// Литералы, а не константы из lib/: тест обязан быть независимой сверкой
// со SPEC.md, иначе переименованная константа подтвердит сама себя.

import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';

/// id слова по номеру: w01, w02, …
String _id(int i) => 'w${i.toString().padLeft(2, '0')}';

/// Верный вариант слова [i].
String _translation(int i) => 'перевод ${_id(i)}';

/// Обманка номер [d] у слова [i]. Тексты уникальны на весь тест: так
/// ошибка «нажали не ту кнопку» видна в сообщении, а не угадывается.
String _distractor(int i, int d) => 'обманка $d к ${_id(i)}';

/// Слово с [distractors] обманками.
ReviewItem _item(int i, {int distractors = 3}) => ReviewItem(
  word: Word(id: _id(i), text: _id(i), translation: _translation(i)),
  distractors: [for (var d = 1; d <= distractors; d++) _distractor(i, d)],
);

/// Сид из [n] слов по три обманки.
List<ReviewItem> _items(int n) => [for (var i = 1; i <= n; i++) _item(i)];

/// Игра на [session]: первое слово уже выдано.
FallingWordsRun _started(ReviewSession session, {int seed = 1}) =>
    FallingWordsRun(session: session, random: Random(seed))..start();

/// Индекс заведомо неверной кнопки.
int _wrongIndex(FallingWordsRun run) => run.correctIndex == 0 ? 1 : 0;

/// Верный ответ за [elapsed] и промотанная подсветка.
void _correct(
  FallingWordsRun run, [
  Duration elapsed = const Duration(seconds: 1),
]) {
  run.choose(run.correctIndex, elapsed);
  run.advance();
}

/// Промах за [elapsed] и промотанная подсветка.
void _miss(
  FallingWordsRun run, [
  Duration elapsed = const Duration(seconds: 1),
]) {
  run.choose(_wrongIndex(run), elapsed);
  run.advance();
}

void main() {
  group('Протокол с сессией', () {
    test('start() → одно слово запрошено, докладов нет', () {
      final session = FakeReviewSession(_items(3));

      final run = _started(session);

      expect(run.phase, FallingPhase.falling);
      expect(run.item!.word.id, 'w01');
      expect(session.nextItemCalls, 1);
      expect(session.reports, isEmpty, reason: 'выдача слова — ещё не ответ');
    });

    test('верный ответ → ровно один report(correct: true)', () {
      final session = FakeReviewSession(_items(3));
      final run = _started(session);

      final accepted = run.choose(run.correctIndex, const Duration(seconds: 2));

      expect(accepted, isTrue);
      expect(session.reports, hasLength(1));
      final outcome = session.reports.single.outcome;
      expect(outcome.correct, isTrue);
      expect(outcome.responseTime, const Duration(seconds: 2));
      expect(outcome.timeLimit, const Duration(seconds: 6));
      expect(outcome.hintsUsed, 0, reason: 'подсказок в этой игре нет');
      expect(run.phase, FallingPhase.reveal);
      expect(run.verdict, Verdict.correct);
      expect(run.chosenIndex, run.correctIndex);
      expect(
        session.nextItemCalls,
        1,
        reason: 'следующее слово берётся только в advance()',
      );
    });

    test('неверный ответ → report(correct: false), подсветка 800 мс', () {
      final session = FakeReviewSession(_items(3));
      final run = _started(session);

      run.choose(_wrongIndex(run), const Duration(seconds: 2));

      expect(session.reports.single.outcome.correct, isFalse);
      expect(
        session.reports.single.outcome.responseTime,
        const Duration(seconds: 2),
        reason: 'ошиблись быстро — это не таймаут',
      );
      expect(run.verdict, Verdict.wrong);
      expect(run.revealTime, const Duration(milliseconds: 800));
    });

    test('верный ответ рассыпается 300 мс', () {
      final run = _started(FakeReviewSession(_items(3)));

      run.choose(run.correctIndex, const Duration(seconds: 2));

      expect(run.revealTime, const Duration(milliseconds: 300));
    });

    test('advance() → следующее слово, фаза падения', () {
      final session = FakeReviewSession(_items(3));
      final run = _started(session);

      _correct(run);

      expect(run.phase, FallingPhase.falling);
      expect(run.item!.word.id, 'w02');
      expect(session.nextItemCalls, 2);
    });

    test('choose() в фазе подсветки → false, второго доклада нет', () {
      final session = FakeReviewSession(_items(3));
      final run = _started(session);

      run.choose(run.correctIndex, const Duration(seconds: 2));
      final second = run.choose(_wrongIndex(run), const Duration(seconds: 3));

      expect(second, isFalse, reason: 'страж «ровно один report() на слово»');
      expect(session.reports, hasLength(1));
    });

    test('timeout() в фазе подсветки → false, второго доклада нет', () {
      final session = FakeReviewSession(_items(3));
      final run = _started(session);

      run.choose(run.correctIndex, const Duration(seconds: 2));

      expect(run.timeout(), isFalse);
      expect(session.reports, hasLength(1));
    });

    test('сессия не дала ни одного слова → «на сегодня всё», без докладов', () {
      final session = FakeReviewSession(const []);

      final run = _started(session);

      expect(run.phase, FallingPhase.nothingToday);
      expect(run.item, isNull);
      expect(session.nextItemCalls, 1);
      expect(session.reports, isEmpty);
    });

    test('слова кончились → итоги, лишних докладов нет', () {
      final session = FakeReviewSession(_items(2));
      final run = _started(session);

      _correct(run);
      _correct(run);

      expect(run.phase, FallingPhase.over);
      expect(session.reports, hasLength(2));
      expect(session.nextItemCalls, 3, reason: 'третий вызов вернул null');
    });

    test('выход в фазе падения → доложен неответ за прожитое время', () {
      final session = FakeReviewSession(_items(3));
      final run = _started(session);

      run.abandon(const Duration(seconds: 2));

      expect(session.reports, hasLength(1));
      expect(session.reports.single.outcome.correct, isFalse);
      expect(
        session.reports.single.outcome.responseTime,
        const Duration(seconds: 2),
        reason: 'game-contract: либо доложи неответ, либо не бери item',
      );
      expect(run.phase, FallingPhase.over);
    });

    test('выход вне фазы падения → ничего не докладывается', () {
      final session = FakeReviewSession(_items(3));
      final run = _started(session);

      run.choose(run.correctIndex, const Duration(seconds: 2));
      run.abandon(const Duration(seconds: 1));

      expect(session.reports, hasLength(1), reason: 'ответ уже доложен');

      run.advance();
      run.abandon(const Duration(seconds: 1));
      run.abandon(const Duration(seconds: 1));

      expect(session.reports, hasLength(2), reason: 'второй выход — не доклад');
    });
  });

  group('Время падения', () {
    test('первое слово падает 6 секунд', () {
      final run = _started(FakeReviewSession(_items(3)));

      expect(run.timeLimit, const Duration(seconds: 6));
    });

    test('каждый уровень комбо снимает 0.25 с', () {
      final run = _started(FakeReviewSession(_items(5)));

      _correct(run);
      expect(run.timeLimit, const Duration(milliseconds: 5750));

      _correct(run);
      expect(run.timeLimit, const Duration(milliseconds: 5500));

      _correct(run);
      expect(run.timeLimit, const Duration(milliseconds: 5250));
    });

    test('быстрее 3 секунд слово не падает', () {
      final run = _started(FakeReviewSession(_items(20)));

      for (var i = 0; i < 12; i++) {
        _correct(run);
      }
      expect(
        run.timeLimit,
        const Duration(seconds: 3),
        reason: '6 − 12 × 0.25',
      );

      _correct(run);
      expect(run.timeLimit, const Duration(seconds: 3), reason: 'пол держится');
    });

    test('промах сбрасывает комбо, лимит возвращается к 6 с', () {
      final run = _started(FakeReviewSession(_items(5)));

      _correct(run);
      _correct(run);
      _miss(run);

      expect(run.combo, 0);
      expect(run.timeLimit, const Duration(seconds: 6));
    });

    test('таймаут → responseTime равен лимиту этого слова', () {
      final session = FakeReviewSession(_items(3));
      final run = _started(session);

      _correct(run);
      final accepted = run.timeout();

      expect(accepted, isTrue);
      final outcome = session.reports.last.outcome;
      expect(outcome.correct, isFalse);
      expect(outcome.timeLimit, const Duration(milliseconds: 5750));
      expect(outcome.responseTime, outcome.timeLimit);
      expect(run.verdict, Verdict.timeout);
      expect(run.chosenIndex, isNull, reason: 'кнопку не нажимали');
      expect(
        run.revealTime,
        const Duration(milliseconds: 800),
        reason: 'таймаут — это неверный ответ',
      );
    });
  });

  group('Жизни', () {
    test('партия начинается с трёх жизней', () {
      final run = _started(FakeReviewSession(_items(3)));

      expect(run.lives, 3);
    });

    test('промах и таймаут стоят по жизни, верный ответ — ничего', () {
      final run = _started(FakeReviewSession(_items(5)));

      _correct(run);
      expect(run.lives, 3, reason: 'верный ответ жизнь не тратит');

      _miss(run);
      expect(run.lives, 2);

      run.timeout();
      run.advance();
      expect(run.lives, 1);
    });

    test('жизни кончились → итоги немедленно, новых слов не берём', () {
      final session = FakeReviewSession(_items(8));
      final run = _started(session);

      _miss(run);
      _miss(run);
      _miss(run);

      expect(run.phase, FallingPhase.over);
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
    test('очки — 10 за ответ, множитель растёт с серией', () {
      final run = _started(FakeReviewSession(_items(5)));

      _correct(run);
      expect(run.score, 10, reason: 'первый верный: множитель 1');
      expect(run.combo, 1);

      _correct(run);
      expect(run.score, 30, reason: '10 + 20');

      _correct(run);
      expect(run.score, 60, reason: '30 + 30');
    });

    test('промах сбрасывает множитель, но не счёт', () {
      final run = _started(FakeReviewSession(_items(5)));

      _correct(run);
      _correct(run);
      _miss(run);
      _correct(run);

      expect(run.score, 40, reason: '10 + 20, промах, снова 10');
      expect(run.combo, 1);
      expect(run.bestCombo, 2, reason: 'лучшая серия помнит максимум');
    });

    test('счётчики ответов: верные и все', () {
      final run = _started(FakeReviewSession(_items(5)));

      _correct(run);
      _miss(run);
      _correct(run);

      expect(run.correctCount, 2);
      expect(run.answeredCount, 3);
    });
  });

  group('Варианты ответа', () {
    test('варианты — перевод и все обманки слова', () {
      final run = _started(FakeReviewSession(_items(1)));
      final expected = {
        _translation(1),
        _distractor(1, 1),
        _distractor(1, 2),
        _distractor(1, 3),
      };

      expect(run.options.toSet(), expected);
      expect(run.options, hasLength(4));
      expect(run.options[run.correctIndex], _translation(1));
    });

    test('одна обманка → две кнопки', () {
      final run = _started(FakeReviewSession([_item(1, distractors: 1)]));

      expect(run.options, hasLength(2));
      expect(run.options[run.correctIndex], _translation(1));
    });

    test('обманок нет → одна кнопка, игра не падает', () {
      final run = _started(FakeReviewSession([_item(1, distractors: 0)]));

      expect(
        run.options,
        [_translation(1)],
        reason: 'вторую кнопку игре взять неоткуда: выдумывать обманки нельзя',
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

    test('одинаковый seed → одинаковый порядок вариантов', () {
      final first = _started(FakeReviewSession(_items(1)), seed: 7);
      final second = _started(FakeReviewSession(_items(1)), seed: 7);

      expect(first.options, second.options);
      expect(first.correctIndex, second.correctIndex);
    });

    test('верный вариант не всегда на одной позиции', () {
      final run = _started(FakeReviewSession(_items(10)));
      final positions = <int>{run.correctIndex};

      for (var i = 0; i < 9; i++) {
        _correct(run);
        positions.add(run.correctIndex);
      }

      expect(
        positions.length,
        greaterThan(1),
        reason: 'иначе игрок запоминает позицию, а не слово',
      );
    });
  });

  group('Стражи: игра не строит битый ReviewOutcome', () {
    test('отрицательное время ответа → ArgumentError, доклада нет', () {
      final session = FakeReviewSession(_items(3));
      final run = _started(session);

      expect(
        () => run.choose(run.correctIndex, const Duration(seconds: -1)),
        throwsArgumentError,
        reason: 'domain это не сторожит: шапка grade_outcome.dart',
      );
      expect(session.reports, isEmpty);
    });

    test('время ответа больше лимита → ArgumentError, доклада нет', () {
      final session = FakeReviewSession(_items(3));
      final run = _started(session);

      expect(
        () => run.choose(run.correctIndex, const Duration(seconds: 7)),
        throwsArgumentError,
        reason: 'дольше лимита слово уже упало — это таймаут, не ответ',
      );
      expect(session.reports, isEmpty);
    });

    test('время ответа ровно по лимиту принимается', () {
      final session = FakeReviewSession(_items(3));
      final run = _started(session);

      run.choose(run.correctIndex, const Duration(seconds: 6));

      expect(session.reports.single.outcome.responseTime, run.timeLimit);
    });

    test('индекс вне списка вариантов → ArgumentError, доклада нет', () {
      final session = FakeReviewSession(_items(3));
      final run = _started(session);

      expect(
        () => run.choose(4, const Duration(seconds: 1)),
        throwsArgumentError,
      );
      expect(
        () => run.choose(-1, const Duration(seconds: 1)),
        throwsArgumentError,
      );
      expect(session.reports, isEmpty);
    });

    test('отрицательное время при выходе → ArgumentError, доклада нет', () {
      final session = FakeReviewSession(_items(3));
      final run = _started(session);

      expect(
        () => run.abandon(const Duration(seconds: -1)),
        throwsArgumentError,
      );
      expect(session.reports, isEmpty);
    });
  });

  group('Бонус «в последний момент»', () {
    test('до первого ответа бонуса нет и очков не начислено', () {
      final run = _started(FakeReviewSession(_items(3)));

      expect(run.nearMiss, isFalse);
      expect(run.lastPoints, 0);
    });

    test('ответ ровно на 85% лимита даёт полуторные очки', () {
      final run = _started(FakeReviewSession(_items(3)));

      run.choose(run.correctIndex, const Duration(microseconds: 5100000));

      expect(run.nearMiss, isTrue);
      expect(run.lastPoints, 15, reason: '10 × 1 × 3 ~/ 2');
      expect(run.score, 15);
    });

    test('микросекундой раньше — обычные очки', () {
      final run = _started(FakeReviewSession(_items(3)));

      run.choose(run.correctIndex, const Duration(microseconds: 5099999));

      expect(run.nearMiss, isFalse);
      expect(run.lastPoints, 10);
      expect(run.score, 10);
    });

    test('бонус считается от очков с множителем, а не от базовых десяти', () {
      final run = _started(FakeReviewSession(_items(6)));

      _correct(run);
      _correct(run);
      _correct(run);
      expect(run.score, 60, reason: '10 + 20 + 30');
      expect(run.timeLimit, const Duration(milliseconds: 5250));

      // 90% от 5.25 с — уверенно в окне, но не на самой границе.
      run.choose(run.correctIndex, const Duration(microseconds: 4725000));

      expect(run.lastPoints, 60, reason: '10 × 4 × 3 ~/ 2, а не 10 × 3 ~/ 2');
      expect(run.score, 120);
    });

    test('бонус не трогает ни серию, ни жизни, ни лимит следующего слова', () {
      final run = _started(FakeReviewSession(_items(3)));

      run.choose(run.correctIndex, const Duration(microseconds: 5100000));
      run.advance();

      expect(
        run.combo,
        1,
        reason: 'один верный ответ — серия один, не полтора',
      );
      expect(run.lives, 3);
      expect(
        run.timeLimit,
        const Duration(milliseconds: 5750),
        reason: 'ускорение считает серию, а не награду',
      );
    });

    test('промах в последний момент бонуса не даёт', () {
      final run = _started(FakeReviewSession(_items(3)));

      run.choose(_wrongIndex(run), const Duration(microseconds: 5940000));

      expect(
        run.nearMiss,
        isFalse,
        reason: 'бонус — награда за верный ответ, а не за поздний',
      );
      expect(run.lastPoints, 0);
      expect(run.score, 0);
    });

    test('таймаут бонуса не даёт, хотя позднее некуда', () {
      final run = _started(FakeReviewSession(_items(3)));

      run.timeout();

      expect(run.nearMiss, isFalse);
      expect(run.lastPoints, 0);
      expect(run.score, 0);
    });

    test('на следующем слове бонус и прирост обнулены', () {
      final run = _started(FakeReviewSession(_items(3)));

      run.choose(run.correctIndex, const Duration(microseconds: 5100000));
      run.advance();

      expect(run.nearMiss, isFalse, reason: 'это факт о прошлом ответе');
      expect(run.lastPoints, 0);
      expect(run.score, 15, reason: 'а вот счёт обнулять нечему');
    });

    test('бонус не виден ядру: ReviewOutcome тот же, что и без бонуса', () {
      final session = FakeReviewSession(_items(3));
      final run = _started(session);

      run.choose(run.correctIndex, const Duration(microseconds: 5100000));

      expect(
        run.lastPoints,
        15,
        reason: 'бонус начислен — без этого остальные ассерты ничего не значат',
      );
      final outcome = session.reports.single.outcome;
      expect(outcome.correct, isTrue);
      expect(
        outcome.responseTime,
        const Duration(microseconds: 5100000),
        reason: 'ровно прожитое время, без надбавки за удачу',
      );
      expect(
        outcome.timeLimit,
        const Duration(seconds: 6),
        reason: 'лимит этого слова, а не окно бонуса',
      );
      expect(outcome.hintsUsed, 0);
    });
  });
}
