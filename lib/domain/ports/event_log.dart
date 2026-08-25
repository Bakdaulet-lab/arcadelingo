/// Порт журнала событий — четвёртый после карточек, серии и ответов.
///
/// Устроен как [AnswerLog] и по тем же причинам: пишется всегда, читается
/// редко, не изменяется никогда, отказ в [Result] не заворачивается. Разница
/// одна и она в чтениях: у ответов спрашивают историю слова, у событий —
/// воронку. «Открыл — начал — доиграл» это три числа за отрезок, а не список.
library;

import '../events/app_event.dart';
import '../streak/streak.dart';

abstract class EventLog {
  /// Дописывает событие. Уже записанные не трогает.
  Future<void> append(AppEvent event);

  /// События одного дня в хронологическом порядке.
  ///
  /// Для разбора конкретного дня: воронка говорит «в среду бросили три
  /// партии», а этот метод — что именно за средой стояло.
  Future<List<AppEvent>> forDay(StreakDay day);

  /// Сколько событий каждого рода случилось за отрезок [from]..[to],
  /// включая обе границы.
  ///
  /// Роды, которых не было ни разу, в карте отсутствуют — их ноль виден по
  /// отсутствию ключа, и достраивать нули обязан тот, кто рисует, а не
  /// хранилище. То же правило, что у `AnswerLog.perDay` с пустыми днями.
  Future<Map<AppEventKind, int>> countsByKind({
    required StreakDay from,
    required StreakDay to,
  });

  /// Дни отрезка [from]..[to], в которые случилось хотя бы одно событие рода
  /// [kind]. Границы включительно.
  ///
  /// Множество, а не список: полосе недели важно «был ли день», а не сколько
  /// раз. Первый потребитель — стрик-карточка с `roundOver`: она обязана
  /// показывать сыгранные дни, а не выводить их из длины серии, потому что
  /// состояние помнит текущую серию и ничего до её обрыва.
  Future<Set<StreakDay>> daysWith({
    required AppEventKind kind,
    required StreakDay from,
    required StreakDay to,
  });
}

/// Журнал, который ничего не пишет и ничего не помнит.
///
/// Умолчание для всех, кому события не нужны: тестов, которые о них не знают,
/// и любого хоста, который журнал не подключил. Приложение с ним работает
/// полностью, просто без истории.
class NoopEventLog implements EventLog {
  const NoopEventLog();

  @override
  Future<void> append(AppEvent event) async {}

  @override
  Future<List<AppEvent>> forDay(StreakDay day) async => const [];

  @override
  Future<Map<AppEventKind, int>> countsByKind({
    required StreakDay from,
    required StreakDay to,
  }) async => const {};

  @override
  Future<Set<StreakDay>> daysWith({
    required AppEventKind kind,
    required StreakDay from,
    required StreakDay to,
  }) async => const {};
}
