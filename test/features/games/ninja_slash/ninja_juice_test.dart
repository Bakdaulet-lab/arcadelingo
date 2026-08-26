// Джус ниндзя-слэша на дереве: хаптика, тряска, прилёт очков, след,
// половинки и искры.
//
// Отдельным файлом от `ninja_slash_game_test.dart`: тот про контракт и
// экран, этот — про украшения поверх них. Помощники продублированы, и это
// названная цена — та же, что между game_test и windup_test.
//
// Хаптика проверяется через mock-обработчик платформенного канала. Без него
// `HapticFeedback` уходит в никуда, тест считает собственный пустой список и
// остаётся зелёным на реализации, где хаптики нет вовсе (урок 0.11).
//
// «Убрать анимации» выставляется флагом доступности платформы, а не
// виджетом `MediaQuery`, там где речь о контроллерах, и `MediaQuery` — там,
// где о `disableAnimationsOf` в `build`. Оба пути настоящие, и оба нужны.

import 'dart:math';

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

/// Игра на телефонном экране, взвод пропущен.
Future<FakeReviewSession> _pumpGame(
  WidgetTester tester, {
  List<ReviewItem>? items,
  bool disableAnimations = false,
}) async {
  if (disableAnimations) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  }
  final session = FakeReviewSession(items ?? wordItems(12), total: 15);
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
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
  await tester.pump(NinjaRun.windUpTime);
  return session;
}

Future<void> _lifecycle(WidgetTester tester, AppLifecycleState state) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    const StringCodec().encodeMessage(state.toString()),
    (_) {},
  );
  await tester.pump();
}

/// Ловушка вызовов хаптики на платформенном канале.
List<String> _captureHaptics(WidgetTester tester) {
  final calls = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') {
      calls.add(call.arguments as String);
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return calls;
}

NinjaField _field(WidgetTester tester) =>
    tester.widget<NinjaField>(find.byType(NinjaField));

int _indexOf(WidgetTester tester, String label) =>
    _field(tester).objects.indexWhere((o) => o.label == label);

int _correctIndex(WidgetTester tester, int word) =>
    _indexOf(tester, wordTranslation(word));

int _wrongIndex(WidgetTester tester, int word) =>
    _correctIndex(tester, word) == 0 ? 1 : 0;

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

/// Смещение точки реза от центра объекта в [_sliceTangent].
const Offset _tangentCut = Offset(20, 20);

/// Рез объекта [index] в четыре точки, и режет только последняя.
///
/// Двумя вещами отличается от [_slice], и обе нужны. Точек больше двух —
/// иначе ломаная неотличима от отрезка между концами жеста, и притом режет
/// последнее движение, иначе в след попали бы не все точки. Линия проходит
/// мимо центра — иначе точка реза совпадает с центром объекта, и «искры
/// летят из реза» неотличимо от «искры летят из центра».
Future<void> _sliceTangent(WidgetTester tester, int index) async {
  final centre = _objectCenter(tester, index);
  final path = [
    centre + const Offset(-60, 70),
    centre + const Offset(-20, 70),
    centre + const Offset(20, 70),
    centre + _tangentCut,
  ];
  final gesture = await tester.startGesture(path.first);
  for (final point in path.skip(1)) {
    await gesture.moveTo(point);
  }
  await gesture.up();
  await tester.pump();
}

/// Верный рез по слову [word] через секунду и промотанная подсветка.
Future<void> _answerCorrectly(WidgetTester tester, int word) async {
  await tester.pump(const Duration(seconds: 1));
  await _slice(tester, _correctIndex(tester, word));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Свайп вдоль верха поля, ниже слова и выше любого объекта: следа ради,
/// а не реза ради. Три движения — чтобы след был не отрезком.
Future<void> _swipeAbove(WidgetTester tester) async {
  final field = tester.getRect(find.byKey(NinjaKeys.playfield));
  final y = field.top + 100;
  final gesture = await tester.startGesture(Offset(field.left + 40, y));
  for (final x in [120.0, 200.0, 280.0]) {
    await gesture.moveTo(Offset(field.left + x, y));
  }
  await gesture.up();
  await tester.pump();
}

/// Наклон объекта [index] на экране: направление его верхней кромки.
///
/// Через `getTopLeft`/`getTopRight`, а не через виджет `Transform`: углы
/// едут через матрицу, и только так видно, что поворот действительно
/// применён к тому, что нарисовано.
double _tilt(WidgetTester tester, int index) {
  final key = find.byKey(NinjaKeys.objectAt(index));
  return (tester.getTopRight(key) - tester.getTopLeft(key)).direction;
}

/// Ширина объекта [index] на экране — с учётом масштаба, а не раскладки.
double _objectWidth(WidgetTester tester, int index) {
  final key = find.byKey(NinjaKeys.objectAt(index));
  return (tester.getTopRight(key) - tester.getTopLeft(key)).distance;
}

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(NinjaSlashGame))).colorScheme;

/// Горизонтальный центр счёта в HUD — по нему меряется тряска.
double _hudX(WidgetTester tester) =>
    tester.getCenter(find.byKey(NinjaKeys.score)).dx;

/// Горизонтальный центр слоя объектов.
double _objectsX(WidgetTester tester) =>
    tester.getCenter(find.byKey(NinjaKeys.objects)).dx;

/// Ширина счёта на экране, а не в раскладке: `getSize` вернул бы размер
/// после layout, которого `Transform.scale` не касается.
double _scoreWidth(WidgetTester tester) {
  final score = find.byKey(NinjaKeys.score);
  return tester.getBottomRight(score).dx - tester.getTopLeft(score).dx;
}

String _hud(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

void main() {
  group('Хаптика', () {
    testWidgets('верный рез — лёгкий отклик, ровно один', (tester) async {
      final haptics = _captureHaptics(tester);
      await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 1));
      await _slice(tester, _correctIndex(tester, 1));

      expect(haptics, ['HapticFeedbackType.lightImpact']);
    });

    testWidgets('промах — тяжёлый отклик', (tester) async {
      final haptics = _captureHaptics(tester);
      await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 1));
      await _slice(tester, _wrongIndex(tester, 1));

      expect(haptics, ['HapticFeedbackType.heavyImpact']);
    });

    testWidgets('таймаут — тоже тяжёлый', (tester) async {
      final haptics = _captureHaptics(tester);
      await _pumpGame(tester);

      await tester.pump(const Duration(milliseconds: 3500));

      expect(haptics, ['HapticFeedbackType.heavyImpact']);
    });

    testWidgets('пятый верный подряд — средний', (tester) async {
      final haptics = _captureHaptics(tester);
      await _pumpGame(tester);

      for (var i = 1; i <= 5; i++) {
        await _answerCorrectly(tester, i);
      }

      expect(haptics, hasLength(5));
      expect(haptics.take(4), everyElement('HapticFeedbackType.lightImpact'));
      expect(haptics.last, 'HapticFeedbackType.mediumImpact');
    });

    testWidgets('рез в последний момент — средний с первого же', (
      tester,
    ) async {
      final haptics = _captureHaptics(tester);
      await _pumpGame(tester);

      // 3200 из 3500 — это 91% лимита, окно бонуса с 85%.
      await tester.pump(const Duration(milliseconds: 3200));
      await _slice(tester, _correctIndex(tester, 1));

      expect(haptics, ['HapticFeedbackType.mediumImpact']);
    });

    testWidgets('свайп на паузе отклика не даёт', (tester) async {
      final haptics = _captureHaptics(tester);
      await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 1));
      await _lifecycle(tester, AppLifecycleState.inactive);
      await _slice(tester, _correctIndex(tester, 1));

      expect(haptics, isEmpty);
    });

    testWidgets('свайп во время подсветки второго отклика не даёт', (
      tester,
    ) async {
      final haptics = _captureHaptics(tester);
      await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 1));
      await _slice(tester, _wrongIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 200));
      await _slice(tester, _correctIndex(tester, 1));

      expect(haptics, hasLength(1));
    });

    testWidgets('выход из игры отклика не даёт', (tester) async {
      final haptics = _captureHaptics(tester);
      await _pumpGame(tester);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());

      expect(
        haptics,
        isEmpty,
        reason: 'уход — не ответ, и отзываться на него нечему',
      );
    });
  });

  group('Тряска на промахе', () {
    testWidgets('HUD трясёт, и он меняет сторону', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));
      final still = _hudX(tester);

      await _slice(tester, _wrongIndex(tester, 1));
      final shifts = <double>[];
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        shifts.add(_hudX(tester) - still);
      }

      expect(shifts.any((s) => s > 1), isTrue, reason: 'вправо');
      expect(shifts.any((s) => s < -1), isTrue, reason: 'и влево');
    });

    testWidgets('объекты трясёт вместе с HUD', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));
      final still = _objectsX(tester);

      await _slice(tester, _wrongIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 50));

      expect((_objectsX(tester) - still).abs(), greaterThan(1));
    });

    testWidgets('пара «слово → перевод» стоит неподвижно всю подсветку', (
      tester,
    ) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _wrongIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 25));
      final first = tester.getCenter(find.byKey(NinjaKeys.revealAnswer));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        expect(
          tester.getCenter(find.byKey(NinjaKeys.revealAnswer)),
          first,
          reason: 'это единственный момент, когда человек чему-то учится',
        );
      }
    });

    testWidgets('трясёт только по горизонтали', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));
      final still = tester.getCenter(find.byKey(NinjaKeys.score)).dy;

      await _slice(tester, _wrongIndex(tester, 1));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        expect(
          tester.getCenter(find.byKey(NinjaKeys.score)).dy,
          still,
          reason: 'вертикаль спорила бы с полётом объектов',
        );
      }
    });

    testWidgets('к 300 мс экран стоит ровно, а подсветка ещё идёт', (
      tester,
    ) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));
      final still = _hudX(tester);

      await _slice(tester, _wrongIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 300));

      expect(_hudX(tester), still);
      expect(
        find.byKey(NinjaKeys.revealAnswer),
        findsOneWidget,
        reason: 'подсветка 800 мс, тряска 300 — остаток на чтение',
      );
    });

    testWidgets('верный рез не трясёт', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));
      final still = _hudX(tester);

      await _slice(tester, _correctIndex(tester, 1));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        expect(_hudX(tester), still);
      }
    });

    testWidgets('таймаут трясёт так же, как промах', (tester) async {
      await _pumpGame(tester);
      final still = _hudX(tester);

      await tester.pump(const Duration(milliseconds: 3500));
      await tester.pump(const Duration(milliseconds: 50));

      expect((_hudX(tester) - still).abs(), greaterThan(1));
    });
  });

  group('Прилёт очков', () {
    testWidgets('верный рез показывает прирост и уводит его к счёту', (
      tester,
    ) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _correctIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 30));
      final start = tester.getCenter(find.byKey(NinjaKeys.scorePop));
      await tester.pump(const Duration(milliseconds: 150));
      final later = tester.getCenter(find.byKey(NinjaKeys.scorePop));

      expect(find.text('+10'), findsOneWidget);
      expect(
        (later - tester.getCenter(find.byKey(NinjaKeys.score))).distance,
        lessThan(
          (start - tester.getCenter(find.byKey(NinjaKeys.score))).distance,
        ),
        reason: 'прирост летит к счётчику, а не от него',
      );
    });

    testWidgets('к концу подсветки прирост со сцены ушёл', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _correctIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 299));

      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.byKey(NinjaKeys.scorePop),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        lessThan(0.05),
      );
    });

    testWidgets('промах прироста не показывает', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _wrongIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(NinjaKeys.scorePop), findsNothing);
    });

    testWidgets('в последний момент — прирост полуторный и с меткой', (
      tester,
    ) async {
      await _pumpGame(tester);

      await tester.pump(const Duration(milliseconds: 3200));
      await _slice(tester, _correctIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.text('+15'), findsOneWidget, reason: '10 × 1 × 3 ~/ 2');
      expect(find.byKey(NinjaKeys.nearMissBadge), findsOneWidget);
      expect(find.text('×1.5'), findsOneWidget);
    });

    testWidgets('обычный рез метки не показывает', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _correctIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.byKey(NinjaKeys.nearMissBadge), findsNothing);
    });

    testWidgets('прирост — это прирост, а не весь счёт', (tester) async {
      await _pumpGame(tester);

      await _answerCorrectly(tester, 1);
      await tester.pump(const Duration(seconds: 1));
      await _slice(tester, _correctIndex(tester, 2));
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.text('+20'), findsOneWidget, reason: 'второй рез: ×2');
      expect(_hud(tester, NinjaKeys.score), '30', reason: 'а счёт — 10 + 20');
    });

    testWidgets('счёт раздувается на прилёте и к концу возвращается', (
      tester,
    ) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));
      await _slice(tester, _correctIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 10));
      final plain = _scoreWidth(tester);

      await tester.pump(const Duration(milliseconds: 215));
      final pulsed = _scoreWidth(tester);
      await tester.pump(const Duration(milliseconds: 75));

      expect(pulsed, greaterThan(plain));
      expect(_scoreWidth(tester), closeTo(plain, 0.5));
    });

    testWidgets('счёт в HUD правдив уже в первом кадре подсветки', (
      tester,
    ) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _correctIndex(tester, 1));

      expect(
        _hud(tester, NinjaKeys.score),
        '10',
        reason: 'полёт — украшение над числом, а не способ его узнать',
      );
    });
  });

  group('Рез: след, половинки, искры', () {
    testWidgets('после реза виден след жеста', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _correctIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.byKey(NinjaKeys.trail), findsOneWidget);
      final trail = tester.widget<BladeTrail>(find.byKey(NinjaKeys.trail));
      expect(trail.points.length, greaterThanOrEqualTo(2));
    });

    testWidgets('след — все точки жеста, а не отрезок между концами', (
      tester,
    ) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _sliceTangent(tester, _correctIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 30));

      final trail = tester.widget<BladeTrail>(find.byKey(NinjaKeys.trail));
      expect(
        trail.points,
        hasLength(4),
        reason: 'касание плюс три движения — четыре точки, а не две',
      );
    });

    testWidgets('разрезанный верный стал половинками', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _correctIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.byType(SlicedObject), findsOneWidget);
      expect(
        tester.widget<SlicedObject>(find.byType(SlicedObject)).label,
        wordTranslation(1),
      );
    });

    testWidgets('половинки расходятся и тают', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _correctIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 30));
      final early =
          tester.widget<SlicedObject>(find.byType(SlicedObject)).progress;
      await tester.pump(const Duration(milliseconds: 150));
      final late =
          tester.widget<SlicedObject>(find.byType(SlicedObject)).progress;

      expect(late, greaterThan(early));
    });

    // Первую половину полёта объект идёт вверх и сносится по x — и куски
    // обязаны идти туда же, иначе они выглядят приклеенными.
    testWidgets('половинки наследуют скорость полёта', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _correctIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 30));

      final sliced = tester.widget<SlicedObject>(find.byType(SlicedObject));
      expect(sliced.velocity.dy, lessThan(0), reason: 'вверх');
      expect(sliced.velocity.dx, isNot(0), reason: 'и дрейф по x тоже');
    });

    testWidgets('искр ровно четырнадцать, и летят они из точки реза', (
      tester,
    ) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));
      final correct = _correctIndex(tester, 1);
      final center = _objectCenter(tester, correct);

      await _slice(tester, correct);
      await tester.pump(const Duration(milliseconds: 30));

      final burst = tester.widget<SparkBurst>(find.byKey(NinjaKeys.sparks));
      expect(burst.sparks, hasLength(14));
      final field = tester.getRect(find.byKey(NinjaKeys.playfield));
      expect(
        (burst.origin + field.topLeft - center).distance,
        lessThanOrEqualTo(34),
        reason: 'точка реза лежит в объекте, а не где-то ещё на экране',
      );
    });

    // Рез мимо центра: точка реза обязана быть на жесте, а не в центре
    // объекта. С центральным свайпом эти два места совпадают, и подмена
    // неотличима.
    testWidgets('искры летят из точки реза, а не из центра объекта', (
      tester,
    ) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));
      final correct = _correctIndex(tester, 1);
      final centre = _objectCenter(tester, correct);

      await _sliceTangent(tester, correct);
      await tester.pump(const Duration(milliseconds: 30));

      final field = tester.getRect(find.byKey(NinjaKeys.playfield));
      final origin =
          tester.widget<SparkBurst>(find.byKey(NinjaKeys.sparks)).origin +
          field.topLeft;
      expect(origin.dx - centre.dx, closeTo(_tangentCut.dx, 0.5));
      expect(origin.dy - centre.dy, closeTo(_tangentCut.dy, 0.5));
    });

    // Горизонтальный свайп: искры обязаны разлетаться вверх и вниз, а не
    // веером во все стороны — это и есть «смещённые перпендикулярно резу».
    testWidgets('искры разлетаются поперёк реза', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _correctIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 30));

      final burst = tester.widget<SparkBurst>(find.byKey(NinjaKeys.sparks));
      for (final spark in burst.sparks) {
        final fromVertical = min(
          (spark.angle - pi / 2).abs() % (2 * pi),
          (spark.angle + pi / 2).abs() % (2 * pi),
        );
        expect(
          min(fromVertical, 2 * pi - fromVertical),
          lessThanOrEqualTo(60 * pi / 180 + 1e-9),
        );
      }
    });

    testWidgets(
      'на промахе ни искр, ни половинок: стоп-кадр целого помеченного объекта',
      (tester) async {
        await _pumpGame(tester);
        await tester.pump(const Duration(seconds: 1));
        final wrong = _wrongIndex(tester, 1);

        await _slice(tester, wrong);
        await tester.pump(const Duration(milliseconds: 30));

        expect(find.byKey(NinjaKeys.sparks), findsNothing);
        expect(
          find.byType(SlicedObject),
          findsNothing,
          reason:
              'половинки, улетающие под гравитацией, а потом целый '
              'объект на прежнем месте — скачок ровно в момент чтения пары',
        );
        expect(find.byKey(NinjaKeys.objectAt(wrong)), findsOneWidget);
        expect(_field(tester).objects[wrong].state, ObjectState.wrong);
      },
    );

    // Найдено картинкой, а не числами: подсветка промаха длится 800 мс, и
    // след, привязанный к ней, доживал до конца — жирная линия ложилась
    // поперёк пары «слово → перевод». SPEC говорит «гаснет за 300 мс», и
    // это 300 мс, а не «вся подсветка».
    testWidgets('на промахе след гаснет за 300 мс, а не за все 800', (
      tester,
    ) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _wrongIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(NinjaKeys.trail), findsOneWidget, reason: 'ещё виден');

      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byKey(NinjaKeys.trail), findsNothing);
      expect(
        find.byKey(NinjaKeys.revealAnswer),
        findsOneWidget,
        reason: 'а пара стоит ещё 500 мс, и стоит чистой',
      );
    });

    testWidgets('на верном резе след и искры живут до конца подсветки', (
      tester,
    ) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _correctIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byKey(NinjaKeys.trail), findsOneWidget);
      expect(find.byKey(NinjaKeys.sparks), findsOneWidget);
    });

    testWidgets('таймаут ни следа, ни половинок не даёт', (tester) async {
      await _pumpGame(tester);

      await tester.pump(const Duration(milliseconds: 3500));
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.byKey(NinjaKeys.trail), findsNothing);
      expect(find.byType(SlicedObject), findsNothing);
    });

    // Часы следа — часы полёта, и у каждой волны они свои. Точка, оставленная
    // в конце первой волны, на старте второй оказалась бы «моложе нуля» и
    // вернулась бы на экран, если её не убрать.
    testWidgets('след прошлой волны не доживает до следующей', (tester) async {
      await _pumpGame(tester);

      await tester.pump(const Duration(milliseconds: 3300));
      await _swipeAbove(tester);
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.byKey(NinjaKeys.trail), findsOneWidget, reason: 'живой');

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.byKey(NinjaKeys.revealAnswer), findsNothing);
      expect(find.byKey(NinjaKeys.objectAt(0)), findsOneWidget);
      expect(find.byKey(NinjaKeys.trail), findsNothing);
    });
  });

  group('Живой след клинка', () {
    testWidgets('свайп мимо объектов оставляет след', (tester) async {
      final session = await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _swipeAbove(tester);
      await tester.pump(const Duration(milliseconds: 30));

      expect(session.reports, isEmpty, reason: 'ничего не разрезано');
      final trail = tester.widget<BladeTrail>(find.byKey(NinjaKeys.trail));
      expect(trail.points.length, greaterThanOrEqualTo(4));
    });

    testWidgets('тает с хвоста: через 300 мс полёта без движения его нет', (
      tester,
    ) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _swipeAbove(tester);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(NinjaKeys.trail), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 160));

      expect(find.byKey(NinjaKeys.trail), findsNothing);
    });

    testWidgets('на паузе след не тает: часы полёта стоят', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _swipeAbove(tester);
      await _lifecycle(tester, AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 5));

      expect(find.byKey(NinjaKeys.trail), findsOneWidget);
    });
  });

  group('Вращение и вылет', () {
    testWidgets('в полёте объекты наклонены, и по-разному', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      final tilts = [for (var i = 0; i < 3; i++) _tilt(tester, i)];

      for (final tilt in tilts) {
        expect(tilt.abs(), greaterThan(0.02), reason: 'стоит прямо');
      }
      expect(tilts.toSet(), hasLength(3), reason: 'у каждого своя скорость');
    });

    testWidgets('наклон не больше 25° даже у посадки', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(milliseconds: 3400));

      for (var i = 0; i < 3; i++) {
        expect(
          _tilt(tester, i).abs(),
          lessThanOrEqualTo(25 * pi / 180 + 1e-6),
          reason: 'слово на объекте обязано читаться',
        );
      }
    });

    testWidgets('на вылете объект меньше, к десятой полёта — полный', (
      tester,
    ) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(milliseconds: 35));

      expect(_objectWidth(tester, 0), lessThan(60), reason: 'ещё растёт');

      await tester.pump(const Duration(milliseconds: 965));

      expect(_objectWidth(tester, 0), closeTo(68, 0.5));
    });
  });

  group('Вспышка удара', () {
    testWidgets('на верном резе: есть на 100 мс, нет на 250', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _correctIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(NinjaKeys.flash), findsOneWidget);
      expect(
        tester.widget<ImpactRing>(find.byKey(NinjaKeys.flash)).color,
        _scheme(tester).primary,
      );

      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byKey(NinjaKeys.flash), findsNothing);
    });

    testWidgets('на промахе тоже, цветом error', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _wrongIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        tester.widget<ImpactRing>(find.byKey(NinjaKeys.flash)).color,
        _scheme(tester).error,
        reason: 'это факт удара, а не награда',
      );
    });

    testWidgets('таймаут вспышки не даёт: удара не было', (tester) async {
      await _pumpGame(tester);

      await tester.pump(const Duration(milliseconds: 3500));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(NinjaKeys.flash), findsNothing);
    });
  });

  group('Поле и прирост', () {
    testWidgets('поле подсвечено, и подсветка знает серию', (tester) async {
      await _pumpGame(tester);

      expect(
        tester.widget<FieldLighting>(find.byKey(NinjaKeys.fieldLight)).combo,
        0,
      );

      for (var i = 1; i <= 3; i++) {
        await _answerCorrectly(tester, i);
      }

      expect(
        tester.widget<FieldLighting>(find.byKey(NinjaKeys.fieldLight)).combo,
        3,
      );
    });

    testWidgets('на горячей серии прирост крупнее', (tester) async {
      await _pumpGame(tester);
      await tester.pump(const Duration(seconds: 1));
      await _slice(tester, _correctIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 30));
      final cold = tester.widget<ScorePop>(find.byType(ScorePop));
      final coldSize =
          tester.widget<Text>(find.byKey(NinjaKeys.scorePop)).style!.fontSize!;
      await tester.pump(const Duration(milliseconds: 270));
      await _answerCorrectly(tester, 2);

      await tester.pump(const Duration(seconds: 1));
      await _slice(tester, _correctIndex(tester, 3));
      await tester.pump(const Duration(milliseconds: 30));

      final hot = tester.widget<ScorePop>(find.byType(ScorePop));
      expect(cold.hot, isFalse);
      expect(hot.hot, isTrue, reason: 'третий верный — серия 3, порог тона');
      expect(
        tester.widget<Text>(find.byKey(NinjaKeys.scorePop)).style!.fontSize!,
        greaterThan(coldSize),
      );
    });
  });

  group('Системное «убрать анимации»', () {
    testWidgets('тряски нет', (tester) async {
      await _pumpGame(tester, disableAnimations: true);
      await tester.pump(const Duration(seconds: 1));
      final still = _hudX(tester);

      await _slice(tester, _wrongIndex(tester, 1));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        expect(_hudX(tester), still);
      }
    });

    testWidgets('прироста в полёте нет, но счёт вырос', (tester) async {
      await _pumpGame(tester, disableAnimations: true);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _correctIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.byKey(NinjaKeys.scorePop), findsNothing);
      expect(_hud(tester, NinjaKeys.score), '10');
    });

    testWidgets('следа, половинок, искр и вспышки нет', (tester) async {
      await _pumpGame(tester, disableAnimations: true);
      await tester.pump(const Duration(seconds: 1));

      await _slice(tester, _correctIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.byKey(NinjaKeys.trail), findsNothing);
      expect(find.byType(SlicedObject), findsNothing);
      expect(find.byKey(NinjaKeys.sparks), findsNothing);
      expect(find.byKey(NinjaKeys.flash), findsNothing);
    });

    testWidgets('живого следа нет', (tester) async {
      await _pumpGame(tester, disableAnimations: true);
      await tester.pump(const Duration(seconds: 1));

      await _swipeAbove(tester);
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.byKey(NinjaKeys.trail), findsNothing);
    });

    testWidgets('объекты стоят прямо и в полный размер с первого кадра', (
      tester,
    ) async {
      await _pumpGame(tester, disableAnimations: true);
      await tester.pump(const Duration(milliseconds: 35));

      for (var i = 0; i < 3; i++) {
        expect(_tilt(tester, i), closeTo(0, 1e-9));
      }
      expect(_objectWidth(tester, 0), closeTo(68, 0.5));

      await tester.pump(const Duration(seconds: 1));

      for (var i = 0; i < 3; i++) {
        expect(_tilt(tester, i), closeTo(0, 1e-9));
      }
    });

    testWidgets('подсветка поля остаётся: это состояние, а не движение', (
      tester,
    ) async {
      await _pumpGame(tester, disableAnimations: true);

      expect(find.byKey(NinjaKeys.fieldLight), findsOneWidget);
    });

    testWidgets('пульса счёта нет', (tester) async {
      await _pumpGame(tester, disableAnimations: true);
      await tester.pump(const Duration(seconds: 1));
      await _slice(tester, _correctIndex(tester, 1));
      await tester.pump(const Duration(milliseconds: 10));
      final plain = _scoreWidth(tester);

      await tester.pump(const Duration(milliseconds: 215));

      expect(_scoreWidth(tester), plain);
    });

    testWidgets('хаптика работает: вибрация — не движение на экране', (
      tester,
    ) async {
      final haptics = _captureHaptics(tester);
      await _pumpGame(tester, disableAnimations: true);

      await tester.pump(const Duration(seconds: 1));
      await _slice(tester, _correctIndex(tester, 1));

      expect(haptics, ['HapticFeedbackType.lightImpact']);
    });

    testWidgets('тон серии остаётся: это состояние, а не движение', (
      tester,
    ) async {
      await _pumpGame(tester, disableAnimations: true);

      for (var i = 1; i <= 4; i++) {
        await _answerCorrectly(tester, i);
      }
      await tester.pump(const Duration(milliseconds: 16));

      final box = tester.widget<DecoratedBox>(find.byKey(NinjaKeys.playfield));
      final gradient =
          (box.decoration as BoxDecoration).gradient! as LinearGradient;
      final scheme =
          Theme.of(tester.element(find.byType(NinjaSlashGame))).colorScheme;
      expect(
        gradient.colors[1],
        isNot(scheme.surface),
        reason: 'серия 4 — поле уже подкрашено, переход просто мгновенный',
      );
    });
  });
}
