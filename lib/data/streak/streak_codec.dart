/// Кодек серии: JSON-документ хранилища ↔ [StreakState].
///
/// Формат v1:
/// ```json
/// {"version":1,"current":3,"best":7,"last_day":"2026-08-25"}
/// ```
/// Пустое состояние пишется без `last_day`: дня ещё не было.
///
/// Контракт ошибок тот же, что у кодека Лейтнера: битые данные — [Err], без
/// исключений, без `as`/`.cast()` на данных из JSON, единственный `catch` —
/// `FormatException` из `jsonDecode`. До конструктора [StreakState] и
/// [StreakDay] битые значения не доходят — их `ArgumentError` сторожит
/// инвариант, а не разбирает хранилище.
///
/// **`last_day` разбирается своим парсером, а не `DateTime.tryParse`,** и это
/// главное отличие от кодека Лейтнера. `tryParse` принял бы
/// `2026-08-25T12:00:00Z` и `2026-08-25T12:00:00+05:00` — то есть моменты, у
/// которых есть зона, — и молча превратил бы их в день. У дня зоны нет
/// (`streak.dart`), поэтому формат здесь ровно один: `ГГГГ-ММ-ДД`, всё
/// остальное — битая запись.
library;

import 'dart:convert';

import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/streak/streak.dart';

/// Версия формата документа. Другая версия — [Err]: читать её некому.
const int _formatVersion = 1;

/// Ровно дата и ничего кроме: ни времени, ни зоны, ни лишних цифр.
final RegExp _dayFormat = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Состояние → JSON-документ для хранилища.
String encodeStreakState(StreakState state) {
  throw UnimplementedError();
}

/// JSON-документ хранилища → состояние; битые данные — [Err].
Result<StreakState> decodeStreakState(String json) {
  throw UnimplementedError();
}
