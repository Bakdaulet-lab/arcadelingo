/// Реализация порта [AnswerLog] поверх [AnswerDatabase].
///
/// Всё, что этот класс делает, — переводит строку таблицы в [AnswerRecord] и
/// обратно. Ни одного решения о том, что считать ответом, здесь нет: правило
/// проекции живёт в `domain/log/answer_record.dart`, а порядок и смысл
/// запросов — в самом порту.
library;

import 'package:arcadelingo/data/day_text.dart';
import 'package:arcadelingo/data/log/answer_database.dart';
import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/ports/answer_log.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:drift/drift.dart';

class DriftAnswerLog implements AnswerLog {
  DriftAnswerLog(this._db);

  final AnswerDatabase _db;

  @override
  Future<void> append(AnswerRecord record) {
    throw UnimplementedError('DriftAnswerLog.append');
  }

  @override
  Future<List<AnswerRecord>> all() {
    throw UnimplementedError('DriftAnswerLog.all');
  }

  @override
  Future<List<AnswerRecord>> forWord(String wordId) {
    throw UnimplementedError('DriftAnswerLog.forWord');
  }

  @override
  Future<List<DayTally>> perDay({
    required StreakDay from,
    required StreakDay to,
  }) {
    throw UnimplementedError('DriftAnswerLog.perDay');
  }
}
