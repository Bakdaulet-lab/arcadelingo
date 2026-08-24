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
  throw UnimplementedError();
}

/// Текст файла → записи. `null` или пустая строка — первый прогон, пустой
/// список. Битый документ — [FormatException]: молча начать с нуля значило бы
/// потерять всю накопленную калибровку.
List<RejectedEntry> parseRejected(String? json) {
  throw UnimplementedError();
}

/// Записи → текст файла: одна запись в одну строку, как в порции и в сиде.
String encodeRejected(List<RejectedEntry> entries) {
  throw UnimplementedError();
}

/// Только id — то, что нужно импортёру.
Set<String> rejectedIds(String? json) {
  throw UnimplementedError();
}

/// Старые записи плюс новые. Повторный отказ того же слова не заводит вторую
/// запись: первая причина и первая дата — те самые, что нужны калибровке.
List<RejectedEntry> withRejected(
  List<RejectedEntry> existing,
  List<RejectedEntry> added,
) {
  throw UnimplementedError();
}
