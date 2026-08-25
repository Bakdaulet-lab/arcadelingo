// Подпись серии: русский счёт.
//
// Правило: 1 — «день», 2–4 — «дня», 5–20 — «дней», дальше по последней
// цифре. Одиннадцать–четырнадцать — исключение, которое ломает наивное
// «смотрим на последнюю цифру»: 11 это «дней», хотя кончается на единицу.

import 'package:arcadelingo/ui/streak_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('один день', () {
    expect(streakLabel(1), 'Серия: 1 день');
  });

  test('два, три, четыре — «дня»', () {
    expect(streakLabel(2), 'Серия: 2 дня');
    expect(streakLabel(3), 'Серия: 3 дня');
    expect(streakLabel(4), 'Серия: 4 дня');
  });

  test('от пяти до десяти — «дней»', () {
    expect(streakLabel(5), 'Серия: 5 дней');
    expect(streakLabel(10), 'Серия: 10 дней');
  });

  test('одиннадцать–четырнадцать — «дней», хотя цифры обманывают', () {
    expect(streakLabel(11), 'Серия: 11 дней');
    expect(streakLabel(12), 'Серия: 12 дней');
    expect(streakLabel(13), 'Серия: 13 дней');
    expect(streakLabel(14), 'Серия: 14 дней');
  });

  test('после двадцати счёт идёт по последней цифре', () {
    expect(streakLabel(21), 'Серия: 21 день');
    expect(streakLabel(22), 'Серия: 22 дня');
    expect(streakLabel(25), 'Серия: 25 дней');
    expect(streakLabel(31), 'Серия: 31 день');
  });

  test('сотни не ломают правило', () {
    expect(streakLabel(101), 'Серия: 101 день');
    expect(streakLabel(111), 'Серия: 111 дней');
    expect(streakLabel(112), 'Серия: 112 дней');
    expect(streakLabel(122), 'Серия: 122 дня');
  });
}
