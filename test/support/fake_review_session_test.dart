// Тесты строгости фейка, а не игры.
//
// Без них тест игры на двойной тап доказывал бы только мягкость фейка:
// пропустил второй report() — значит «зелёный», а настоящая сессия на том
// же сценарии бросит StateError. game-contract: «Фейк обязан быть таким же
// строгим, как настоящая сессия». Формулировки бросков сверены с
// lib/domain/session/leitner_review_session.dart.

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_review_session.dart';

/// Слово по номеру: w01, w02, …
ReviewItem _item(int i) {
  final id = 'w${i.toString().padLeft(2, '0')}';
  return ReviewItem(
    word: Word(id: id, text: id, translation: 'перевод $id'),
    distractors: const ['обманка'],
  );
}

/// Сид из [n] слов.
List<ReviewItem> _items(int n) => [for (var i = 1; i <= n; i++) _item(i)];

const ReviewOutcome _answer = ReviewOutcome(
  correct: true,
  responseTime: Duration(seconds: 1),
  timeLimit: Duration(seconds: 6),
);

void main() {
  test('report() без выданного слова → StateError', () {
    final session = FakeReviewSession(_items(2));

    expect(() => session.report(_answer), throwsStateError);
  });

  test('nextItem() при неотвеченном слове → StateError', () {
    final session = FakeReviewSession(_items(2));

    session.nextItem();

    expect(() => session.nextItem(), throwsStateError);
  });

  test('второй report() по тому же слову → StateError', () {
    final session = FakeReviewSession(_items(2));

    session.nextItem();
    session.report(_answer);

    expect(() => session.report(_answer), throwsStateError);
    expect(session.reports, hasLength(1), reason: 'второй доклад не записан');
  });

  test('слова выдаются по порядку, дальше null; счётчики растут', () {
    final session = FakeReviewSession(_items(2), total: 15);

    expect(session.total, 15, reason: 'размер сессии задаёт хост');
    expect(session.nextItem()!.word.id, 'w01');
    session.report(_answer);
    expect(session.nextItem()!.word.id, 'w02');
    session.report(_answer);

    expect(session.nextItem(), isNull, reason: 'очередь исчерпана');
    expect(session.nextItemCalls, 3, reason: 'пустой вызов тоже считается');
    expect(session.answered, 2);
    expect(session.isFinished, isTrue);
    expect(session.reports.map((r) => r.item.word.id), ['w01', 'w02']);
  });
}
