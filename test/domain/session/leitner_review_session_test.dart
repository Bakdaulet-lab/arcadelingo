// Сессия повторения поверх Лейтнера (задача 0.6). Правила очереди —
// .claude/skills/srs-engine/SKILL.md, «Очередь сессии»; обязательный кейс из
// docs/dev/tasks.md — «карточка из коробки 1 всплывает не раньше чем через
// 3 другие».
//
// Оценки задаются литералами ReviewOutcome при лимите 10 с, а не через
// ReviewGrade: сессия получает от игры сырой факт, и тест обязан идти тем же
// путём. Интервалы Лейтнера (1 день за good, 3 за easy) — тоже литералами,
// как в leitner_test.dart: тест сверяется со скиллом, а не с реализацией.
//
// Часы — замыкание над локальной переменной: DateTime.now() здесь нет намеренно.

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/leitner_review_session.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Фиксированное «сейчас» старта сессии.
final _t0 = DateTime.utc(2026, 3, 8, 12);

const _limit = Duration(seconds: 10);

/// Неверный ответ: again при любом времени.
const _again = ReviewOutcome(
  correct: false,
  responseTime: _limit,
  timeLimit: _limit,
);

/// ratio 0.8 → hard: коробка та же, для новой карточки — снова коробка 1.
const _hard = ReviewOutcome(
  correct: true,
  responseTime: Duration(seconds: 8),
  timeLimit: _limit,
);

/// ratio 0.4 → good: коробка +1.
const _good = ReviewOutcome(
  correct: true,
  responseTime: Duration(seconds: 4),
  timeLimit: _limit,
);

/// ratio 0.1 → easy: коробка +2.
const _easy = ReviewOutcome(
  correct: true,
  responseTime: Duration(seconds: 1),
  timeLimit: _limit,
);

/// id слова по номеру в сиде: w01, w02, …
String _w(int i) => 'w${i.toString().padLeft(2, '0')}';

/// id первых [n] слов сида.
List<String> _ids(int n) => [for (var i = 1; i <= n; i++) _w(i)];

/// Сид из слов с данными id, в этом порядке.
List<ReviewItem> _items(Iterable<String> ids) => [
  for (final id in ids)
    ReviewItem(
      word: Word(id: id, text: id, translation: 'перевод $id'),
      distractors: const ['x', 'y', 'z'],
    ),
];

/// Сессия с разумными умолчаниями: пустое состояние, часы стоят на [_t0],
/// снимки карты после каждого report() — в [snapshots].
LeitnerReviewSession _start({
  required List<ReviewItem> items,
  Map<String, LeitnerCard>? cards,
  int target = 15,
  DateTime Function()? now,
  List<Map<String, LeitnerCard>>? snapshots,
}) => LeitnerReviewSession.start(
  cards: cards ?? <String, LeitnerCard>{},
  items: items,
  target: target,
  now: now ?? () => _t0,
  // Карта живая — снимок копирует её в момент вызова.
  onCardsChanged: (cards) => snapshots?.add(Map.of(cards)),
);

/// Проигрывает сессию до конца, отвечая [answer] (по умолчанию good — без
/// повторов), и возвращает id слов в порядке показа.
List<String> _play(
  ReviewSession session, {
  ReviewOutcome Function(String id)? answer,
}) {
  final shown = <String>[];
  for (var item = session.nextItem(); item != null; item = session.nextItem()) {
    shown.add(item.word.id);
    session.report(answer?.call(item.word.id) ?? _good);
  }
  return shown;
}

/// [outcome] на первом показе каждого слова из [ids], иначе good.
ReviewOutcome Function(String) _onFirstShowing(
  Set<String> ids,
  ReviewOutcome outcome,
) {
  final seen = <String>{};
  return (id) => ids.contains(id) && seen.add(id) ? outcome : _good;
}

/// again на [k]-м показе (считая с 1), иначе good.
ReviewOutcome Function(String) _missAt(int k) {
  var shown = 0;
  return (_) => ++shown == k ? _again : _good;
}

void main() {
  group('Состав очереди', () {
    test('пустое состояние, 50 слов, target 15 → первые 15 слов сида', () {
      final session = _start(items: _items(_ids(50)), target: 15);

      expect(session.total, 15);
      expect(_play(session), _ids(15), reason: 'новые — в порядке сида');
      expect(session.nextItem(), isNull, reason: '16-го слова нет');
    });

    test(
      'готовые — первыми, по due (самые просроченные раньше), потом новые',
      () {
        const day = Duration(days: 1);
        final cards = {
          'w10': LeitnerCard(box: 2, due: _t0.subtract(day * 3)),
          'w20': LeitnerCard(box: 2, due: _t0.subtract(day * 1)),
          'w30': LeitnerCard(box: 3, due: _t0.subtract(day * 2)),
          'w40': LeitnerCard(box: 2, due: _t0),
          'w50': LeitnerCard(box: 4, due: _t0.subtract(day * 5)),
        };
        final session = _start(items: _items(_ids(50)), cards: cards);

        expect(session.total, 15);
        expect(_play(session), [
          'w50', 'w10', 'w30', 'w20', 'w40', // готовые: от −5 дней к 0
          ..._ids(9), 'w11', // 10 новых в порядке сида, без w10
        ]);
      },
    );

    test('готовых больше target → ровно target самых просроченных', () {
      // w20 просрочено на 20 дней, w01 — на один: в сессию идут w20..w06.
      final cards = {
        for (var i = 1; i <= 20; i++)
          _w(i): LeitnerCard(box: 2, due: _t0.subtract(Duration(days: i))),
      };
      final snapshots = <Map<String, LeitnerCard>>[];
      final session = _start(
        items: _items(_ids(20)),
        cards: cards,
        target: 15,
        snapshots: snapshots,
      );

      expect(session.total, 15, reason: 'потолок — target, а не число готовых');
      expect(_play(session), [for (var i = 20; i >= 6; i--) _w(i)]);
      for (var i = 1; i <= 5; i++) {
        expect(
          snapshots.last[_w(i)],
          cards[_w(i)],
          reason: 'невошедшая карточка $i не тронута и не потеряна',
        );
      }
    });

    test('due в будущем — не в очереди; due == now — в очереди', () {
      final cards = {
        'w01': LeitnerCard(box: 2, due: _t0.add(const Duration(seconds: 1))),
        'w02': LeitnerCard(box: 2, due: _t0),
      };
      final session = _start(items: _items(_ids(3)), cards: cards);

      expect(session.total, 2);
      expect(
        _play(session),
        ['w02', 'w03'],
        reason: 'w01 ещё не готово и не новое; w02 готово ровно сейчас',
      );
    });

    test(
      'равные due → порядок сида; один вход дважды → одна последовательность',
      () {
        final due = _t0.subtract(const Duration(days: 1));
        Map<String, LeitnerCard> cards() => {
          for (final id in ['w05', 'w03', 'w01', 'w04', 'w02'])
            id: LeitnerCard(box: 2, due: due),
        };

        final first = _play(_start(items: _items(_ids(5)), cards: cards()));
        final second = _play(_start(items: _items(_ids(5)), cards: cards()));

        expect(first, _ids(5), reason: 'при равных due решает порядок сида');
        expect(
          second,
          first,
          reason: 'ни случайности, ни зависимости от карты',
        );
      },
    );

    test('мало готовых, новых нет → сессия короче, без добивки', () {
      final cards = {
        for (final id in _ids(3))
          id: LeitnerCard(box: 2, due: _t0.subtract(const Duration(days: 1))),
      };
      final session = _start(items: _items(_ids(3)), cards: cards, target: 15);

      expect(session.total, 3, reason: 'SPEC кейс 6: честно короче');
      expect(_play(session), _ids(3));
    });

    test('показывать нечего → сессия завершена сразу, колбэк не вызван', () {
      final cards = {
        for (final id in _ids(3))
          id: LeitnerCard(box: 2, due: _t0.add(const Duration(days: 1))),
      };
      final snapshots = <Map<String, LeitnerCard>>[];
      final session = _start(
        items: _items(_ids(3)),
        cards: cards,
        snapshots: snapshots,
      );

      expect(session.total, 0);
      expect(session.isFinished, isTrue);
      expect(session.nextItem(), isNull, reason: 'SPEC кейс 7: null сразу');
      expect(snapshots, isEmpty);
    });

    test(
      'карточка появляется только у отвеченного слова, в момент report()',
      () {
        final snapshots = <Map<String, LeitnerCard>>[];
        final session = _start(items: _items(_ids(2)), snapshots: snapshots);

        session.nextItem();
        expect(snapshots, isEmpty, reason: 'выдача слова — не изменение');

        session.report(_good);

        expect(snapshots.single.keys, ['w01'], reason: 'w02 без карточки');
        expect(
          snapshots.single['w01'],
          LeitnerCard(box: 2, due: _t0.add(const Duration(days: 1))),
          reason: 'новая карточка = коробка 1 + good',
        );
      },
    );

    test(
      'сирота (карточка без слова в сиде) не в очереди, но в каждом снимке',
      () {
        final ghost = LeitnerCard(
          box: 3,
          due: _t0.subtract(const Duration(days: 1)),
        );
        final snapshots = <Map<String, LeitnerCard>>[];
        final session = _start(
          items: _items(_ids(2)),
          cards: {'ghost': ghost},
          snapshots: snapshots,
        );

        expect(
          _play(session),
          _ids(2),
          reason: 'показывать нечего — слова нет',
        );
        for (final snapshot in snapshots) {
          expect(snapshot['ghost'], ghost, reason: 'прогресс не теряется');
        }
      },
    );

    test('target < 0 — ошибка вызывающего; target 0 — пустая сессия', () {
      expect(
        () => _start(items: _items(_ids(3)), target: -1),
        throwsArgumentError,
      );

      final empty = _start(items: _items(_ids(3)), target: 0);
      expect(empty.total, 0);
      expect(empty.isFinished, isTrue);
      expect(empty.nextItem(), isNull);
    });
  });

  group('Правило трёх карточек', () {
    test('обязательный: промах → слово всплывает ровно после трёх других', () {
      final session = _start(items: _items(_ids(15)), target: 15);

      expect(session.nextItem()!.word.id, 'w01');
      session.report(_again);
      for (final expected in ['w02', 'w03', 'w04']) {
        expect(session.nextItem()!.word.id, expected, reason: 'не раньше');
        session.report(_good);
      }

      expect(session.nextItem()!.word.id, 'w01', reason: 'четвёртым — снова');
      expect(session.total, 15, reason: 'размер сессии не вырос');
    });

    test(
      'цепочка промахов: каждый всплывает после трёх других, не сдвигаясь',
      () {
        final session = _start(items: _items(_ids(15)), target: 15);

        final shown = _play(
          session,
          answer: _onFirstShowing({'w01', 'w02', 'w03', 'w04'}, _again),
        );

        expect(shown, [..._ids(4), ..._ids(11)]);
        expect(session.total, 15);
      },
    );

    test(
      'ожидающие повторы невытесняемы: 4 промаха из 8 — все повторы показаны',
      () {
        // Самая плотная цепочка: к четвёртому промаху в очереди три ожидающих
        // повтора и одна непоказанная. Вытесняется непоказанная, повторы
        // остаются и показываются по порядку.
        final snapshots = <Map<String, LeitnerCard>>[];
        final session = _start(
          items: _items(_ids(8)),
          target: 8,
          snapshots: snapshots,
        );

        final shown = _play(
          session,
          answer: _onFirstShowing({'w01', 'w02', 'w03', 'w04'}, _again),
        );

        expect(shown, [..._ids(4), ..._ids(4)]);
        expect(
          snapshots.last.keys,
          unorderedEquals(_ids(4)),
          reason: 'w05–w08 вытеснены: не показаны и без карточек',
        );
      },
    );

    test('hard на новом слове оставляет коробку 1 → тоже повтор', () {
      final snapshots = <Map<String, LeitnerCard>>[];
      final session = _start(
        items: _items(_ids(5)),
        target: 5,
        snapshots: snapshots,
      );

      final shown = _play(session, answer: _onFirstShowing({'w01'}, _hard));

      expect(shown, ['w01', 'w02', 'w03', 'w04', 'w01']);
      expect(
        snapshots.first['w01'],
        LeitnerCard(box: 1, due: _t0),
        reason: 'правило смотрит на карточку, а не на оценку',
      );
    });

    test('good и easy на новом слове уводят из коробки 1 → без повтора', () {
      final snapshots = <Map<String, LeitnerCard>>[];
      final session = _start(
        items: _items(_ids(5)),
        target: 5,
        snapshots: snapshots,
      );

      final shown = _play(session, answer: (id) => id == 'w01' ? _easy : _good);

      expect(shown, _ids(5));
      expect(
        snapshots.last['w01'],
        LeitnerCard(box: 3, due: _t0.add(const Duration(days: 3))),
      );
      expect(
        snapshots.last['w02'],
        LeitnerCard(box: 2, due: _t0.add(const Duration(days: 1))),
      );
    });

    test('второй промах того же слова на повторе → третьего показа нет', () {
      final snapshots = <Map<String, LeitnerCard>>[];
      final session = _start(
        items: _items(_ids(8)),
        target: 8,
        snapshots: snapshots,
      );

      final shown = _play(
        session,
        answer: (id) => id == 'w01' ? _again : _good,
      );

      expect(shown, ['w01', 'w02', 'w03', 'w04', 'w01', 'w05', 'w06', 'w07']);
      expect(
        snapshots.last['w01'],
        LeitnerCard(box: 1, due: _t0),
        reason: 'остаётся в коробке 1 и всплывёт в следующей сессии',
      );
    });

    test(
      'повтор вытесняет последнюю непоказанную: total тот же, ей нет карточки',
      () {
        final snapshots = <Map<String, LeitnerCard>>[];
        final session = _start(
          items: _items(_ids(15)),
          target: 15,
          snapshots: snapshots,
        );

        final shown = _play(session, answer: _missAt(1));

        expect(shown, hasLength(15));
        expect(
          shown,
          isNot(contains('w15')),
          reason: 'вытеснено последнее новое',
        );
        expect(session.total, 15);
        expect(snapshots.last.containsKey('w15'), isFalse);
        expect(snapshots.last, hasLength(14));
      },
    );

    test('впереди ровно 4 → повтор есть; ровно 3 и меньше → повтора нет', () {
      final onEleventh = _play(
        _start(items: _items(_ids(15)), target: 15),
        answer: _missAt(11),
      );
      final afterThree = [..._ids(14), 'w11'];
      expect(
        onEleventh,
        afterThree,
        reason: 'впереди w12–w15: w15 вытеснено, w11 после трёх',
      );

      for (final k in [12, 13, 14, 15]) {
        final snapshots = <Map<String, LeitnerCard>>[];
        final session = _start(
          items: _items(_ids(15)),
          target: 15,
          snapshots: snapshots,
        );

        final shown = _play(session, answer: _missAt(k));

        expect(shown, _ids(15), reason: 'промах на $k-м: повтора нет');
        expect(
          snapshots.last[_w(k)],
          LeitnerCard(box: 1, due: _t0),
          reason: 'карточка в коробке 1 ждёт следующей сессии',
        );
      }
    });
  });

  group('Время', () {
    test('report() считает due от момента ответа, а не старта сессии', () {
      var now = _t0;
      final snapshots = <Map<String, LeitnerCard>>[];
      final session = _start(
        items: _items(_ids(1)),
        now: () => now,
        snapshots: snapshots,
      );

      session.nextItem();
      now = _t0.add(const Duration(hours: 1));
      session.report(_good);

      expect(
        snapshots.single['w01'],
        LeitnerCard(box: 2, due: now.add(const Duration(days: 1))),
        reason: 'сессия могла провисеть в фоне — отсчёт от ответа',
      );
    });

    test('состав очереди — по часам на момент старта', () {
      var now = _t0;
      final cards = {
        'w01': LeitnerCard(box: 2, due: _t0.add(const Duration(minutes: 30))),
      };
      final session = _start(
        items: _items(_ids(2)),
        cards: cards,
        now: () => now,
      );

      now = _t0.add(const Duration(hours: 1));

      expect(
        _play(session),
        ['w02'],
        reason: 'w01 стало готовым позже старта — в эту сессию не попадает',
      );
    });
  });

  group('Сохранение', () {
    test('колбэк после каждого report() с полной картой, и только тогда', () {
      final w01 = LeitnerCard(
        box: 2,
        due: _t0.subtract(const Duration(days: 1)),
      );
      final ghost = LeitnerCard(box: 5, due: _t0.add(const Duration(days: 20)));
      final snapshots = <Map<String, LeitnerCard>>[];
      final session = _start(
        items: _items(_ids(3)),
        cards: {'w01': w01, 'ghost': ghost},
        target: 3,
        snapshots: snapshots,
      );

      expect(snapshots, isEmpty, reason: 'старт — не изменение');
      session.nextItem();
      expect(snapshots, isEmpty, reason: 'выдача — не изменение');

      session.report(_good);
      expect(snapshots, hasLength(1));
      expect(snapshots[0].keys, unorderedEquals(['ghost', 'w01']));

      session.nextItem();
      session.report(_good);
      session.nextItem();
      session.report(_good);
      expect(session.nextItem(), isNull);

      expect(
        snapshots,
        hasLength(3),
        reason: 'ровно answered раз, без финального',
      );
      expect(
        snapshots.last.keys,
        unorderedEquals(['ghost', 'w01', 'w02', 'w03']),
      );
      expect(
        snapshots.last['ghost'],
        ghost,
        reason: 'неизменённое — тоже в карте',
      );
      expect(session.answered, 3);
    });

    test('сессия владеет копией: правки хоста в исходной карте не видны', () {
      final cards = {
        'w01': LeitnerCard(box: 2, due: _t0.subtract(const Duration(days: 1))),
      };
      final snapshots = <Map<String, LeitnerCard>>[];
      final session = _start(
        items: _items(_ids(2)),
        cards: cards,
        snapshots: snapshots,
      );

      cards.remove('w01');
      cards['zzz'] = LeitnerCard(box: 1, due: _t0);

      expect(_play(session), ['w01', 'w02']);
      expect(snapshots.last.containsKey('zzz'), isFalse);
      expect(snapshots.last.keys, unorderedEquals(['w01', 'w02']));
    });
  });

  group('Контракт report()', () {
    test(
      'report() без выданного элемента → StateError, состояние не тронуто',
      () {
        final snapshots = <Map<String, LeitnerCard>>[];
        final session = _start(items: _items(_ids(2)), snapshots: snapshots);

        expect(
          () => session.report(_good),
          throwsStateError,
          reason: 'до nextItem()',
        );
        expect(snapshots, isEmpty);
        expect(session.answered, 0);

        session.nextItem();
        session.report(_good);
        expect(
          () => session.report(_good),
          throwsStateError,
          reason: 'дважды подряд',
        );
        expect(snapshots, hasLength(1));
        expect(session.answered, 1);

        session.nextItem();
        session.report(_good);
        expect(session.nextItem(), isNull);
        expect(
          () => session.report(_good),
          throwsStateError,
          reason: 'после конца',
        );
        expect(session.answered, 2);
      },
    );

    test('nextItem() при неотвеченном элементе → StateError, сессия жива', () {
      final session = _start(items: _items(_ids(2)));

      expect(session.nextItem()!.word.id, 'w01');
      expect(() => session.nextItem(), throwsStateError);

      session.report(_good);
      expect(session.nextItem()!.word.id, 'w02', reason: 'элемент не потерян');
    });

    test('nextItem() после null → снова null, без ошибки', () {
      final session = _start(items: _items(_ids(1)));

      _play(session);

      expect(session.nextItem(), isNull);
      expect(session.nextItem(), isNull);
    });

    test('isFinished: false при элементе в полёте, true после report()', () {
      final session = _start(items: _items(_ids(1)));

      expect(session.isFinished, isFalse);
      session.nextItem();
      expect(
        session.isFinished,
        isFalse,
        reason: 'очередь пуста, но ответа нет',
      );
      session.report(_good);
      expect(session.isFinished, isTrue);
      expect(session.nextItem(), isNull);
    });
  });
}
