// Экран игры «падающие слова»: SPEC.md → «Проверка» и все девять edge
// cases, плюс читаемость под увеличенным системным шрифтом.
//
// Время в этих тестах — только кадры: tester.pump(Δ) двигает фейковые часы
// ровно на Δ, реальных задержек и pumpAndSettle здесь нет (последний
// домотал бы падение до таймаута). Отсюда правило «кадр-взвод»: анимация,
// запущенная вне кадра — из обработчика тапа или из сообщения о смене
// состояния приложения, — встаёт на часы только следующим кадром, поэтому
// хелперы _tap и _lifecycle заканчиваются пустым pump().
//
// Пауза проверяется на inactive (шторка, звонок, переключатель приложений),
// а не только на paused. Причина: на paused фреймворк выключает кадры сам,
// и игра, которая ничего не паузит, прошла бы такой тест — тикер всё равно
// не тикает. На inactive кадры идут, и тест видит разницу между «время
// остановлено» и «время идёт». Отдельный тест на paused остаётся: он
// проверяет буквальный кейс 2 SPEC — возврат из фона с той же точки.
//
// Чего здесь нет: правил начисления очков и переходов фаз — они не требуют
// дерева и живут в falling_words_run_test.dart. Голдены — задача 0.9.

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';

/// id слова по номеру: w01, w02, … Он же текст падающего слова.
String _id(int i) => 'w${i.toString().padLeft(2, '0')}';

/// Верный вариант слова [i].
String _translation(int i) => 'перевод ${_id(i)}';

/// Обманка номер [d] у слова [i].
String _distractor(int i, int d) => 'обманка $d к ${_id(i)}';

/// Слово с [distractors] обманками.
ReviewItem _item(int i, {int distractors = 3}) => ReviewItem(
  word: Word(id: _id(i), text: _id(i), translation: _translation(i)),
  distractors: [for (var d = 1; d <= distractors; d++) _distractor(i, d)],
);

/// Сид из [n] слов по три обманки.
List<ReviewItem> _items(int n) => [for (var i = 1; i <= n; i++) _item(i)];

/// Игра на телефонном экране; возвращает сессию, по которой сверяют доклады.
///
/// Экран задан явно: размер кнопок и переносы строк зависят от него, а
/// умолчание 800×600 — не телефон. seed фиксирован, иначе порядок кнопок
/// менялся бы от запуска к запуску.
Future<FakeReviewSession> _pumpGame(
  WidgetTester tester, {
  List<ReviewItem>? items,
  int? total,
}) async {
  final session = FakeReviewSession(items ?? _items(3), total: total);
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    MaterialApp(home: FallingWordsGame(session: session, seed: 1)),
  );
  return session;
}

/// Тап по кнопке с текстом [label] и кадр-взвод.
///
/// [expectHit] выключают там, где тап намеренно не должен дойти: в фазе
/// подсветки кнопки не принимают нажатий, и предупреждение о промахе было
/// бы шумом, а не находкой.
Future<void> _tap(
  WidgetTester tester,
  String label, {
  bool expectHit = true,
}) async {
  await tester.tap(find.text(label), warnIfMissed: expectHit);
  await tester.pump();
}

/// Смена состояния приложения так, как её шлёт система, — сообщением в
/// канал. Прямой вызов на binding пропустил бы промежуточные состояния,
/// которые канал синтезирует (resumed → inactive → hidden → paused).
Future<void> _lifecycle(WidgetTester tester, AppLifecycleState state) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    const StringCodec().encodeMessage(state.toString()),
    (_) {},
  );
  await tester.pump();
}

/// Верный ответ на слово [i] через секунду и промотанная подсветка.
Future<void> _answerCorrectly(WidgetTester tester, int i) async {
  await tester.pump(const Duration(seconds: 1));
  await _tap(tester, _translation(i));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Промах по слову [i] через секунду и промотанная подсветка.
Future<void> _answerWrongly(WidgetTester tester, int i) async {
  await tester.pump(const Duration(seconds: 1));
  await _tap(tester, _distractor(i, 1));
  await tester.pump(const Duration(milliseconds: 800));
}

/// Кнопка, на которой написан [label].
AnswerButton _button(WidgetTester tester, String label) =>
    tester.widget<AnswerButton>(
      find.ancestor(of: find.text(label), matching: find.byType(AnswerButton)),
    );

/// Сколько жизней показывает HUD.
int _lives(WidgetTester tester) =>
    find.byIcon(Icons.favorite).evaluate().length;

/// Текст элемента HUD по ключу.
String _hud(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

void main() {
  group('Контракт с ядром', () {
    testWidgets('верный тап → один report(correct: true) за прожитое время', (
      tester,
    ) async {
      final session = await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 2));
      await _tap(tester, _translation(1));

      expect(session.reports, hasLength(1));
      final outcome = session.reports.single.outcome;
      expect(outcome.correct, isTrue);
      expect(
        outcome.responseTime,
        const Duration(seconds: 2),
        reason: 'часы игры — только кадры теста',
      );
      expect(outcome.responseTime, lessThan(outcome.timeLimit));
      expect(outcome.timeLimit, const Duration(seconds: 6));
      expect(outcome.hintsUsed, 0);
    });

    testWidgets('слово долетело до низа → неответ, responseTime == timeLimit', (
      tester,
    ) async {
      final session = await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 6));

      expect(session.reports, hasLength(1));
      final outcome = session.reports.single.outcome;
      expect(outcome.correct, isFalse);
      expect(outcome.responseTime, outcome.timeLimit);
      expect(outcome.responseTime, const Duration(seconds: 6));
      expect(_lives(tester), 2, reason: 'таймаут стоит жизни');
    });

    testWidgets('жизни кончились на пятом слове → итоги, лишних слов нет', (
      tester,
    ) async {
      final session = await _pumpGame(tester, items: _items(8));

      await _answerCorrectly(tester, 1);
      await _answerCorrectly(tester, 2);
      await _answerWrongly(tester, 3);
      await _answerWrongly(tester, 4);
      await _answerWrongly(tester, 5);

      expect(find.byKey(FallingWordsKeys.summary), findsOneWidget);
      expect(find.text('Верных ответов: 2 из 5'), findsOneWidget);
      expect(session.reports, hasLength(5));
      expect(
        session.nextItemCalls,
        5,
        reason: 'шестое слово не запрашивается — SPEC, кейс 9',
      );
    });

    testWidgets('сессия пуста на первом вызове → «на сегодня всё»', (
      tester,
    ) async {
      final session = await _pumpGame(tester, items: const []);

      expect(find.byKey(FallingWordsKeys.nothingToday), findsOneWidget);
      expect(
        find.byKey(FallingWordsKeys.summary),
        findsNothing,
        reason: 'это не итоги пустой игры',
      );
      expect(session.reports, isEmpty);
    });

    testWidgets('слов меньше цели → итоги по фактическому числу', (
      tester,
    ) async {
      final session = await _pumpGame(tester, items: _items(2), total: 15);

      await _answerCorrectly(tester, 1);
      await _answerCorrectly(tester, 2);

      expect(find.byKey(FallingWordsKeys.summary), findsOneWidget);
      expect(
        find.text('Верных ответов: 2 из 2'),
        findsOneWidget,
        reason: 'без добивки случайными словами — SPEC, кейс 6',
      );
      expect(session.reports, hasLength(2));
    });
  });

  group('Время', () {
    testWidgets('слово идёт сверху вниз', (tester) async {
      await _pumpGame(tester);
      final start = tester.getTopLeft(find.byKey(FallingWordsKeys.word));

      await tester.pump(const Duration(seconds: 3));

      expect(
        tester.getTopLeft(find.byKey(FallingWordsKeys.word)).dy,
        greaterThan(start.dy),
      );
    });

    testWidgets('после верного ответа лимит короче на 0.25 с', (tester) async {
      final session = await _pumpGame(tester);

      await _answerCorrectly(tester, 1);
      await tester.pump(const Duration(milliseconds: 5750));

      expect(session.reports, hasLength(2));
      final second = session.reports.last.outcome;
      expect(second.correct, isFalse);
      expect(
        second.timeLimit,
        const Duration(milliseconds: 5750),
        reason: 'лимит реальный, а не константа из головы',
      );
      expect(second.responseTime, second.timeLimit);
    });

    testWidgets('шторка во время падения → кадры идут, а время стоит', (
      tester,
    ) async {
      final session = await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 2));
      final beforePause = tester.getTopLeft(find.byKey(FallingWordsKeys.word));

      await _lifecycle(tester, AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 10));

      expect(session.reports, isEmpty, reason: 'на паузе таймер не тикает');

      await _lifecycle(tester, AppLifecycleState.resumed);

      expect(
        tester.getTopLeft(find.byKey(FallingWordsKeys.word)),
        beforePause,
        reason: 'падение продолжается с той же точки — SPEC, кейс 2',
      );

      await tester.pump(const Duration(seconds: 1));

      expect(
        tester.getTopLeft(find.byKey(FallingWordsKeys.word)).dy,
        greaterThan(beforePause.dy),
        reason: 'и продолжается, а не стоит',
      );

      await _tap(tester, _translation(1));

      expect(
        session.reports.single.outcome.responseTime,
        const Duration(seconds: 3),
        reason: '2 с до паузы плюс 1 с после; 10 с в фоне не считаются',
      );
    });

    testWidgets('свёрнуто во время падения → возврат с той же точки', (
      tester,
    ) async {
      final session = await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 2));
      final beforePause = tester.getTopLeft(find.byKey(FallingWordsKeys.word));

      await _lifecycle(tester, AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 10));
      await _lifecycle(tester, AppLifecycleState.resumed);

      expect(
        tester.getTopLeft(find.byKey(FallingWordsKeys.word)),
        beforePause,
        reason: 'падение продолжается с той же точки — SPEC, кейс 2',
      );

      await tester.pump(const Duration(seconds: 1));
      await _tap(tester, _translation(1));

      expect(
        session.reports.single.outcome.responseTime,
        const Duration(seconds: 3),
        reason: '2 с до сворачивания плюс 1 с после',
      );
    });

    testWidgets('таймаут переживает паузу: срабатывает через остаток', (
      tester,
    ) async {
      final session = await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 2));
      await _lifecycle(tester, AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 10));
      await _lifecycle(tester, AppLifecycleState.resumed);

      await tester.pump(const Duration(milliseconds: 3500));
      expect(session.reports, isEmpty, reason: 'до низа ещё полсекунды');

      await tester.pump(const Duration(milliseconds: 500));

      expect(session.reports, hasLength(1));
      expect(
        session.reports.single.outcome.responseTime,
        const Duration(seconds: 6),
      );
    });

    testWidgets('пауза во время подсветки: 800 мс досчитываются после', (
      tester,
    ) async {
      final session = await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 1));
      await _tap(tester, _distractor(1, 1));
      await tester.pump(const Duration(milliseconds: 300));

      await _lifecycle(tester, AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 10));
      await _lifecycle(tester, AppLifecycleState.resumed);

      await tester.pump(const Duration(milliseconds: 499));
      expect(
        find.text(_id(2)),
        findsNothing,
        reason: 'подсветке остался 1 мс, слово ещё не сменилось',
      );

      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text(_id(2)), findsOneWidget);
      expect(session.reports, hasLength(1));
    });

    testWidgets('тап на паузе не принимается и не снимает паузу', (
      tester,
    ) async {
      final session = await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 2));
      await _lifecycle(tester, AppLifecycleState.inactive);
      await _tap(tester, _translation(1));
      await tester.pump(const Duration(seconds: 6));

      expect(
        session.reports,
        isEmpty,
        reason:
            'кнопка на паузе живая (окно интерактивно в split-screen), '
            'но ответ не считается',
      );
      expect(
        find.text(_id(1)),
        findsOneWidget,
        reason: 'игра не уехала на следующее слово мимо паузы',
      );
    });

    testWidgets('системное «убрать анимации» не ускоряет таймер игры', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      final session = await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 2));

      expect(
        session.reports,
        isEmpty,
        reason: 'при ускорении в 20 раз слово упало бы за 0.3 с',
      );

      await _tap(tester, _translation(1));

      expect(
        session.reports.single.outcome.responseTime,
        const Duration(seconds: 2),
      );
    });
  });

  group('Один report() на слово', () {
    testWidgets('тап во время подсветки игнорируется', (tester) async {
      final session = await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 1));
      await _tap(tester, _distractor(1, 1));
      await tester.pump(const Duration(milliseconds: 400));
      await _tap(tester, _translation(1), expectHit: false);

      expect(session.reports, hasLength(1), reason: 'SPEC, кейс 3');

      await tester.pump(const Duration(milliseconds: 399));
      expect(
        find.text(_id(2)),
        findsNothing,
        reason: 'до конца подсветки 1 мс',
      );

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text(_id(2)), findsOneWidget, reason: 'ровно 800 мс');
    });

    testWidgets('двойной быстрый тап по одной кнопке → засчитан один', (
      tester,
    ) async {
      final session = await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text(_translation(1)));
      await tester.tap(find.text(_translation(1)));
      await tester.pump();

      expect(
        session.reports,
        hasLength(1),
        reason: 'второй тап приходит в ещё не перестроенное дерево — SPEC, 4',
      );
      expect(session.reports.single.outcome.correct, isTrue);
    });

    testWidgets('тап по двум кнопкам в одном кадре → засчитан первый', (
      tester,
    ) async {
      final session = await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text(_translation(1)));
      await tester.tap(find.text(_distractor(1, 1)));
      await tester.pump();

      expect(session.reports, hasLength(1), reason: 'SPEC, кейс 5');
      expect(
        session.reports.single.outcome.correct,
        isTrue,
        reason: 'первым обработан верный',
      );
    });
  });

  group('Пути выхода', () {
    testWidgets('выход с выданным словом → доложен неответ', (tester) async {
      final session = await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox());

      expect(session.reports, hasLength(1));
      final outcome = session.reports.single.outcome;
      expect(outcome.correct, isFalse);
      expect(
        outcome.responseTime,
        const Duration(seconds: 2),
        reason: 'сколько слово успело прожить',
      );
    });

    testWidgets('выход в фазе подсветки → лишнего доклада нет', (tester) async {
      final session = await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 1));
      await _tap(tester, _translation(1));
      await tester.pumpWidget(const SizedBox());

      expect(session.reports, hasLength(1), reason: 'ответ уже доложен');
    });

    testWidgets('выход с экрана итогов → лишнего доклада нет', (tester) async {
      final session = await _pumpGame(tester, items: _items(1));

      await _answerCorrectly(tester, 1);
      expect(find.byKey(FallingWordsKeys.summary), findsOneWidget);

      await tester.pumpWidget(const SizedBox());

      expect(session.reports, hasLength(1));
    });
  });

  group('Экран', () {
    testWidgets('HUD показывает жизни, счёт, серию и прогресс', (tester) async {
      await _pumpGame(tester, items: _items(5), total: 15);

      expect(_lives(tester), 3);
      expect(
        _hud(tester, FallingWordsKeys.progress),
        '1/15',
        reason: 'первое слово из пятнадцати запланированных',
      );
      expect(
        _hud(tester, FallingWordsKeys.combo),
        '×1',
        reason:
            'на экране множитель, который применится: первый верный '
            'ответ даёт 10 очков, а не ноль',
      );

      await _answerCorrectly(tester, 1);

      expect(
        _hud(tester, FallingWordsKeys.progress),
        '2/15',
        reason: 'на втором слове прогресс не отстаёт на единицу',
      );
      expect(_hud(tester, FallingWordsKeys.score), '10');
      expect(
        _hud(tester, FallingWordsKeys.combo),
        '×2',
        reason: 'серия 1 — следующий верный ответ принесёт 20',
      );

      await _answerCorrectly(tester, 2);

      expect(_hud(tester, FallingWordsKeys.score), '30', reason: '10 + 20');
      expect(_hud(tester, FallingWordsKeys.combo), '×3');

      await _answerWrongly(tester, 3);

      expect(
        _hud(tester, FallingWordsKeys.combo),
        '×1',
        reason: 'промах сбрасывает серию',
      );
      expect(_lives(tester), 2);
    });

    testWidgets('подсветка ошибки: верный и нажатый различимы не цветом', (
      tester,
    ) async {
      await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 1));
      await _tap(tester, _distractor(1, 1));

      expect(_button(tester, _translation(1)).state, AnswerState.correct);
      expect(_button(tester, _distractor(1, 1)).state, AnswerState.wrong);
      expect(_button(tester, _distractor(1, 2)).state, AnswerState.dimmed);
      expect(
        find.byIcon(Icons.check),
        findsOneWidget,
        reason: 'верный вариант помечен иконкой, а не только цветом',
      );
      expect(
        find.byIcon(Icons.close),
        findsNWidgets(2),
        reason: 'нажатая кнопка и само слово',
      );
    });

    testWidgets('таймаут подсвечивает верный вариант, нажатых нет', (
      tester,
    ) async {
      await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 6));

      expect(_button(tester, _translation(1)).state, AnswerState.correct);
      expect(_button(tester, _distractor(1, 1)).state, AnswerState.dimmed);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(
        find.byIcon(Icons.close),
        findsOneWidget,
        reason: 'только у слова: кнопку не нажимали',
      );
    });

    testWidgets('одна обманка → две кнопки, игра не падает', (tester) async {
      await _pumpGame(tester, items: [_item(1, distractors: 1)]);

      expect(find.byType(AnswerButton), findsNWidgets(2));
      expect(find.text(_translation(1)), findsOneWidget);
      expect(find.text(_distractor(1, 1)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('обманок нет → одна кнопка, игра не падает', (tester) async {
      await _pumpGame(tester, items: [_item(1, distractors: 0)]);

      expect(
        find.byType(AnswerButton),
        findsOneWidget,
        reason: 'вторую кнопку игре взять неоткуда — SPEC, кейс 8',
      );
      expect(find.text(_translation(1)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('итоги: счёт, лучшая серия, число верных', (tester) async {
      final session = await _pumpGame(tester, items: _items(4));

      await _answerCorrectly(tester, 1);
      await _answerCorrectly(tester, 2);
      await _answerWrongly(tester, 3);
      await _answerCorrectly(tester, 4);

      expect(find.byKey(FallingWordsKeys.summary), findsOneWidget);
      expect(
        find.text('Счёт: 40'),
        findsOneWidget,
        reason: '10 и 20 за серию, промах, снова 10',
      );
      expect(find.text('Лучшая серия: 2'), findsOneWidget);
      expect(find.text('Верных ответов: 3 из 4'), findsOneWidget);
      expect(session.reports, hasLength(4));
    });
  });

  group('Читаемость', () {
    testWidgets('системный шрифт крупнее: текст растёт, экран не ломается', (
      tester,
    ) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));
      final normal = tester.getSize(find.text(_translation(1)));

      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pump();
      final doubled = tester.getSize(find.text(_translation(1)));

      expect(
        doubled.height,
        greaterThan(normal.height),
        reason: 'масштаб честный, без FittedBox',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'ничего не переполнилось: overflow — это FlutterError',
      );
      expect(find.text(_translation(1)).hitTestable(), findsOneWidget);
      expect(find.text(_distractor(1, 3)).hitTestable(), findsOneWidget);

      tester.platformDispatcher.textScaleFactorTestValue = 3;
      await tester.pump();

      expect(
        tester.getSize(find.text(_translation(1))),
        doubled,
        reason: 'масштаб зажат на 2×: при 3× четыре кнопки уже не влезают',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('доступность: цели нажатия, подписи, контраст', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });
}
