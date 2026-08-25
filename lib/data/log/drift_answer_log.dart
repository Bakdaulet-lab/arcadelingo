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
  Future<void> append(AnswerRecord record) => _db
      .into(_db.answers)
      .insert(
        AnswersCompanion.insert(
          wordId: record.wordId,
          // toUtc() здесь, а не у вызывающего: колонка хранит момент, зону
          // ей записать нечем, и приводить обязано то, что пишет.
          atUtcMicros: record.at.toUtc().microsecondsSinceEpoch,
          localDay: encodeDay(record.localDay),
          grade: record.grade,
          correct: record.correct,
          responseMicros: record.responseTime.inMicroseconds,
          limitMicros: record.timeLimit.inMicroseconds,
          hintsUsed: record.hintsUsed,
          gameId: record.gameId,
          sessionId: record.sessionId,
        ),
      );

  @override
  Future<List<AnswerRecord>> all() => _read(_db.select(_db.answers));

  @override
  Future<List<AnswerRecord>> forWord(String wordId) =>
      _read(_db.select(_db.answers)..where((row) => row.wordId.equals(wordId)));

  @override
  Future<List<DayTally>> perDay({
    required StreakDay from,
    required StreakDay to,
  }) async {
    final answers = _db.answers;
    final total = answers.id.count();
    // CAST, а не COUNT(...) FILTER: фильтрованный счёт — синтаксис новее, чем
    // самая старая из трёх наших сборок sqlite обязана понимать. Колонка
    // булева, то есть 0 или 1, и её сумма и есть число верных.
    final right = answers.correct.cast<int>().sum();
    final query =
        _db.selectOnly(answers)
          ..addColumns([answers.localDay, total, right])
          // Границы включительно; сравнение строк совпадает с календарным,
          // потому что формат `ГГГГ-ММ-ДД` с ведущими нулями (`day_text.dart`).
          ..where(
            answers.localDay.isBetweenValues(encodeDay(from), encodeDay(to)),
          )
          ..groupBy([answers.localDay])
          ..orderBy([OrderingTerm.asc(answers.localDay)]);

    final rows = await query.get();
    return [
      for (final row in rows)
        DayTally(
          // Строка пришла из нашей же колонки и другой быть не может: формат
          // сторожит ограничение длины плюс единственная точка записи выше.
          day: decodeDay(row.read(answers.localDay)!)!,
          answers: row.read(total)!,
          correct: row.read(right) ?? 0,
        ),
    ];
  }

  /// Общий хвост чтений: порядок и перевод строк в записи.
  ///
  /// Порядок задан здесь, а не в каждом методе: хронологический — обещание
  /// порта, и переигровка на нём стоит. Второй ключ — `id`: на подставленных
  /// часах вся партия попадает в один момент, и без него порядок ответов
  /// внутри неё определялся бы тем, как БД решит вернуть строки.
  Future<List<AnswerRecord>> _read(
    SimpleSelectStatement<$AnswersTable, Answer> query,
  ) async {
    query.orderBy([
      (row) => OrderingTerm.asc(row.atUtcMicros),
      (row) => OrderingTerm.asc(row.id),
    ]);
    return [for (final row in await query.get()) _toRecord(row)];
  }

  AnswerRecord _toRecord(Answer row) => AnswerRecord(
    wordId: row.wordId,
    at: DateTime.fromMicrosecondsSinceEpoch(row.atUtcMicros, isUtc: true),
    localDay: decodeDay(row.localDay)!,
    grade: row.grade,
    correct: row.correct,
    responseTime: Duration(microseconds: row.responseMicros),
    timeLimit: Duration(microseconds: row.limitMicros),
    hintsUsed: row.hintsUsed,
    gameId: row.gameId,
    sessionId: row.sessionId,
  );
}
