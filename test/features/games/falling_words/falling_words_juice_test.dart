// Решения джуса без дерева виджетов: порог «в последний момент», форма
// тряски, выбор отклика для руки, тон фона от серии.
//
// Литералы, а не константы из lib/: тест обязан быть независимой сверкой
// со SPEC.md → «Джус», иначе переименованная константа подтвердит сама
// себя. Порог 0.85 пишется здесь микросекундами (5 100 000 из 6 000 000),
// потому что ровно так его и считает реализация — целыми, без float.
//
// Чего здесь нет: того, что эти функции кто-то вызывает в нужный момент и
// применяет к нужной части экрана. Это falling_words_game_test.dart — там
// нужен tester.

import 'dart:math';

import 'package:arcadelingo/features/games/falling_words/falling_words_juice.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Насколько цвет [b] ушёл от цвета [a]. Грубая мера, и её хватает: нужна
/// только монотонность, а не абсолютная величина.
double _distance(Color a, Color b) =>
    sqrt(pow(a.r - b.r, 2) + pow(a.g - b.g, 2) + pow(a.b - b.b, 2));

/// Контраст по WCAG 2.1. Считается здесь, а не берётся с виджета: так
/// проверка не зависит от того, каким виджетом фон в итоге нарисован.
double _contrast(Color fg, Color bg) {
  final first = fg.computeLuminance();
  final second = bg.computeLuminance();
  return (max(first, second) + 0.05) / (min(first, second) + 0.05);
}

void main() {
  group('«В последний момент»: порог', () {
    test('ровно 85% лимита — уже последний момент', () {
      expect(
        isNearMiss(
          responseTime: const Duration(microseconds: 5100000),
          timeLimit: const Duration(seconds: 6),
        ),
        isTrue,
        reason: 'SPEC говорит «последние 15%», то есть граница включительно',
      );
    });

    test('микросекундой раньше — ещё нет', () {
      expect(
        isNearMiss(
          responseTime: const Duration(microseconds: 5099999),
          timeLimit: const Duration(seconds: 6),
        ),
        isFalse,
        reason: 'на границе не должно быть люфта в пользу игрока',
      );
    });

    test('порог в долях, а не в секундах: на полу 3 с окно вдвое уже', () {
      expect(
        isNearMiss(
          responseTime: const Duration(microseconds: 2550000),
          timeLimit: const Duration(seconds: 3),
        ),
        isTrue,
      );
      expect(
        isNearMiss(
          responseTime: const Duration(microseconds: 2549999),
          timeLimit: const Duration(seconds: 3),
        ),
        isFalse,
      );
      expect(
        isNearMiss(
          responseTime: const Duration(microseconds: 2550000),
          timeLimit: const Duration(seconds: 6),
        ),
        isFalse,
        reason:
            'то же время при вдвое большем лимите — обычный быстрый ответ; '
            'порог, заданный секундами, съедался бы комбо-ускорением',
      );
    });

    test('нулевой лимит → не последний момент, а не деление на ноль', () {
      expect(
        isNearMiss(responseTime: Duration.zero, timeLimit: Duration.zero),
        isFalse,
      );
      expect(
        isNearMiss(
          responseTime: const Duration(seconds: 1),
          timeLimit: Duration.zero,
        ),
        isFalse,
      );
    });

    test('мгновенный ответ — не последний момент', () {
      expect(
        isNearMiss(
          responseTime: Duration.zero,
          timeLimit: const Duration(seconds: 6),
        ),
        isFalse,
      );
    });

    test('время ответа больше лимита → да, и без броска', () {
      expect(
        isNearMiss(
          responseTime: const Duration(seconds: 7),
          timeLimit: const Duration(seconds: 6),
        ),
        isTrue,
        reason:
            'этот случай сторожит игра своим ArgumentError; функция джуса '
            'второго стража не заводит',
      );
    });
  });

  group('Тряска', () {
    test('нулевой кадр — полная амплитуда: удар бьёт, а не разгоняется', () {
      expect(shakeIntensity(0), closeTo(1, 1e-9));
    });

    test('на конце ровно ноль: экран не остаётся сдвинутым', () {
      expect(shakeIntensity(1), closeTo(0, 1e-9));
    });

    test('шесть полуразмахов, и каждый следующий слабее', () {
      // Три полных колебания за окно — экстремумы стоят в долях k/6.
      final peaks = [for (var k = 0; k <= 6; k++) shakeIntensity(k / 6).abs()];

      for (var k = 1; k < peaks.length; k++) {
        expect(
          peaks[k],
          lessThan(peaks[k - 1]),
          reason: 'пик $k не слабее предыдущего — это колебание, не затухание',
        );
      }
      expect(peaks.last, closeTo(0, 1e-9));
    });

    test('знак меняется: это тряска, а не уплывание вбок', () {
      final values = [for (var i = 0; i <= 200; i++) shakeIntensity(i / 200)];

      expect(values.any((v) => v > 0.1), isTrue);
      expect(
        values.any((v) => v < -0.1),
        isTrue,
        reason: 'без ухода в минус экран просто отъехал бы вправо и вернулся',
      );
    });

    test('за единицу не выходит: 8 dp остаются 8 dp', () {
      for (var i = 0; i <= 200; i++) {
        expect(
          shakeIntensity(i / 200).abs(),
          lessThanOrEqualTo(1),
          reason: 'огибающая обязана быть не выше единицы на всём окне',
        );
      }
    });

    test('вне 0…1 зажимается в края, а не продолжает колебаться', () {
      expect(shakeIntensity(1.5), closeTo(0, 1e-9));
      expect(shakeIntensity(-1), closeTo(1, 1e-9));
    });
  });

  group('Хаптика', () {
    test('промах и таймаут — тяжёлый отклик при любой серии', () {
      expect(
        hapticFor(correct: false, combo: 0, nearMiss: false),
        Haptic.heavy,
      );
      expect(hapticFor(correct: false, combo: 0, nearMiss: true), Haptic.heavy);
      expect(
        hapticFor(correct: false, combo: 10, nearMiss: false),
        Haptic.heavy,
      );
    });

    test('обычный верный ответ — лёгкий', () {
      expect(hapticFor(correct: true, combo: 1, nearMiss: false), Haptic.light);
    });

    test('серия: четвёртый верный ещё лёгкий, пятый уже средний', () {
      expect(hapticFor(correct: true, combo: 4, nearMiss: false), Haptic.light);
      expect(
        hapticFor(correct: true, combo: 5, nearMiss: false),
        Haptic.medium,
      );
      expect(
        hapticFor(correct: true, combo: 12, nearMiss: false),
        Haptic.medium,
      );
    });

    test('ответ в последний момент слышен рукой с первого же', () {
      expect(
        hapticFor(correct: true, combo: 1, nearMiss: true),
        Haptic.medium,
        reason: 'бонус, который ничем не отзывается, игрок не заметит',
      );
    });

    test('удача никогда не звучит как провал', () {
      for (final combo in [1, 4, 5, 20]) {
        expect(
          hapticFor(correct: true, combo: combo, nearMiss: true),
          isNot(Haptic.heavy),
          reason:
              'тяжёлый отклик занят потерей жизни: иначе рука не отличит '
              'победу от поражения — SPEC, «Джус»',
        );
      }
    });
  });

  group('Тон фона от серии', () {
    // Схема приложения, а не своя копия. С копией закон о контрасте сторожил
    // бы палитру, которой никто не видит: сменили тему — тесты зелёные,
    // экран нечитаемый.
    final scheme = wordarcadeTheme().colorScheme;

    test('до серии 3 фон чистый', () {
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
        reason:
            'нижняя граница потолка: смешение, которого не видно, — не '
            'награда, а просто трата — SPEC, «Джус»',
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
    final scheme = wordarcadeTheme().colorScheme;

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
  });

  group('Тон поля — градиент, а не заливка', () {
    final scheme = wordarcadeTheme().colorScheme;

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
        reason:
            'схлопнутая растяжка — это та же жёсткая граница, из-за которой '
            'поле читалось панелью на голденах 0.9',
      );
      expect(stops[2], lessThan(0.9));
      expect(
        stops[1],
        closeTo(1 - stops[2], 1e-9),
        reason: 'края симметричны: стык и с HUD, и с кнопками одинаков',
      );
    });

    test('градиент вертикальный: горизонтальный спорил бы с падением', () {
      final gradient = comboGradient(scheme, 8);

      expect(gradient.begin, Alignment.topCenter);
      expect(gradient.end, Alignment.bottomCenter);
    });
  });
}
