// Стор настроек: тот же контракт, что у двух соседних документов prefs.

import 'package:arcadelingo/data/settings/settings_codec.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/domain/reminders/reminder_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/result.dart';

Future<SettingsPrefsStore> _store([
  Map<String, Object> prefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  return SettingsPrefsStore(await SharedPreferences.getInstance());
}

void main() {
  test('ключа нет — умолчание, а не ошибка', () async {
    final store = await _store();

    expect(ok(store.load()), ReminderSettings.defaults);
  });

  test('записанное читается обратно', () async {
    final store = await _store();
    const settings = ReminderSettings(enabled: true, at: ReminderTime(7, 30));

    await store.save(settings);

    expect(ok(store.load()), settings);
  });

  test('битый документ — Err, и стор ничего не сбрасывает', () async {
    final store = await _store({SettingsPrefsStore.key: 'битый документ'});

    expect(err(store.load()).message, contains('настройки'));
    expect(
      (await SharedPreferences.getInstance()).getString(SettingsPrefsStore.key),
      isNotNull,
      reason: 'молчаливого сброса нет ни у одного документа',
    );
  });

  test('reset удаляет документ: следующее чтение — умолчание', () async {
    final store = await _store();
    await store.save(ReminderSettings.defaults.copyWith(enabled: true));

    await store.reset();

    expect(ok(store.load()), ReminderSettings.defaults);
  });

  // Литералом: переименование ключа — потеря настроек у пользователей.
  test('пишет под своим ключом и не трогает чужие', () async {
    final store = await _store({LeitnerPrefsStore.key: 'карточки'});

    await store.save(ReminderSettings.defaults.copyWith(enabled: true));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('reminder_settings'), isNotNull);
    expect(prefs.getString(LeitnerPrefsStore.key), 'карточки');
  });

  test('запись заменяет документ целиком', () async {
    final store = await _store();
    await store.save(
      const ReminderSettings(enabled: true, at: ReminderTime(7, 0)),
    );

    await store.save(ReminderSettings.defaults);

    expect(
      (await SharedPreferences.getInstance()).getString(SettingsPrefsStore.key),
      encodeSettings(ReminderSettings.defaults),
    );
  });
}
