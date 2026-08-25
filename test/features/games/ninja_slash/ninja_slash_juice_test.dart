// Решения джуса ниндзя-слэша без дерева виджетов: порог «в последний
// момент», форма тряски, выбор отклика для руки.
//
// Литералы, а не константы из lib/: тест обязан быть независимой сверкой
// со SPEC.md → «Ниндзя-слэш» → «Джус», иначе переименованная константа
// подтвердит сама себя. Порог 0.85 пишется здесь микросекундами
// (2 975 000 из 3 500 000), потому что ровно так его и считает реализация —
// целыми, без float.
//
// Файл — копия falling_words_juice_test.dart с числами полёта вместо чисел
// падения. Копия, а не общий помощник: игры — острова (правило 5), и
// дублирование здесь названо вслух как цена, а не спрятано.
//
// Чего здесь нет: того, что эти функции кто-то вызывает в нужный момент и
// применяет к нужной части экрана. Это тесты виджета — там нужен tester.

import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_juice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('«В последний момент»: порог', () {
    test('ровно 85% полёта — уже последний момент', () {
      expect(
        isNearMiss(
          responseTime: const Duration(microseconds: 2975000),
          timeLimit: const Duration(milliseconds: 3500),
        ),
        isTrue,
        reason: 'SPEC говорит «последние 15%», то есть граница включительно',
      );
    });

    test('микросекундой раньше — ещё нет', () {
      expect(
        isNearMiss(
          responseTime: const Duration(microseconds: 2974999),
          timeLimit: const Duration(milliseconds: 3500),
        ),
        isFalse,
        reason: 'на границе не должно быть люфта в пользу игрока',
      );
    });

    test('порог в долях, а не в секундах: на полу 2 с окно уже', () {
      expect(
        isNearMiss(
          responseTime: const Duration(microseconds: 1700000),
          timeLimit: const Duration(seconds: 2),
        ),
        isTrue,
      );
      expect(
        isNearMiss(
          responseTime: const Duration(microseconds: 1699999),
          timeLimit: const Duration(seconds: 2),
        ),
        isFalse,
      );
      expect(
        isNearMiss(
          responseTime: const Duration(microseconds: 1700000),
          timeLimit: const Duration(milliseconds: 3500),
        ),
        isFalse,
        reason:
            'то же время при большем лимите — обычный быстрый рез; порог, '
            'заданный секундами, съедался бы комбо-ускорением',
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

    test('мгновенный рез — не последний момент', () {
      expect(
        isNearMiss(
          responseTime: Duration.zero,
          timeLimit: const Duration(milliseconds: 3500),
        ),
        isFalse,
      );
    });

    test('время реза больше лимита → да, и без броска', () {
      expect(
        isNearMiss(
          responseTime: const Duration(seconds: 4),
          timeLimit: const Duration(milliseconds: 3500),
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

    test('обычный верный рез — лёгкий', () {
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

    test('рез в последний момент слышен рукой с первого же', () {
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

  group('Числа из SPEC', () {
    test('порог — 17/20, награда — 3/2, серия для среднего отклика — 5', () {
      expect(nearMissNumerator, 17);
      expect(nearMissDenominator, 20);
      expect(nearMissBonusNumerator, 3);
      expect(nearMissBonusDenominator, 2);
      expect(comboHapticFrom, 5);
    });

    test('тряска — 300 мс, 8 dp, три колебания', () {
      expect(shakeTime, const Duration(milliseconds: 300));
      expect(shakeAmplitude, 8);
      expect(shakeOscillations, 3);
    });
  });
}
