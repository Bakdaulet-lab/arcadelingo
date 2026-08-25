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
  final day = state.lastDay;
  return jsonEncode({
    'version': _formatVersion,
    'current': state.current,
    'best': state.best,
    if (day != null) 'last_day': _formatDay(day),
  });
}

/// День в формате `ГГГГ-ММ-ДД`.
///
/// Своя функция, а не `toString()`: `toString` — для чтения человеком в
/// сообщении упавшего теста, и завязывать на него формат хранилища значит
/// однажды сломать документ, поправив отладочный вывод.
String _formatDay(StreakDay day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// JSON-документ хранилища → состояние; битые данные — [Err].
Result<StreakState> decodeStreakState(String json) {
  final Object? root;
  try {
    root = jsonDecode(json);
  } on FormatException catch (e) {
    return Err(Failure('серия: невалидный JSON: ${e.message}'));
  }
  if (root is! Map<String, Object?>) {
    return const Err(Failure('серия: корень не объект'));
  }
  if (root['version'] != _formatVersion) {
    return Err(Failure('серия: неизвестная версия формата ${root['version']}'));
  }
  final current = root['current'];
  if (current is! int || current < 0) {
    return Err(
      Failure('серия: current отсутствует или не целое ≥ 0: $current'),
    );
  }
  final best = root['best'];
  if (best is! int || best < 0) {
    return Err(Failure('серия: best отсутствует или не целое ≥ 0: $best'));
  }
  if (best < current) {
    return Err(Failure('серия: best $best меньше current $current'));
  }
  final rawDay = root['last_day'];
  if (rawDay == null) {
    if (current != 0) {
      return Err(
        Failure('серия: current $current без last_day — состояние неполное'),
      );
    }
    return Ok(StreakState(current: current, best: best));
  }
  if (rawDay is! String) {
    return Err(Failure('серия: last_day не строка: $rawDay'));
  }
  final parsed = _dayFormat.firstMatch(rawDay);
  if (parsed == null) {
    return Err(
      Failure(
        'серия: last_day не дата вида ГГГГ-ММ-ДД: "$rawDay". '
        'У дня нет момента, а значит нет и зоны',
      ),
    );
  }
  final day = StreakDay.tryCreate(
    int.parse(parsed.group(1)!),
    int.parse(parsed.group(2)!),
    int.parse(parsed.group(3)!),
  );
  if (day == null) {
    return Err(Failure('серия: last_day — несуществующая дата: "$rawDay"'));
  }
  if (current == 0) {
    return Err(
      Failure('серия: last_day "$rawDay" при current 0 — состояние неполное'),
    );
  }
  return Ok(StreakState(current: current, best: best, lastDay: day));
}
