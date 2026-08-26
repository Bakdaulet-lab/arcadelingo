// Настройки напоминания: время суток и умолчание.

import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Время суток', () {
    test('несуществующее время — не создаётся', () {
      expect(ReminderTime.tryCreate(24, 0), isNull);
      expect(ReminderTime.tryCreate(-1, 0), isNull);
      expect(ReminderTime.tryCreate(20, 60), isNull);
      expect(ReminderTime.tryCreate(20, -1), isNull);
    });

    test('границы суток существуют', () {
      expect(ReminderTime.tryCreate(0, 0), const ReminderTime(0, 0));
      expect(ReminderTime.tryCreate(23, 59), const ReminderTime(23, 59));
    });

    test('накладывается на день, не трогая дату', () {
      final moment = const ReminderTime(7, 5).on(DateTime(2026, 8, 26, 23, 40));

      expect(moment, DateTime(2026, 8, 26, 7, 5));
    });

    test('в строке — часы и минуты с ведущими нулями', () {
      expect(const ReminderTime(7, 5).toString(), '07:05');
    });

    test('равенство по полям', () {
      expect(const ReminderTime(20, 0), const ReminderTime(20, 0));
      expect(const ReminderTime(20, 0), isNot(const ReminderTime(20, 1)));
    });
  });

  group('Умолчание', () {
    // Приложение, спрашивающее разрешение на уведомления до того, как человек
    // о них попросил, — приложение, которому отказывают.
    test('напоминания выключены', () {
      expect(AppSettings.defaults.enabled, isFalse);
    });

    test('час выставлен, чтобы его было куда двигать', () {
      expect(AppSettings.defaults.at, const ReminderTime(20, 0));
    });
  });

  group('Правка', () {
    test('copyWith меняет одно поле и не трогает второе', () {
      final on = AppSettings.defaults.copyWith(enabled: true);

      expect(on.enabled, isTrue);
      expect(on.at, AppSettings.defaults.at);
    });

    test('равенство по полям', () {
      expect(
        AppSettings.defaults.copyWith(enabled: true),
        const AppSettings(enabled: true, at: ReminderTime(20, 0)),
      );
    });
  });
}
