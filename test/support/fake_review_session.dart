// Фейковая ReviewSession для тестов игры: заранее заданные слова, журнал
// докладов и счётчик запросов.
//
// Строгость — не украшение, а смысл этого файла. Настоящая сессия
// (lib/domain/session/leitner_review_session.dart) бросает StateError на
// нарушение протокола «ровно один report() на каждый непустой nextItem()».
// Мягкий фейк пропустил бы двойной тап, на котором продакшн упадёт, —
// game-contract требует ровно этого совпадения и называет ноль и два
// report() самой частой ошибкой игр.
//
// Чего фейк не делает: не планирует повторы и не строит очередь. Слово,
// которое должно вернуться в ту же сессию, кладут в список дважды.

import 'package:arcadelingo/domain/review/review_contract.dart';

/// Один доклад: по какому слову он пришёл и что игра сообщила.
typedef ReportRecord = ({ReviewItem item, ReviewOutcome outcome});

/// Сессия из готового списка слов.
class FakeReviewSession implements ReviewSession {
  /// Слова выдаются в порядке [items]. [total] отвечает за HUD и по
  /// умолчанию равен длине списка; хост может задать больший размер
  /// сессии, чем реально набралось слов.
  factory FakeReviewSession(Iterable<ReviewItem> items, {int? total}) {
    final queue = List.of(items);
    return FakeReviewSession._(queue, total ?? queue.length);
  }

  FakeReviewSession._(this._queue, this.total);

  final List<ReviewItem> _queue;

  /// Всё, что игра доложила, по порядку.
  final List<ReportRecord> reports = [];

  /// Сколько раз игра спросила слово — включая вызов, вернувший null.
  int nextItemCalls = 0;

  /// Выданное и ещё не отвеченное слово — страж протокола.
  ReviewItem? _current;

  int _answered = 0;

  @override
  final int total;

  @override
  int get answered => _answered;

  @override
  bool get isFinished => _current == null && _queue.isEmpty;

  @override
  ReviewItem? nextItem() {
    final pending = _current;
    if (pending != null) {
      throw StateError(
        'nextItem() до report(): слово "${pending.word.id}" выдано, ответа нет',
      );
    }
    nextItemCalls++;
    if (_queue.isEmpty) return null;
    final item = _queue.removeAt(0);
    _current = item;
    return item;
  }

  @override
  void report(ReviewOutcome outcome) {
    final item = _current;
    if (item == null) {
      throw StateError(
        'report() без выданного слова: nextItem() не вызывался '
        'или ответ по нему уже доложен',
      );
    }
    _current = null;
    _answered++;
    reports.add((item: item, outcome: outcome));
  }
}
