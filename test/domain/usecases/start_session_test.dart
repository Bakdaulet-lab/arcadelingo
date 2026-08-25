// Проводка партии: хранилища, сессия, наблюдатели.
//
// Ради этого файла usecase и заведён. До него та же проводка жила в
// обработчике тапа, и проверить «после report() серия продлилась» можно было
// только через дерево виджетов — с prefs, маршрутами и кадрами. Здесь это
// чистый тест на портах в памяти: ни Flutter, ни хранилища, ни экрана.
//
// Часы инъектируются переменной: «завтра» здесь — присваивание, а не сутки
// ожидания.

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

void main() {
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
