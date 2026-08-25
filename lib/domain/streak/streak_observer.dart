/// Наблюдатель, который продлевает серию дней по факту ответа.
///
/// Первый потребитель шва из `observed_session.dart` и образец для
/// остальных: журнала Этапа 2.3 и аналитики Фазы 3.
library;

import 'dart:async';

import '../ports/streak_store.dart';
import '../session/observed_session.dart';
import 'streak.dart';

class StreakObserver implements ReviewObserver {
  /// [initial] приходит готовым, а не читается здесь: чтение отдаёт
  /// [Result], разбирать его — работа usecase'а, а наблюдатель обязан
  /// оставаться простым. Заодно это один чтение на партию вместо одного на
  /// каждый ответ.
  StreakObserver({required StreakStore store, required StreakState initial})
    : _store = store,
      _state = initial;

  final StreakStore _store;
  StreakState _state;

  /// Текущее состояние серии — для теста проводки и для хоста, если
  /// понадобится показать серию, не перечитывая хранилище.
  StreakState get state => _state;

  /// Первый ответ дня продлевает серию и пишет её; остальные ответы того же
  /// дня не делают ничего.
  ///
  /// Запись — `unawaited`, как и сохранение карточек: `onAnswer` синхронен,
  /// ждать её некому. При убийстве приложения теряется запись в полёте, и
  /// худшее последствие — «серия не продлилась сегодня», которое чинится
  /// следующей партией.
  @override
  void onAnswer(ReviewEvent event) {
    final advanced = advanceStreak(_state, StreakDay.of(event.at));
    // Тот же день возвращает то же состояние — и тогда писать нечего.
    // Сравнение по значению, а не по ссылке: `advanceStreak` вправе
    // вернуть новый объект с теми же полями.
    if (advanced == _state) return;
    _state = advanced;
    unawaited(_store.save(advanced));
  }
}
