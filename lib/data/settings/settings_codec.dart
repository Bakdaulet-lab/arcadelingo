/// Кодек настроек напоминания: JSON-документ ↔ [ReminderSettings].
///
/// Формат v1:
/// ```json
/// {"version":1,"enabled":true,"hour":20,"minute":0}
/// ```
///
/// Контракт ошибок тот же, что у кодеков Лейтнера и серии: битые данные —
/// [Err], без исключений, без `as` на данных из JSON, единственный `catch` —
/// `FormatException` из `jsonDecode`. До конструктора [ReminderTime] битые
/// значения не доходят: его `assert` сторожит инвариант, а не разбирает
/// хранилище.
library;

import 'dart:convert';

import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/reminders/reminder_settings.dart';

/// Версия формата документа. Другая — [Err]: читать её некому.
const int _formatVersion = 1;

/// Настройки → JSON-документ.
String encodeSettings(ReminderSettings settings) => jsonEncode({
  'version': _formatVersion,
  'enabled': settings.enabled,
  'hour': settings.at.hour,
  'minute': settings.at.minute,
});

/// JSON-документ → настройки; битые данные — [Err].
Result<ReminderSettings> decodeSettings(String json) {
  final Object? root;
  try {
    root = jsonDecode(json);
  } on FormatException catch (e) {
    return Err(Failure('настройки: невалидный JSON: ${e.message}'));
  }
  if (root is! Map<String, Object?>) {
    return const Err(Failure('настройки: корень не объект'));
  }
  if (root['version'] != _formatVersion) {
    return Err(
      Failure('настройки: неизвестная версия формата ${root['version']}'),
    );
  }
  final enabled = root['enabled'];
  if (enabled is! bool) {
    return Err(Failure('настройки: enabled не булево: $enabled'));
  }
  final hour = root['hour'];
  final minute = root['minute'];
  if (hour is! int || minute is! int) {
    return Err(Failure('настройки: hour или minute не целые: $hour:$minute'));
  }
  final at = ReminderTime.tryCreate(hour, minute);
  if (at == null) {
    return Err(Failure('настройки: такого времени не бывает: $hour:$minute'));
  }
  return Ok(ReminderSettings(enabled: enabled, at: at));
}
