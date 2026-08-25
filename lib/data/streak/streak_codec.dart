/// Кодек серии: JSON-документ хранилища ↔ [StreakState].
///
/// Формат v2:
/// ```json
/// {"version":2,"current":5,"best":9,"last_day":"2026-08-28",
///  "freezes":0,"days_since_freeze":1,"frozen_day":"2026-08-27"}
/// ```
/// Пустое состояние пишется без `last_day`: дня ещё не было. `frozen_day`
/// пишется, только если заморозка что-то прикрыла в текущей серии.
///
/// **Документы v1 читаются** — они лежат на телефонах, и терять на них
/// прогресс не за что. Недостающие поля запаса приходят нулями: заморозки не
/// существовало, когда документ писали, значит человек её не заработал и не
/// потерял. Выдать её при миграции значило бы развести правила — новый игрок
/// начинает без заморозки, а мигрировавший с ней. Пишем всегда v2.
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

/// Версия, в которой пишем.
const int _formatVersion = 2;

/// Версии, которые умеем читать. Всё остальное — [Err]: читать её некому.
const Set<int> _readableVersions = {1, 2};

/// Ровно дата и ничего кроме: ни времени, ни зоны, ни лишних цифр.
final RegExp _dayFormat = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Состояние → JSON-документ для хранилища.
String encodeStreakState(StreakState state) {
  final day = state.lastDay;
  final frozen = state.lastFrozenDay;
  return jsonEncode({
    'version': _formatVersion,
    'current': state.current,
    'best': state.best,
    if (day != null) 'last_day': _formatDay(day),
    'freezes': state.freezes,
    'days_since_freeze': state.daysSinceFreeze,
    if (frozen != null) 'frozen_day': _formatDay(frozen),
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
  final version = root['version'];
  if (version is! int || !_readableVersions.contains(version)) {
    return Err(Failure('серия: неизвестная версия формата $version'));
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
  final StreakDay? day;
  final rawDay = root['last_day'];
  if (rawDay == null) {
    if (current != 0) {
      return Err(
        Failure('серия: current $current без last_day — состояние неполное'),
      );
    }
    day = null;
  } else {
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
    day = StreakDay.tryCreate(
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
  }

  // Запас заморозок. В документах v1 его нет и быть не может — приходит
  // нулями (см. шапку). В v2 поля обязательны: отсутствие — не «значение по
  // умолчанию», а неполный документ.
  var freezes = 0;
  var daysSinceFreeze = 0;
  StreakDay? frozenDay;
  if (version >= 2) {
    final rawFreezes = root['freezes'];
    if (rawFreezes is! int ||
        rawFreezes < 0 ||
        rawFreezes > StreakState.maxFreezes) {
      return Err(
        Failure(
          'серия: freezes отсутствует или вне '
          '0..${StreakState.maxFreezes}: $rawFreezes',
        ),
      );
    }
    freezes = rawFreezes;

    final rawSince = root['days_since_freeze'];
    if (rawSince is! int || rawSince < 0) {
      return Err(
        Failure(
          'серия: days_since_freeze отсутствует или не целое ≥ 0: $rawSince',
        ),
      );
    }
    if (freezes == StreakState.maxFreezes && rawSince != 0) {
      return Err(
        Failure(
          'серия: заморозка в запасе и days_since_freeze $rawSince — '
          'копить уже нечего',
        ),
      );
    }
    daysSinceFreeze = rawSince;

    final rawFrozen = root['frozen_day'];
    if (rawFrozen != null) {
      if (rawFrozen is! String) {
        return Err(Failure('серия: frozen_day не строка: $rawFrozen'));
      }
      final parsed = _dayFormat.firstMatch(rawFrozen);
      if (parsed == null) {
        return Err(
          Failure(
            'серия: frozen_day не дата вида ГГГГ-ММ-ДД: "$rawFrozen". '
            'У дня нет момента, а значит нет и зоны',
          ),
        );
      }
      frozenDay = StreakDay.tryCreate(
        int.parse(parsed.group(1)!),
        int.parse(parsed.group(2)!),
        int.parse(parsed.group(3)!),
      );
      if (frozenDay == null) {
        return Err(
          Failure('серия: frozen_day — несуществующая дата: "$rawFrozen"'),
        );
      }
      if (day == null || frozenDay.compareTo(day) >= 0) {
        return Err(
          Failure(
            'серия: frozen_day "$rawFrozen" не раньше last_day "$day" — '
            'заморозить можно только прошедший день',
          ),
        );
      }
    }
  }

  return Ok(
    StreakState(
      current: current,
      best: best,
      lastDay: day,
      freezes: freezes,
      daysSinceFreeze: daysSinceFreeze,
      lastFrozenDay: frozenDay,
    ),
  );
}
