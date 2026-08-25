// Кодек серии: круговой прогон и битые документы.
//
// Половина файла — про одно поле, `last_day`, и это не перекос. Оно
// единственное, где легко ошибиться в сторону молчаливой порчи: `DateTime`
// охотно съедает и время, и зону, и тогда «день» начинает зависеть от того,
// где его прочитали. Поэтому здесь перечислены поимённо все формы, которые
// обязаны отлететь.
//
// Литералы, а не константы из lib/.

import 'package:arcadelingo/data/streak/streak_codec.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/result.dart';

/// Документ с подставленным значением `last_day`.
String _withDay(String raw) =>
    '{"version":1,"current":2,"best":5,"last_day":$raw}';

void main() {
  group('Круговой прогон', () {
    test('состояние с днём переживает запись и чтение', () {
      final state = StreakState(
        current: 3,
        best: 7,
        lastDay: StreakDay(2026, 8, 25),
      );

      expect(ok(decodeStreakState(encodeStreakState(state))), state);
    });

    test('пустое состояние пишется без дня и читается пустым', () {
      final encoded = encodeStreakState(StreakState.empty);

      expect(
        encoded,
        isNot(contains('last_day')),
        reason: 'дня ещё не было — нечего и записывать',
      );
      expect(ok(decodeStreakState(encoded)), StreakState.empty);
    });

    test('день пишется как дата с ведущими нулями', () {
      final encoded = encodeStreakState(
        StreakState(current: 1, best: 1, lastDay: StreakDay(2026, 3, 5)),
      );

      expect(encoded, contains('"last_day":"2026-03-05"'));
    });
  });

  group('День: только дата, без времени и зоны', () {
    test('ровно дата — читается', () {
      expect(
        ok(decodeStreakState(_withDay('"2026-08-25"'))).lastDay,
        StreakDay(2026, 8, 25),
      );
    });

    // Главное отличие от кодека Лейтнера: там строка без зоны — битые данные,
    // здесь битые данные — строка С зоной. DateTime.tryParse принял бы обе.
    test('момент с зоной — битые данные, а не день', () {
      for (final raw in const [
        '"2026-08-25T00:00:00Z"',
        '"2026-08-25T12:00:00+05:00"',
        '"2026-08-25T00:00:00"',
        '"2026-08-25 00:00:00"',
      ]) {
        expect(
          err(decodeStreakState(_withDay(raw))).message,
          contains('last_day'),
          reason: 'у дня нет момента, а значит и зоны: $raw',
        );
      }
    });

    test('дата не по формату — битые данные', () {
      for (final raw in const [
        '"2026-8-25"',
        '"26-08-25"',
        '"2026-08-25 "',
        '"20260825"',
        '"2026/08/25"',
        '""',
      ]) {
        expect(
          err(decodeStreakState(_withDay(raw))).message,
          contains('last_day'),
          reason: 'формат ровно один: ГГГГ-ММ-ДД, а это $raw',
        );
      }
    });

    test('несуществующая дата — битые данные, а не смещение на март', () {
      expect(
        err(decodeStreakState(_withDay('"2026-02-31"'))).message,
        contains('last_day'),
        reason: 'DateTime молча превратил бы это в 3 марта',
      );
      expect(
        err(decodeStreakState(_withDay('"2027-02-29"'))).message,
        contains('last_day'),
      );
      expect(
        err(decodeStreakState(_withDay('"2026-13-01"'))).message,
        contains('last_day'),
      );
    });

    test('день не строка — битые данные', () {
      expect(
        err(decodeStreakState(_withDay('20260825'))).message,
        contains('last_day'),
      );
      expect(
        err(decodeStreakState(_withDay('null'))).message,
        contains('last_day'),
      );
    });
  });

  group('Документ целиком', () {
    test('не JSON — Err с причиной', () {
      expect(err(decodeStreakState('не json')).message, contains('серия'));
    });

    test('корень не объект — Err', () {
      expect(err(decodeStreakState('[1,2]')).message, contains('серия'));
    });

    test('неизвестная версия — Err: читать её некому', () {
      expect(
        err(decodeStreakState('{"version":2,"current":0,"best":0}')).message,
        contains('версия'),
      );
    });

    test('счётчики не целые — Err', () {
      expect(
        err(decodeStreakState('{"version":1,"current":"2","best":5}')).message,
        contains('current'),
      );
      expect(
        err(decodeStreakState('{"version":1,"current":2,"best":null}')).message,
        contains('best'),
      );
    });

    test('счётчики отрицательные — Err, до конструктора не доходит', () {
      expect(
        err(decodeStreakState('{"version":1,"current":-1,"best":0}')).message,
        contains('current'),
      );
    });

    test('рекорд меньше серии — Err', () {
      expect(
        err(
          decodeStreakState(
            _withDay('"2026-08-25"').replaceAll('"best":5', '"best":1'),
          ),
        ).message,
        contains('best'),
      );
    });

    test('серия есть, а дня нет — Err: состояние несогласованно', () {
      expect(
        err(decodeStreakState('{"version":1,"current":3,"best":3}')).message,
        contains('last_day'),
      );
    });

    test('дня нет и серии нет — это пустое состояние, не ошибка', () {
      expect(
        ok(decodeStreakState('{"version":1,"current":0,"best":0}')),
        StreakState.empty,
      );
    });

    // Рекорд без текущей серии — состояние законное, хотя переходом его не
    // получить: `advanceStreak` при обрыве ставит current в единицу, а не в
    // ноль. Инвариант конструктора связывает current и last_day, а рекорд
    // живёт сам по себе — в этом и смысл поля.
    test('рекорд без текущей серии читается, а не отвергается', () {
      final state = ok(decodeStreakState('{"version":1,"current":0,"best":4}'));

      expect(state.current, 0);
      expect(state.best, 4);
      expect(state.lastDay, isNull);
    });
  });
}
