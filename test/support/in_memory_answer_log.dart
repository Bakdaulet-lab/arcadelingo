// Журнал ответов в памяти: список вместо таблицы.
//
// Отдельным файлом от `in_memory_stores.dart` намеренно. Те два фейка —
// хранилища состояния, у них есть `reset()` и битые варианты; журнал append-only
// и падать ему незачем. Складывать в один файл разное значит однажды дописать
// сюда `FailingAnswerLog` просто по соседству, хотя порт отказов не знает.
//
// Фейк, а не мок (`.claude/rules/domain.md`): наблюдатель и переигровка обязаны
// проверяться без единого мока.

import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/ports/answer_log.dart';
import 'package:arcadelingo/domain/streak/streak.dart';

class InMemoryAnswerLog implements AnswerLog {
  /// Записи в порядке поступления. Публичный список — весь смысл фейка:
  /// по нему видно, что и сколько раз записали.
  final List<AnswerRecord> records = [];

  @override
  Future<void> append(AnswerRecord record) async => records.add(record);

  @override
  Future<List<AnswerRecord>> all() async => List.of(records);

  @override
  Future<List<AnswerRecord>> forWord(String wordId) async =>
      records.where((r) => r.wordId == wordId).toList();

  @override
  Future<List<DayTally>> perDay({
    required StreakDay from,
    required StreakDay to,
  }) async {
    final byDay = <StreakDay, DayTally>{};
    for (final record in records) {
      final day = record.localDay;
      if (day.compareTo(from) < 0 || day.compareTo(to) > 0) continue;
      final seen = byDay[day];
      byDay[day] = DayTally(
        day: day,
        answers: (seen?.answers ?? 0) + 1,
        correct: (seen?.correct ?? 0) + (record.correct ? 1 : 0),
      );
    }
    final days = byDay.keys.toList()..sort();
    return [for (final day in days) byDay[day]!];
  }

  @override
  Future<AnswerTotals> totals() async => AnswerTotals(
    answers: records.length,
    correct: records.where((r) => r.correct).length,
    days: {for (final r in records) r.localDay}.length,
  );
}
