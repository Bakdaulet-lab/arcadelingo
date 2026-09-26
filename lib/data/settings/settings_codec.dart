/// Кодек настроек напоминания: JSON-документ ↔ [AppSettings].
///
/// Формат v2:
/// ```json
/// {"version":2,"enabled":true,"hour":20,"minute":0,"soundOn":true}
/// ```
///
/// Читаются обе версии: v1 — тот же документ без `soundOn`. Миграция ничего
/// не выдумывает: у документа, записанного до звука, человек про звук не
/// решал, и он получает то же самое умолчание, что и новый игрок. Это не
/// подарок, как заморозки в миграции серии v1 → v2, а буквальное отсутствие
/// выбора.
///
/// Контракт ошибок тот же, что у кодеков Лейтнера и серии: битые данные —
/// [Err], без исключений, без `as` на данных из JSON, единственный `catch` —
/// `FormatException` из `jsonDecode`. До конструктора [ReminderTime] битые
/// значения не доходят: его `assert` сторожит инвариант, а не разбирает
/// хранилище.
library;

import 'dart:convert';

import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';

/// Версия, которой пишем.
const int _formatVersion = 2;

/// Версии, которые умеем читать. Старше — [Err]: читать нечем.
const Set<int> _readableVersions = {1, 2};

/// Настройки → JSON-документ.
String encodeSettings(AppSettings settings) => jsonEncode({
  'version': _formatVersion,
  'enabled': settings.enabled,
  'hour': settings.at.hour,
  'minute': settings.at.minute,
  'soundOn': settings.soundOn,
});

/// JSON-документ → настройки; битые данные — [Err].
Result<AppSettings> decodeSettings(String json) {
  final Object? root;
  try {
    root = jsonDecode(json);
  } on FormatException catch (e) {
    return Err(Failure('настройки: невалидный JSON: ${e.message}'));
  }
  if (root is! Map<String, Object?>) {
    return const Err(Failure('настройки: корень не объект'));
  }
  if (!_readableVersions.contains(root['version'])) {
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
  // Ключа нет — это v1, и там про звук не решали. Ключ есть, но не булев —
  // документ битый, и молча подставлять умолчание нельзя: отличие между
  // «не выбирал» и «испорчено» и есть вся разница.
  final sound = root['soundOn'];
  if (sound != null && sound is! bool) {
    return Err(Failure('настройки: soundOn не булево: $sound'));
  }
  return Ok(
    AppSettings(
      enabled: enabled,
      at: at,
      soundOn: sound as bool? ?? AppSettings.defaults.soundOn,
    ),
  );
}
