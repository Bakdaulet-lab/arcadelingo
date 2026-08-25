// Экран ниндзя-слэша: `SPEC.md` → «Проверка» и все десять edge cases, плюс
// читаемость под увеличенным системным шрифтом.
//
// Время в этих тестах — только кадры: tester.pump(Δ) двигает фейковые часы
// ровно на Δ, реальных задержек и pumpAndSettle здесь нет (последний домотал
// бы полёт до таймаута). Отсюда правило «кадр-взвод»: анимация, запущенная
// вне кадра — из обработчика жеста или из сообщения о смене состояния
// приложения, — встаёт на часы только следующим кадром, поэтому хелперы
// заканчиваются пустым pump().
//
// Пауза проверяется на inactive (шторка, звонок, переключатель приложений),
// а не только на paused. Причина: на paused фреймворк выключает кадры сам, и
// игра, которая ничего не паузит, прошла бы такой тест — тикер всё равно не
// тикает. На inactive кадры идут, и тест видит разницу между «время
// остановлено» и «время идёт».
//
// Чего здесь нет: правил начисления очков и переходов фаз — они не требуют
// дерева и живут в ninja_run_test.dart. Геометрия реза — в
// ninja_geometry_test.dart. Взвод — в ninja_windup_test.dart. Джус и
// голдены — этап 4.3.

import 'dart:math' as math;

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_game.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_views.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';
import '../../../support/review_items.dart';

/// Игра на телефонном экране; возвращает сессию, по которой сверяют доклады.
///
/// Экран задан явно: размеры объектов и переносы строк зависят от него, а
/// умолчание 800×600 — не телефон. seed фиксирован, иначе состав волны
/// менялся бы от запуска к запуску.
Future<FakeReviewSession> _pumpGame(
  WidgetTester tester, {
  List<ReviewItem>? items,
  int? total,
  String Function()? summaryFooter,
  VoidCallback? onPlayAgain,
  VoidCallback? onExit,
  VoidCallback? onRoundOver,
  Size size = const Size(1080, 2340),
}) async {
  final session = FakeReviewSession(items ?? wordItems(3), total: total);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    MaterialApp(
      // Настоящая тема приложения, а не дефолтная синяя: иначе
      // textContrastGuideline проверял бы палитру, которой никто не видит.
      theme: wordarcadeTheme(),
      home: NinjaSlashGame(
        session: session,
        seed: 1,
        summaryFooter: summaryFooter,
        onPlayAgain: onPlayAgain ?? () {},
        onExit: onExit ?? () {},
        onRoundOver: onRoundOver,
      ),
    ),
  );
  // Взвод перед первой волной пропускается здесь, а не в каждом тесте: ни
  // один из них не про взвод, а про то, что после него.
  await tester.pump(NinjaRun.windUpTime);
  return session;
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

/// Поле волны в текущем кадре.
NinjaField _field(WidgetTester tester) =>
    tester.widget<NinjaField>(find.byType(NinjaField));

/// Дорожка, на которой стоит объект с переводом [label].
int _indexOf(WidgetTester tester, String label) =>
    _field(tester).objects.indexWhere((o) => o.label == label);

/// Дорожка верного объекта для слова [word].
int _correctIndex(WidgetTester tester, int word) =>
    _indexOf(tester, wordTranslation(word));

/// Дорожка заведомо неверного объекта для слова [word].
int _wrongIndex(WidgetTester tester, int word) {
  final correct = _correctIndex(tester, word);
  return correct == 0 ? 1 : 0;
}

/// Где сейчас центр объекта на дорожке [index] — в координатах экрана.
Offset _objectCenter(WidgetTester tester, int index) =>
    tester.getCenter(find.byKey(NinjaKeys.objectAt(index)));

/// Рез объекта [index]: свайп на 120 dp сквозь его центр.
Future<void> _slice(WidgetTester tester, int index) async {
  final center = _objectCenter(tester, index);
  final gesture = await tester.startGesture(center - const Offset(60, 0));
  await gesture.moveTo(center + const Offset(60, 0));
  await gesture.up();
  await tester.pump();
}

/// Одно движение сквозь два объекта: от [a] к [b] с запасом с обеих сторон.
Future<void> _sliceThrough(WidgetTester tester, int a, int b) async {
  final from = _objectCenter(tester, a);
  final to = _objectCenter(tester, b);
  final step = (to - from) / (to - from).distance * 60;
  final gesture = await tester.startGesture(from - step);
  await gesture.moveTo(to + step);
  await gesture.up();
  await tester.pump();
}

/// Верный рез по слову [word] через секунду и промотанная подсветка.
Future<void> _answerCorrectly(WidgetTester tester, int word) async {
  await tester.pump(const Duration(seconds: 1));
  await _slice(tester, _correctIndex(tester, word));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Промах по слову [word] через секунду и промотанная подсветка.
Future<void> _answerWrongly(WidgetTester tester, int word) async {
  await tester.pump(const Duration(seconds: 1));
  await _slice(tester, _wrongIndex(tester, word));
  await tester.pump(const Duration(milliseconds: 800));
}

/// Сколько жизней показывает HUD.
int _lives(WidgetTester tester) =>
    find.byIcon(Icons.favorite).evaluate().length;

/// Текст элемента HUD по ключу.
String _hud(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

/// Высота экрана в логических пикселях.
double _screenHeight(WidgetTester tester) =>
    tester.view.physicalSize.height / tester.view.devicePixelRatio;

/// Высота связки «слово — перевод» в фазе подсветки промаха.
double _pairSpan(WidgetTester tester) {
  final word = tester.getRect(find.byKey(NinjaKeys.word));
  final answer = tester.getRect(find.byKey(NinjaKeys.revealAnswer));
  return math.max(word.bottom, answer.bottom) - math.min(word.top, answer.top);
}

void main() {
  group('Контракт с ядром', () {
    testWidgets('верный рез → один report(correct: true) за прожитое время', (
      tester,
    ) async {
      final session = await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 1));
      await _slice(tester, _correctIndex(tester, 1));

      expect(session.reports, hasLength(1));
      final outcome = session.reports.single.outcome;
      expect(outcome.correct, isTrue);
      expect(outcome.responseTime, const Duration(seconds: 1));
      expect(outcome.timeLimit, const Duration(milliseconds: 3500));
      expect(outcome.hintsUsed, 0);
    });

    // Edge case 1.
    testWidgets('объекты упали, ни один не разрезан → неответ за весь лимит', (
      tester,
    ) async {
      final session = await _pumpGame(tester);

      await tester.pump(const Duration(milliseconds: 3500));

      expect(session.reports, hasLength(1));
      final outcome = session.reports.single.outcome;
      expect(outcome.correct, isFalse);
      expect(outcome.responseTime, outcome.timeLimit);
      expect(_lives(tester), 2);
    });

    // Edge case 9.
    testWidgets('жизни кончились на середине → итоги, лишних слов нет', (
      tester,
    ) async {
      final session = await _pumpGame(tester, items: wordItems(8), total: 15);

      await _answerWrongly(tester, 1);
      await _answerWrongly(tester, 2);
      await _answerWrongly(tester, 3);

      expect(find.byKey(NinjaKeys.summary), findsOneWidget);
      expect(session.reports, hasLength(3));
      expect(
        session.nextItemCalls,
        3,
        reason: 'четвёртое слово не запрашивается',
      );
    });

    // Edge case 7.
    testWidgets('сессия пуста на первом вызове → «на сегодня всё»', (
      tester,
    ) async {
      final session = await _pumpGame(tester, items: const []);

      expect(find.byKey(NinjaKeys.nothingToday), findsOneWidget);
      expect(find.byKey(NinjaKeys.summary), findsNothing);
      expect(session.reports, isEmpty);
    });

    testWidgets('слов меньше цели → итоги по фактическому числу', (
      tester,
    ) async {
      await _pumpGame(tester, items: wordItems(2), total: 15);

      await _answerCorrectly(tester, 1);
      await _answerCorrectly(tester, 2);

      expect(find.text('Верных ответов: 2 из 2'), findsOneWidget);
    });
  });

  group('Рез', () {
    // Edge case 6.
    testWidgets('тап по объекту не режет', (tester) async {
      final session = await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await tester.tapAt(_objectCenter(tester, _correctIndex(tester, 1)));
      await tester.pump();

      expect(
        session.reports,
        isEmpty,
        reason: 'случайное касание в полёте не должно стоить жизни',
      );
    });

    // Edge case 6, вторая сторона порога.
    testWidgets('движение короче 16 dp не режет, а его продолжение — режет', (
      tester,
    ) async {
      final session = await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));
      final center = _objectCenter(tester, _correctIndex(tester, 1));

      final gesture = await tester.startGesture(center - const Offset(7, 0));
      await gesture.moveBy(const Offset(15, 0));
      await tester.pump();
      expect(session.reports, isEmpty, reason: '15 dp — ещё не свайп');

      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      await gesture.up();

      expect(
        session.reports,
        hasLength(1),
        reason: 'путь набрался, и тот же жест стал резом',
      );
    });

    testWidgets('рез неверного объекта → промах и минус жизнь', (tester) async {
      final session = await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _wrongIndex(tester, 1));

      expect(session.reports.single.outcome.correct, isFalse);
      expect(_lives(tester), 2);
    });

    testWidgets('свайп мимо всех объектов ничего не решает', (tester) async {
      final session = await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));
      final field = tester.getRect(find.byKey(NinjaKeys.playfield));

      final gesture = await tester.startGesture(
        Offset(field.left + 8, field.bottom - 8),
      );
      await gesture.moveTo(Offset(field.right - 8, field.bottom - 8));
      await gesture.up();
      await tester.pump();

      expect(session.reports, isEmpty);
      expect(_lives(tester), 3);
    });

    // Edge case 5.
    testWidgets('одно движение сквозь двоих режет ближний к началу', (
      tester,
    ) async {
      final session = await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _sliceThrough(tester, 0, 2);

      expect(session.reports, hasLength(1), reason: 'ровно один report()');
      final objects = _field(tester).objects;
      expect(
        objects[0].state,
        isNot(ObjectState.dimmed),
        reason: 'рука прошла через нулевую дорожку первой',
      );
      expect(objects[2].state, ObjectState.dimmed);
    });

    testWidgets('обратное движение режет тот, что ближе к его началу', (
      tester,
    ) async {
      final session = await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _sliceThrough(tester, 2, 0);

      expect(session.reports, hasLength(1));
      final objects = _field(tester).objects;
      expect(objects[2].state, isNot(ObjectState.dimmed));
      expect(objects[0].state, ObjectState.dimmed);
    });
  });

  group('Один report() на волну', () {
    // Edge case 3.
    testWidgets('свайп во время подсветки игнорируется', (tester) async {
      final session = await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));
      await _slice(tester, _wrongIndex(tester, 1));

      await tester.pump(const Duration(milliseconds: 200));
      await _slice(tester, _correctIndex(tester, 1));

      expect(session.reports, hasLength(1));
      expect(session.reports.single.outcome.correct, isFalse);
    });

    testWidgets('вторая точка того же жеста второго реза не даёт', (
      tester,
    ) async {
      final session = await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));
      final first = _objectCenter(tester, 0);
      final second = _objectCenter(tester, 2);

      final gesture = await tester.startGesture(first - const Offset(60, 0));
      await gesture.moveTo(first + const Offset(60, 0));
      await tester.pump();
      await gesture.moveTo(second);
      await tester.pump();
      await gesture.up();

      expect(
        session.reports,
        hasLength(1),
        reason: 'первый рез решает волну, остальное — тот же жест',
      );
    });
  });

  group('Время', () {
    testWidgets('объекты идут вверх, а к концу полёта возвращаются вниз', (
      tester,
    ) async {
      await _pumpGame(tester);

      await tester.pump(const Duration(milliseconds: 500));
      final low = _objectCenter(tester, 0).dy;
      await tester.pump(const Duration(milliseconds: 1250));
      final apex = _objectCenter(tester, 0).dy;
      await tester.pump(const Duration(milliseconds: 1250));
      final back = _objectCenter(tester, 0).dy;

      expect(apex, lessThan(low), reason: 'первая половина — подъём');
      expect(back, greaterThan(apex), reason: 'вторая — падение');
    });

    testWidgets('после верного реза лимит короче на 0.2 с', (tester) async {
      final session = await _pumpGame(tester, items: wordItems(3));

      await _answerCorrectly(tester, 1);
      await tester.pump(const Duration(milliseconds: 3300));

      expect(session.reports, hasLength(2));
      expect(
        session.reports.last.outcome.timeLimit,
        const Duration(milliseconds: 3300),
      );
    });

    // Edge case 2, на inactive: кадры идут, а время обязано стоять.
    testWidgets('шторка во время полёта → кадры идут, а время стоит', (
      tester,
    ) async {
      final session = await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 1));
      await _lifecycle(tester, AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 10));
      expect(session.reports, isEmpty, reason: 'на паузе таймаут не наступает');

      await _lifecycle(tester, AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 2499));
      expect(session.reports, isEmpty, reason: 'осталось 2.5 с, не больше');

      await tester.pump(const Duration(milliseconds: 1));

      expect(session.reports, hasLength(1));
      expect(
        session.reports.single.outcome.responseTime,
        const Duration(milliseconds: 3500),
        reason: 'время в фоне в ответ не попало',
      );
    });

    // Edge case 2, буквально: свёрнуто и возвращено.
    testWidgets('свёрнуто во время полёта → возврат с той же точки', (
      tester,
    ) async {
      await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 1));
      final before = _objectCenter(tester, 0);
      await _lifecycle(tester, AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 5));

      expect(_objectCenter(tester, 0), before, reason: 'объект не уехал');

      await _lifecycle(tester, AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 200));

      expect(_objectCenter(tester, 0), isNot(before));
    });

    testWidgets('пауза во время подсветки: 800 мс досчитываются после', (
      tester,
    ) async {
      final session = await _pumpGame(tester, items: wordItems(3));
      await tester.pump(const Duration(seconds: 1));
      await _slice(tester, _wrongIndex(tester, 1));

      await tester.pump(const Duration(milliseconds: 300));
      await _lifecycle(tester, AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 5));
      expect(
        session.nextItemCalls,
        1,
        reason: 'подсветка стоит вместе с игрой',
      );

      await _lifecycle(tester, AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 500));

      expect(session.nextItemCalls, 2, reason: 'досчитались оставшиеся 500 мс');
    });

    testWidgets('свайп на паузе не принимается и не снимает паузу', (
      tester,
    ) async {
      final session = await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _lifecycle(tester, AppLifecycleState.inactive);
      await _slice(tester, _correctIndex(tester, 1));

      expect(session.reports, isEmpty);

      await tester.pump(const Duration(seconds: 10));

      expect(
        session.reports,
        isEmpty,
        reason: 'принятый на паузе жест снял бы паузу де-факто',
      );
    });

    testWidgets('системное «убрать анимации» не ускоряет полёт', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      final session = await _pumpGame(tester);

      await tester.pump(const Duration(milliseconds: 3499));
      expect(session.reports, isEmpty, reason: 'полёт остался 3.5-секундным');

      await tester.pump(const Duration(milliseconds: 1));

      expect(session.reports, hasLength(1));
    });
  });

  group('Пути выхода', () {
    // Edge case 10.
    testWidgets('выход в полёте → неответ доложен, конца раунда нет', (
      tester,
    ) async {
      var rounds = 0;
      final session = await _pumpGame(tester, onRoundOver: () => rounds++);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox());

      expect(session.reports, hasLength(1));
      final outcome = session.reports.single.outcome;
      expect(outcome.correct, isFalse);
      expect(outcome.responseTime, const Duration(seconds: 2));
      expect(rounds, 0, reason: 'уход — не конец раунда');
    });

    testWidgets('выход в фазе подсветки → лишнего доклада нет', (tester) async {
      final session = await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 1));
      await _slice(tester, _correctIndex(tester, 1));
      await tester.pumpWidget(const SizedBox());

      expect(session.reports, hasLength(1), reason: 'ответ уже доложен');
    });

    testWidgets('выход с экрана итогов → лишнего доклада нет', (tester) async {
      final session = await _pumpGame(tester, items: wordItems(1));

      await _answerCorrectly(tester, 1);
      expect(find.byKey(NinjaKeys.summary), findsOneWidget);

      await tester.pumpWidget(const SizedBox());

      expect(session.reports, hasLength(1));
    });
  });

  group('Экран', () {
    testWidgets('HUD показывает жизни, счёт, серию и прогресс', (tester) async {
      await _pumpGame(tester, items: wordItems(5), total: 15);

      expect(_lives(tester), 3);
      expect(_hud(tester, NinjaKeys.progress), '1/15');
      expect(
        _hud(tester, NinjaKeys.combo),
        '×1',
        reason: 'на экране множитель, который применится, а не длина серии',
      );
      expect(_hud(tester, NinjaKeys.score), '0');
    });

    testWidgets('слово стоит наверху поля весь полёт', (tester) async {
      await _pumpGame(tester);
      final field = tester.getRect(find.byKey(NinjaKeys.playfield));

      for (final t in [0, 1000, 1750, 3000]) {
        await tester.pump(Duration(milliseconds: t == 0 ? 0 : 1000));
        expect(
          tester.getCenter(find.byKey(NinjaKeys.word)).dy,
          lessThan(field.center.dy),
          reason: 'слово читают, а не догоняют',
        );
      }
    });

    testWidgets('промах: пара по центру, объекты замерли', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));
      await _slice(tester, _wrongIndex(tester, 1));
      final frozen = _objectCenter(tester, 0);

      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester.widget<Text>(find.byKey(NinjaKeys.revealAnswer)).data,
        wordTranslation(1),
      );
      expect(
        _objectCenter(tester, 0),
        frozen,
        reason: 'стоп-кадр: подсветка не время лететь дальше',
      );
      expect(
        _field(tester).faded,
        isTrue,
        reason: 'объекты гаснут, чтобы пара по центру читалась',
      );
    });

    testWidgets('промах: разрезанный неверный помечен, остальные нет', (
      tester,
    ) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));
      final wrong = _wrongIndex(tester, 1);

      await _slice(tester, wrong);

      final objects = _field(tester).objects;
      expect(objects[wrong].state, ObjectState.wrong);
      for (var i = 0; i < objects.length; i++) {
        if (i == wrong) continue;
        expect(objects[i].state, ObjectState.dimmed, reason: 'дорожка $i');
      }
    });

    testWidgets('таймаут: та же пара, разрезанных объектов нет', (
      tester,
    ) async {
      await _pumpGame(tester);

      await tester.pump(const Duration(milliseconds: 3500));

      expect(find.byKey(NinjaKeys.revealAnswer), findsOneWidget);
      for (final object in _field(tester).objects) {
        expect(object.state, ObjectState.dimmed);
      }
    });

    testWidgets('верный рез: разрезанный помечен, пары нет', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));
      final correct = _correctIndex(tester, 1);

      await _slice(tester, correct);

      expect(_field(tester).objects[correct].state, ObjectState.correct);
      expect(
        find.byKey(NinjaKeys.revealAnswer),
        findsNothing,
        reason: 'учить нечему: человек и так ответил верно',
      );
    });

    testWidgets('связка читается одним взглядом', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _wrongIndex(tester, 1));

      expect(
        _pairSpan(tester),
        lessThan(_screenHeight(tester) / 3),
        reason: 'на саккаду через экран и обратно 800 мс не хватит',
      );
    });

    // Edge case 8.
    testWidgets('одна обманка → два объекта, игра не падает', (tester) async {
      await _pumpGame(tester, items: [wordItem(1, distractors: 1)]);

      expect(_field(tester).objects, hasLength(2));
      expect(find.byKey(NinjaKeys.objectAt(1)), findsOneWidget);
    });

    // Edge case 8, край.
    testWidgets('обманок нет → один объект, игра не падает', (tester) async {
      await _pumpGame(tester, items: [wordItem(1, distractors: 0)]);

      expect(_field(tester).objects, hasLength(1));
      expect(_field(tester).objects.single.label, wordTranslation(1));
    });

    testWidgets('три обманки → всё равно три объекта', (tester) async {
      await _pumpGame(tester);

      expect(
        _field(tester).objects,
        hasLength(3),
        reason: 'третья обманка остаётся невостребованной — цена читаемости',
      );
    });
  });

  group('Конец партии', () {
    testWidgets('очередь кончилась → «Раунд окончен» и обе кнопки', (
      tester,
    ) async {
      await _pumpGame(tester, items: wordItems(1));

      await _answerCorrectly(tester, 1);

      expect(find.text('Раунд окончен'), findsOneWidget);
      expect(find.byKey(NinjaKeys.playAgain), findsOneWidget);
      expect(find.byKey(NinjaKeys.exit), findsOneWidget);
    });

    testWidgets('жизни кончились → заголовок про жизни', (tester) async {
      await _pumpGame(tester, items: wordItems(8));

      await _answerWrongly(tester, 1);
      await _answerWrongly(tester, 2);
      await _answerWrongly(tester, 3);

      expect(find.text('Жизни кончились'), findsOneWidget);
      expect(find.text('Раунд окончен'), findsNothing);
    });

    testWidgets('строка хоста берётся один раз, после последнего доклада', (
      tester,
    ) async {
      var asked = 0;
      await _pumpGame(
        tester,
        items: wordItems(1),
        summaryFooter: () {
          asked++;
          return 'ещё есть слова';
        },
      );

      await _answerCorrectly(tester, 1);

      expect(find.byKey(NinjaKeys.summaryFooter), findsOneWidget);
      expect(find.text('ещё есть слова'), findsOneWidget);
      expect(asked, 1, reason: 'на итогах ничего не меняется');

      await tester.pump(const Duration(seconds: 1));

      expect(asked, 1, reason: 'перестройка экрана хоста не переспрашивает');
    });

    testWidgets('строки хоста нет → итоги без неё', (tester) async {
      await _pumpGame(tester, items: wordItems(1));

      await _answerCorrectly(tester, 1);

      expect(find.byKey(NinjaKeys.summaryFooter), findsNothing);
    });

    testWidgets('конец раунда доложен ровно один раз', (tester) async {
      var rounds = 0;
      await _pumpGame(tester, items: wordItems(1), onRoundOver: () => rounds++);

      await _answerCorrectly(tester, 1);
      await tester.pump(const Duration(seconds: 1));

      expect(rounds, 1);
    });

    testWidgets('пустая сессия конца раунда не даёт', (tester) async {
      var rounds = 0;
      await _pumpGame(tester, items: const [], onRoundOver: () => rounds++);

      expect(find.byKey(NinjaKeys.nothingToday), findsOneWidget);
      expect(
        rounds,
        0,
        reason: 'засчитывает день хост, и «на сегодня всё» он видит сам',
      );
    });

    testWidgets('кнопки итогов зовут хост, а не игру', (tester) async {
      var again = 0;
      var exits = 0;
      await _pumpGame(
        tester,
        items: wordItems(1),
        onPlayAgain: () => again++,
        onExit: () => exits++,
      );
      await _answerCorrectly(tester, 1);

      await tester.tap(find.byKey(NinjaKeys.playAgain));
      await tester.pump();
      await tester.tap(find.byKey(NinjaKeys.exit));
      await tester.pump();

      expect(again, 1);
      expect(exits, 1);
    });

    testWidgets('«на сегодня всё» → тоже есть выход', (tester) async {
      var exits = 0;
      await _pumpGame(tester, items: const [], onExit: () => exits++);

      await tester.tap(find.byKey(NinjaKeys.exit));
      await tester.pump();

      expect(exits, 1);
      expect(
        find.byKey(NinjaKeys.playAgain),
        findsNothing,
        reason: 'переигрывать нечего: вторая попытка дала бы этот же экран',
      );
    });
  });

  group('Читаемость', () {
    testWidgets('системный шрифт 2× на 360×640 поле не переполняет', (
      tester,
    ) async {
      await _pumpGame(tester, size: const Size(1080, 1920));
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            theme: wordarcadeTheme(),
            home: NinjaSlashGame(
              session: FakeReviewSession(wordItems(3)),
              seed: 1,
              onPlayAgain: () {},
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.pump(NinjaRun.windUpTime);
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.byKey(NinjaKeys.playfield), findsOneWidget);
    });

    testWidgets('итоги при шрифте 2× на коротком экране: выход достижим', (
      tester,
    ) async {
      await _pumpGame(
        tester,
        items: wordItems(1),
        size: const Size(1080, 1920),
      );
      await _answerCorrectly(tester, 1);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pump();

      expect(tester.takeException(), isNull);
      await tester.dragUntilVisible(
        find.byKey(NinjaKeys.exit),
        find.byType(SingleChildScrollView),
        const Offset(0, -60),
      );

      expect(find.byKey(NinjaKeys.exit), findsOneWidget);
    });

    testWidgets('доступность: цели нажатия, подписи, контраст', (tester) async {
      await _pumpGame(tester, items: wordItems(1));
      await tester.pump(const Duration(seconds: 1));
      final handle = tester.ensureSemantics();

      await expectLater(tester, meetsGuideline(textContrastGuideline));

      await _answerCorrectly(tester, 1);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });
}
