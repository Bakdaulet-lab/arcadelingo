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

import 'dart:math';
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

final _spaces = RegExp(r'\s+');

const _laneClearance = objectRadius * 2 + 10;
const _threeTierHeight = 350;

/// Ширина мишени с запасом на целое слово или несколько строк фразы.
/// На низком поле две боковые мишени должны помещаться рядом.
double targetWidth(String label, Size field) {
  final words = label.split(_spaces);
  final longest = words.fold(0, (n, word) => max(n, word.runes.length));
  final columns = max(longest, (label.runes.length / 2.3).ceil());
  if (columns <= 7) return objectRadius * 2;
  return (22.0 + columns * 8).clamp(
    objectRadius * 2,
    max(
      objectRadius * 2,
      min(236.0, field.width * (field.height >= _threeTierHeight ? .70 : .475)),
    ),
  );
}

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
  bool wide = false,
}) {
  if (slot < 0 || slot >= laneFractions.length) {
    throw ArgumentError.value(
      slot,
      'slot',
      'дорожки 0..${laneFractions.length - 1}',
    );
  }
  if (wide && slot != 1) {
    // Широкие мишени летят на разных высотах. Если высоты мало, две
    // боковые вдвое уже поля и могут лететь рядом под центральной.
    final tall = height >= _threeTierHeight;
    final clearance = _launchOffset(slot, height);
    final separation =
        tall
            ? max(_laneClearance, height * .14) * (slot == 0 ? 1 : 2)
            : max(clearance, height * (slot == 0 ? .20 : .12));
    final inset = tall ? .36 : .245;
    return NinjaFlight(
      lane: (slot == 0 ? inset : 1 - inset) * width,
      drift: (slot == 0 ? 1 : -1) * (tall ? .018 : .005) * width,
      apex: height * apexFractions[1] + clearance - separation,
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

double _launchOffset(int slot, double height) => switch (slot) {
  1 => 0,
  2 when height >= _threeTierHeight => _laneClearance * 2,
  _ => _laneClearance,
};

/// Ход времени замедляется у вершины. Производная нужна половинкам,
/// чтобы их скорость при разрезе совпала с видимой скоростью мишени.
({double time, double rate}) _flightClock(double t) {
  const span = .2;
  const strength = .46;
  final offset = t - .5;
  final u = offset / span;
  if (u.abs() >= 1) return (time: t, rate: 1);
  final q = 1 - u * u;
  return (
    time: t - strength * offset * q * q * q,
    rate: 1 - strength * q * q * (1 - 7 * u * u),
  );
}

/// Где объект в долю полёта [t].
///
/// Горизонтальный дрейф и парабола используют общие часы полёта.
/// Вершина остаётся на середине времени, даже с замедлением.
Offset trajectory({
  required double t,
  required double lane,
  required double drift,
  required double apex,
  required double bottom,
}) {
  final time = _flightClock(t).time;
  return Offset(lane + drift * time, bottom - apex * 4 * time * (1 - time));
}

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
  bool wide = false,
}) {
  final bottom = flightBottom(height);
  return [
    for (final slot in laneSlotsFor(count))
      _positionOnSlot(
        slot,
        t: t,
        width: width,
        height: height,
        bottom: bottom,
        wide: wide,
      ),
  ];
}

/// Где объект дорожки [slot] в долю полёта [t].
Offset _positionOnSlot(
  int slot, {
  required double t,
  required double width,
  required double height,
  required double bottom,
  required bool wide,
}) {
  final flight = flightForSlot(slot, width: width, height: height, wide: wide);
  return trajectory(
    t: t,
    lane: flight.lane,
    drift: flight.drift,
    apex: flight.apex,
    bottom: bottom + (wide ? _launchOffset(slot, height) : 0),
  );
}

/// Скорость объекта [index] волны из [count] в долю полёта [t], в
/// пикселях поля в секунду, при полёте длиной [duration].
///
/// Производная [trajectory] с учётом хода часов у вершины.
/// Её наследуют половинки мишени в момент реза.
Offset waveVelocity({
  required int count,
  required int index,
  required double t,
  required double width,
  required double height,
  required Duration duration,
  bool wide = false,
}) {
  final slot = laneSlotsFor(count)[index];
  final flight = flightForSlot(slot, width: width, height: height, wide: wide);
  return trajectoryVelocity(
    t: t,
    drift: flight.drift,
    apex: flight.apex,
    duration: duration,
  );
}

Offset trajectoryVelocity({
  required double t,
  required double drift,
  required double apex,
  required Duration duration,
}) {
  final clock = _flightClock(t);
  final seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
  return Offset(drift, -apex * 4 * (1 - 2 * clock.time)) *
      (clock.rate / seconds);
}
