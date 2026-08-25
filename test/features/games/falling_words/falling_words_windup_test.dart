// Взвод перед первым падением: 700 мс, в которые ничего не движется.
//
// Отдельным файлом от `falling_words_game_test.dart` намеренно. Тамошний
// помощник `_pumpGame` взвод **пропускает** — ни один из его тестов не про
// взвод, а про то, что происходит после. Здесь помощник свой, и он
// останавливается ровно на взводе.
//
// Зачем взвод вообще: до Фазы 3 первое слово ехало вниз в нулевом кадре, до
// того как человек нашёл глазами четыре кнопки. Жизнь терялась на каждом
// старте сессии — то есть каждый день (`SPEC.md`, раздел «Взвод»).

import 'package:arcadelingo/features/games/falling_words/falling_words_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';
import '../../../support/review_items.dart';

/// Числа из SPEC литералами: тест, сверяющийся с той же константой, которую
/// проверяет, зелен при любом её значении.
const Duration _windUp = Duration(milliseconds: 700);
const Duration _fall = Duration(seconds: 6);

/// Игра **на взводе**: помощник не пропускает его, в отличие от соседнего
/// файла.
Future<FakeReviewSession> _pumpAtWindUp(
  WidgetTester tester, {
  bool disableAnimations = false,
}) async {
  final session = FakeReviewSession(wordItems(3));
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp(
        theme: wordarcadeTheme(),
        home: FallingWordsGame(
          session: session,
          seed: 1,
          onPlayAgain: () {},
          onExit: () {},
        ),
      ),
    ),
  );
  return session;
}

/// Где сейчас слово по вертикали.
double _wordTop(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(FallingWordsKeys.word)).dy;

void main() {
  group('Пока идёт взвод', () {
    testWidgets('слово уже на экране, но стоит', (tester) async {
      await _pumpAtWindUp(tester);
      final start = _wordTop(tester);

      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(FallingWordsKeys.word), findsOneWidget);
      expect(
        _wordTop(tester),
        start,
        reason: 'взвод — это пауза перед падением, а не медленное падение',
      );
    });

    testWidgets('кнопки уже на месте: их и ищут эти 700 мс', (tester) async {
      await _pumpAtWindUp(tester);

      expect(find.text(wordTranslation(1)), findsOneWidget);
      for (var d = 1; d <= 3; d++) {
        expect(find.text(wordDistractor(1, d)), findsOneWidget);
      }
    });

    // 700 мс даны на то, чтобы найти кнопки, а не ответить: тап в этом окне —
    // рефлекс, а не ответ.
    testWidgets('тап не уходит в report()', (tester) async {
      final session = await _pumpAtWindUp(tester);

      await tester.tap(find.text(wordTranslation(1)));
      await tester.pump();

      expect(session.reports, isEmpty);
    });

    testWidgets('после взвода тот же тап засчитывается', (tester) async {
      final session = await _pumpAtWindUp(tester);
      await tester.pump(_windUp);

      await tester.tap(find.text(wordTranslation(1)));
      await tester.pump();

      expect(session.reports, hasLength(1));
      expect(session.reports.single.outcome.correct, isTrue);
    });
  });

  group('Взвод кончается и начинается падение', () {
    testWidgets('через 700 мс слово поехало', (tester) async {
      await _pumpAtWindUp(tester);
      await tester.pump(_windUp);
      final start = _wordTop(tester);

      await tester.pump(const Duration(seconds: 1));

      expect(_wordTop(tester), greaterThan(start));
    });

    // Главное, что тут сторожится: взвод — надбавка, а не часть шести секунд.
    testWidgets('взвод не съедает время падения', (tester) async {
      final session = await _pumpAtWindUp(tester);

      // Взвод плюс почти всё падение: слово ещё летит.
      await tester.pump(_windUp);
      await tester.pump(_fall - const Duration(milliseconds: 1));
      expect(
        session.reports,
        isEmpty,
        reason: 'шесть секунд отсчитываются от начала падения, а не от старта',
      );

      await tester.pump(const Duration(milliseconds: 1));

      expect(session.reports, hasLength(1));
      expect(session.reports.single.outcome.correct, isFalse);
      expect(session.reports.single.outcome.responseTime, _fall);
    });

    testWidgets('взвод только перед первым словом', (tester) async {
      final session = await _pumpAtWindUp(tester);
      await tester.pump(_windUp);
      await tester.tap(find.text(wordTranslation(1)));
      await tester.pump();
      // Подсветка верного ответа — 300 мс, и после неё второе слово обязано
      // поехать сразу: между словами взвода нет.
      await tester.pump(const Duration(milliseconds: 300));
      final start = _wordTop(tester);

      await tester.pump(const Duration(seconds: 1));

      expect(
        _wordTop(tester),
        greaterThan(start),
        reason: 'вторая пауза подряд превратила бы темп в рваный',
      );
      expect(session.reports, hasLength(1));
    });
  });

  group('Взвод — игровое время', () {
    // Как и падение: `preserve`, а не умножение на ноль в build. Человеку,
    // который выключил анимации, кнопки нужно найти тем более.
    testWidgets('при «убрать анимации» взвод на месте и по-прежнему 700 мс', (
      tester,
    ) async {
      final session = await _pumpAtWindUp(tester, disableAnimations: true);
      final start = _wordTop(tester);

      await tester.pump(const Duration(milliseconds: 690));
      expect(_wordTop(tester), start, reason: 'взвод не сократился');
      await tester.tap(find.text(wordTranslation(1)));
      await tester.pump();
      expect(session.reports, isEmpty, reason: 'тапы всё ещё не принимаются');

      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(seconds: 1));

      expect(_wordTop(tester), greaterThan(start));
    });

    testWidgets('при «убрать анимации» падение остаётся шестисекундным', (
      tester,
    ) async {
      final session = await _pumpAtWindUp(tester, disableAnimations: true);

      await tester.pump(_windUp);
      await tester.pump(_fall - const Duration(milliseconds: 1));
      expect(session.reports, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));

      expect(session.reports, hasLength(1));
    });
  });

  group('Числа из SPEC', () {
    test('взвод — 700 мс', () {
      expect(FallingWordsRun.windUpTime, const Duration(milliseconds: 700));
    });

    test('взвод короче падения и заметен человеку', () {
      expect(
        FallingWordsRun.windUpTime,
        lessThan(FallingWordsRun.baseFallTime),
      );
      expect(
        FallingWordsRun.windUpTime,
        greaterThanOrEqualTo(const Duration(milliseconds: 600)),
        reason: 'меньше шестисот кнопки найти не успевают',
      );
    });
  });
}
