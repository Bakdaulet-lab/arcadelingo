/// Шов «ответ произошёл»: декоратор над [ReviewSession] и наблюдатели.
///
/// Зачем декоратор, а не правка сессии или контракта. Трём фичам Фазы 2 и 3 —
/// серии дней, журналу ответов, аналитике — нужно одно и то же событие, и
/// каждая из них по-своему просилась внутрь `LeitnerReviewSession`. Внутрь
/// нельзя: контракт `review_contract.dart` неприкосновенен, а сессия и без
/// того держит очередь, повторы и протокол. Декоратор даёт шов снаружи,
/// ничего из этого не трогая.
///
/// Игры о нём не знают и знать не должны: они видят [ReviewSession], а
/// какой именно — их не касается. `FakeReviewSession` в тестах игр остаётся
/// прежней.
///
/// `onCardsChanged` при этом никуда не девается и наблюдателем не становится:
/// там состояние, здесь события. Смешивать их — значит однажды объяснять,
/// почему запись карточки прилетела дважды.
library;

import '../review/review_contract.dart';
import '../srs/grade_outcome.dart';
import '../srs/review_grade.dart';

/// Один ответ игрока — всё, что о нём известно в момент, когда он случился.
///
/// [grade] считается здесь один раз [gradeOutcome] и раздаётся готовым:
/// иначе каждый наблюдатель завёл бы свою шкалу, а это ровно то, от чего
/// шкала вынесена в `domain/srs`.
class ReviewEvent {
  const ReviewEvent({
    required this.item,
    required this.outcome,
    required this.grade,
    required this.at,
    required this.gameId,
    required this.sessionId,
  });

  /// Слово, по которому пришёл ответ.
  final ReviewItem item;

  /// Сырой факт от игры.
  final ReviewOutcome outcome;

  /// Оценка для планировщика, посчитанная из [outcome].
  final ReviewGrade grade;

  /// Момент ответа — **как его отдал хост**, то есть в его зоне.
  ///
  /// Ни `toUtc()`, ни `toLocal()` здесь нет намеренно. Серии нужен локальный
  /// календарный день, и приведение к UTC сдвинуло бы его для доброй половины
  /// планеты. Журналу Фазы 3 нужен момент — он и приведёт к UTC у себя.
  final DateTime at;

  /// Какая игра дала ответ. На Фазе 2 игра одна; поле заведено сразу, чтобы
  /// Этапу 2.2 не пришлось менять тип события.
  final String gameId;

  /// Партия, внутри которой случился ответ: по нему журнал Этапа 2.3 сможет
  /// собрать ответы одной сессии, не заводя второго ключа.
  final String sessionId;

  @override
  String toString() =>
      'ReviewEvent(${item.word.id}, $grade, at: $at, '
      'game: $gameId, session: $sessionId)';
}

/// Кто-то, кому интересен факт ответа.
///
/// Бросок отсюда не глушится: наблюдатель, который упал, — баг, и молчание
/// о нём стоило бы дороже. К моменту вызова внутренняя сессия уже в
/// согласованном состоянии, так что падение наблюдателя её не портит.
abstract class ReviewObserver {
  void onAnswer(ReviewEvent event);
}

/// [ReviewSession], которая после каждого доклада зовёт наблюдателей.
///
/// Порядок в [report] важен: сначала делегат, потом наблюдатели. Делегат —
/// хозяин протокола, он же бросит [StateError] на `report()` без выданного
/// слова; наблюдатели зовутся только тогда, когда ответ действительно принят.
class ObservedSession implements ReviewSession {
  ObservedSession({
    required ReviewSession inner,
    required List<ReviewObserver> observers,
    required DateTime Function() now,
    required String gameId,
    required String sessionId,
  }) : _inner = inner,
       _observers = List.unmodifiable(observers),
       _now = now,
       _gameId = gameId,
       _sessionId = sessionId;

  final ReviewSession _inner;
  final List<ReviewObserver> _observers;
  final DateTime Function() _now;
  final String _gameId;
  final String _sessionId;

  /// Выданное слово: событию нужно знать, по какому именно пришёл ответ.
  /// Зеркалит состояние делегата, а не заменяет его страж.
  ReviewItem? _current;

  @override
  ReviewItem? nextItem() {
    throw UnimplementedError();
  }

  @override
  void report(ReviewOutcome outcome) {
    throw UnimplementedError();
  }

  @override
  bool get isFinished => _inner.isFinished;

  @override
  int get answered => _inner.answered;

  @override
  int get total => _inner.total;
}
