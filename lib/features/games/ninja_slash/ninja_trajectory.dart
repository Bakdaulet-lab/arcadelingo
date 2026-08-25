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
List<int> laneSlotsFor(int count) => throw UnimplementedError();

/// Параметры полёта для дорожки [slot] на поле [width] × [height].
NinjaFlight flightForSlot(
  int slot, {
  required double width,
  required double height,
}) => throw UnimplementedError();

/// Нижняя кромка полёта: объект стартует и садится под ней, а не на ней.
double flightBottom(double height) => throw UnimplementedError();

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
}) => throw UnimplementedError();
