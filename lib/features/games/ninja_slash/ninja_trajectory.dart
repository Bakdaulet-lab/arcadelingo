/// Куда и как летят объекты волны: дорожки, апексы, дрейф и позиция как
/// функция доли полёта.
///
/// Здесь нет ни времени, ни контроллера — только геометрия. Время приносит
/// виджет одним `AnimationController` с `AnimationBehavior.preserve`, и это
/// исполненный вердикт по Flame (`docs/dev/context.md`): собственный игровой
/// цикл сломал бы паузу при сворачивании.
///
/// Числа — `SPEC.md`, раздел «Ниндзя-слэш» → «Волна» и «Траектория».
library;

import 'dart:ui';

/// Доли ширины поля, на которых стоят три дорожки.
const List<double> laneFractions = [0.20, 0.50, 0.80];

/// Высота подъёма в долях высоты поля — в порядке дорожек.
///
/// Три разных, а не одна: на равных апексах три объекта в момент `t = 0.5`
/// выстраиваются в строку и читаются как ряд кнопок, только движущийся.
const List<double> apexFractions = [0.62, 0.78, 0.70];

/// Сдвиг по x за весь полёт в долях ширины поля. Знак чередуется по
/// дорожкам.
const double driftFraction = 0.06;

/// Радиус объекта в логических пикселях.
const double objectRadius = 34;

/// Параметры полёта одного объекта в единицах поля.
class NinjaFlight {
  const NinjaFlight({
    required this.lane,
    required this.drift,
    required this.apex,
  });

  /// x старта и посадки.
  final double lane;

  /// На сколько объект уедет по x за весь полёт.
  final double drift;

  /// Высота подъёма над нижней кромкой.
  final double apex;
}

/// Дорожки для волны из [count] объектов.
///
/// Симметрично, а не первые подряд: один объект — по центру, два — по краям
/// (`SPEC.md`). Волна из одного объекта на дорожке 0.20 выглядела бы
/// поломкой вёрстки, а не решением.
List<int> laneSlotsFor(int count) {
  if (count < 0 || count > laneFractions.length) {
    throw ArgumentError.value(
      count,
      'count',
      'дорожек всего ${laneFractions.length}',
    );
  }
  return switch (count) {
    0 => const [],
    1 => const [1],
    2 => const [0, 2],
    _ => const [0, 1, 2],
  };
}

/// Параметры полёта для дорожки [slot] на поле [width] × [height].
NinjaFlight flightForSlot(
  int slot, {
  required double width,
  required double height,
}) {
  if (slot < 0 || slot >= laneFractions.length) {
    throw ArgumentError.value(
      slot,
      'slot',
      'дорожки 0..${laneFractions.length - 1}',
    );
  }
  return NinjaFlight(
    lane: laneFractions[slot] * width,
    // Знак чередуется по дорожкам: без этого соседи сносились бы в одну
    // сторону и расстояние между ними за полёт не менялось бы вовсе.
    drift: driftFraction * width * (slot.isEven ? 1 : -1),
    apex: apexFractions[slot] * height,
  );
}

/// Нижняя кромка полёта: объект стартует и садится под ней, а не на ней.
double flightBottom(double height) => height + objectRadius;

/// Где объект в долю полёта [t].
///
/// `y = bottom − apex · 4t(1 − t)`: множитель `4t(1 − t)` — парабола,
/// нормированная на единицу в вершине, поэтому [apex] и есть высота
/// подъёма, а не вчетверо меньшая. Вершина ровно при `t = 0.5`.
Offset trajectory({
  required double t,
  required double lane,
  required double drift,
  required double apex,
  required double bottom,
}) => Offset(lane + drift * t, bottom - apex * 4 * t * (1 - t));

/// Где стоят объекты волны из [count] штук в долю полёта [t] на поле
/// [width] × [height].
///
/// Одна функция на двоих: по ней поле рисует объекты, и по ней же игра
/// проверяет, что задел рез. Рисовать одно, а резать другое здесь
/// невозможно по построению — а разъехаться две копии этой арифметики
/// успели бы к первому же изменению апексов.
List<Offset> wavePositions({
  required int count,
  required double t,
  required double width,
  required double height,
}) {
  final bottom = flightBottom(height);
  return [
    for (final slot in laneSlotsFor(count))
      _positionOnSlot(slot, t: t, width: width, height: height, bottom: bottom),
  ];
}

/// Где объект дорожки [slot] в долю полёта [t].
Offset _positionOnSlot(
  int slot, {
  required double t,
  required double width,
  required double height,
  required double bottom,
}) {
  final flight = flightForSlot(slot, width: width, height: height);
  return trajectory(
    t: t,
    lane: flight.lane,
    drift: flight.drift,
    apex: flight.apex,
    bottom: bottom,
  );
}

/// Скорость объекта [index] волны из [count] в долю полёта [t], в
/// пикселях поля в секунду, при полёте длиной [duration].
///
/// Производная [trajectory] по времени: `dx/dt = drift`,
/// `dy/dt = −apex · 4(1 − 2t)`, обе делённые на длину полёта. Нужна
/// половинкам разрезанного объекта — они наследуют её в момент реза. Здесь,
/// а не в украшениях, потому что это производная той же параболы, и две
/// копии формулы разошлись бы молча.
Offset waveVelocity({
  required int count,
  required int index,
  required double t,
  required double width,
  required double height,
  required Duration duration,
}) {
  final slot = laneSlotsFor(count)[index];
  final flight = flightForSlot(slot, width: width, height: height);
  final seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
  return Offset(flight.drift, -flight.apex * 4 * (1 - 2 * t)) / seconds;
}
