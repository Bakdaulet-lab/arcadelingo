// Напоминания в памяти: журнал того, что поставили и что сняли.
//
// Фейк, а не мок: проводку надо проверять без единого мока, и «что именно
// ушло в расписание» читается списком, а не настройкой ожиданий.

import 'package:arcadelingo/domain/ports/reminders.dart';

/// Одно поставленное напоминание.
class ScheduledReminder {
  const ScheduledReminder({
    required this.at,
    required this.title,
    required this.body,
  });

  final DateTime at;
  final String title;
  final String body;

  @override
  String toString() => 'ScheduledReminder($at: $title)';
}

class FakeReminders implements Reminders {
  /// Всё, что поставили, по порядку. Последний элемент — то, что стоит
  /// сейчас: адаптер снимает прежнее перед каждой постановкой.
  final List<ScheduledReminder> scheduled = [];

  /// Сколько раз снимали всё.
  int cancels = 0;

  /// То, что стоит в расписании сейчас; null — не ставили ничего.
  ScheduledReminder? get current => scheduled.isEmpty ? null : scheduled.last;

  @override
  Future<void> schedule({
    required DateTime at,
    required String title,
    required String body,
  }) async {
    scheduled.add(ScheduledReminder(at: at, title: title, body: body));
  }

  @override
  Future<void> cancelAll() async => cancels++;
}
