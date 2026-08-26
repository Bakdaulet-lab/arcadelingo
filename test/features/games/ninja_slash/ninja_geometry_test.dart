// Геометрия реза: порог свайпа и что задел отрезок.
//
// Литералы, а не константы из lib/: тест обязан быть независимой сверкой со
// SPEC.md → «Ниндзя-слэш» → «Рез».
//
// Главный кейс здесь — «отрезок ловит то, что точка пропускает». Быстрый
// свайп даёт точки реже, чем диаметр объекта, и проверка «точка в круге»
// пропускала бы объект насквозь: обе точки снаружи, а прошли сквозь центр.

import 'package:arcadelingo/features/games/ninja_slash/ninja_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

const double _radius = 34;

void main() {
  group('Порог свайпа', () {
    test('ровно 16 dp — уже рез', () {
      expect(swipeCounts(16), isTrue);
    });

    test('чуть меньше — ещё нет', () {
      expect(swipeCounts(15.999), isFalse);
    });

    test('тап не режет', () {
      expect(
        swipeCounts(0),
        isFalse,
        reason: 'случайное касание в полёте не должно стоить жизни',
      );
    });

    test('длинный свайп режет', () {
      expect(swipeCounts(400), isTrue);
    });

    test('порог — 16 dp', () {
      expect(sliceThreshold, 16);
    });
  });

  group('Попадание отрезком', () {
    test('отрезок сквозь центр — попадание', () {
      expect(
        sliceHit(
          from: const Offset(0, 100),
          to: const Offset(200, 100),
          center: const Offset(100, 100),
          radius: _radius,
        ),
        isTrue,
      );
    });

    test('ровно по радиусу — попадание, на пиксель дальше — нет', () {
      expect(
        sliceHit(
          from: const Offset(0, 134),
          to: const Offset(200, 134),
          center: const Offset(100, 100),
          radius: _radius,
        ),
        isTrue,
        reason: 'касание края — тоже рез: граница включительно',
      );
      expect(
        sliceHit(
          from: const Offset(0, 135),
          to: const Offset(200, 135),
          center: const Offset(100, 100),
          radius: _radius,
        ),
        isFalse,
      );
    });

    test('отрезок ловит то, что обе его точки пропускают', () {
      const from = Offset(0, 100);
      const to = Offset(200, 100);
      const center = Offset(100, 100);

      expect(
        (from - center).distance,
        greaterThan(_radius),
        reason: 'начало снаружи круга — иначе кейс ничего не доказывает',
      );
      expect((to - center).distance, greaterThan(_radius));
      expect(
        sliceHit(from: from, to: to, center: center, radius: _radius),
        isTrue,
        reason: 'проверка «точка в круге» пропустила бы объект насквозь',
      );
    });

    test('отрезок кончился, не дойдя: продолжение не считается', () {
      expect(
        sliceHit(
          from: const Offset(0, 100),
          to: const Offset(50, 100),
          center: const Offset(200, 100),
          radius: _radius,
        ),
        isFalse,
        reason: 'режет отрезок, а не бесконечная прямая через него',
      );
    });

    test('вырожденный отрезок ведёт себя как точка', () {
      expect(
        sliceHit(
          from: const Offset(100, 100),
          to: const Offset(100, 100),
          center: const Offset(110, 100),
          radius: _radius,
        ),
        isTrue,
      );
      expect(
        sliceHit(
          from: const Offset(100, 100),
          to: const Offset(100, 100),
          center: const Offset(200, 100),
          radius: _radius,
        ),
        isFalse,
      );
    });

    test('ближайшая точка внутри отрезка, а не на его конце', () {
      // Центр строго над серединой: расстояние до конца велико, до отрезка —
      // нет. Проверка «до концов» дала бы промах.
      const from = Offset(0, 300);
      const to = Offset(600, 300);
      const center = Offset(300, 320);

      expect((from - center).distance, greaterThan(_radius));
      expect((to - center).distance, greaterThan(_radius));
      expect(
        sliceHit(from: from, to: to, center: center, radius: _radius),
        isTrue,
      );
    });
  });

  group('Кого резать, если задето двое', () {
    test('режется ближний к началу движения', () {
      final target = sliceTarget(
        from: const Offset(0, 100),
        to: const Offset(400, 100),
        centers: const [Offset(300, 100), Offset(100, 100)],
        radius: _radius,
      );

      expect(target, 1, reason: 'рука прошла через объект на x = 100 первой');
    });

    test('порядок в списке ничего не решает', () {
      final target = sliceTarget(
        from: const Offset(0, 100),
        to: const Offset(400, 100),
        centers: const [Offset(100, 100), Offset(300, 100)],
        radius: _radius,
      );

      expect(target, 0);
    });

    test('обратный свайп режет тот, что ближе к его началу', () {
      final target = sliceTarget(
        from: const Offset(400, 100),
        to: const Offset(0, 100),
        centers: const [Offset(100, 100), Offset(300, 100)],
        radius: _radius,
      );

      expect(
        target,
        1,
        reason:
            'слева направо и справа налево — не одно и то'
            ' же движение',
      );
    });

    test('задет один — он и режется', () {
      final target = sliceTarget(
        from: const Offset(0, 100),
        to: const Offset(400, 100),
        centers: const [Offset(200, 400), Offset(300, 100)],
        radius: _radius,
      );

      expect(target, 1);
    });

    test('не задет никто — null, а не первый попавшийся', () {
      final target = sliceTarget(
        from: const Offset(0, 100),
        to: const Offset(400, 100),
        centers: const [Offset(200, 400), Offset(300, 500)],
        radius: _radius,
      );

      expect(target, isNull);
    });

    test('пустая волна — null, и без броска', () {
      expect(
        sliceTarget(
          from: const Offset(0, 100),
          to: const Offset(400, 100),
          centers: const [],
          radius: _radius,
        ),
        isNull,
      );
    });
  });

  group('Точка реза', () {
    test('проекция внутри отрезка', () {
      expect(
        closestPointOnSegment(
          from: const Offset(0, 100),
          to: const Offset(200, 100),
          point: const Offset(70, 130),
        ),
        const Offset(70, 100),
      );
    });

    test('за концом отрезка — сам конец, а не точка на прямой', () {
      expect(
        closestPointOnSegment(
          from: const Offset(0, 100),
          to: const Offset(50, 100),
          point: const Offset(500, 100),
        ),
        const Offset(50, 100),
        reason: 'режет отрезок, а не бесконечная прямая через него',
      );
      expect(
        closestPointOnSegment(
          from: const Offset(0, 100),
          to: const Offset(50, 100),
          point: const Offset(-500, 100),
        ),
        const Offset(0, 100),
      );
    });

    test('вырожденный отрезок — своё же начало', () {
      expect(
        closestPointOnSegment(
          from: const Offset(30, 40),
          to: const Offset(30, 40),
          point: const Offset(900, 900),
        ),
        const Offset(30, 40),
      );
    });

    test('точка реза лежит внутри объекта, который разрезали', () {
      const center = Offset(100, 100);
      final cut = closestPointOnSegment(
        from: const Offset(0, 120),
        to: const Offset(200, 120),
        point: center,
      );

      expect((cut - center).distance, lessThanOrEqualTo(_radius));
    });

    test('расстояние до отрезка — это расстояние до точки реза', () {
      const from = Offset(0, 300);
      const to = Offset(600, 300);
      const center = Offset(300, 320);
      final cut = closestPointOnSegment(from: from, to: to, point: center);

      expect(
        sliceHit(from: from, to: to, center: center, radius: _radius),
        (cut - center).distance <= _radius,
      );
    });
  });
}
