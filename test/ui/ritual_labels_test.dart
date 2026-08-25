// Тексты ритуала: таблица состояний, а не разглядывание экрана.
//
// Шесть строк таблицы из плана фазы: не сыграно · сыграно · серия под
// угрозой и заморозка спасёт · заморозка потрачена вчера · заморозки нет,
// вернётся через N дней · пустой день. Голдена на каждую из них не будет —
// картинок три, а состояний больше, и проверять их надо там, где они
// дёшевы.

import 'package:arcadelingo/ui/ritual_labels.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ritual_views.dart';

void main() {
  group('Кнопка приглашает по-разному', () {
    test('серии нет — просто «Играть»', () {
      expect(ritualCallToAction(ritualView()), 'Играть');
    });

    test('серия оборвана — тоже «Играть»: новая начнётся с единицы', () {
      // Последний засчитанный день — позавчера, заморозки нет.
      expect(ritualCallToAction(ritualView(days: 4, lastOffset: 2)), 'Играть');
    });

    test('серия жива, сегодня не сыграно — «Продолжить серию»', () {
      expect(
        ritualCallToAction(ritualView(days: 4, lastOffset: 1)),
        'Продолжить серию',
      );
    });

    test('пропущен день, заморозка спасёт — «Спасти серию»', () {
      expect(
        ritualCallToAction(ritualView(days: 4, lastOffset: 2, freezes: 1)),
        'Спасти серию',
      );
    });

    test('сегодня уже сыграно — «Сыграть ещё раз»', () {
      expect(ritualCallToAction(ritualView(days: 4)), 'Сыграть ещё раз');
    });
  });

  group('Сегодняшний день', () {
    test('засчитан', () {
      expect(ritualTodayLabel(ritualView(days: 2)), 'Сегодня сыграно');
    });

    test('ещё нет', () {
      expect(
        ritualTodayLabel(ritualView(days: 2, lastOffset: 1)),
        'Сегодня ещё не сыграно',
      );
    });

    test('серии нет вовсе — всё равно ещё не сыграно', () {
      expect(ritualTodayLabel(ritualView()), 'Сегодня ещё не сыграно');
    });
  });

  group('Строка серии', () {
    test('живая серия — с правильной формой слова', () {
      expect(ritualStreakLabel(ritualView(days: 1)), 'Серия: 1 день');
      expect(ritualStreakLabel(ritualView(days: 3)), 'Серия: 3 дня');
      expect(ritualStreakLabel(ritualView(days: 11)), 'Серия: 11 дней');
    });

    // Ноль дней — это не «Серия: 0 дней», а отсутствие строки. У того, кто
    // ещё не играл, и у того, кто серию оборвал, на экране одинаково пусто;
    // разница между ними — в кнопке.
    test('серии нет — строки нет', () {
      expect(ritualStreakLabel(ritualView()), isNull);
    });

    test('оборванная серия — строки тоже нет', () {
      expect(ritualStreakLabel(ritualView(days: 6, lastOffset: 3)), isNull);
    });

    test('под угрозой, но живая — строка на месте', () {
      expect(
        ritualStreakLabel(ritualView(days: 6, lastOffset: 2, freezes: 1)),
        'Серия: 6 дней',
      );
    });
  });

  group('Заморозка называется вслух', () {
    test('есть в запасе', () {
      expect(
        ritualFreezeLabel(ritualView(days: 2, freezes: 1)),
        'Заморозка в запасе',
      );
    });

    test('потрачена — и видно, на какой день', () {
      expect(
        ritualFreezeLabel(
          ritualView(days: 5, daysSinceFreeze: 1, frozenOffset: 1),
        ),
        'Заморозка потрачена за 25 августа',
      );
    });

    test('нет — и видно, когда вернётся', () {
      expect(
        ritualFreezeLabel(ritualView(days: 3, daysSinceFreeze: 3)),
        'Заморозка вернётся через 4 дня',
      );
      expect(
        ritualFreezeLabel(ritualView(days: 6, daysSinceFreeze: 6)),
        'Заморозка вернётся через 1 день',
      );
    });

    // До первой партии говорить не о чем: человек ещё не знает ни про серию,
    // ни про заморозку, и строка «вернётся через 7 дней» была бы обещанием
    // непонятно чего.
    test('серии нет — молчим', () {
      expect(ritualFreezeLabel(ritualView()), isNull);
    });

    test('серия оборвана — про потраченную не вспоминаем', () {
      expect(
        ritualFreezeLabel(
          ritualView(
            days: 5,
            lastOffset: 3,
            daysSinceFreeze: 1,
            frozenOffset: 4,
          ),
        ),
        'Заморозка вернётся через 6 дней',
      );
    });
  });

  group('Месяцы в родительном падеже', () {
    test('все двенадцать', () {
      const expected = [
        'января',
        'февраля',
        'марта',
        'апреля',
        'мая',
        'июня',
        'июля',
        'августа',
        'сентября',
        'октября',
        'ноября',
        'декабря',
      ];
      for (var month = 1; month <= 12; month++) {
        expect(monthInGenitive(month), expected[month - 1], reason: '$month');
      }
    });
  });
}
