// Тон поля от серии и порог разогрева — без дерева виджетов.
//
// Файл — копия трёх групп falling_words_juice_test.dart: игры острова, и
// функции тона у ниндзя свои. Числа те же, потому что экономика и джус
// один в один (`SPEC.md`, решение автора), и разъедутся они только если
// кто-то правит одну игру, забыв про вторую, — ровно тот риск, цену
// которого Фаза 4 назвала вслух.
//
// Схема берётся из `wordarcadeTheme()`, а не собирается своя: с копией
// закон о контрасте сторожил бы палитру, которой никто не видит.

import 'dart:math';

import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_views.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Насколько цвет [b] ушёл от цвета [a]. Грубая мера, и её хватает: нужна
/// только монотонность, а не абсолютная величина.
double _distance(Color a, Color b) =>
    sqrt(pow(a.r - b.r, 2) + pow(a.g - b.g, 2) + pow(a.b - b.b, 2));

/// Контраст по WCAG 2.1.
double _contrast(Color fg, Color bg) {
  final first = fg.computeLuminance();
  final second = bg.computeLuminance();
  return (max(first, second) + 0.05) / (min(first, second) + 0.05);
}

void main() {
  final scheme = wordarcadeTheme().colorScheme;

  group('Тон поля от серии', () {
    test('до серии 3 поле чистое', () {
      expect(comboTint(scheme, 0), scheme.surface);
      expect(comboTint(scheme, 1), scheme.surface);
      expect(
        comboTint(scheme, 2),
        scheme.surface,
        reason: 'ранний тон — шум, а не награда',
      );
    });

    test('с серии 3 тон появляется', () {
      expect(comboTint(scheme, 3), isNot(scheme.surface));
    });

    test('от 3 до 8 густеет монотонно', () {
      final distances = [
        for (var combo = 2; combo <= 8; combo++)
          _distance(scheme.surface, comboTint(scheme, combo)),
      ];

      for (var i = 1; i < distances.length; i++) {
        expect(
          distances[i],
          greaterThan(distances[i - 1]),
          reason: 'серия ${i + 2} не гуще предыдущей — тон не растёт',
        );
      }
    });

    test('с серии 8 — потолок', () {
      expect(comboTint(scheme, 9), comboTint(scheme, 8));
      expect(comboTint(scheme, 40), comboTint(scheme, 8));
    });

    test('отрицательной серии не бывает, но тон она не переворачивает', () {
      expect(comboTint(scheme, -1), scheme.surface);
    });

    test('на самом густом тоне текст всё ещё читается', () {
      expect(
        _contrast(scheme.onSurface, comboTint(scheme, 40)),
        greaterThanOrEqualTo(4.5),
        reason: 'верхняя граница потолка смешения — SPEC, «Джус»',
      );
    });

    test('на потолке тон заметен, а не выдаёт себя за чистый фон', () {
      expect(
        _distance(scheme.surface, comboTint(scheme, 8)),
        greaterThan(0.15),
        reason: 'смешение, которого не видно, — не награда, а просто трата',
      );
    });

    test('на разогретом поле читается и то, что туда прилетает', () {
      final hot = comboTint(scheme, 8);

      expect(
        _contrast(scheme.primary, hot),
        greaterThanOrEqualTo(4.5),
        reason: '«+N» летит именно на разогретое поле, а не на чистое',
      );
      expect(
        _contrast(scheme.tertiary, hot),
        greaterThanOrEqualTo(4.5),
        reason: 'метка множителя летит с ним рядом',
      );
    });
  });

  group('Порог разогрева — один на поле и на HUD', () {
    test('загорается на серии 3, на серии 2 ещё нет', () {
      expect(comboIsHot(2), isFalse);
      expect(comboIsHot(3), isTrue);
    });

    test('серии до первой не бывает, но и она не горит', () {
      expect(comboIsHot(0), isFalse);
      expect(comboIsHot(-1), isFalse);
    });

    test('множитель и поле загораются ровно вместе', () {
      for (var combo = 0; combo <= 12; combo++) {
        expect(
          comboIsHot(combo),
          comboTint(scheme, combo) != scheme.surface,
          reason:
              'серия $combo: множитель и поле разошлись, а порог у них '
              'обязан быть один и тот же — SPEC, «Джус»',
        );
      }
    });

    // Согласие двух функций — ещё не согласие экрана: HUD может спрашивать
    // не ту. Мутация «множитель горит по combo > 0» проходила мимо всех
    // тестов, пока проводка не проверялась отдельно.
    testWidgets('HUD спрашивает про разогрев ту же функцию', (tester) async {
      Future<Color?> colorAt(int combo) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: wordarcadeTheme(),
            home: Scaffold(
              body: GameHud(
                lives: 3,
                maxLives: 3,
                score: 0,
                multiplier: combo + 1,
                current: 1,
                total: 15,
                combo: combo,
              ),
            ),
          ),
        );
        return tester.widget<Text>(find.byKey(NinjaKeys.combo)).style?.color;
      }

      expect(await colorAt(1), scheme.onSurfaceVariant);
      expect(await colorAt(2), scheme.onSurfaceVariant);
      expect(await colorAt(3), scheme.primary);
      expect(await colorAt(9), scheme.primary);
    });
  });

  group('Тон поля — градиент, а не заливка', () {
    test('на серии 0 градиент ровный: весь фон', () {
      final gradient = comboGradient(scheme, 0);

      expect(
        gradient.colors.toSet(),
        {scheme.surface},
        reason: 'до серии 3 поле чистое, и градиент этого не меняет',
      );
    });

    test('середина горячая, оба края — чистый фон', () {
      final gradient = comboGradient(scheme, 8);

      expect(gradient.colors.first, scheme.surface, reason: 'верхний край');
      expect(gradient.colors.last, scheme.surface, reason: 'нижний край');
      expect(gradient.colors[1], comboTint(scheme, 8));
      expect(gradient.colors[2], comboTint(scheme, 8));
      expect(
        gradient.colors[1],
        isNot(scheme.surface),
        reason: 'иначе градиента нет вовсе и панель вернулась',
      );
    });

    test('растяжка настоящая: край не схлопнут в ноль', () {
      final stops = comboGradient(scheme, 8).stops!;

      expect(stops.first, 0);
      expect(stops.last, 1);
      expect(
        stops[1],
        greaterThan(0.1),
        reason: 'схлопнутая растяжка — это та же жёсткая граница о HUD',
      );
      expect(stops[2], lessThan(0.9));
      expect(
        stops[1],
        closeTo(1 - stops[2], 1e-9),
        reason: 'края симметричны: стык и с HUD, и с низом экрана одинаков',
      );
    });

    test('градиент вертикальный: горизонтальный спорил бы с полётом', () {
      final gradient = comboGradient(scheme, 8);

      expect(gradient.begin, Alignment.topCenter);
      expect(gradient.end, Alignment.bottomCenter);
    });

    test('числа из SPEC: пороги 3 и 8, потолок 0.35, растяжка 22%', () {
      expect(comboTintStart, 2, reason: 'загорается на следующей после двух');
      expect(comboTintEnd, 8);
      expect(comboTintMax, 0.35);
      expect(comboGradientEdge, 0.22);
      expect(comboTintFade, const Duration(milliseconds: 400));
    });
  });

  group('Подсветка верха поля', () {
    test('на чистой серии 0.10, на потолке 0.24', () {
      expect(topLightAlpha(0), closeTo(0.10, 1e-9));
      expect(topLightAlpha(2), closeTo(0.10, 1e-9));
      expect(topLightAlpha(8), closeTo(0.24, 1e-9));
      expect(topLightAlpha(40), closeTo(0.24, 1e-9));
    });

    test('растёт монотонно между порогами', () {
      var previous = 0.0;
      for (var combo = 2; combo <= 8; combo++) {
        final alpha = topLightAlpha(combo);
        expect(alpha, greaterThanOrEqualTo(previous));
        previous = alpha;
      }
      expect(topLightAlpha(5), greaterThan(topLightAlpha(3)));
    });

    test('по той же шкале, что и тон поля', () {
      expect(comboDepth(2), 0);
      expect(comboDepth(8), 1);
      expect(comboDepth(5), closeTo(0.5, 1e-9));
      expect(comboDepth(40), 1);
    });

    test('кончается ровно там, где начинается полоса тона', () {
      expect(
        topLightSpan,
        comboGradientEdge,
        reason:
            'сложись подсветка с полосой, на потолке смешение перевалило бы '
            'за 0.45, где onSurface теряет 4.5:1',
      );
    });

    test('на потолке слово наверху всё ещё читается', () {
      final lit = Color.lerp(scheme.surface, scheme.primary, topLightAlpha(8))!;

      expect(_contrast(scheme.onSurface, lit), greaterThanOrEqualTo(4.5));
    });

    test('числа из SPEC: низ темнеет с 55% до 0.5, виньетка 0.45 от 0.65', () {
      expect(bottomDarkFrom, 0.55);
      expect(bottomDarkAlpha, 0.5);
      expect(vignetteAlpha, 0.45);
      expect(vignetteInner, 0.65);
    });
  });

  group('Обод объекта', () {
    Future<BoxDecoration> decorationOf(
      WidgetTester tester,
      ObjectState state,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: wordarcadeTheme(),
          home: Scaffold(
            body: Center(child: FlyingObject(label: 'перевод', state: state)),
          ),
        ),
      );
      return tester.widget<Container>(find.byType(Container)).decoration!
          as BoxDecoration;
    }

    testWidgets('в полёте — вторым акцентом и со свечением', (tester) async {
      final box = await decorationOf(tester, ObjectState.idle);

      final border = box.border! as Border;
      expect(border.top.color, scheme.tertiary.withValues(alpha: 0.75));
      expect(border.top.width, 2);
      expect(box.boxShadow, isNotEmpty, reason: 'без свечения — серый круг');
    });

    testWidgets('разрезанный — цветом вердикта', (tester) async {
      final correct = await decorationOf(tester, ObjectState.correct);
      final wrong = await decorationOf(tester, ObjectState.wrong);

      expect(
        correct.boxShadow!.first.color.withValues(alpha: 1),
        scheme.primary.withValues(alpha: 1),
      );
      expect(
        wrong.boxShadow!.first.color.withValues(alpha: 1),
        scheme.error.withValues(alpha: 1),
      );
    });
  });

  group('Половинки разрезанного объекта', () {
    /// Две половинки на экране: прямоугольники через getRect, потому что
    /// расхождение и поворот живут в матрице Transform, а не в раскладке.
    Future<List<Finder>> halves(
      WidgetTester tester,
      double progress, {
      double angle = 0,
      Offset velocity = Offset.zero,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: wordarcadeTheme(),
          home: Scaffold(
            body: Center(
              child: SlicedObject(
                label: 'перевод',
                state: ObjectState.correct,
                angle: angle,
                velocity: velocity,
                progress: progress,
              ),
            ),
          ),
        ),
      );
      return find
          .byType(FlyingObject)
          .evaluate()
          .map((e) => find.byWidget(e.widget))
          .toList();
    }

    testWidgets('расходятся поперёк линии реза, а не вдоль', (tester) async {
      final parts = await halves(tester, 1);

      expect(parts, hasLength(2));
      final a = tester.getCenter(parts[0]);
      final b = tester.getCenter(parts[1]);
      expect(
        (a.dy - b.dy).abs(),
        closeTo(120, 0.5),
        reason: 'рез горизонтальный — по 60 dp в каждую сторону за 0.3 с',
      );
      expect(a.dx, closeTo(b.dx, 0.5));
    });

    testWidgets('на старте подсветки ещё вместе', (tester) async {
      final parts = await halves(tester, 0);

      expect(
        tester.getCenter(parts[0]),
        within(distance: 0.5, from: tester.getCenter(parts[1])),
      );
    });

    testWidgets('вращаются в разные стороны', (tester) async {
      final parts = await halves(tester, 1);

      double tilt(Finder part) =>
          (tester.getTopRight(part) - tester.getTopLeft(part)).direction;
      final a = tilt(parts[0]);
      final b = tilt(parts[1]);
      expect(a.abs(), closeTo(40 * pi / 180, 1e-6));
      expect(b.abs(), closeTo(40 * pi / 180, 1e-6));
      expect(a.sign, isNot(b.sign));
    });

    testWidgets('падают и наследуют скорость', (tester) async {
      final still = await halves(tester, 1);
      final restY =
          (tester.getCenter(still[0]).dy + tester.getCenter(still[1]).dy) / 2;
      final moving = await halves(tester, 1, velocity: const Offset(0, -200));
      final movingY =
          (tester.getCenter(moving[0]).dy + tester.getCenter(moving[1]).dy) / 2;

      expect(movingY, closeTo(restY - 60, 0.5));
    });

    testWidgets('тают: к концу подсветки их не видно', (tester) async {
      await halves(tester, 0.2);
      final early = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((o) => o.opacity)
          .reduce(min);

      await halves(tester, 0.9);
      final late = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((o) => o.opacity)
          .reduce(min);

      expect(late, lessThan(early));
      expect(late, lessThan(0.2));
    });
  });

  group('Прирост очков', () {
    Future<Text> popText(WidgetTester tester, {required bool hot}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: wordarcadeTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: ScorePop(
                points: 10,
                from: const Offset(150, 150),
                progress: 0.1,
                nearMiss: false,
                hot: hot,
              ),
            ),
          ),
        ),
      );
      return tester.widget<Text>(find.byKey(NinjaKeys.scorePop));
    }

    testWidgets('на горячей серии крупнее и со свечением', (tester) async {
      final cold = await popText(tester, hot: false);
      final hot = await popText(tester, hot: true);

      expect(hot.style!.fontSize!, greaterThan(cold.style!.fontSize!));
      expect(hot.style!.shadows, isNotEmpty);
      expect(cold.style!.shadows ?? const [], isEmpty);
    });

    testWidgets('выскакивает: на старте меньше, к 35% — полный', (
      tester,
    ) async {
      Future<double> widthAt(double progress) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: wordarcadeTheme(),
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 300,
                child: ScorePop(
                  points: 10,
                  from: const Offset(150, 150),
                  progress: progress,
                  nearMiss: false,
                  hot: false,
                ),
              ),
            ),
          ),
        );
        final pop = find.byKey(NinjaKeys.scorePop);
        // Через углы, а не getSize: масштаб живёт в матрице Transform.
        return (tester.getTopRight(pop) - tester.getTopLeft(pop)).distance;
      }

      final small = await widthAt(0.01);
      final full = await widthAt(0.5);

      expect(small, lessThan(full * 0.6), reason: 'масштаб 0.3 на старте');
    });

    testWidgets('первую треть стоит на месте, потом летит к счёту', (
      tester,
    ) async {
      Future<Offset> at(double progress) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: wordarcadeTheme(),
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 300,
                child: ScorePop(
                  points: 10,
                  from: const Offset(150, 150),
                  progress: progress,
                  nearMiss: false,
                  hot: false,
                ),
              ),
            ),
          ),
        );
        return tester.getCenter(find.byKey(NinjaKeys.scorePop));
      }

      final start = await at(0.05);
      final held = await at(0.3);
      final flying = await at(0.7);

      expect(held, within(distance: 0.5, from: start));
      expect(flying, isNot(within(distance: 5, from: start)));
    });
  });
}
