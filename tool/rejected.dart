/// Формат `tool/out/rejected.json` — слова, отклонённые при вычитке.
///
/// Зачем файл вообще существует: без него ручная работа испаряется. Слово,
/// выброшенное на порции 3, вернулось бы в порцию 30 и было бы разобрано
/// заново — с тем же исходом и той же потраченной минутой. Причины отказов
/// вдобавок копятся в калибровку генератора обманок (К3): «нет одного главного
/// значения» и «перевод сталкивается с уже принятым» — разные болезни.
///
/// Поэтому этот файл единственный из `tool/out/` живёт в истории репозитория
/// (`.gitignore`: `tool/out/*` плюс `!tool/out/rejected.json`).
///
/// Читают его двое: `merge_portion` дописывает, `import_cefrj` исключает эти id
/// из новых порций ровно так же, как слова, уже лежащие в сиде.
library;

import 'dart:convert';

/// Версия формата. Другая — [FormatException]: читать её некому.
const int rejectedFormatVersion = 1;

/// Одно отклонённое слово.
class RejectedEntry {
  const RejectedEntry({
    required this.id,
    required this.reason,
    required this.date,
    required this.portion,
  });

  final String id;

  /// Причина отказа, как её написал человек. Пустой она быть не может: отказ
  /// без причины ничему не учит и в калибровку не годится.
  final String reason;

  /// `ГГГГ-ММ-ДД` в UTC. Дата, а не момент: точность до дня здесь и нужна,
  /// а зона в дате без времени — источник вечных расхождений.
  final String date;

  /// Из какой порции слово выброшено — чтобы видеть, где было тяжело.
  final int portion;
}

/// `ГГГГ-ММ-ДД` в UTC из момента. Время в инструмент приходит параметром:
/// иначе тест не отличить от прогона.
String formatRejectedDate(DateTime now) {
  final utc = now.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$month-$day';
}

/// Текст файла → записи. `null` или пустая строка — первый прогон, пустой
/// список. Битый документ — [FormatException]: молча начать с нуля значило бы
/// потерять всю накопленную калибровку.
List<RejectedEntry> parseRejected(String? json) {
  if (json == null || json.trim().isEmpty) return const [];
  final Object? root;
  try {
    root = jsonDecode(json);
  } on FormatException catch (e) {
    throw FormatException('файл отказов: невалидный JSON: ${e.message}');
  }
  if (root is! Map<String, Object?>) {
    throw const FormatException('файл отказов: корень не объект');
  }
  if (root['version'] != rejectedFormatVersion) {
    throw FormatException(
      'файл отказов: неизвестная версия формата ${root['version']}',
    );
  }
  final raw = root['rejected'];
  if (raw is! List<Object?>) {
    throw const FormatException(
      'файл отказов: поле rejected отсутствует или не список',
    );
  }
  final entries = <RejectedEntry>[];
  for (final (index, item) in raw.indexed) {
    if (item is! Map<String, Object?>) {
      throw FormatException('файл отказов: запись #$index не объект');
    }
    final id = item['id'];
    final reason = item['reason'];
    final date = item['date'];
    final portion = item['portion'];
    final name = id is String && id.isNotEmpty ? '"$id"' : '#$index';
    if (id is! String || id.isEmpty) {
      throw FormatException('файл отказов: запись $name без id');
    }
    if (reason is! String || reason.trim().isEmpty) {
      throw FormatException('файл отказов: запись $name без причины');
    }
    if (date is! String || date.isEmpty) {
      throw FormatException('файл отказов: запись $name без даты');
    }
    if (portion is! int) {
      throw FormatException('файл отказов: запись $name без номера порции');
    }
    entries.add(
      RejectedEntry(id: id, reason: reason, date: date, portion: portion),
    );
  }
  return entries;
}

/// Записи → текст файла: одна запись в одну строку, как в порции и в сиде.
String encodeRejected(List<RejectedEntry> entries) {
  final buffer =
      StringBuffer()
        ..writeln('{')
        ..writeln('  "version": $rejectedFormatVersion,')
        ..writeln('  "rejected": [');
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final comma = i == entries.length - 1 ? '' : ',';
    buffer.writeln(
      '    { "id": ${jsonEncode(entry.id)}, '
      '"reason": ${jsonEncode(entry.reason)}, '
      '"date": ${jsonEncode(entry.date)}, '
      '"portion": ${entry.portion} }$comma',
    );
  }
  return (buffer
        ..writeln('  ]')
        ..writeln('}'))
      .toString();
}

/// Только id — то, что нужно импортёру.
Set<String> rejectedIds(String? json) => {
  for (final entry in parseRejected(json)) entry.id,
};

/// Старые записи плюс новые. Повторный отказ того же слова не заводит вторую
/// запись: первая причина и первая дата — те самые, что нужны калибровке.
List<RejectedEntry> withRejected(
  List<RejectedEntry> existing,
  List<RejectedEntry> added,
) {
  final result = [...existing];
  final known = {for (final entry in existing) entry.id};
  for (final entry in added) {
    if (known.add(entry.id)) result.add(entry);
  }
  return result;
}
