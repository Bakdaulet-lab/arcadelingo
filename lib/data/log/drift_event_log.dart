/// Реализация порта [EventLog] поверх [HistoryDatabase].
///
/// Всё, что делает класс, — переводит событие в строку и обратно. Ни одного
/// решения о том, что считать событием, здесь нет: род события заводит
/// `domain/events/app_event.dart`, а смысл запросов — сам порт.
library;

import 'package:arcadelingo/data/day_text.dart';
import 'package:arcadelingo/data/log/history_database.dart';
import 'package:arcadelingo/domain/events/app_event.dart';
import 'package:arcadelingo/domain/ports/event_log.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:drift/drift.dart';

class DriftEventLog implements EventLog {
  DriftEventLog(this._db);

  final HistoryDatabase _db;

  @override
  Future<void> append(AppEvent event) => _db
      .into(_db.events)
      .insert(
        EventsCompanion.insert(
          kind: event.kind,
          // toUtc() здесь, а не у вызывающего: колонка хранит момент, зону ей
          // записать нечем, и приводить обязано то, что пишет.
          atUtcMicros: event.at.toUtc().microsecondsSinceEpoch,
          localDay: encodeDay(event.localDay),
          sessionId: Value(event.sessionId),
        ),
      );

  @override
  Future<List<AppEvent>> forDay(StreakDay day) async {
    final query =
        _db.select(_db.events)
          ..where((row) => row.localDay.equals(encodeDay(day)))
          // Хронологический, а с равными моментами — в порядке записи: на
          // подставленных часах весь день попадает в один момент.
          ..orderBy([
            (row) => OrderingTerm.asc(row.atUtcMicros),
            (row) => OrderingTerm.asc(row.id),
          ]);
    return [for (final row in await query.get()) _toEvent(row)];
  }

  @override
  Future<Map<AppEventKind, int>> countsByKind({
    required StreakDay from,
    required StreakDay to,
  }) async {
    final events = _db.events;
    final total = events.id.count();
    final query =
        _db.selectOnly(events)
          ..addColumns([events.kind, total])
          // Границы включительно; сравнение строк совпадает с календарным,
          // потому что формат `ГГГГ-ММ-ДД` с ведущими нулями (`day_text.dart`).
          ..where(
            events.localDay.isBetweenValues(encodeDay(from), encodeDay(to)),
          )
          ..groupBy([events.kind]);

    return {
      // readWithConverter, а не read: колонка хранит имя значения, и
      // обратный перевод делает тот же конвертер, что и при записи.
      for (final row in await query.get())
        row.readWithConverter(events.kind)!: row.read(total)!,
    };
  }

  @override
  Future<Set<StreakDay>> daysWith({
    required AppEventKind kind,
    required StreakDay from,
    required StreakDay to,
  }) {
    throw UnimplementedError('DriftEventLog.daysWith');
  }

  AppEvent _toEvent(Event row) => AppEvent(
    kind: row.kind,
    at: DateTime.fromMicrosecondsSinceEpoch(row.atUtcMicros, isUtc: true),
    localDay: decodeDay(row.localDay)!,
    sessionId: row.sessionId,
  );
}
