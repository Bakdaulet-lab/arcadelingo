// Решения про пламя: ступень, настроение и цвета.
//
// Пороги — из SPEC, и проверяются обе стороны каждого. Картинку эти тесты не
// видят вовсе: она в голденах, а здесь арифметика, которую картинкой
// проверять дорого и бессмысленно.

import 'dart:math';

import 'package:arcadelingo/ui/streak_flame.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ritual_views.dart';

/// Контраст по WCAG 2.1, считается здесь, а не берётся с виджета.
double _contrast(Color fg, Color bg) {
  final first = fg.computeLuminance();
  final second = bg.computeLuminance();
  return (max(first, second) + 0.05) / (min(first, second) + 0.05);
}

ColorScheme get _scheme => wordarcadeTheme().colorScheme;

void main() {
  group('Ступень по длине серии', () {
    test('нет серии — нет пламени', () {
      expect(flameTier(0), FlameTier.none);
    });

    test('обе стороны порога 0/1', () {
      expect(flameTier(0), FlameTier.none);
      expect(flameTier(1), FlameTier.spark);
    });

    test('обе стороны порога 2/3', () {
      expect(flameTier(2), FlameTier.spark);
      expect(flameTier(3), FlameTier.steady);
    });

    test('обе стороны порога 6/7', () {
      expect(flameTier(6), FlameTier.steady);
      expect(flameTier(7), FlameTier.blaze);
    });

    test('обе стороны порога 13/14', () {
      expect(flameTier(13), FlameTier.blaze);
      expect(flameTier(14), FlameTier.inferno);
    });

    test('дальше максимума ступеней нет', () {
      expect(flameTier(100), FlameTier.inferno);
      expect(flameTier(3650), FlameTier.inferno);
    });

    // Отрицательных серий не бывает — это инвариант StreakState. Функция
    // чужой инвариант не сторожит и просто не выделяет их в свой случай.
    test('отрицательное — та же ступень, что и ноль', () {
      expect(flameTier(-1), FlameTier.none);
    });
  });

  group('Размеры растут вместе со ступенью', () {
    test('высота строго возрастает', () {
      final heights = [
        for (final tier in FlameTier.values) flameHeights[tier]!,
      ];
      for (var i = 1; i < heights.length; i++) {
        expect(
          heights[i],
          greaterThan(heights[i - 1]),
          reason: 'вся суть ступеней в том, что дальше есть куда расти',
        );
      }
    });

    test('кегль числа растёт вместе с высотой', () {
      const lit = [
        FlameTier.spark,
        FlameTier.steady,
        FlameTier.blaze,
        FlameTier.inferno,
      ];
      for (var i = 1; i < lit.length; i++) {
        expect(
          flameDigitSizes[lit[i]]!,
          greaterThan(flameDigitSizes[lit[i - 1]]!),
        );
      }
    });

    test('у ступени без пламени числа нет', () {
      expect(flameDigitSizes[FlameTier.none], isNull);
    });

    test('числа из SPEC, а не из головы', () {
      expect(flameHeights[FlameTier.none], 64);
      expect(flameHeights[FlameTier.spark], 72);
      expect(flameHeights[FlameTier.steady], 96);
      expect(flameHeights[FlameTier.blaze], 120);
      expect(flameHeights[FlameTier.inferno], 140);
      expect(flameAspect, 0.72);
    });
  });

  group('Настроение по сегодняшнему дню', () {
    test('сыграно — горит', () {
      expect(flameMood(ritualView(days: 4)), FlameMood.lit);
    });

    test('не сыграно, пропуска не было — контур', () {
      expect(flameMood(ritualView(days: 4, lastOffset: 1)), FlameMood.unlit);
    });

    test('пропущен день и заморозка спасёт — тревога', () {
      expect(
        flameMood(ritualView(days: 4, lastOffset: 2, freezes: 1)),
        FlameMood.atRisk,
      );
    });

    test('серии нет — контур, а не тревога', () {
      expect(flameMood(ritualView()), FlameMood.unlit);
    });

    test('серия оборвана без заморозки — контур', () {
      expect(flameMood(ritualView(days: 4, lastOffset: 2)), FlameMood.unlit);
    });

    // Проверялся «порядок условий», а порядок здесь ни на что не влияет:
    // `streakAsOf` не выдаёт состояний, где истинны оба признака. Мутация
    // «поменять их местами» это и показала — она осталась зелёной.
    // Настоящий инвариант ниже, и он наблюдаем.
    test('сыграно и тревога не бывают одновременно', () {
      final views = [
        ritualView(),
        ritualView(days: 4),
        ritualView(days: 4, lastOffset: 1),
        ritualView(days: 4, lastOffset: 2),
        ritualView(days: 4, lastOffset: 2, freezes: 1),
        ritualView(days: 6, daysSinceFreeze: 1, frozenOffset: 1),
        ritualView(days: 9, lastOffset: 5, freezes: 1),
      ];

      for (final view in views) {
        expect(
          view.playedToday && view.freezeWillCover,
          isFalse,
          reason:
              'сыграно значит «сегодня уже засчитано», тревога — «между '
              'последним засчитанным и сегодня зияет день»: $view',
        );
      }
    });
  });

  group('Цвета', () {
    test('край горящего пламени — янтарь', () {
      expect(flameEdgeColor(_scheme, FlameMood.lit), _scheme.tertiary);
    });

    test('край тревожного уходит к малиновому, но не становится им', () {
      final edge = flameEdgeColor(_scheme, FlameMood.atRisk);

      expect(edge, isNot(_scheme.tertiary));
      expect(edge, isNot(_scheme.error));
      expect(edge.r, greaterThan(0.5), reason: 'это всё ещё огонь, не крест');
    });

    test('число на горящем пламени — цвета фона: вырезано, а не положено', () {
      expect(flameDigitColor(_scheme, FlameMood.lit), _scheme.surface);
      expect(flameDigitColor(_scheme, FlameMood.atRisk), _scheme.surface);
    });

    test('число на незажжённом видно на карточке', () {
      expect(
        flameDigitColor(_scheme, FlameMood.unlit),
        isNot(_scheme.surface),
        reason: 'цвет фона на фоне карточки был бы невидим',
      );
    });
  });

  group('Закон о контрасте', () {
    test('число на ядре пламени — не ниже 4.5:1', () {
      expect(
        _contrast(flameDigitColor(_scheme, FlameMood.lit), _scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('число на незажжённом пламени — не ниже 4.5:1', () {
      expect(
        _contrast(
          flameDigitColor(_scheme, FlameMood.unlit),
          _scheme.surfaceContainerHighest,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('буква дня на кружке — не ниже 4.5:1', () {
      expect(
        _contrast(_scheme.onSurfaceVariant, _scheme.surfaceContainerHighest),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('галочка на сыгранном кружке — не ниже 3:1', () {
      // Значок, а не текст: WCAG требует 3:1 для графических элементов.
      expect(
        _contrast(_scheme.primary, _scheme.primaryContainer),
        greaterThanOrEqualTo(3),
      );
    });
  });
}
