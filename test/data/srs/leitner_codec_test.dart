// Кодек состояния Лейтнера: формат на диске и разбор битых данных.
//
// Контракт (docs/dev/tasks.md, 0.5): десериализация возвращает Failure на
// битых данных и НЕ доводит их до конструктора LeitnerCard — его
// ArgumentError сторожит инвариант, а не разбирает хранилище.
//
// Границы коробок здесь литералами (0/6 — битые, 1/5 — валидные), а не
// LeitnerCard.minBox/maxBox: тест — независимая сверка, как в
// leitner_test.dart. Тексты Failure проверяются только на вхождение id:
// точная формулировка — не контракт.

import 'dart:convert';

import 'package:arcadelingo/data/srs/leitner_codec.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/result.dart';

/// Валидная UTC-строка due для записей, где проверяется что-то другое.
const _dueZ = '2026-03-09T12:00:00.000Z';

final _isErr = isA<Err<Object?>>();

/// Документ формата v1 с одной карточкой `apple`. [card] подставляется как
/// есть — так битые значения полей задаются в одну строку.
String _doc(Map<String, Object?> card, {Object? version = 1}) => jsonEncode({
  'version': version,
  'cards': {'apple': card},
});

/// Строка `due` карточки [id] из закодированного документа. Касты здесь
/// допустимы: это тест на известный формат, а не разбор недоверенных данных.
String _dueOf(String encoded, String id) {
  final root = jsonDecode(encoded) as Map<String, Object?>;
  final cards = root['cards'] as Map<String, Object?>;
  final card = cards[id] as Map<String, Object?>;
  return card['due'] as String;
}

void main() {
  group('encodeLeitnerState', () {
    test('формат на диске: version 1, cards по id, due — ISO-8601 с Z', () {
      // Пин формата, а не round-trip: round-trip разрешил бы формату дрейфовать
      // незаметно, а миграция Фазы 2 будет читать именно этот документ.
      final encoded = encodeLeitnerState({
        'apple': LeitnerCard(box: 2, due: DateTime.utc(2026, 3, 9, 12)),
      });

      expect(jsonDecode(encoded), {
        'version': 1,
        'cards': {
          'apple': {'box': 2, 'due': '2026-03-09T12:00:00.000Z'},
        },
      });
    });

    test('карточка из локального времени пишется UTC-строкой с Z', () {
      // Инвариант «due всегда UTC» держит конструктор; кодек обязан на него
      // опираться, а не изобретать своё представление.
      final local = DateTime(2026, 3, 8, 12);
      final encoded = encodeLeitnerState({
        'apple': LeitnerCard(box: 1, due: local),
      });

      final due = _dueOf(encoded, 'apple');
      expect(due, endsWith('Z'));
      expect(DateTime.parse(due), local.toUtc());
    });
  });

  group('decodeLeitnerState: валидные данные', () {
    test('round-trip сохраняет коробку, момент до микросекунды и флаг UTC', () {
      // DateTime.== сравнивает и момент, и isUtc — поэтому равенство карточек
      // здесь и есть проверка, что после чтения due остался в UTC.
      final card = LeitnerCard(
        box: 3,
        due: DateTime.utc(2026, 3, 8, 12, 34, 56, 789, 12),
      );

      final cards = ok(decodeLeitnerState(encodeLeitnerState({'apple': card})));

      expect(cards, {'apple': card});
      expect(cards['apple']!.due.isUtc, isTrue);
    });

    test('пустое состояние: ключ есть, карточек ноль → Ok, пустая карта', () {
      final cards = ok(decodeLeitnerState(encodeLeitnerState({})));

      expect(cards, isEmpty);
    });

    test('границы 1 и 5 → Ok', () {
      for (final box in [1, 5]) {
        final cards = ok(decodeLeitnerState(_doc({'box': box, 'due': _dueZ})));
        expect(cards['apple']?.box, box, reason: 'box=$box');
      }
    });

    test('due с явным смещением читается однозначно, в UTC', () {
      // Момент однозначен — Dart сам приводит смещение к UTC.
      final cards = ok(
        decodeLeitnerState(
          _doc({'box': 2, 'due': '2026-03-08T17:00:00.000+05:00'}),
        ),
      );

      final due = cards['apple']!.due;
      expect(due.isUtc, isTrue);
      expect(due, DateTime.utc(2026, 3, 8, 12));
    });
  });

  group('decodeLeitnerState: битые данные → Err, не исключение', () {
    test('невалидный JSON', () {
      expect(() => decodeLeitnerState('{bad'), returnsNormally);
      expect(decodeLeitnerState('{bad'), _isErr);
    });

    test('корень не объект', () {
      for (final raw in ['[]', '42', 'null', '"apple"']) {
        expect(decodeLeitnerState(raw), _isErr, reason: 'вход: $raw');
      }
    });

    test('version не 1 или отсутствует', () {
      expect(
        decodeLeitnerState(_doc({'box': 2, 'due': _dueZ}, version: 2)),
        _isErr,
        reason: 'version 2',
      );
      expect(
        decodeLeitnerState(jsonEncode({'cards': <String, Object?>{}})),
        _isErr,
        reason: 'version отсутствует',
      );
    });

    test('cards отсутствует или не объект', () {
      expect(decodeLeitnerState('{"version":1}'), _isErr, reason: 'нет cards');
      expect(
        decodeLeitnerState('{"version":1,"cards":[]}'),
        _isErr,
        reason: 'cards — список',
      );
    });

    test('запись карточки не объект', () {
      expect(decodeLeitnerState('{"version":1,"cards":{"apple":3}}'), _isErr);
    });

    test('отсутствующий ключ: нет box / нет due → Err, а не подмена нулём', () {
      expect(
        decodeLeitnerState(_doc({'due': _dueZ})),
        _isErr,
        reason: 'нет box',
      );
      expect(decodeLeitnerState(_doc({'box': 2})), _isErr, reason: 'нет due');
    });

    test('box вне 1..5 → Err, а не ArgumentError из конструктора', () {
      for (final box in [0, 6, -1]) {
        final raw = _doc({'box': box, 'due': _dueZ});
        expect(
          () => decodeLeitnerState(raw),
          returnsNormally,
          reason: 'box=$box',
        );
        expect(decodeLeitnerState(raw), _isErr, reason: 'box=$box');
      }
    });

    test('box не целое число', () {
      // 2.0 намеренно не проверяется: на dart2js `2.0 is int` истинно.
      for (final box in ['2', 2.5, null, true]) {
        expect(
          decodeLeitnerState(_doc({'box': box, 'due': _dueZ})),
          _isErr,
          reason: 'box=$box',
        );
      }
    });

    test('due не парсится', () {
      for (final due in ['вчера', 42, '', null]) {
        expect(
          decodeLeitnerState(_doc({'box': 2, 'due': due})),
          _isErr,
          reason: 'due=$due',
        );
      }
    });

    test('due без обозначения зоны — неоднозначно → Err', () {
      // DateTime.parse читает такую строку по зоне устройства в момент чтения:
      // один и тот же текст на двух телефонах даёт два разных момента.
      expect(
        decodeLeitnerState(_doc({'box': 2, 'due': '2026-03-08T12:00:00.000'})),
        _isErr,
      );
    });

    test('одна битая карточка из двух → Err на весь документ, с её id', () {
      final raw = jsonEncode({
        'version': 1,
        'cards': {
          'apple': {'box': 2, 'due': _dueZ},
          'bread': {'box': 9, 'due': _dueZ},
        },
      });

      final failure = err(decodeLeitnerState(raw));

      expect(failure.message, contains('bread'));
    });
  });
}
