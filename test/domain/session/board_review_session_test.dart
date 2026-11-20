import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/usecases/start_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_answer_log.dart';
import '../../support/in_memory_stores.dart';

void main() {
  test(
    'board reports in any order through the real session and preserves unplayed cards',
    () {
      final items = List.generate(
        8,
        (index) => ReviewItem(
          word: Word(
            id: '$index',
            text: 'word $index',
            translation: 'перевод $index',
            level: CefrLevel.b1,
          ),
        ),
      );
      final log = InMemoryAnswerLog();
      final cards = InMemoryCardStore();
      final result =
          StartSession(
                cards: cards,
                streaks: InMemoryStreakStore(),
                answerLog: log,
                now: () => DateTime(2026, 11, 21),
                target: 7,
              )(items: items, level: CefrLevel.b1, gameId: 'word_mahjong')
              as Ok<ReviewSession>;
      final session = result.value as BoardReviewSession;
      const wrong = ReviewOutcome.untimed(
        correct: false,
        responseTime: Duration.zero,
        selectedAnswer: 'ошибка',
      );
      const right = ReviewOutcome.untimed(
        correct: true,
        responseTime: Duration.zero,
      );
      expect(session.remainingItems, items.take(7));
      expect(cards.saves, isEmpty);
      expect(() => session.reportPair(items.last, right), throwsStateError);
      session.reportPair(items[3], wrong);
      expect(() => session.reportPair(items[3], wrong), throwsStateError);
      expect(session.remainingItems, [
        items[0],
        items[1],
        items[2],
        ...items.sublist(4, 7),
      ]);
      session.reportPair(items[1], right);
      expect(session.answered, 2);
      expect(session.total, 7);
      expect(log.records.map((record) => record.wordId), ['3', '1']);
      expect(log.records.first.correct, isFalse);
      expect(log.records.last.correct, isTrue);
      expect(cards.saves.last.keys, unorderedEquals(['3', '1']));
      expect(session.isFinished, isFalse);
    },
  );
}
