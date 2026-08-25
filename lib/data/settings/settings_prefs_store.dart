/// Настройки напоминания в `shared_preferences`: один ключ, один документ.
///
/// Устройство скопировано с двух соседних сторов до мелочей — три документа в
/// одном хранилище обязаны вести себя одинаково, иначе «не читается» будет
/// значить разное в зависимости от того, какой именно побился.
///
/// Отличие ровно одно, и оно в природе данных: настройки — не прогресс. Их
/// потеря обидна, но не смертельна, поэтому битый документ здесь не ведёт к
/// экрану ошибки, а показывает умолчание (решение хоста, не стора).
library;

import 'package:arcadelingo/data/settings/settings_codec.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/ports/settings_store.dart';
import 'package:arcadelingo/domain/reminders/reminder_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPrefsStore implements SettingsStore {
  SettingsPrefsStore(this._prefs);

  final SharedPreferences _prefs;

  /// Ключ документа. Переименование — потеря настроек у пользователей; тест
  /// держит это имя литералом именно поэтому.
  static const String key = 'reminder_settings';

  @override
  Result<ReminderSettings> load() {
    final raw = _prefs.getString(key);
    if (raw == null) return const Ok(ReminderSettings.defaults);
    return decodeSettings(raw);
  }

  @override
  Future<bool> save(ReminderSettings settings) =>
      _prefs.setString(key, encodeSettings(settings));

  @override
  Future<bool> reset() => _prefs.remove(key);
}
