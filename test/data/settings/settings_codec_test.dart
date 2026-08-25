// Кодек настроек: тот же контракт ошибок, что у двух соседних документов.

import 'package:arcadelingo/data/settings/settings_codec.dart';
import 'package:arcadelingo/domain/reminders/reminder_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/result.dart';

/// Документ с подставленными полями.
String _doc({
  String enabled = 'true',
  String hour = '20',
  String minute = '0',
}) => '{"version":1,"enabled":$enabled,"hour":$hour,"minute":$minute}';

void main() {
  group('Круговой прогон', () {
    test('настройки переживают запись и чтение', () {
      const settings = ReminderSettings(enabled: true, at: ReminderTime(7, 5));

      expect(ok(decodeSettings(encodeSettings(settings))), settings);
    });

    test('выключенные тоже', () {
      expect(
        ok(decodeSettings(encodeSettings(ReminderSettings.defaults))),
        ReminderSettings.defaults,
      );
    });

    test('пишется версия 1', () {
      expect(
        encodeSettings(ReminderSettings.defaults),
        contains('"version":1'),
      );
    });
  });

  group('Битые данные — Err, до конструктора не доходят', () {
    test('невалидный JSON', () {
      expect(err(decodeSettings('не json')).message, contains('JSON'));
    });

    test('корень не объект', () {
      expect(err(decodeSettings('[1,2]')).message, contains('настройки'));
    });

    test('неизвестная версия', () {
      expect(
        err(
          decodeSettings('{"version":2,"enabled":true,"hour":20,"minute":0}'),
        ).message,
        contains('версия'),
      );
    });

    test('enabled не булево', () {
      expect(
        err(decodeSettings(_doc(enabled: '"да"'))).message,
        contains('enabled'),
      );
    });

    test('час или минута не целые', () {
      expect(err(decodeSettings(_doc(hour: '"20"'))).message, contains('hour'));
      expect(
        err(decodeSettings(_doc(minute: 'null'))).message,
        contains('minute'),
      );
    });

    test('такого времени не бывает', () {
      expect(
        err(decodeSettings(_doc(hour: '24'))).message,
        contains('времени'),
      );
      expect(
        err(decodeSettings(_doc(minute: '60'))).message,
        contains('времени'),
      );
      expect(
        err(decodeSettings(_doc(hour: '-1'))).message,
        contains('времени'),
      );
    });

    test('поля отсутствуют', () {
      expect(err(decodeSettings('{"version":1}')).message, contains('enabled'));
    });
  });
}
