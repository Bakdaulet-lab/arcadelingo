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
}
