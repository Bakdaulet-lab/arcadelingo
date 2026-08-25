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
import 'package:arcadelingo/domain/streak/streak.dart';
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

/// Партия целиком; возвращает число ответов.
///
/// Число нужно не для красоты. Верный ответ уводит слово в третью коробку на
/// трое суток, поэтому короткий сид кончается после первой же партии, и
/// вторая оказывается пустой. Тест, который этого не заметит, будет
/// ложно-зелёным: «серия не изменилась» станет означать «отвечать было
/// нечего», а не «правило сработало».
int _playThrough(ReviewSession session) {
  var answered = 0;
  while (true) {
    final item = session.nextItem();
    if (item == null) return answered;
    session.report(_correct());
    answered++;
  }
}

/// Usecase на сиде, которого хватает на несколько партий подряд: короткая
/// партия и длинный сид, чтобы каждой следующей было что показать.
StartSession _usecase({
  required DateTime Function() now,
  required InMemoryStreakStore streaks,
  InMemoryCardStore? cards,
}) => StartSession(
  cards: cards ?? InMemoryCardStore(),
  streaks: streaks,
  now: now,
  target: 3,
);

/// Сид на несколько партий.
List<ReviewItem> _seed() => wordItems(30);

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

  group('Серия продвигается по ответу', () {
    test('первый ответ дня записывает серию в хранилище', () {
      final streaks = InMemoryStreakStore();
      final usecase = StartSession(
        cards: InMemoryCardStore(),
        streaks: streaks,
        now: () => _today,
        target: 15,
      );

      final session = ok(usecase(items: wordItems(3), gameId: 'falling_words'));
      session.nextItem();
      session.report(_correct());

      expect(streaks.saves, hasLength(1));
      expect(streaks.state.current, 1);
      expect(streaks.state.lastDay, StreakDay(2026, 8, 25));
    });

    test('остальные ответы того же дня не пишут ничего', () {
      final streaks = InMemoryStreakStore();
      final usecase = StartSession(
        cards: InMemoryCardStore(),
        streaks: streaks,
        now: () => _today,
        target: 15,
      );

      final answered = _playThrough(
        ok(usecase(items: wordItems(3), gameId: 'falling_words')),
      );

      expect(answered, 3, reason: 'ответов несколько, а запись одна');
      expect(
        streaks.saves,
        hasLength(1),
        reason: 'серия меняется раз в день, а не раз в ответ',
      );
    });

    test('вторая партия в тот же день серию не двигает', () {
      final streaks = InMemoryStreakStore();
      final usecase = _usecase(now: () => _today, streaks: streaks);

      _playThrough(ok(usecase(items: _seed(), gameId: 'falling_words')));
      final afterFirst = streaks.state;
      final second = _playThrough(
        ok(usecase(items: _seed(), gameId: 'falling_words')),
      );

      expect(
        second,
        greaterThan(0),
        reason: 'иначе тест зелен оттого, что отвечать было нечего',
      );
      expect(streaks.state, afterFirst);
    });

    test('партия назавтра продлевает серию', () {
      var now = _today;
      final streaks = InMemoryStreakStore();
      final usecase = _usecase(now: () => now, streaks: streaks);

      _playThrough(ok(usecase(items: _seed(), gameId: 'falling_words')));
      now = _today.add(const Duration(days: 1));
      final second = _playThrough(
        ok(usecase(items: _seed(), gameId: 'falling_words')),
      );

      expect(second, greaterThan(0));
      expect(streaks.state.current, 2);
      expect(streaks.state.best, 2);
      expect(streaks.state.lastDay, StreakDay(2026, 8, 26));
    });

    test('пропущенный день обрывает серию, рекорд остаётся', () {
      var now = _today;
      final streaks = InMemoryStreakStore();
      final usecase = _usecase(now: () => now, streaks: streaks);

      for (final shift in [0, 1, 3]) {
        now = _today.add(Duration(days: shift));
        final answered = _playThrough(
          ok(usecase(items: _seed(), gameId: 'falling_words')),
        );
        expect(answered, greaterThan(0), reason: 'день $shift: партия пустая');
      }

      expect(streaks.state.current, 1);
      expect(streaks.state.best, 2);
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
