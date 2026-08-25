// Журнал событий в памяти: список вместо таблицы.
//
// Фейк, а не мок: проводку хоста надо проверять без единого мока.

import 'package:arcadelingo/domain/events/app_event.dart';
import 'package:arcadelingo/domain/ports/event_log.dart';
import 'package:arcadelingo/domain/streak/streak.dart';

class InMemoryEventLog implements EventLog {
  /// События в порядке поступления — весь смысл фейка.
  final List<AppEvent> events = [];

  /// Роды событий по порядку: по ним читаются ожидания проводки.
  Iterable<AppEventKind> get kinds => events.map((e) => e.kind);

  @override
  Future<void> append(AppEvent event) async => events.add(event);

  @override
  Future<List<AppEvent>> forDay(StreakDay day) async =>
      events.where((e) => e.localDay == day).toList();

  @override
  Future<Map<AppEventKind, int>> countsByKind({
    required StreakDay from,
    required StreakDay to,
  }) async {
    final counts = <AppEventKind, int>{};
    for (final event in events) {
      if (event.localDay.compareTo(from) < 0) continue;
      if (event.localDay.compareTo(to) > 0) continue;
      counts[event.kind] = (counts[event.kind] ?? 0) + 1;
    }
    return counts;
  }
}
