/// Порт настроек напоминания — четвёртый документ prefs после карточек,
/// серии и... впрочем, третий: журналы живут в БД.
///
/// Устроен как [StreakStore] и по тем же причинам: [load] синхронный, битый
/// документ — [Err], молчаливого сброса нет. Отличие одно и оно в природе
/// данных: настройки — не прогресс. Потерять их обиднее, чем неприятно, но
/// не смертельно, и экран настроек умеет показать умолчание.
library;

import '../core/result.dart';
import '../reminders/reminder_settings.dart';

abstract class SettingsStore {
  /// Сохранённые настройки. Ключа нет — [ReminderSettings.defaults], не
  /// ошибка. Битый документ — [Err]; реализация ничего не сбрасывает сама.
  Result<ReminderSettings> load();

  Future<bool> save(ReminderSettings settings);

  Future<bool> reset();
}
