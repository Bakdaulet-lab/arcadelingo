// Тесты формата файла отказов.
//
// Файл живёт в истории репозитория и копится годами: разбор обязан быть
// строгим, а «начать с чистого листа» на битом документе — невозможным.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/rejected.dart';

const RejectedEntry _adult = RejectedEntry(
  id: 'adult',
  reason: 'нет одного главного значения',
  date: '2026-08-25',
  portion: 7,
);

void main() {
  test('дата — календарный день в UTC, а не момент', () {
    // Вечер в Кызылорде — уже следующий день по UTC; важно, что дата не
    // зависит от того, где запустили инструмент.
    expect(formatRejectedDate(DateTime.utc(2026, 8, 25, 21, 30)), '2026-08-25');
    expect(formatRejectedDate(DateTime.utc(2026, 1, 2)), '2026-01-02');
  });

  test('первый прогон: файла нет — пустой список, а не ошибка', () {
    expect(parseRejected(null), isEmpty);
    expect(parseRejected(''), isEmpty);
    expect(parseRejected('   '), isEmpty);
    expect(rejectedIds(null), isEmpty);
  });

  group('битый документ — падение, а не пустой список', () {
    test('невалидный JSON', () {
      expect(() => parseRejected('{'), throwsA(isA<FormatException>()));
    });

    test('чужая версия формата', () {
      expect(
        () =>
            parseRejected(jsonEncode({'version': 2, 'rejected': <Object?>[]})),
        throwsA(isA<FormatException>()),
      );
    });

    test('запись без причины или без id', () {
      expect(
        () => parseRejected(
          jsonEncode({
            'version': rejectedFormatVersion,
            'rejected': [
              {'id': 'adult', 'reason': '', 'date': '2026-08-25', 'portion': 7},
            ],
          }),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseRejected(
          jsonEncode({
            'version': rejectedFormatVersion,
            'rejected': [
              {'reason': 'причина', 'date': '2026-08-25', 'portion': 7},
            ],
          }),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('запись переживает круг «закодировать — разобрать»', () {
    final back = parseRejected(encodeRejected(const [_adult])).single;

    expect(back.id, _adult.id);
    expect(back.reason, _adult.reason);
    expect(back.date, _adult.date);
    expect(back.portion, _adult.portion);
  });

  test('одна запись — одна строка, как в сиде и в порции', () {
    final lines = const LineSplitter().convert(encodeRejected(const [_adult]));

    expect(lines.where((l) => l.contains('"id"')), hasLength(1));
    expect(
      lines.firstWhere((l) => l.contains('"id"')),
      allOf(contains('"reason"'), contains('"date"'), contains('"portion"')),
    );
  });

  test('rejectedIds отдаёт только id', () {
    expect(rejectedIds(encodeRejected(const [_adult])), {'adult'});
  });

  group('дозапись', () {
    test('старые записи не теряются', () {
      final merged = withRejected(
        const [_adult],
        const [
          RejectedEntry(
            id: 'alright',
            reason: 'разговорное',
            date: '2026-08-26',
            portion: 8,
          ),
        ],
      );

      expect(merged.map((e) => e.id), ['adult', 'alright']);
    });

    test('повторный отказ того же слова не заводит вторую запись', () {
      // Калибровке нужна первая причина и первая дата, а не последняя.
      final merged = withRejected(
        const [_adult],
        const [
          RejectedEntry(
            id: 'adult',
            reason: 'другая формулировка',
            date: '2026-09-01',
            portion: 30,
          ),
        ],
      );

      expect(merged, hasLength(1));
      expect(merged.single.reason, _adult.reason);
      expect(merged.single.date, '2026-08-25');
    });
  });
}
