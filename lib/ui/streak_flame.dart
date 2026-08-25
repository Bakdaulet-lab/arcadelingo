/// Решения про пламя стрик-карточки: какого размера и какого настроения.
///
/// Здесь нет ни одной команды рисования — только ответы на два вопроса,
/// которые задаёт `CustomPaint`. Разделение не церемония: пороги ступеней
/// проверяются таблицей за миллисекунды, а картинка — голденом, который
/// снимается на другой машине и принимается человеком. Смешав их, пришлось бы
/// проверять арифметику порогов картинками.
///
/// Числа — из `SPEC.md`, раздел «Стрик-карточка», и написаны там до этого
/// файла.
library;

import 'package:arcadelingo/domain/streak/streak_view.dart';
import 'package:flutter/material.dart';

/// Ступень пламени. Зависит **только от длины серии**.
enum FlameTier {
  /// Серии нет: контур без числа.
  none,

  /// 1–2 дня.
  spark,

  /// 3–6 дней.
  steady,

  /// 7–13 дней.
  blaze,

  /// 14 и выше: максимум, единственная ступень с ореолом.
  inferno,
}

/// Настроение пламени. Про сегодняшний день, от ступени не зависит.
enum FlameMood {
  /// Сегодня сыграно: горит.
  lit,

  /// Сегодня ещё не сыграно, пропуска не было: контур.
  unlit,

  /// Пропущен ровно день, и заморозка его прикроет: горит тревожно.
  atRisk,
}

/// Высота пламени по ступени, dp.
const Map<FlameTier, double> flameHeights = {
  FlameTier.none: 64,
  FlameTier.spark: 72,
  FlameTier.steady: 96,
  FlameTier.blaze: 120,
  FlameTier.inferno: 140,
};

/// Кегль числа дней по ступени, dp. У [FlameTier.none] числа нет.
const Map<FlameTier, double> flameDigitSizes = {
  FlameTier.spark: 26,
  FlameTier.steady: 34,
  FlameTier.blaze: 42,
  FlameTier.inferno: 48,
};

/// Ширина пламени относительно высоты.
const double flameAspect = 0.72;

/// Радиус ореола относительно высоты пламени.
const double flameHaloRadius = 1.35;

/// Прозрачность ореола в центре.
const double flameHaloAlpha = 0.18;

/// Насколько край уходит к малиновому, когда серия под угрозой.
const double flameRiskBlend = 0.55;

/// Ступень по длине серии [days].
///
/// Пороги — из SPEC: 0 · 1–2 · 3–6 · 7–13 · 14+. Отрицательных серий не
/// бывает (инвариант `StreakState`), но ноль и меньше дают одну и ту же
/// ступень: функция не место сторожить чужой инвариант.
FlameTier flameTier(int days) {
  if (days <= 0) return FlameTier.none;
  if (days <= 2) return FlameTier.spark;
  if (days <= 6) return FlameTier.steady;
  if (days <= 13) return FlameTier.blaze;
  return FlameTier.inferno;
}

/// Настроение по сегодняшнему состоянию серии.
FlameMood flameMood(StreakView view) {
  // Порядок здесь ни на что не влияет, и это проверено мутацией: `streakAsOf`
  // не выдаёт состояний, где истинны оба признака — «сыграно» значит
  // «сегодня уже засчитано», а тревога значит «между последним засчитанным и
  // сегодня зияет день». Написан он так, как читается: сначала хорошее.
  // Инвариант закреплён тестом, мутация из списка убрана как театр.
  if (view.playedToday) return FlameMood.lit;
  if (view.freezeWillCover) return FlameMood.atRisk;
  return FlameMood.unlit;
}

/// Цвет края пламени: янтарь, а под угрозой — сведённый к малиновому.
Color flameEdgeColor(ColorScheme scheme, FlameMood mood) =>
    mood == FlameMood.atRisk
        ? Color.lerp(scheme.tertiary, scheme.error, flameRiskBlend)!
        : scheme.tertiary;

/// Цвет числа дней.
///
/// На горящем пламени — цвет фона: число вырезано из огня, а не положено
/// сверху. На незажжённом заливки нет, вырезать не из чего, и число берёт
/// цвет обычной подписи — иначе оно стало бы невидимым на тёмной карточке.
/// Пробел найден при рисовании и дописан в SPEC отдельной строкой.
Color flameDigitColor(ColorScheme scheme, FlameMood mood) =>
    mood == FlameMood.unlit ? scheme.onSurfaceVariant : scheme.surface;
