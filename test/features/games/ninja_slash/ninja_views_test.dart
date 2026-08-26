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

  group('Искры', () {
    test('ровно восемь', () {
      expect(sparkBurst(Random(1)), hasLength(8));
      expect(sparkCount, 8);
    });

    test('одинаковый seed — одинаковые искры: без этого кадр не снять', () {
      expect(sparkBurst(Random(7)), sparkBurst(Random(7)));
    });

    test('разлёт в обещанных границах', () {
      for (final spark in sparkBurst(Random(3))) {
        expect(spark.distance, greaterThanOrEqualTo(40));
        expect(spark.distance, lessThanOrEqualTo(70));
      }
      expect(sparkMinReach, 40);
      expect(sparkMaxReach, 70);
    });

    test('разлетаются во все стороны, а не веером в одну', () {
      final sparks = sparkBurst(Random(5));

      expect(sparks.any((s) => s.dx > 0), isTrue);
      expect(sparks.any((s) => s.dx < 0), isTrue);
      expect(sparks.any((s) => s.dy > 0), isTrue);
      expect(sparks.any((s) => s.dy < 0), isTrue);
    });

    test('направления различны: это брызги, а не одна искра восемь раз', () {
      final angles = sparkBurst(Random(11)).map((s) => s.direction).toSet();

      expect(angles, hasLength(8));
    });

    // Восемь ровных лучей — тоже восемь разных направлений, и предыдущий
    // тест их пропускает. Ровные не зависели бы от сида вовсе.
    test('направления зависят от сида, а не стоят ровными лучами', () {
      expect(
        sparkBurst(Random(1)).map((s) => s.direction),
        isNot(sparkBurst(Random(2)).map((s) => s.direction)),
      );
    });

    test('дальность у искр разная, а не у всех одна', () {
      final reaches = sparkBurst(Random(9)).map((s) => s.distance).toSet();

      expect(
        reaches,
        hasLength(8),
        reason: 'одинаковый разлёт читается как ровное кольцо, а не брызги',
      );
    });

    test('числа из SPEC: радиус искры и толщина следа', () {
      expect(sparkRadius, 3);
      expect(trailWidth, 4);
      expect(halfSpread, 24);
    });
  });

  group('Половинки разрезанного объекта', () {
    /// Две половинки на экране: центры считаются через getRect, потому что
    /// расхождение живёт в матрице Transform, а не в раскладке.
    Future<List<Rect>> halves(WidgetTester tester, double progress) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: wordarcadeTheme(),
          home: Scaffold(
            body: Center(
              child: SlicedObject(
                label: 'перевод',
                state: ObjectState.correct,
                angle: 0,
                progress: progress,
              ),
            ),
          ),
        ),
      );
      return find
          .byType(FlyingObject)
          .evaluate()
          .map((e) => tester.getRect(find.byWidget(e.widget)))
          .toList();
    }

    testWidgets('расходятся поперёк линии реза, а не вдоль', (tester) async {
      final parts = await halves(tester, 1);

      expect(parts, hasLength(2));
      expect(
        (parts[0].center.dy - parts[1].center.dy).abs(),
        closeTo(2 * halfSpread, 0.5),
        reason: 'рез горизонтальный — половинки расходятся по вертикали',
      );
      expect(
        parts[0].center.dx,
        closeTo(parts[1].center.dx, 0.5),
        reason: 'вдоль реза они просто разъехались бы по той же прямой',
      );
    });

    testWidgets('на старте подсветки ещё вместе', (tester) async {
      final parts = await halves(tester, 0);

      expect(parts[0].center.dy, closeTo(parts[1].center.dy, 0.5));
    });

    testWidgets('тают: к концу подсветки их не видно', (tester) async {
      await halves(tester, 0.2);
      final early = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((o) => o.opacity)
          .reduce(min);

      await halves(tester, 0.8);
      final late = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((o) => o.opacity)
          .reduce(min);

      expect(late, lessThan(early));
      expect(late, lessThan(0.3));
    });
  });
}
