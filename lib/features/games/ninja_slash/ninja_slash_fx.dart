/// Физика и геометрия украшений ниндзя-слэша: след клинка, вращение и
/// вылет объектов, вспышка удара, половинки, искры, прилёт очков.
///
/// Здесь только числа и функции от них — ни виджетов, ни палитры, ни
/// контроллеров. Рисует всё это `ninja_slash_views.dart`, время приносит
/// `ninja_slash_game.dart` из своих трёх контроллеров, и ни один из них не
/// заведён ради украшений (правило 0.11). Функции чистые, поэтому «искры
/// не розетка» и «наклон не больше 25°» проверяются без дерева виджетов.
///
/// Это редакция после отказа в приёмке (`docs/dev/context.md`): энергия
/// Fruit Ninja, пересказанная нашим неоновым языком. Геймплей этот файл не
/// трогает — ни радиуса, ни порога, ни траекторий: только то, что видно.
///
/// Числа — `SPEC.md`, раздел «Ниндзя-слэш» → «Джус» → «Новое».
library;

import 'dart:math';

import 'package:flutter/animation.dart';

// ---------------------------------------------------------------- след ----

/// Ширина следа у головы, dp; к хвосту он сходит в остриё.
const double trailHeadWidth = 10;

/// Во сколько раз слой свечения шире следа.
const double trailGlowWidth = 2.4;

/// Альфа слоя свечения.
const double trailGlowAlpha = 0.45;

/// Размытие слоя свечения, dp.
const double trailGlowBlur = 6;

/// Во сколько раз ядро уже следа.
const double trailCoreWidth = 0.45;

/// Сколько живёт точка следа: дольше — размазня, короче — след не виден.
const Duration trailLife = Duration(milliseconds: 300);

/// Сколько точек жеста держит след. Список без предела рос бы всё время,
/// пока палец на экране.
const int trailPoints = 32;

/// Сколько проб кривой приходится на один отрезок ломаной.
const int trailSamplesPerSegment = 6;

/// Точка следа: где коснулись и когда — по часам полёта.
typedef TrailPoint = ({Offset at, Duration stamp});

/// Живая точка следа: где и насколько свежа — 1 только что, 0 на грани.
typedef TrailSample = ({Offset at, double freshness});

/// Что от следа осталось к моменту [now]: точки моложе [trailLife], каждая
/// со свежестью. Так след тает **с хвоста**: старые точки выбывают первыми,
/// а не весь след разом.
List<TrailSample> trailAlive(List<TrailPoint> points, Duration now) => [
  for (final point in points)
    if (now - point.stamp < trailLife)
      (
        at: point.at,
        freshness: (1 -
                (now - point.stamp).inMicroseconds / trailLife.inMicroseconds)
            .clamp(0.0, 1.0),
      ),
];

/// Сглаженная кривая по точкам следа: квадратичные Безье через середины
/// соседних отрезков, по [trailSamplesPerSegment] проб на отрезок. Первая
/// и последняя точки остаются на месте, свежесть интерполируется вместе с
/// позицией.
///
/// Кривая, а не ломаная, — главная причина вердикта «резьба очень прямая».
List<TrailSample> smoothTrail(List<TrailSample> points) {
  if (points.length < 2) return List.of(points);
  final out = <TrailSample>[points.first];
  var current = points.first;
  // Каждая внутренняя точка — контрольная: кривая идёт от середины одного
  // отрезка к середине следующего, огибая угол, а не проходя через него.
  for (var i = 1; i < points.length - 1; i++) {
    final control = points[i];
    final end = _between(points[i], points[i + 1], 0.5);
    for (var k = 1; k <= trailSamplesPerSegment; k++) {
      final u = k / trailSamplesPerSegment;
      final sample = (
        at: _quadratic(current.at, control.at, end.at, u),
        freshness: _lerp(current.freshness, end.freshness, u),
      );
      out.add(sample);
    }
    current = end;
  }
  // Последний отрезок — прямой до головы: она обязана остаться на месте,
  // иначе след отставал бы от пальца.
  for (var k = 1; k <= trailSamplesPerSegment; k++) {
    out.add(_between(current, points.last, k / trailSamplesPerSegment));
  }
  return out;
}

/// Ширина следа в пробе: [freshness] 0…1 и [along] — 0 у хвоста, 1 у
/// головы. Обе оси нужны: быстрый свайп даёт всем точкам одну свежесть, и
/// без [along] след был бы палкой одной толщины.
double trailWidthAt({required double freshness, required double along}) =>
    // Корень и по свежести, и по длине: линейное старение давало нитку уже
    // к середине жизни точки, а линейный сход к хвосту — нитку на большей
    // части следа. Клинок обязан быть клинком почти до самого острия.
    trailHeadWidth *
    sqrt(freshness.clamp(0.0, 1.0)) *
    sqrt(along.clamp(0.0, 1.0));

TrailSample _between(TrailSample a, TrailSample b, double u) => (
  at: Offset.lerp(a.at, b.at, u)!,
  freshness: _lerp(a.freshness, b.freshness, u),
);

Offset _quadratic(Offset a, Offset control, Offset b, double u) =>
    a * ((1 - u) * (1 - u)) + control * (2 * u * (1 - u)) + b * (u * u);

double _lerp(double a, double b, double u) => a + (b - a) * u;

// ------------------------------------------------------ вращение и вылет ----

/// Наклон к посадке — не меньше этого, иначе вращения не видно.
const double minSpinDegrees = 12;

/// **Предел наклона в любой фазе полёта.** Слово на объекте обязано
/// читаться — это учебная игра. Единственное декоративное число, которое
/// сторожит тест.
const double maxSpinDegrees = 25;

/// Угловая скорость объекта — наклон к посадке в радианах, знак случаен.
double spinFor(Random random) {
  final degrees =
      minSpinDegrees + random.nextDouble() * (maxSpinDegrees - minSpinDegrees);
  return (random.nextBool() ? 1 : -1) * degrees * pi / 180;
}

/// Наклон объекта в долю полёта [t]: линейно от нуля на старте, поэтому
/// предел достигается только у посадки, где объект уже уходит за кромку.
double objectTilt({required double spin, required double t}) =>
    spin * t.clamp(0.0, 1.0);

/// Какую долю полёта занимает scale-pop при вылете из-за кромки.
const double popFraction = 0.10;

/// С какого масштаба объект вылетает.
const double popStartScale = 0.5;

/// Масштаб объекта в долю полёта [t]: от [popStartScale] до 1 с перехлёстом
/// за первые [popFraction], дальше ровно 1.
double emergeScale(double t) {
  if (t >= popFraction) return 1;
  final u = (t / popFraction).clamp(0.0, 1.0);
  return popStartScale + (1 - popStartScale) * Curves.easeOutBack.transform(u);
}

// -------------------------------------------------------------- вспышка ----

/// Кольцо-ударная волна: радиус, толщина, жизнь.
const double ringStartRadius = 8;
const double ringEndRadius = 64;
const double ringStartStroke = 4;
const double ringEndStroke = 1;
const Duration ringLife = Duration(milliseconds: 200);

/// Радиус кольца в долю жизни [phase]: разбегается с замедлением, как волна.
double ringRadius(double phase) =>
    ringStartRadius +
    (ringEndRadius - ringStartRadius) *
        Curves.easeOutCubic.transform(phase.clamp(0.0, 1.0));

/// Толщина кольца в долю жизни [phase].
double ringStroke(double phase) =>
    _lerp(ringStartStroke, ringEndStroke, phase.clamp(0.0, 1.0));

/// Альфа кольца: 0.9 в момент удара, 0 к концу.
double ringAlpha(double phase) => 0.9 * (1 - phase.clamp(0.0, 1.0));

// ------------------------------------------------------------ гравитация ----

/// Одна на половинки и искры, dp/с². За [sliceLife] это 40 dp падения —
/// заметно, но не тяжело.
const double fxGravity = 900;

/// Сколько живут половинки, искры и след реза — ровно рез.
const Duration sliceLife = Duration(milliseconds: 300);

/// Сколько секунд прожито к доле [phase] от [sliceLife].
double _seconds(double phase) =>
    phase.clamp(0.0, 1.0) * sliceLife.inMicroseconds / 1e6;

/// На сколько dp упало тело за долю [phase] от [sliceLife].
double fallBy(double phase) {
  final seconds = _seconds(phase);
  return 0.5 * fxGravity * seconds * seconds;
}

// ------------------------------------------------------------- половинки ----

/// С какой скоростью половинки расходятся по нормали к резу, dp/с.
const double halfSpreadSpeed = 200;

/// На сколько поворачивается каждая половинка за свою жизнь, в градусах;
/// знак — по стороне.
const double halfSpinDegrees = 40;

/// Где половинка: смещение от места реза, поворот и прозрачность.
typedef HalfMotion = ({Offset offset, double rotation, double alpha});

/// Половинка [side] (±1) в долю [phase] жизни.
///
/// Расходятся поперёк реза под углом [angle], наследуют [velocity] полёта
/// в момент реза, падают под [fxGravity] и тают. Без наследования
/// половинки выглядели бы приклеенными: объект летел, а его куски — нет.
HalfMotion halfMotion({
  required double side,
  required double angle,
  required Offset velocity,
  required double phase,
}) {
  final p = phase.clamp(0.0, 1.0);
  final seconds = _seconds(p);
  final normal = Offset(-sin(angle), cos(angle));
  return (
    offset:
        normal * (side * halfSpreadSpeed * seconds) +
        velocity * seconds +
        Offset(0, fallBy(p)),
    rotation: side * halfSpinDegrees * pi / 180 * p,
    alpha: 1 - p,
  );
}

// ----------------------------------------------------------------- искры ----

/// Сколько искр даёт верный рез.
const int sparkCount = 14;

/// Разброс направления искры вокруг нормали к резу, в градусах.
const double sparkSpreadDegrees = 60;

/// Дальность разлёта, dp.
const double sparkMinReach = 40;
const double sparkMaxReach = 90;

/// Размер искры, dp.
const double sparkMinSize = 3;
const double sparkMaxSize = 6;

/// Насколько искра может быть подмешана к белому.
const double sparkMaxBrightness = 0.4;

/// Одна искра: куда, как далеко, какого размера и насколько ярче акцента.
class Spark {
  const Spark({
    required this.angle,
    required this.reach,
    required this.size,
    required this.brightness,
  });

  /// Направление в радианах.
  final double angle;

  /// Дальность на полном разлёте, dp.
  final double reach;

  /// Размер в момент рождения, dp.
  final double size;

  /// Доля белого в цвете, 0…[sparkMaxBrightness].
  final double brightness;
}

/// Искры реза под углом [cutAngle]: половина по одну сторону от нормали,
/// половина по другую, каждая со своим разбросом, дальностью, размером и
/// яркостью из [random]. Ровная розетка — то самое «неуклюже».
List<Spark> sparkBurst(Random random, {required double cutAngle}) {
  final normal = cutAngle + pi / 2;
  const spread = sparkSpreadDegrees * pi / 180;
  return [
    for (var i = 0; i < sparkCount; i++)
      Spark(
        // Чётные — по одну сторону реза, нечётные — по другую; внутри
        // стороны направление гуляет, поэтому лучи не ложатся ровно.
        angle:
            normal +
            (i.isEven ? 0 : pi) +
            (random.nextDouble() * 2 - 1) * spread,
        reach:
            sparkMinReach +
            random.nextDouble() * (sparkMaxReach - sparkMinReach),
        size:
            sparkMinSize + random.nextDouble() * (sparkMaxSize - sparkMinSize),
        brightness: random.nextDouble() * sparkMaxBrightness,
      ),
  ];
}

/// Где искра в долю [phase] жизни: разлёт с замедлением плюс падение.
///
/// Замедление, а не ровный ход: искра, летящая с одной скоростью до самого
/// конца, читается как пуля, а не как брызги.
Offset sparkPosition(
  Spark spark, {
  required Offset origin,
  required double phase,
}) {
  final p = phase.clamp(0.0, 1.0);
  final flown = Curves.easeOutCubic.transform(p);
  return origin +
      Offset.fromDirection(spark.angle, spark.reach * flown) +
      Offset(0, fallBy(p));
}

/// Альфа искры: тает к концу.
double sparkAlpha(double phase) {
  // 1 − t², а не 1 − t: искра держится яркой дольше половины жизни и гаснет
  // быстро в конце — так читаются брызги, а не медленно тускнеющая пыль.
  final p = phase.clamp(0.0, 1.0);
  return 1 - p * p;
}

/// Размер искры в долю [phase]: уменьшается к концу, но не в ноль.
double sparkSizeAt(Spark spark, double phase) =>
    spark.size * (1 - 0.5 * phase.clamp(0.0, 1.0));

// ---------------------------------------------------------- прилёт очков ----

/// Какую долю подсветки «+N» выскакивает на месте, прежде чем лететь.
const double scorePopHold = 0.35;

/// С какого масштаба выскакивает.
const double scorePopStartScale = 0.3;

/// Масштаб «+N» в долю подсветки: перехлёст (`elasticOut`) за
/// [scorePopHold], дальше ровно 1.
double scorePopScale(double phase) {
  if (phase >= scorePopHold) return 1;
  final u = (phase / scorePopHold).clamp(0.0, 1.0);
  return scorePopStartScale +
      (1 - scorePopStartScale) * Curves.elasticOut.transform(u);
}

/// Доля пути к счётчику: 0 всё время [scorePopHold], затем разгон к 1.
double scorePopFlight(double phase) {
  if (phase <= scorePopHold) return 0;
  final u = ((phase - scorePopHold) / (1 - scorePopHold)).clamp(0.0, 1.0);
  return Curves.easeInCubic.transform(u);
}
