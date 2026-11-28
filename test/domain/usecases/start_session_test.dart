// Проводка партии: хранилища, сессия, наблюдатели.
//
// Ради этого файла usecase и заведён. До него та же проводка жила в
// обработчике тапа, и проверить «после report() серия продлилась» можно было
// только через дерево виджетов — с prefs, маршрутами и кадрами. Здесь это
// чистый тест на портах в памяти: ни Flutter, ни хранилища, ни экрана.
//
// Часы инъектируются переменной: «завтра» здесь — присваивание, а не сутки
// ожидания.

import 'dart:math';

import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/usecases/start_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_stores.dart';
import '../../support/result.dart';
import '../../support/review_items.dart';

final DateTime _today = DateTime(2026, 8, 25, 10);

ReviewOutcome _correct() => const ReviewOutcome(
  correct: true,
  responseTime: Duration(seconds: 1),
  timeLimit: Duration(seconds: 6),
);

ReviewItem _levelWord(String id, CefrLevel level) =>
    ReviewItem(word: Word(id: id, text: id, translation: id, level: level));

void main() {
  test(
    'continuous play cycles through one level and saves each actual answer',
    () {
      final untouched = LeitnerCard(box: 4, due: _today);
      final cards = InMemoryCardStore({'outside': untouched});
      final session =
          ok(
                StartSession(
                  cards: cards,
                  streaks: InMemoryStreakStore(),
                  now: () => _today,
                  target: 1,
                )(
                  items: [
                    _levelWord('outside', CefrLevel.b2),
                    for (final id in ['uno', 'dos', 'tres'])
                      _levelWord(id, CefrLevel.a2),
                  ],
                  gameId: 'snake',
                  level: CefrLevel.a2,
                  continuousShuffle: Random(17),
                ),
              )
              as BoardReviewSession;
      String? previous;
      for (var cycle = 0; cycle < 6; cycle++) {
        final seen = <String>{};
        for (var i = 0; i < 3; i++) {
          final item = session.remainingItems.first;
          expect(item.word.id, isNot(previous));
          expect(seen.add(item.word.id), isTrue);
          previous = item.word.id;
          if (cycle.isEven) {
            session.reportPair(item, _correct());
          } else {
            expect(session.nextItem(), same(item));
            session.report(_correct());
          }
          expect(session.isFinished, isFalse);
        }
        expect(seen, {'uno', 'dos', 'tres'});
      }
      expect(session.answered, 18);
      expect(cards.saves, hasLength(18));
      expect(cards.saves.last['outside'], untouched);
    },
  );

  group('Не читается состояние — партии нет', () {
    test('битые карточки: Err с причиной, сессия не создаётся', () {
      final usecase = StartSession(
        cards: FailingCardStore('карточка "apple": box 9 вне 1..5'),
        streaks: InMemoryStreakStore(),
        now: () => _today,
        target: 15,
      );

      final result = usecase(items: wordItems(3), gameId: 'falling_words');

      expect(result, isA<Err<ReviewSession>>());
      expect(err(result).message, contains('box 9'));
    });

    test('битая серия — тоже Err: серия это прогресс', () {
      final usecase = StartSession(
        cards: InMemoryCardStore(),
        streaks: FailingStreakStore('серия: last_day не парсится'),
        now: () => _today,
        target: 15,
      );

      final result = usecase(items: wordItems(3), gameId: 'falling_words');

      expect(result, isA<Err<ReviewSession>>());
      expect(
        err(result).message,
        contains('last_day'),
        reason: 'причина обязана называть, какой именно документ побит',
      );
    });

    test('битая серия не роняет карточки: в них никто не писал', () {
      final cards = InMemoryCardStore();
      final usecase = StartSession(
        cards: cards,
        streaks: FailingStreakStore(),
        now: () => _today,
        target: 15,
      );

      usecase(items: wordItems(3), gameId: 'falling_words');

      expect(cards.saves, isEmpty);
    });
  });

  // Группа «Серия продвигается по ответу» уехала целиком в
  // `count_played_day_test.dart`: с Фазы 3 день засчитывает конец партии, а
  // не первый ответ, и StartSession серию больше не двигает вовсе. Сценарии
  // не выброшены — они те же самые, только у нового вызывающего.
  //
  // Чтение серии здесь осталось, и проверяет его группа «Ошибки хранилища»:
  // битый документ обязан стать громким на входе в партию, а не на итогах.

  group('Уровень слов', () {
    test('в раунде A2 только его новые слова и повторы', () {
      final usecase = StartSession(
        cards: InMemoryCardStore({
          'a1-due': LeitnerCard(
            box: 2,
            due: _today.subtract(const Duration(days: 1)),
          ),
          'a2-due': LeitnerCard(box: 2, due: _today),
        }),
        streaks: InMemoryStreakStore(),
        now: () => _today,
        target: 15,
      );

      final session = ok(
        usecase(
          items: [
            _levelWord('a1-due', CefrLevel.a1),
            _levelWord('a2-new', CefrLevel.a2),
            _levelWord('b1-new', CefrLevel.b1),
            _levelWord('a2-due', CefrLevel.a2),
          ],
          gameId: 'falling_words',
          level: CefrLevel.a2,
        ),
      );

      expect(session.total, 2);
      expect(session.nextItem()!.word.id, 'a2-due');
      session.report(_correct());
      expect(session.nextItem()!.word.id, 'a2-new');
      session.report(_correct());
      expect(session.nextItem(), isNull);
    });

    test('пустой B1 не подмешивает слова других уровней', () {
      final usecase = StartSession(
        cards: InMemoryCardStore(),
        streaks: InMemoryStreakStore(),
        now: () => _today,
        target: 15,
      );

      final session = ok(
        usecase(
          items: [_levelWord('a2-new', CefrLevel.a2)],
          gameId: 'ninja_slash',
          level: CefrLevel.b1,
        ),
      );

      expect(session.total, 0);
      expect(session.isFinished, isTrue);
      expect(session.nextItem(), isNull);
    });

    test('ответ на A2 не меняет сохранённую карточку другого уровня', () {
      final a1Card = LeitnerCard(box: 4, due: _today);
      final cards = InMemoryCardStore({'a1-due': a1Card});
      final usecase = StartSession(
        cards: cards,
        streaks: InMemoryStreakStore(),
        now: () => _today,
        target: 15,
      );

      final session = ok(
        usecase(
          items: [
            _levelWord('a1-due', CefrLevel.a1),
            _levelWord('a2-new', CefrLevel.a2),
          ],
          gameId: 'ninja_slash',
          level: CefrLevel.a2,
        ),
      );
      expect(session.nextItem()!.word.id, 'a2-new');
      session.report(_correct());

      expect(cards.saves.single['a1-due'], a1Card);
      expect(cards.saves.single['a2-new']?.box, 3);
    });
  });

  group('Карточки', () {
    test('состояние сохраняется в порт после каждого ответа', () {
      final cards = InMemoryCardStore();
      final usecase = StartSession(
        cards: cards,
        streaks: InMemoryStreakStore(),
        now: () => _today,
        target: 15,
      );

      final session = ok(usecase(items: wordItems(3), gameId: 'falling_words'));
      session.nextItem();
      session.report(_correct());
      session.nextItem();
      session.report(_correct());

      expect(cards.saves, hasLength(2));
      expect(cards.saves.last.keys, containsAll(<String>['w01', 'w02']));
    });

    test(
      'хосту тоже отдают свежую карту — по ней он считает строку итогов',
      () {
        final seen = <Map<String, LeitnerCard>>[];
        final usecase = StartSession(
          cards: InMemoryCardStore(),
          streaks: InMemoryStreakStore(),
          now: () => _today,
          target: 15,
        );

        final session = ok(
          usecase(
            items: wordItems(3),
            gameId: 'falling_words',
            onCardsChanged: seen.add,
          ),
        );
        session.nextItem();
        session.report(_correct());

        expect(seen, hasLength(1));
        expect(
          seen.single['w01']!.box,
          3,
          reason: 'быстрый верный ответ — easy',
        );
      },
    );

    test('очередь строится по состоянию хранилища, а не с нуля', () {
      // w01 уже в пятой коробке и созреет через три недели: в сегодняшнюю
      // очередь он попасть не должен.
      final cards = InMemoryCardStore({
        'w01': LeitnerCard(box: 5, due: _today.add(const Duration(days: 21))),
      });
      final usecase = StartSession(
        cards: cards,
        streaks: InMemoryStreakStore(),
        now: () => _today,
        target: 15,
      );

      final session = ok(usecase(items: wordItems(3), gameId: 'falling_words'));

      expect(session.total, 2);
      expect(session.nextItem()!.word.id, 'w02');
    });
  });
}
