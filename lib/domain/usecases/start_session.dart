/// Единственный usecase Фазы 2: собрать партию из хранилищ и наблюдателей.
///
/// Заведён не ради слоя, а ради проверяемости. До него вся эта проводка жила
/// в обработчике тапа `lib/app/app.dart`, и проверить «после `report()`
/// серия продлилась» можно было только через дерево виджетов. Здесь она
/// проверяется чистым тестом на in-memory портах — без Flutter, без prefs,
/// без экрана.
///
/// Что usecase делает и чего не делает: он **соединяет**, но не решает.
/// Порядок показа остаётся в `LeitnerReviewSession`, шкала оценки — в
/// `domain/srs`, размер сессии приходит параметром от хоста.
library;

import 'dart:async';

import '../core/result.dart';
import '../ports/card_store.dart';
import '../ports/streak_store.dart';
import '../review/review_contract.dart';
import '../session/leitner_review_session.dart';
import '../session/observed_session.dart';
import '../srs/leitner.dart';
import '../streak/streak_observer.dart';

class StartSession {
  StartSession({
    required CardStore cards,
    required StreakStore streaks,
    required DateTime Function() now,
    required int target,
  }) : _cards = cards,
       _streaks = streaks,
       _now = now,
       _target = target;

  final CardStore _cards;
  final StreakStore _streaks;
  final DateTime Function() _now;
  final int _target;

  /// Партия по состоянию хранилищ на текущий момент, или [Err], если
  /// состояние не читается.
  ///
  /// Оба документа — прогресс, и оба битыми дают [Err]: молчаливого сброса
  /// нет ни у карточек, ни у серии. Хост показывает причину и предлагает
  /// сброс, который нажимает человек.
  ///
  /// [onCardsChanged] — для хоста: сохранение в порт usecase берёт на себя,
  /// а колбэк остаётся тому, кому нужна свежая карта (строка итогов).
  Result<ReviewSession> call({
    required List<ReviewItem> items,
    required String gameId,
    void Function(Map<String, LeitnerCard> cards)? onCardsChanged,
  }) {
    throw UnimplementedError();
  }
}
