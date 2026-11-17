import 'package:arcadelingo/domain/learning/learning_plan.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/leitner_review_session.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 11, 17, 12);

ReviewItem _item(String id, CefrLevel level) => ReviewItem(
  word: Word(
    id: id,
    text: 'word-$id',
    translation: 'перевод-$id',
    level: level,
  ),
  distractors: ['вариант-$id'],
);

List<String> _ids(Iterable<ReviewItem> items) =>
    items.map((item) => item.word.id).toList();

void main() {
  for (final level in CefrLevel.values) {
    test(
      '${level.name}: знакомство и очередь содержат только выбранный уровень',
      () {
        final items = <ReviewItem>[];
        final cards = <String, LeitnerCard>{};
        for (final itemLevel in CefrLevel.values) {
          items.add(_item('${itemLevel.name}-due', itemLevel));
          items.add(_item('${itemLevel.name}-future', itemLevel));
          for (var index = 0; index < 8; index++) {
            items.add(_item('${itemLevel.name}-new-$index', itemLevel));
          }
          cards['${itemLevel.name}-due'] = LeitnerCard(
            box: 2,
            due: _now.subtract(const Duration(days: 1)),
          );
          cards['${itemLevel.name}-future'] = LeitnerCard(
            box: 4,
            due: _now.add(const Duration(days: 1)),
          );
        }
        final before = Map<String, LeitnerCard>.of(cards);
        final plan = LearningPlan.build(
          items: items,
          cards: cards,
          level: level,
          now: _now,
        );

        expect(_ids(plan.selectedItems), [
          '${level.name}-due',
          for (var index = 0; index < 5; index++) '${level.name}-new-$index',
        ]);
        expect(plan.newWords.map((word) => word.id), [
          for (var index = 0; index < 5; index++) '${level.name}-new-$index',
        ]);
        expect(plan.newWords.every((word) => word.level == level), isTrue);
        expect(cards, before, reason: 'просмотр не изменяет прогресс');
      },
    );
  }

  test('повторы идут по сроку, равные сроки — по порядку словаря', () {
    final first = _item('first', CefrLevel.b1);
    final oldest = _item('oldest', CefrLevel.b1);
    final sameDue = _item('same-due', CefrLevel.b1);
    final plan = LearningPlan.build(
      items: [_item('new', CefrLevel.b1), first, oldest, sameDue],
      cards: {
        first.word.id: LeitnerCard(box: 2, due: _now),
        oldest.word.id: LeitnerCard(
          box: 3,
          due: _now.subtract(const Duration(days: 2)),
        ),
        sameDue.word.id: LeitnerCard(box: 4, due: _now),
      },
      level: CefrLevel.b1,
      now: _now,
    );

    expect(_ids(plan.selectedItems), ['oldest', 'first', 'same-due', 'new']);
    expect(plan.newWords.single.id, 'new');
  });

  test('15 срочных повторов занимают раунд без добавления новых слов', () {
    final reviews = [
      for (var index = 0; index < 18; index++)
        _item('review-$index', CefrLevel.a2),
    ];
    final plan = LearningPlan.build(
      items: [_item('new', CefrLevel.a2), ...reviews],
      cards: {
        for (final item in reviews)
          item.word.id: LeitnerCard(box: 2, due: _now),
      },
      level: CefrLevel.a2,
      now: _now,
    );

    expect(_ids(plan.selectedItems), _ids(reviews.take(15)));
    expect(plan.newWords, isEmpty);
  });

  test('при 13 повторах знакомство содержит только два новых слова', () {
    final reviews = [
      for (var index = 0; index < 13; index++)
        _item('review-$index', CefrLevel.c1),
    ];
    final plan = LearningPlan.build(
      items: [
        ...reviews,
        for (var index = 0; index < 7; index++)
          _item('new-$index', CefrLevel.c1),
      ],
      cards: {
        for (final item in reviews)
          item.word.id: LeitnerCard(box: 2, due: _now),
      },
      level: CefrLevel.c1,
      now: _now,
    );

    expect(plan.selectedItems, hasLength(15));
    expect(plan.newWords.map((word) => word.id), ['new-0', 'new-1']);
  });

  test('пустой уровень и только будущие повторы дают пустой план', () {
    final plan = LearningPlan.build(
      items: [_item('foreign', CefrLevel.a1), _item('future', CefrLevel.c2)],
      cards: {
        'future': LeitnerCard(box: 4, due: _now.add(const Duration(days: 1))),
      },
      level: CefrLevel.c2,
      now: _now,
    );

    expect(plan.selectedItems, isEmpty);
    expect(plan.newWords, isEmpty);
  });

  test('одно слово не дублируется ни в знакомстве, ни в игровой очереди', () {
    final item = _item('same', CefrLevel.b2);
    final plan = LearningPlan.build(
      items: [item, item, _item('second', CefrLevel.b2), item],
      cards: {},
      level: CefrLevel.b2,
      now: _now,
    );

    expect(_ids(plan.selectedItems), ['same', 'second']);
    expect(plan.newWords.map((word) => word.id), ['same', 'second']);
  });

  test('допустимые нулевые лимиты и меньший размер раунда', () {
    final items = [
      for (var index = 0; index < 8; index++) _item('$index', CefrLevel.b1),
    ];
    final noRound = LearningPlan.build(
      items: items,
      cards: {},
      level: CefrLevel.b1,
      now: _now,
      target: 0,
    );
    final noNew = LearningPlan.build(
      items: items,
      cards: {},
      level: CefrLevel.b1,
      now: _now,
      maxNewWords: 0,
    );
    final short = LearningPlan.build(
      items: items,
      cards: {},
      level: CefrLevel.b1,
      now: _now,
      target: 3,
    );

    expect(noRound.selectedItems, isEmpty);
    expect(noRound.newWords, isEmpty);
    expect(noNew.selectedItems, isEmpty);
    expect(noNew.newWords, isEmpty);
    expect(short.newWords.map((word) => word.id), ['0', '1', '2']);
    expect(_ids(short.selectedItems), ['0', '1', '2']);
  });

  test('отрицательные лимиты отклоняются как неверный вызов', () {
    expect(
      () => LearningPlan.build(
        items: [],
        cards: {},
        level: CefrLevel.a1,
        now: _now,
        target: -1,
      ),
      throwsArgumentError,
    );
    expect(
      () => LearningPlan.build(
        items: [],
        cards: {},
        level: CefrLevel.a1,
        now: _now,
        maxNewWords: -1,
      ),
      throwsArgumentError,
    );
  });

  test(
    'план — неизменяемый снимок, исходные списки и карта остаются независимы',
    () {
      final item = _item('new', CefrLevel.b1);
      final items = [item];
      final cards = <String, LeitnerCard>{};
      final plan = LearningPlan.build(
        items: items,
        cards: cards,
        level: CefrLevel.b1,
        now: _now,
      );

      items.clear();
      cards[item.word.id] = LeitnerCard(box: 5, due: _now);
      expect(_ids(plan.selectedItems), ['new']);
      expect(plan.newWords.single.id, 'new');
      expect(() => plan.selectedItems.clear(), throwsUnsupportedError);
      expect(() => plan.newWords.clear(), throwsUnsupportedError);
    },
  );

  test(
    'реальная сессия не выдаёт неизвестные слова за пределами знакомства',
    () {
      final items = [
        for (var index = 0; index < 20; index++) _item('$index', CefrLevel.c2),
      ];
      final plan = LearningPlan.build(
        items: items,
        cards: {},
        level: CefrLevel.c2,
        now: _now,
      );
      final seen = <String>[];
      final session = LeitnerReviewSession.start(
        cards: {},
        items: plan.selectedItems,
        target: 15,
        now: () => _now,
        onCardsChanged: (_) {},
      );
      while (!session.isFinished) {
        final item = session.nextItem()!;
        seen.add(item.word.id);
        session.report(
          const ReviewOutcome(
            correct: false,
            responseTime: Duration(seconds: 6),
            timeLimit: Duration(seconds: 6),
          ),
        );
      }

      expect(seen, hasLength(5));
      expect(
        seen.toSet().difference(plan.newWords.map((word) => word.id).toSet()),
        isEmpty,
      );
      expect(seen.toSet(), isNot(contains('5')));
    },
  );
}
