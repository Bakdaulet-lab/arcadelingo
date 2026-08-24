/// Тема приложения — одна на всё, включая голден-тесты.
///
/// Вынесена из `app.dart` не ради опрятности. Голден обязан снимать ту самую
/// палитру, которую видит человек на телефоне; собранная в тесте копия
/// разошлась бы с приложением молча — при смене цветов эталоны остались бы
/// зелёными и при этом неправильными.
///
/// Палитра задана поимённо, а не выведена из зерна. `ColorScheme.fromSeed`
/// пастелит контейнеры при любом зерне: `primaryContainer` выходит бледным,
/// `surfaceContainerHighest` — почти тем же цветом, что фон. Насыщать зерно
/// бессмысленно, выйдет та же пастель другого оттенка. `fromSeed` оставлен
/// базой, чтобы роли, которых экраны не используют, остались осмысленными;
/// переопределены ровно те, что видно (задача 0.12).
library;

import 'package:flutter/material.dart';

/// Зерно, от которого достраиваются неиспользуемые роли.
const Color wordarcadeSeed = Color(0xFF3DFFC0);

/// Семейство. Файл — `assets/fonts/Rubik-Variable.ttf`, лицензия OFL 1.1
/// лежит рядом и уходит в `LicenseRegistry` из `main.dart`.
const String wordarcadeFont = 'Rubik';

/// Палитра «ночной автомат»: глубокий тёмный фон и два неоновых акцента.
///
/// Все текстовые пары замерены по WCAG и держат 4.5:1 — от 17.0 у слова на
/// поле до 4.8 у метки множителя над разогретым полем. Две самые тесные
/// пары — красное слово в паре промаха (5.8) и та самая метка; если они
/// покажутся слабыми, поднимать надо их светлоту, а не гасить фон.
final ColorScheme wordarcadeColors = ColorScheme.fromSeed(
  seedColor: wordarcadeSeed,
  brightness: Brightness.dark,
).copyWith(
  surface: const Color(0xFF0D0A12),
  onSurface: const Color(0xFFF2ECFF),
  onSurfaceVariant: const Color(0xFFA79CB8),
  surfaceContainerHighest: const Color(0xFF241E2E),
  outline: const Color(0xFF4A4159),
  primary: const Color(0xFF3DFFC0),
  onPrimary: const Color(0xFF00251A),
  primaryContainer: const Color(0xFF0A4A38),
  onPrimaryContainer: const Color(0xFF7FFFDA),
  error: const Color(0xFFFF3D71),
  onError: const Color(0xFF380012),
  errorContainer: const Color(0xFF5A0A24),
  onErrorContainer: const Color(0xFFFFB0C6),
  tertiary: const Color(0xFFFFC93D),
);

/// Вес для вариативного шрифта.
///
/// Обычный `fontWeight` на `Rubik` **не работает**: замерено — одна и та же
/// строка в `w400` и в `w700` выходит ровно одной ширины (111.20 против
/// 111.20), потому что ось `wght` от него не двигается. Через
/// `FontVariation` — 122.31. Без оси весь текст рисуется значением файла по
/// умолчанию, а у Rubik это Light 300, то есть тонким.
///
/// `fontWeight` при этом ставится тоже: он верен для запасных шрифтов и для
/// семантики, просто сам по себе ничего не решает. Проводку сторожит
/// канарейка в `test/golden/`.
TextStyle withWeight(TextStyle style, FontWeight weight) => style.copyWith(
  fontWeight: weight,
  fontVariations: [FontVariation('wght', weight.value.toDouble())],
);

/// Тема приложения.
///
/// [platform] нужен голденам: `Typography` выбирает семейство шрифта по
/// платформе, и эталон обязан сниматься в той конфигурации, в которой игра
/// живёт. Сегодня это ничего не меняет — `flutter test` выставляет
/// `FLUTTER_TEST`, и `defaultTargetPlatform` из-за этого и так равен
/// `android`, — так что мутацией пин не поймать. Он остаётся как явно
/// названная цель съёмки: то поведение живёт внутри `assert`. Приложение
/// параметр не передаёт — там платформа настоящая.
ThemeData wordarcadeTheme({TargetPlatform? platform}) {
  final base = ThemeData(
    colorScheme: wordarcadeColors,
    platform: platform,
    fontFamily: wordarcadeFont,
  );
  return base.copyWith(textTheme: _withAxis(base.textTheme));
}

/// Проставляет ось веса каждому стилю темы.
///
/// Иначе `Typography` расставила бы `fontWeight`, а на экране всё осталось
/// бы одним начертанием — тем самым Light 300.
TextTheme _withAxis(TextTheme theme) => TextTheme(
  displayLarge: _axis(theme.displayLarge),
  displayMedium: _axis(theme.displayMedium),
  displaySmall: _axis(theme.displaySmall),
  headlineLarge: _axis(theme.headlineLarge),
  headlineMedium: _axis(theme.headlineMedium),
  headlineSmall: _axis(theme.headlineSmall),
  titleLarge: _axis(theme.titleLarge),
  titleMedium: _axis(theme.titleMedium),
  titleSmall: _axis(theme.titleSmall),
  bodyLarge: _axis(theme.bodyLarge),
  bodyMedium: _axis(theme.bodyMedium),
  bodySmall: _axis(theme.bodySmall),
  labelLarge: _axis(theme.labelLarge),
  labelMedium: _axis(theme.labelMedium),
  labelSmall: _axis(theme.labelSmall),
);

TextStyle? _axis(TextStyle? style) =>
    style == null
        ? null
        : withWeight(style, style.fontWeight ?? FontWeight.w400);
