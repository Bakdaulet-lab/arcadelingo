// Формат v2: запас заморозок в документе серии, и чтение документов v1.
//
// Отдельным файлом от `streak_codec_test.dart` намеренно: там разбор битых
// данных, написанный до заморозки, и он остаётся верным дословно. Здесь —
// то, что добавила Фаза 3, и главное в этом файле не новые поля, а миграция:
// документ, лежащий на телефоне автора, написан кодеком v1, и прочитать его
// обязаны, ничего не потеряв и ничего не выдумав.

import 'package:arcadelingo/data/streak/streak_codec.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/result.dart';

void main() {
  group('Круговой прогон v2', () {
    test('запас и замороженный день переживают запись и чтение', () {
      final state = StreakState(
        current: 5,
        best: 9,
        lastDay: StreakDay(2026, 8, 28),
        daysSinceFreeze: 3,
        lastFrozenDay: StreakDay(2026, 8, 27),
      );

      expect(ok(decodeStreakState(encodeStreakState(state))), state);
    });

    test('заморозка в запасе переживает запись и чтение', () {
      final state = StreakState(
        current: 7,
        best: 7,
        lastDay: StreakDay(2026, 8, 30),
        freezes: 1,
      );

      expect(ok(decodeStreakState(encodeStreakState(state))), state);
    });

    test('пишется версия 2', () {
      expect(encodeStreakState(StreakState.empty), contains('"version":2'));
    });

    test('замороженного дня не было — поля в документе нет', () {
      final encoded = encodeStreakState(
        StreakState(current: 2, best: 2, lastDay: StreakDay(2026, 8, 25)),
      );

      expect(encoded, isNot(contains('frozen_day')));
    });

    test('замороженный день пишется датой с ведущими нулями', () {
      final encoded = encodeStreakState(
        StreakState(
          current: 3,
          best: 3,
          lastDay: StreakDay(2026, 3, 7),
          daysSinceFreeze: 1,
          lastFrozenDay: StreakDay(2026, 3, 6),
        ),
      );

      expect(encoded, contains('"frozen_day":"2026-03-06"'));
    });
  });

  group('Документ v1 читается и дополняется', () {
    test('состояние сохраняется целиком', () {
      final state = ok(
        decodeStreakState(
          '{"version":1,"current":4,"best":9,"last_day":"2026-08-25"}',
        ),
      );

      expect(state.current, 4);
      expect(state.best, 9);
      expect(state.lastDay, StreakDay(2026, 8, 25));
    });

    // Ни подарка, ни отъёма. Заморозки не существовало, когда документ
    // писали, — значит человек её не заработал и не потерял. Выдать её при
    // миграции значило бы развести правила: новый игрок начинает без
    // заморозки, а мигрировавший — с ней.
    test('запас начинается с нуля, а не выдаётся при миграции', () {
      final state = ok(
        decodeStreakState(
          '{"version":1,"current":4,"best":9,"last_day":"2026-08-25"}',
        ),
      );

      expect(state.freezes, 0);
      expect(state.daysSinceFreeze, 0);
      expect(state.lastFrozenDay, isNull);
    });

    test('пустой документ v1 читается пустым состоянием', () {
      expect(
        ok(decodeStreakState('{"version":1,"current":0,"best":0}')),
        StreakState.empty,
      );
    });
  });

  group('Битый запас — Err, до конструктора не доходит', () {
    test('заморозок больше максимума', () {
      expect(
        err(
          decodeStreakState(
            '{"version":2,"current":1,"best":1,"last_day":"2026-08-25",'
            '"freezes":2,"days_since_freeze":0}',
          ),
        ).message,
        contains('freezes'),
      );
    });

    test('отрицательный запас', () {
      expect(
        err(
          decodeStreakState(
            '{"version":2,"current":1,"best":1,"last_day":"2026-08-25",'
            '"freezes":-1,"days_since_freeze":0}',
          ),
        ).message,
        contains('freezes'),
      );
    });

    test('запас не целое число', () {
      expect(
        err(
          decodeStreakState(
            '{"version":2,"current":1,"best":1,"last_day":"2026-08-25",'
            '"freezes":"нет","days_since_freeze":0}',
          ),
        ).message,
        contains('freezes'),
      );
    });

    test('счётчик к заморозке отрицательный', () {
      expect(
        err(
          decodeStreakState(
            '{"version":2,"current":1,"best":1,"last_day":"2026-08-25",'
            '"freezes":0,"days_since_freeze":-2}',
          ),
        ).message,
        contains('days_since_freeze'),
      );
    });

    test('заморозка в запасе и ненулевой счётчик — несогласованно', () {
      expect(
        err(
          decodeStreakState(
            '{"version":2,"current":1,"best":1,"last_day":"2026-08-25",'
            '"freezes":1,"days_since_freeze":4}',
          ),
        ).message,
        contains('days_since_freeze'),
      );
    });

    test('в документе v2 поля запаса обязательны', () {
      expect(
        err(
          decodeStreakState(
            '{"version":2,"current":1,"best":1,"last_day":"2026-08-25"}',
          ),
        ).message,
        contains('freezes'),
      );
    });

    test('замороженный день не по формату — как и last_day', () {
      expect(
        err(
          decodeStreakState(
            '{"version":2,"current":2,"best":2,"last_day":"2026-08-25",'
            '"freezes":0,"days_since_freeze":1,'
            '"frozen_day":"2026-08-24T00:00:00Z"}',
          ),
        ).message,
        contains('frozen_day'),
      );
    });

    test('замороженный день не раньше последнего сыгранного', () {
      expect(
        err(
          decodeStreakState(
            '{"version":2,"current":2,"best":2,"last_day":"2026-08-25",'
            '"freezes":0,"days_since_freeze":1,"frozen_day":"2026-08-25"}',
          ),
        ).message,
        contains('frozen_day'),
      );
    });

    test('замороженный день без единого сыгранного', () {
      expect(
        err(
          decodeStreakState(
            '{"version":2,"current":0,"best":0,'
            '"freezes":0,"days_since_freeze":1,"frozen_day":"2026-08-25"}',
          ),
        ).message,
        contains('frozen_day'),
      );
    });
  });
}
