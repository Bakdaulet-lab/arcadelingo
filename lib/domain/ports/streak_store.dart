/// Порт хранилища серии — по образцу [CardStore] и по тем же причинам.
///
/// [load] синхронный из того же соображения: `StartSession` читает состояние
/// в момент тапа «Играть», между тапом и сессией `await` нет.
library;

import '../core/result.dart';
import '../streak/streak.dart';
import 'card_store.dart';

/// Серия дней подряд.
abstract class StreakStore {
  /// Сохранённое состояние. Пусто — первый запуск, не ошибка: [StreakState.empty].
  /// Битый документ — [Err], без автосброса.
  Result<StreakState> load();

  /// Записывает состояние целиком.
  Future<bool> save(StreakState state);

  /// Удаляет документ. Как и у карточек, зовётся только по нажатию человека:
  /// «Сбросить прогресс» сбрасывает весь прогресс, а серия — это прогресс.
  Future<bool> reset();
}
