// Обязательные тест-кейсы Лейтнера: .claude/skills/srs-engine/SKILL.md,
// «Шаг 2 (v1) → Обязательные тест-кейсы». Нумерация тестов совпадает с
// нумерацией в скилле — правишь таблицу там, ищешь по номеру здесь.
//
// Интервалы записаны литералами (1/3/7/21 день), а не константами из lib/:
// тест обязан быть независимой сверкой с таблицей скилла. Ссылайся он на ту же
// константу, что и реализация, — он подтвердил бы любую ошибку в ней.
//
// `DateTime.now()` здесь нет намеренно: тест на детерминированный движок сам
// обязан быть детерминированным.

import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:flutter_test/flutter_test.dart';

/// Фиксированное «сейчас». Конкретное значение неважно, важно постоянство.
final _now = DateTime.utc(2026, 3, 8, 12);

void main() {
  group('Лейтнер: переходы коробок', () {
    test('кейс 1: новая карточка + good → коробка 2, due = now + 1 день', () {
      // Новая карточка живёт в первой коробке и готова к показу немедленно.
      final card = LeitnerCard(box: 1, due: _now);

      final next = schedule(card, ReviewGrade.good, now: _now);

      expect(next.box, 2, reason: 'good двигает на одну коробку вперёд');
      expect(next.due, _now.add(const Duration(days: 1)));
    });

    test('кейс 2: коробка 5 + good → остаётся 5, due = now + 21 день', () {
      final card = LeitnerCard(box: 5, due: _now);

      final next = schedule(card, ReviewGrade.good, now: _now);

      expect(next.box, 5, reason: 'потолок: шестой коробки не существует');
      expect(next.due, _now.add(const Duration(days: 21)));
    });

    test('кейс 3: коробка 5 + easy → остаётся 5, потолок держит и +2', () {
      final card = LeitnerCard(box: 5, due: _now);

      final next = schedule(card, ReviewGrade.easy, now: _now);

      expect(next.box, 5, reason: 'easy = +2, но выше пятой коробки не уводит');
      expect(next.due, _now.add(const Duration(days: 21)));
    });

    test('кейс 4: коробка 4 + again → коробка 1, повтор внутри сессии', () {
      final card = LeitnerCard(box: 4, due: _now.add(const Duration(days: 7)));

      final next = schedule(card, ReviewGrade.again, now: _now);

      expect(next.box, 1, reason: 'again всегда сбрасывает в первую коробку');
      expect(
        next.due.isAfter(_now),
        isFalse,
        reason: 'забытое слово возвращается в эту же сессию, а не через сутки',
      );
      expect(
        next.due.isAtSameMomentAs(_now),
        isTrue,
        reason: 'коробка 1 показывается в этой же сессии: due == now',
      );
    });

    test('кейс 5: коробка 1 + easy → коробка 3, а не 2', () {
      final card = LeitnerCard(box: 1, due: _now);

      final next = schedule(card, ReviewGrade.easy, now: _now);

      expect(next.box, 3, reason: 'easy = +2 коробки');
      expect(next.due, _now.add(const Duration(days: 3)));
    });

    test('кейс 6: коробка 3 + hard → коробка 3, due = now + 3 дня от now', () {
      // due просрочен на двое суток: если реализация отсчитает интервал от
      // старого due, а не от now, получится now + 1 день — и тест это поймает.
      final card = LeitnerCard(
        box: 3,
        due: _now.subtract(const Duration(days: 2)),
      );

      final next = schedule(card, ReviewGrade.hard, now: _now);

      expect(next.box, 3, reason: 'hard оставляет карточку в той же коробке');
      expect(
        next.due,
        _now.add(const Duration(days: 3)),
        reason: 'отсчёт от now, а не от старого due',
      );
    });

    test('кейс 7: одинаковое состояние и одинаковый now → один результат', () {
      final a = LeitnerCard(
        box: 2,
        due: _now.subtract(const Duration(days: 1)),
      );
      final b = LeitnerCard(
        box: 2,
        due: _now.subtract(const Duration(days: 1)),
      );

      expect(
        schedule(a, ReviewGrade.good, now: _now),
        schedule(b, ReviewGrade.good, now: _now),
        reason: 'две карточки в одинаковом состоянии неразличимы для движка',
      );
      expect(
        schedule(a, ReviewGrade.good, now: _now),
        schedule(a, ReviewGrade.good, now: _now),
        reason: 'повторный вызов на том же входе не должен «плыть»',
      );
    });

    test('коробка вне 1..5 — карточка не строится', () {
      // Битое хранилище (0.5: null -> 0 из shared_preferences) не должно
      // притворяться рабочим состоянием. Раньше box: 0 + easy тихо давал
      // коробку 2: 0 + 2 попадало в диапазон, и зажим не срабатывал.
      expect(() => LeitnerCard(box: 0, due: _now), throwsArgumentError);
      expect(() => LeitnerCard(box: 6, due: _now), throwsArgumentError);
      expect(() => LeitnerCard(box: -1, due: _now), throwsArgumentError);
    });

    test('границы диапазона 1 и 5 — карточка строится', () {
      // Сторож не должен отрезать лишнего: обе крайние коробки валидны.
      expect(LeitnerCard(box: 1, due: _now).box, 1);
      expect(LeitnerCard(box: 5, due: _now).box, 5);
    });

    test(
      'due нормализуется в UTC: локальный и UTC-вход дают равные карточки',
      () {
        // Инвариант типа, а не функции: карточка приходит и из десериализации
        // (задача 0.5), конструктор — единственная точка, через которую проходят
        // все. DateTime.== чувствителен к флагу isUtc, поэтому без нормализации
        // два представления одного момента дают неравные карточки.
        final local = DateTime(2026, 3, 8, 12);
        final utc = local.toUtc();

        final fromLocal = LeitnerCard(box: 2, due: local);
        final fromUtc = LeitnerCard(box: 2, due: utc);

        expect(fromLocal.due.isUtc, isTrue, reason: 'due всегда в UTC');
        expect(fromLocal, fromUtc, reason: 'один момент — одна карточка');
        expect(
          fromLocal.hashCode,
          fromUtc.hashCode,
          reason: 'иначе промах по ключу в HashMap при равном ==',
        );
      },
    );

    test('schedule() отдаёт due в UTC, даже если now локальный', () {
      final localNow = DateTime(2026, 3, 8, 12);
      final card = LeitnerCard(box: 1, due: localNow);

      final next = schedule(card, ReviewGrade.good, now: localNow);

      expect(next.due.isUtc, isTrue);
      expect(
        next.due.isAtSameMomentAs(localNow.add(const Duration(days: 1))),
        isTrue,
        reason: 'нормализация меняет представление, а не момент',
      );
    });

    test('кейс 8: граница суток и смена зоны не меняют номер коробки', () {
      // DateTime в Dart — это момент времени; часовой пояс лишь способ его
      // записать. Планировщик обязан считать от момента, а не от календарного
      // дня, иначе перелёт со сменой зоны начнёт двигать коробки.
      final beforeMidnight = DateTime.utc(2026, 3, 8, 23, 59, 59, 999);
      final midday = DateTime.utc(2026, 3, 8, 12);
      final card = LeitnerCard(box: 1, due: beforeMidnight);

      expect(
        schedule(card, ReviewGrade.good, now: beforeMidnight).box,
        schedule(card, ReviewGrade.good, now: midday).box,
        reason: 'ответ за секунду до полуночи не особеннее ответа в полдень',
      );

      // Тот же самый момент, записанный в UTC и в локальной зоне.
      final fromUtc = schedule(card, ReviewGrade.good, now: beforeMidnight);
      final fromLocal = schedule(
        card,
        ReviewGrade.good,
        now: beforeMidnight.toLocal(),
      );

      expect(fromLocal.box, fromUtc.box, reason: 'коробка не зависит от зоны');
      expect(
        fromLocal.due.isAtSameMomentAs(fromUtc.due),
        isTrue,
        reason: 'due — момент, а не показание настенных часов',
      );
    });
  });
}
