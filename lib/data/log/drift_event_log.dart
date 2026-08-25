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
  Future<void> append(AppEvent event) {
    throw UnimplementedError('DriftEventLog.append');
  }

  @override
  Future<List<AppEvent>> forDay(StreakDay day) {
    throw UnimplementedError('DriftEventLog.forDay');
  }

  @override
  Future<Map<AppEventKind, int>> countsByKind({
    required StreakDay from,
    required StreakDay to,
  }) {
    throw UnimplementedError('DriftEventLog.countsByKind');
  }
}
