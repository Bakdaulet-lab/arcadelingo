// Физика и геометрия украшений без дерева виджетов: след клинка, вращение
// и вылет объектов, вспышка удара, половинки, искры, прилёт очков.
//
// Литералы, а не константы из lib/: тест обязан быть независимой сверкой со
// SPEC.md → «Ниндзя-слэш» → «Джус» → «Новое», иначе переименованная
// константа подтвердит сама себя.
//
// Урок этапа 4.3, записанный в context.md: мера шире свойства. Каждый
// ассерт здесь подобран так, чтобы краснеть на ближайшей подмене: розетка
// из равных лучей — на «зазоры неравные», отрезок между концами — на
// «срезает угол», одинаковая дальность — на «у каждой своя».

import 'dart:math';

import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_fx.dart';
import 'package:flutter_test/flutter_test.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

TrailPoint _stamped(double x, double y, int ms) => (
  at: Offset(x, y),
  stamp: _ms(ms),
);

TrailSample _fresh(double x, double y, [double freshness = 1]) => (
  at: Offset(x, y),
  freshness: freshness,
);

/// Лежит ли [p] на отрезке [a] → [b] с допуском.
bool _onSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / ab.distanceSquared;
  if (t < -1e-9 || t > 1 + 1e-9) return false;
  return (p - (a + ab * t)).distance < 1e-6;
}

/// Разность углов, приведённая в (−π, π].
double _angleDiff(double a, double b) {
  var d = (a - b) % (2 * pi);
  if (d > pi) d -= 2 * pi;
  return d;
}

const double _deg = pi / 180;

void main() {
  group('След: что осталось к моменту', () {
    test('точка моложе 300 мс жива, старше — нет', () {
      final points = [
        _stamped(0, 0, 0),
        _stamped(10, 0, 100),
        _stamped(20, 0, 250),
      ];

      final alive = trailAlive(points, _ms(350));

      expect(alive.map((s) => s.at), [
        const Offset(10, 0),
        const Offset(20, 0),
      ]);
    });

    test('ровно 300 мс — уже выбыла: граница строгая', () {
      final alive = trailAlive([_stamped(0, 0, 0)], _ms(300));

      expect(alive, isEmpty);
    });

    test('свежесть: только что коснулись — 1, на грани — почти 0', () {
      final points = [_stamped(0, 0, 0), _stamped(1, 0, 299)];
      final alive = trailAlive(points, _ms(299));

      expect(alive.last.freshness, closeTo(1, 1e-9));
      expect(alive.first.freshness, closeTo(1 / 300, 1e-9));
    });

    test('тает с хвоста: живые точки — это суффикс списка', () {
      final points = [
        for (var i = 0; i < 10; i++) _stamped(i * 10.0, 0, i * 50),
      ];

      final alive = trailAlive(points, _ms(500));

      expect(
        alive.map((s) => s.at),
        points.sublist(5).map((p) => p.at),
        reason: 'старые точки выбывают первыми, а не весь след разом',
      );
    });

    test('пусто → пусто', () {
      expect(trailAlive(const [], _ms(100)), isEmpty);
    });

    test('числа из SPEC: жизнь 300 мс, до 32 точек', () {
      expect(trailLife, _ms(300));
      expect(trailPoints, 32);
    });
  });

  group('След: кривая, а не палка', () {
    final corner = [_fresh(0, 0), _fresh(100, 0), _fresh(100, 100)];

    test('концы остаются на месте', () {
      final curve = smoothTrail(corner);

      expect(curve.first.at, const Offset(0, 0));
      expect(curve.last.at, const Offset(100, 100));
    });

    test('на угле путь срезает угол: есть пробы не на ломаной', () {
      final curve = smoothTrail(corner);

      final off = curve.where(
        (s) =>
            !_onSegment(s.at, const Offset(0, 0), const Offset(100, 0)) &&
            !_onSegment(s.at, const Offset(100, 0), const Offset(100, 100)),
      );

      expect(
        off,
        isNotEmpty,
        reason:
            'ломаная по точкам и отрезок между концами оба прошли бы по '
            'прямым — это и есть «резьба очень прямая»',
      );
      expect(
        off.every((s) => s.at.dx < 100 && s.at.dy > 0),
        isTrue,
        reason: 'срезает внутрь угла, а не выбрасывает наружу',
      );
    });

    test('прямая остаётся прямой: кривая не вихляет', () {
      final curve = smoothTrail([
        _fresh(0, 0),
        _fresh(50, 0),
        _fresh(100, 0),
        _fresh(150, 0),
      ]);

      var previous = -1.0;
      for (final s in curve) {
        expect(s.at.dy, closeTo(0, 1e-9));
        expect(s.at.dx, greaterThan(previous), reason: 'и не идёт назад');
        previous = s.at.dx;
      }
    });

    test('проб больше, чем точек: шесть на отрезок', () {
      expect(
        smoothTrail(corner),
        hasLength(1 + 2 * 6),
        reason: 'старт плюс шесть проб на каждый из двух отрезков',
      );
      expect(smoothTrail([_fresh(0, 0), _fresh(100, 0)]), hasLength(1 + 6));
      expect(trailSamplesPerSegment, 6);
    });

    test('свежесть интерполируется вдоль кривой', () {
      final curve = smoothTrail([_fresh(0, 0, 0), _fresh(100, 0, 1)]);

      expect(curve.first.freshness, closeTo(0, 1e-9));
      expect(curve.last.freshness, closeTo(1, 1e-9));
      for (var i = 1; i < curve.length; i++) {
        expect(
          curve[i].freshness,
          greaterThanOrEqualTo(curve[i - 1].freshness),
        );
      }
    });

    test('одна точка — одна проба, ноль — ноль', () {
      expect(smoothTrail([_fresh(3, 4)]).map((s) => s.at), [
        const Offset(3, 4),
      ]);
      expect(smoothTrail(const []), isEmpty);
    });
  });

  group('След: ширина', () {
    test('свежая голова — 10 dp', () {
      expect(trailWidthAt(freshness: 1, along: 1), closeTo(10, 1e-9));
      expect(trailHeadWidth, 10);
    });

    test('хвост — остриё', () {
      expect(trailWidthAt(freshness: 1, along: 0), closeTo(0, 1e-9));
    });

    test('к голове толще', () {
      var previous = -1.0;
      for (var i = 0; i <= 10; i++) {
        final width = trailWidthAt(freshness: 1, along: i / 10);
        expect(width, greaterThan(previous));
        previous = width;
      }
    });

    test('старая точка тоньше свежей, мёртвая — ноль', () {
      expect(
        trailWidthAt(freshness: 0.5, along: 1),
        lessThan(trailWidthAt(freshness: 1, along: 1)),
      );
      expect(trailWidthAt(freshness: 0, along: 1), closeTo(0, 1e-9));
    });

    test('числа из SPEC: свечение ×2.4 с альфой 0.45 и размытием 6, ядро '
        '×0.45', () {
      expect(trailGlowWidth, 2.4);
      expect(trailGlowAlpha, 0.45);
      expect(trailGlowBlur, 6);
      expect(trailCoreWidth, 0.45);
    });
  });

  group('Вращение объекта', () {
    final spins = [
      for (var seed = 0; seed < 200; seed++) spinFor(Random(seed)),
    ];

    test('наклон к посадке — от 12° до 25°', () {
      for (final spin in spins) {
        expect(spin.abs(), greaterThanOrEqualTo(12 * _deg - 1e-9));
        expect(spin.abs(), lessThanOrEqualTo(25 * _deg + 1e-9));
      }
    });

    test('оба знака встречаются', () {
      expect(spins.any((s) => s > 0), isTrue);
      expect(spins.any((s) => s < 0), isTrue);
    });

    test('в любой фазе полёта наклон не больше 25°: слово читается', () {
      for (final spin in spins) {
        for (var i = 0; i <= 20; i++) {
          expect(
            objectTilt(spin: spin, t: i / 20).abs(),
            lessThanOrEqualTo(25 * _deg + 1e-9),
            reason: 'это учебная игра, слово на объекте обязано читаться',
          );
        }
      }
    });

    test('на старте объект стоит прямо', () {
      expect(objectTilt(spin: 0.4, t: 0), 0);
    });

    test('наклон растёт с полётом, а не качается', () {
      var previous = -1.0;
      for (var i = 0; i <= 10; i++) {
        final tilt = objectTilt(spin: 0.4, t: i / 10);
        expect(tilt, greaterThan(previous));
        previous = tilt;
      }
    });

    test('один и тот же seed — тот же наклон', () {
      expect(spinFor(Random(7)), spinFor(Random(7)));
    });

    test('числа из SPEC', () {
      expect(minSpinDegrees, 12);
      expect(maxSpinDegrees, 25);
    });
  });

  group('Вылет из-за кромки', () {
    test('на старте — половина размера', () {
      expect(emergeScale(0), closeTo(0.5, 1e-9));
    });

    test('к первой десятой полёта — полный, и дальше полный', () {
      expect(emergeScale(0.1), closeTo(1, 1e-9));
      expect(emergeScale(0.5), 1);
      expect(emergeScale(1), 1);
    });

    test('между ними — перехлёст: масштаб заходит за единицу', () {
      final scales = [for (var i = 1; i < 20; i++) emergeScale(i / 200)];

      expect(
        scales.any((s) => s > 1),
        isTrue,
        reason: 'без перехлёста это не pop, а плавный рост',
      );
    });

    test('числа из SPEC', () {
      expect(popFraction, 0.10);
      expect(popStartScale, 0.5);
    });
  });

  group('Вспышка удара', () {
    test('радиус 8 → 64', () {
      expect(ringRadius(0), closeTo(8, 1e-9));
      expect(ringRadius(1), closeTo(64, 1e-9));
      expect(ringRadius(0.5), greaterThan(8));
      expect(ringRadius(0.5), lessThan(64));
    });

    test('толщина 4 → 1', () {
      expect(ringStroke(0), closeTo(4, 1e-9));
      expect(ringStroke(1), closeTo(1, 1e-9));
    });

    test('альфа 0.9 → 0, монотонно', () {
      expect(ringAlpha(0), closeTo(0.9, 1e-9));
      expect(ringAlpha(1), closeTo(0, 1e-9));
      var previous = 2.0;
      for (var i = 0; i <= 10; i++) {
        final alpha = ringAlpha(i / 10);
        expect(alpha, lessThan(previous));
        previous = alpha;
      }
    });

    test('живёт 200 мс', () {
      expect(ringLife, _ms(200));
    });
  });

  group('Гравитация', () {
    test('за 300 мс — около 40 dp', () {
      expect(fallBy(1), closeTo(40.5, 1e-6), reason: '½ · 900 · 0.3²');
    });

    test('на старте — ноль', () {
      expect(fallBy(0), 0);
    });

    test('падение ускоряется: вторая половина длиннее первой', () {
      expect(fallBy(1) - fallBy(0.5), greaterThan(fallBy(0.5)));
    });

    test('числа из SPEC', () {
      expect(fxGravity, 900);
      expect(sliceLife, _ms(300));
    });
  });

  group('Половинки', () {
    HalfMotion at(
      double side, {
      double angle = 0,
      Offset velocity = Offset.zero,
      double phase = 1,
    }) =>
        halfMotion(side: side, angle: angle, velocity: velocity, phase: phase);

    test('расходятся поперёк реза, а не вдоль', () {
      final a = at(1);
      final b = at(-1);

      expect(
        a.offset.dx,
        closeTo(b.offset.dx, 1e-9),
        reason: 'горизонтальный рез — по x половинки вместе',
      );
      expect(
        (a.offset.dy - b.offset.dy).abs(),
        closeTo(2 * 200 * 0.3, 1e-9),
        reason: '200 dp/с в каждую сторону за 0.3 с',
      );
    });

    test('наклонный рез: нормаль повёрнута вместе с ним', () {
      final a = at(1, angle: pi / 2);
      final b = at(-1, angle: pi / 2);

      expect(a.offset.dy, closeTo(b.offset.dy, 1e-9));
      expect((a.offset.dx - b.offset.dx).abs(), closeTo(120, 1e-9));
    });

    test('наследуют скорость полёта: летящий вверх объект — и куски вверх', () {
      final still = at(1);
      final moving = at(1, velocity: const Offset(0, -200));

      expect(
        moving.offset.dy,
        closeTo(still.offset.dy - 60, 1e-9),
        reason: '200 dp/с вверх за 0.3 с — 60 dp',
      );
    });

    test('падают: без скорости середина между половинками уходит вниз', () {
      final a = at(1);
      final b = at(-1);

      expect((a.offset.dy + b.offset.dy) / 2, closeTo(fallBy(1), 1e-9));
      expect(fallBy(1), greaterThan(0));
    });

    test('вращаются в разные стороны на 40° к концу', () {
      expect(at(1).rotation, closeTo(40 * _deg, 1e-9));
      expect(at(-1).rotation, closeTo(-40 * _deg, 1e-9));
      expect(at(1, phase: 0).rotation, 0);
    });

    test('тают: альфа 1 → 0', () {
      expect(at(1, phase: 0).alpha, closeTo(1, 1e-9));
      expect(at(1, phase: 0.5).alpha, closeTo(0.5, 1e-9));
      expect(at(1, phase: 1).alpha, closeTo(0, 1e-9));
    });

    test('на старте ещё вместе', () {
      expect(at(1, phase: 0).offset, Offset.zero);
      expect(at(-1, phase: 0).offset, Offset.zero);
    });

    test('числа из SPEC', () {
      expect(halfSpreadSpeed, 200);
      expect(halfSpinDegrees, 40);
    });
  });

  group('Искры', () {
    // Горизонтальный рез: нормали смотрят вверх (−π/2) и вниз (+π/2).
    final sparks = sparkBurst(Random(1), cutAngle: 0);

    double toNormal(Spark s) => min(
      _angleDiff(s.angle, -pi / 2).abs(),
      _angleDiff(s.angle, pi / 2).abs(),
    );

    test('ровно четырнадцать', () {
      expect(sparks, hasLength(14));
      expect(sparkCount, 14);
    });

    test('одинаковый seed — одинаковые искры: без этого кадр не снять', () {
      final again = sparkBurst(Random(1), cutAngle: 0);

      for (var i = 0; i < sparks.length; i++) {
        expect(again[i].angle, sparks[i].angle);
        expect(again[i].reach, sparks[i].reach);
        expect(again[i].size, sparks[i].size);
        expect(again[i].brightness, sparks[i].brightness);
      }
    });

    test('все летят по нормали к резу: не дальше 60° от неё', () {
      for (final spark in sparks) {
        expect(toNormal(spark), lessThanOrEqualTo(60 * _deg + 1e-9));
      }
    });

    test('половина в каждую сторону от реза', () {
      final up = sparks.where(
        (s) => _angleDiff(s.angle, -pi / 2).abs() <= 60 * _deg + 1e-9,
      );

      expect(up, hasLength(7));
    });

    test('не розетка: зазоры между соседними углами неравные', () {
      final angles = sparks.map((s) => s.angle % (2 * pi)).toList()..sort();
      final gaps = [
        for (var i = 1; i < angles.length; i++) angles[i] - angles[i - 1],
        2 * pi - angles.last + angles.first,
      ];

      expect(
        gaps.reduce(max) - gaps.reduce(min),
        greaterThan(1 * _deg),
        reason:
            'ровная розетка даёт равные зазоры до градуса — это и есть '
            '«неуклюже»',
      );
    });

    test('дальность у каждой своя, в 40…90', () {
      for (final spark in sparks) {
        expect(spark.reach, greaterThanOrEqualTo(40));
        expect(spark.reach, lessThanOrEqualTo(90));
      }
      expect(sparks.map((s) => s.reach).toSet(), hasLength(14));
    });

    test('размер у каждой свой, в 2…4', () {
      for (final spark in sparks) {
        expect(spark.size, greaterThanOrEqualTo(2));
        expect(spark.size, lessThanOrEqualTo(4));
      }
      expect(sparks.map((s) => s.size).toSet(), hasLength(14));
    });

    test('яркость в 0…0.4, и не у всех одна', () {
      for (final spark in sparks) {
        expect(spark.brightness, greaterThanOrEqualTo(0));
        expect(spark.brightness, lessThanOrEqualTo(0.4));
      }
      expect(sparks.map((s) => s.brightness).toSet().length, greaterThan(1));
    });

    test('разброс зависит от seed, а не зашит', () {
      expect(
        sparkBurst(Random(2), cutAngle: 0).map((s) => s.angle),
        isNot(sparks.map((s) => s.angle)),
      );
    });

    test('нормаль поворачивается вместе с резом', () {
      for (final spark in sparkBurst(Random(1), cutAngle: pi / 2)) {
        final toSide = min(
          _angleDiff(spark.angle, 0).abs(),
          _angleDiff(spark.angle, pi).abs(),
        );
        expect(toSide, lessThanOrEqualTo(60 * _deg + 1e-9));
      }
    });

    test('стартует из точки реза и разлетается с замедлением', () {
      const spark = Spark(angle: 0, reach: 60, size: 3, brightness: 0);
      const origin = Offset(100, 100);

      expect(sparkPosition(spark, origin: origin, phase: 0), origin);
      final half = sparkPosition(spark, origin: origin, phase: 0.5).dx - 100;
      final full = sparkPosition(spark, origin: origin, phase: 1).dx - 100;
      expect(full, closeTo(60, 1e-9));
      expect(half, greaterThan(30), reason: 'первая половина пути быстрее');
    });

    test('гравитация опускает каждую: летящая вверх садится ниже вершины', () {
      const spark = Spark(angle: -pi / 2, reach: 60, size: 3, brightness: 0);
      const origin = Offset(100, 100);

      final end = sparkPosition(spark, origin: origin, phase: 1);

      expect(end.dy, closeTo(100 - 60 + fallBy(1), 1e-9));
      expect(end.dy, greaterThan(40));
    });

    test('тают и уменьшаются, но не в ноль', () {
      const spark = Spark(angle: 0, reach: 60, size: 3, brightness: 0);

      expect(sparkAlpha(0), closeTo(1, 1e-9));
      expect(sparkAlpha(1), closeTo(0, 1e-9));
      expect(sparkSizeAt(spark, 0), closeTo(3, 1e-9));
      expect(sparkSizeAt(spark, 1), lessThan(3));
      expect(sparkSizeAt(spark, 1), greaterThan(0));
    });

    test('числа из SPEC', () {
      expect(sparkSpreadDegrees, 60);
      expect(sparkMinReach, 40);
      expect(sparkMaxReach, 90);
      expect(sparkMinSize, 2);
      expect(sparkMaxSize, 4);
      expect(sparkMaxBrightness, 0.4);
    });
  });

  group('Прилёт очков', () {
    test('выскакивает с перехлёстом: масштаб 0.3 → за единицу → 1', () {
      expect(scorePopScale(0), closeTo(0.3, 1e-9));
      final during = [for (var i = 1; i < 35; i++) scorePopScale(i / 100)];
      expect(
        during.any((s) => s > 1),
        isTrue,
        reason: 'elasticOut заходит за 1',
      );
      expect(scorePopScale(0.35), closeTo(1, 1e-9));
      expect(scorePopScale(0.7), 1);
    });

    test('первые 35% стоит на месте, потом летит', () {
      expect(scorePopFlight(0), 0);
      expect(scorePopFlight(0.35), 0);
      expect(scorePopFlight(0.5), greaterThan(0));
      expect(scorePopFlight(1), closeTo(1, 1e-9));
      var previous = -1.0;
      for (var i = 0; i <= 20; i++) {
        final flown = scorePopFlight(i / 20);
        expect(flown, greaterThanOrEqualTo(previous));
        previous = flown;
      }
    });

    test('числа из SPEC', () {
      expect(scorePopHold, 0.35);
      expect(scorePopStartScale, 0.3);
    });
  });
}
