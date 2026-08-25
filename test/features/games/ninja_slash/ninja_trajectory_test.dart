// Геометрия волны: дорожки, апексы, дрейф и позиция как функция доли
// полёта.
//
// Литералы, а не константы из lib/: тест обязан быть независимой сверкой со
// SPEC.md → «Ниндзя-слэш» → «Волна» и «Траектория». Поле 300 × 600 взято
// круглым, чтобы доли читались числами: дорожки 60/150/240, апексы
// 372/468/420, дрейф 18.

import 'package:arcadelingo/features/games/ninja_slash/ninja_trajectory.dart';
import 'package:flutter_test/flutter_test.dart';

const double _width = 300;
const double _height = 600;

/// Полёт по дорожке [slot] на поле 300 × 600.
NinjaFlight _flight(int slot) =>
    flightForSlot(slot, width: _width, height: _height);

/// Где объект дорожки [slot] в долю полёта [t].
Offset _at(int slot, double t) {
  final flight = _flight(slot);
  return trajectory(
    t: t,
    lane: flight.lane,
    drift: flight.drift,
    apex: flight.apex,
    bottom: flightBottom(_height),
  );
}

void main() {
  group('Парабола', () {
    test('апекс ровно в середине полёта', () {
      final flight = _flight(0);
      final bottom = flightBottom(_height);

      final top = trajectory(
        t: 0.5,
        lane: flight.lane,
        drift: flight.drift,
        apex: flight.apex,
        bottom: bottom,
      );

      expect(
        bottom - top.dy,
        closeTo(flight.apex, 1e-9),
        reason:
            'нормировка 4t(1−t): apex и есть высота подъёма, а не вчетверо'
            ' меньшая',
      );
      for (final t in [0.1, 0.3, 0.49, 0.51, 0.7, 0.9]) {
        expect(
          _at(0, t).dy,
          greaterThan(top.dy),
          reason: 'на t = $t объект ниже вершины',
        );
      }
    });

    test('старт и посадка — под нижней кромкой поля', () {
      expect(_at(0, 0).dy, closeTo(_height + 34, 1e-9));
      expect(_at(0, 1).dy, closeTo(_height + 34, 1e-9));
      expect(
        _at(0, 0).dy,
        greaterThan(_height),
        reason: 'объект выезжает из-под края, а не появляется на нём',
      );
    });

    test('подъём симметричен: равные доли от концов дают равную высоту', () {
      for (final t in [0.1, 0.25, 0.4]) {
        expect(_at(1, t).dy, closeTo(_at(1, 1 - t).dy, 1e-9));
      }
    });

    test('дрейф монотонен и уводит ровно на свою величину', () {
      final flight = _flight(0);

      expect(_at(0, 0).dx, closeTo(flight.lane, 1e-9));
      expect(_at(0, 1).dx, closeTo(flight.lane + flight.drift, 1e-9));

      var previous = _at(0, 0).dx;
      for (var i = 1; i <= 20; i++) {
        final current = _at(0, i / 20).dx;
        expect(
          current,
          greaterThan(previous),
          reason: 'дрейф — снос в одну сторону, а не колебание',
        );
        previous = current;
      }
    });
  });

  group('Дорожки', () {
    test('три дорожки на 0.20, 0.50 и 0.80 ширины', () {
      expect(_flight(0).lane, closeTo(60, 1e-9));
      expect(_flight(1).lane, closeTo(150, 1e-9));
      expect(_flight(2).lane, closeTo(240, 1e-9));
    });

    test('три разных апекса: 0.62, 0.78 и 0.70 высоты', () {
      expect(_flight(0).apex, closeTo(372, 1e-9));
      expect(_flight(1).apex, closeTo(468, 1e-9));
      expect(_flight(2).apex, closeTo(420, 1e-9));

      final apexes = {_flight(0).apex, _flight(1).apex, _flight(2).apex};
      expect(
        apexes,
        hasLength(3),
        reason: 'на равных апексах три объекта в t = 0.5 встают в строку',
      );
    });

    test('дрейф — 0.06 ширины, знак чередуется', () {
      expect(_flight(0).drift, closeTo(18, 1e-9));
      expect(_flight(1).drift, closeTo(-18, 1e-9));
      expect(_flight(2).drift, closeTo(18, 1e-9));
    });

    test('дорожки вне таблицы — ошибка вызывающего', () {
      expect(
        () => flightForSlot(3, width: _width, height: _height),
        throwsArgumentError,
      );
      expect(
        () => flightForSlot(-1, width: _width, height: _height),
        throwsArgumentError,
      );
    });

    test('нижняя кромка — высота поля плюс радиус объекта', () {
      expect(flightBottom(_height), closeTo(_height + 34, 1e-9));
      expect(objectRadius, 34);
    });
  });

  group('Неполная волна', () {
    test('три объекта — все три дорожки', () {
      expect(laneSlotsFor(3), [0, 1, 2]);
    });

    test('два объекта — по краям, середина пуста', () {
      expect(
        laneSlotsFor(2),
        [0, 2],
        reason:
            'две штуки рядом на 0.20 и 0.50 читались бы как пара, а не'
            ' как выбор',
      );
    });

    test('один объект — по центру', () {
      expect(
        laneSlotsFor(1),
        [1],
        reason: 'один объект на краю выглядит поломкой вёрстки, а не решением',
      );
    });

    test('ни одного объекта — ни одной дорожки', () {
      expect(laneSlotsFor(0), isEmpty);
    });

    test('больше трёх объектов волна не поднимает', () {
      expect(() => laneSlotsFor(4), throwsArgumentError);
      expect(() => laneSlotsFor(-1), throwsArgumentError);
    });

    test('дорожки любой волны различны', () {
      for (final count in [1, 2, 3]) {
        final slots = laneSlotsFor(count);
        expect(slots.toSet(), hasLength(count), reason: 'волна из $count');
      }
    });
  });

  group('Позиции волны', () {
    test('позиций столько же, сколько объектов', () {
      for (final count in [1, 2, 3]) {
        expect(
          wavePositions(count: count, t: 0.5, width: _width, height: _height),
          hasLength(count),
          reason: 'волна из $count',
        );
      }
      expect(
        wavePositions(count: 0, t: 0.5, width: _width, height: _height),
        isEmpty,
      );
    });

    test('позиция объекта — та же, что даёт связка дорожки и траектории', () {
      final positions = wavePositions(
        count: 3,
        t: 0.37,
        width: _width,
        height: _height,
      );

      for (var slot = 0; slot < 3; slot++) {
        expect(positions[slot], _at(slot, 0.37), reason: 'дорожка $slot');
      }
    });

    test('три объекта стоят на трёх разных дорожках', () {
      final xs =
          wavePositions(
            count: 3,
            t: 0.5,
            width: _width,
            height: _height,
          ).map((p) => p.dx).toSet();

      expect(xs, hasLength(3));
    });

    test('один объект — по центру поля', () {
      final only =
          wavePositions(
            count: 1,
            t: 0.5,
            width: _width,
            height: _height,
          ).single;

      expect(only.dx, closeTo(_width / 2, 1e-9));
    });

    test('в начале и в конце полёта все под нижней кромкой', () {
      for (final t in [0.0, 1.0]) {
        for (final p in wavePositions(
          count: 3,
          t: t,
          width: _width,
          height: _height,
        )) {
          expect(p.dy, greaterThan(_height), reason: 't = $t');
        }
      }
    });

    test('волна шире таблицы дорожек — ошибка вызывающего', () {
      expect(
        () => wavePositions(count: 4, t: 0.5, width: _width, height: _height),
        throwsArgumentError,
      );
    });
  });
}
