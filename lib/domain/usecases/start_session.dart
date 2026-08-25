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
import '../log/logging_observer.dart';
import '../ports/answer_log.dart';
import '../ports/card_store.dart';
import '../ports/streak_store.dart';
import '../review/review_contract.dart';
import '../session/leitner_review_session.dart';
import '../session/observed_session.dart';
import '../srs/leitner.dart';
import '../streak/streak.dart';
import '../streak/streak_observer.dart';

class StartSession {
  StartSession({
    required CardStore cards,
    required StreakStore streaks,
    required DateTime Function() now,
    required int target,
    AnswerLog answerLog = const NoopAnswerLog(),
  }) : _cards = cards,
       _streaks = streaks,
       _now = now,
       _target = target,
       _answerLog = answerLog;

  final CardStore _cards;
  final StreakStore _streaks;
  final DateTime Function() _now;
  final int _target;

  /// Журнал ответов. С умолчанием, а не обязательным параметром: истории у
  /// приложения не было до Этапа 2.3, и партия без неё полноценна. Тесты,
  /// которые о журнале не знают, получают нулевой объект и не меняются.
  final AnswerLog _answerLog;

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
    final Map<String, LeitnerCard> cards;
    switch (_cards.load()) {
      case Ok(:final value):
        cards = value;
      case Err(:final failure):
        return Err(failure);
    }
    // Серия читается до создания сессии, а не при первом ответе: партия,
    // которая началась и упала на середине, — худший из возможных исходов.
    final StreakState streak;
    switch (_streaks.load()) {
      case Ok(:final value):
        streak = value;
      case Err(:final failure):
        return Err(failure);
    }
    final startedAt = _now();
    final inner = LeitnerReviewSession.start(
      cards: cards,
      items: items,
      target: _target,
      now: _now,
      onCardsChanged: (changed) {
        // Ответ уже принят, ждать записи некому: report() не async, а
        // сохранение кодирует состояние синхронно, до первого await.
        unawaited(_cards.save(changed));
        onCardsChanged?.call(changed);
      },
    );
    return Ok(
      ObservedSession(
        inner: inner,
        // Порядок наблюдателей значения не имеет: они не разговаривают
        // друг с другом и видят одно и то же событие.
        observers: [
          StreakObserver(store: _streaks, initial: streak),
          LoggingObserver(log: _answerLog),
        ],
        now: _now,
        gameId: gameId,
        // Момент старта, а не счётчик: партия длится минуты, столкнуться
        // двум сессиям в одной миллисекунде негде, а значение при этом
        // детерминировано подставленными часами.
        sessionId: startedAt.toIso8601String(),
      ),
    );
  }
}
