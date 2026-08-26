// Взвод перед первой волной: 700 мс, в которые поле пусто и ничего не
// движется.
//
// Отдельным файлом от `ninja_slash_game_test.dart` намеренно: тамошний
// помощник взвод **пропускает** — ни один из его тестов не про взвод, а
// про то, что после него. Здесь помощник свой, и он останавливается ровно
// на взводе.
//
// Зачем взвод: то же, что в падающих словах, — 700 мс на то, чтобы понять,
// где поле, до того как жест начнёт что-то стоить (`SPEC.md`).

import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_game.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_views.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';
import '../../../support/review_items.dart';

/// Числа из SPEC литералами: тест, сверяющийся с той же константой, которую
/// проверяет, зелен при любом её значении.
const Duration _windUp = Duration(milliseconds: 700);
const Duration _flight = Duration(milliseconds: 3500);

/// Игра **на взводе**: помощник его не пропускает, в отличие от соседнего
/// файла.
///
/// «Убрать анимации» выставляется флагом доступности платформы, а не
/// виджетом `MediaQuery`: `AnimationBehavior` смотрит на
/// `SemanticsBinding.disableAnimations`, а не на дерево (урок этапа 3.6).
Future<FakeReviewSession> _pumpAtWindUp(
  WidgetTester tester, {
  bool disableAnimations = false,
}) async {
  if (disableAnimations) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
  }
  final session = FakeReviewSession(wordItems(3));
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: wordarcadeTheme(),
      home: NinjaSlashGame(
        session: session,
        seed: 1,
        onPlayAgain: () {},
        onExit: () {},
      ),
    ),
  );
  return session;
}

/// Смена состояния приложения так, как её шлёт система, — сообщением в
/// канал: прямой вызов на binding пропустил бы промежуточные состояния.
Future<void> _lifecycle(WidgetTester tester, AppLifecycleState state) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    const StringCodec().encodeMessage(state.toString()),
    (_) {},
  );
  await tester.pump();
}

/// Свайп поперёк поля — там, где объекты были бы, если бы летели.
Future<void> _swipeAcross(WidgetTester tester) async {
  final field = tester.getRect(find.byKey(NinjaKeys.playfield));
  final gesture = await tester.startGesture(field.center - const Offset(80, 0));
  await gesture.moveTo(field.center + const Offset(80, 0));
  await gesture.up();
  await tester.pump();
}

/// Рез верного объекта в его текущей позиции.
Future<void> _sliceCorrect(WidgetTester tester, int word) async {
  final field = tester.widget<NinjaField>(find.byType(NinjaField));
  final index = field.objects.indexWhere(
    (o) => o.label == wordTranslation(word),
  );
  final center = tester.getCenter(find.byKey(NinjaKeys.objectAt(index)));
  final gesture = await tester.startGesture(center - const Offset(60, 0));
  await gesture.moveTo(center + const Offset(60, 0));
  await gesture.up();
  await tester.pump();
}

/// Есть ли на экране хоть один объект волны.
bool _hasObjects(WidgetTester tester) =>
    find.byKey(NinjaKeys.objectAt(0)).evaluate().isNotEmpty;

/// Где сейчас первый объект по вертикали.
double _objectY(WidgetTester tester) =>
    tester.getCenter(find.byKey(NinjaKeys.objectAt(0))).dy;

void main() {
  group('Пока идёт взвод', () {
    testWidgets('слово уже на экране, а поле пусто', (tester) async {
      await _pumpAtWindUp(tester);

      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(wordId(1)), findsOneWidget);
      expect(
        _hasObjects(tester),
        isFalse,
        reason: 'взвод — время прочитать слово, а не догонять объекты',
      );
    });

    testWidgets('свайп не уходит в report()', (tester) async {
      final session = await _pumpAtWindUp(tester);

      await _swipeAcross(tester);

      expect(session.reports, isEmpty);
    });

    testWidgets('после взвода объекты появились и тот же рез считается', (
      tester,
    ) async {
      final session = await _pumpAtWindUp(tester);

      await tester.pump(_windUp);
      await tester.pump(const Duration(seconds: 1));

      expect(_hasObjects(tester), isTrue);
      await _sliceCorrect(tester, 1);

      expect(session.reports, hasLength(1));
      expect(session.reports.single.outcome.correct, isTrue);
    });
  });

  group('Взвод кончается и начинается полёт', () {
    testWidgets('через 700 мс объекты поехали', (tester) async {
      await _pumpAtWindUp(tester);
      await tester.pump(_windUp);
      await tester.pump(const Duration(milliseconds: 500));
      final start = _objectY(tester);

      await tester.pump(const Duration(milliseconds: 500));

      expect(
        _objectY(tester),
        lessThan(start),
        reason: 'первую половину полёта объекты идут вверх',
      );
    });

    // Главное, что тут сторожится: взвод — надбавка, а не часть 3.5 с.
    testWidgets('взвод не съедает время полёта', (tester) async {
      final session = await _pumpAtWindUp(tester);

      await tester.pump(_windUp);
      await tester.pump(_flight - const Duration(milliseconds: 1));
      expect(
        session.reports,
        isEmpty,
        reason: '3.5 секунды отсчитываются от старта волны, а не от экрана',
      );

      await tester.pump(const Duration(milliseconds: 1));

      expect(session.reports, hasLength(1));
      expect(session.reports.single.outcome.correct, isFalse);
      expect(session.reports.single.outcome.responseTime, _flight);
    });

    testWidgets('взвод только перед первой волной', (tester) async {
      final session = await _pumpAtWindUp(tester);
      await tester.pump(_windUp);
      await tester.pump(const Duration(seconds: 1));
      await _sliceCorrect(tester, 1);
      // Подсветка верного реза — 300 мс, и после неё вторая волна обязана
      // взлететь сразу: между волнами взвода нет.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
      final start = _objectY(tester);

      await tester.pump(const Duration(milliseconds: 500));

      expect(
        _objectY(tester),
        lessThan(start),
        reason: 'вторая пауза подряд превратила бы темп в рваный',
      );
      expect(session.reports, hasLength(1));
    });
  });

  group('Взвод — игровое время', () {
    testWidgets('при «убрать анимации» взвод на месте и по-прежнему 700 мс', (
      tester,
    ) async {
      final session = await _pumpAtWindUp(tester, disableAnimations: true);

      await tester.pump(const Duration(milliseconds: 690));
      expect(_hasObjects(tester), isFalse, reason: 'взвод не сократился');
      await _swipeAcross(tester);
      expect(session.reports, isEmpty, reason: 'жест всё ещё не принимается');

      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 500));

      expect(_hasObjects(tester), isTrue);
    });

    testWidgets('при «убрать анимации» полёт остаётся 3.5-секундным', (
      tester,
    ) async {
      final session = await _pumpAtWindUp(tester, disableAnimations: true);

      await tester.pump(_windUp);
      await tester.pump(_flight - const Duration(milliseconds: 1));
      expect(session.reports, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));

      expect(session.reports, hasLength(1));
    });
  });

  group('Взвод пауз не боится', () {
    testWidgets('сворачивание останавливает взвод', (tester) async {
      final session = await _pumpAtWindUp(tester);
      await tester.pump(const Duration(milliseconds: 300));

      await _lifecycle(tester, AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 5));

      expect(_hasObjects(tester), isFalse, reason: 'волна так и не взлетела');
      await _swipeAcross(tester);
      expect(session.reports, isEmpty, reason: 'всё ещё взвод');
    });

    testWidgets('после возврата взвод продолжается с того же места', (
      tester,
    ) async {
      await _pumpAtWindUp(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await _lifecycle(tester, AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 5));

      await _lifecycle(tester, AppLifecycleState.resumed);
      // Оставалось 400 мс: на 390 всё ещё взвод.
      await tester.pump(const Duration(milliseconds: 390));
      expect(_hasObjects(tester), isFalse, reason: 'взвод не досижен');

      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        _hasObjects(tester),
        isTrue,
        reason: 'взвод досижен ровно, а не сгорел и не начался заново',
      );
    });
  });

  group('Числа из SPEC', () {
    test('взвод — 700 мс и короче полёта', () {
      expect(NinjaRun.windUpTime, const Duration(milliseconds: 700));
      expect(NinjaRun.windUpTime, lessThan(NinjaRun.baseFlightTime));
    });
  });
}
