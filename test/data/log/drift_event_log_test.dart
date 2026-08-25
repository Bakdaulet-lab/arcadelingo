// Журнал событий на настоящем sqlite: запись, чтение дня и воронка.
//
// `test()`, а не `testWidgets()`, по той же причине, что и у журнала ответов:
// хранилищу истории Flutter-рантайм не нужен.

import 'package:arcadelingo/data/log/drift_event_log.dart';
import 'package:arcadelingo/data/log/history_database.dart';
import 'package:arcadelingo/domain/events/app_event.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/sqlite_for_tests.dart';

final DateTime _t0 = DateTime.utc(2026, 8, 26, 10);

AppEvent _event(
  AppEventKind kind, {
  DateTime? at,
  StreakDay? day,
  String? sessionId,
}) {
  final moment = at ?? _t0;
  return AppEvent(
    kind: kind,
    at: moment,
    localDay: day ?? StreakDay.of(moment),
    sessionId: sessionId,
  );
}

void main() {
  setUpAll(useTestSqlite);

  late HistoryDatabase db;
  late DriftEventLog log;

  setUp(() {
    db = HistoryDatabase(NativeDatabase.memory());
    log = DriftEventLog(db);
  });

  tearDown(() => db.close());

  group('Запись и чтение', () {
    test('событие возвращается тем же самым', () async {
      final event = _event(AppEventKind.roundStart, sessionId: 'сессия-1');

      await log.append(event);

      expect(await log.forDay(StreakDay.of(_t0)), [event]);
    });

    test('событие без партии хранит NULL, а не пустую строку', () async {
      await log.append(_event(AppEventKind.appOpen));

      expect((await log.forDay(StreakDay.of(_t0))).single.sessionId, isNull);
    });

    test('микросекунды момента переживают запись', () async {
      final precise = DateTime.utc(2026, 8, 26, 10, 0, 0, 123, 456);

      await log.append(_event(AppEventKind.appOpen, at: precise));

      expect(
        (await log.forDay(
          StreakDay.of(precise),
        )).single.at.microsecondsSinceEpoch,
        precise.microsecondsSinceEpoch,
      );
    });

    test('прочитанный момент — в UTC и тот же самый', () async {
      final local = DateTime(2026, 8, 26, 10);

      await log.append(
        _event(AppEventKind.appOpen, at: local, day: StreakDay(2026, 8, 26)),
      );

      final read = (await log.forDay(StreakDay(2026, 8, 26))).single.at;
      expect(read.isUtc, isTrue);
      expect(read.isAtSameMomentAs(local), isTrue);
    });

    // Тот же принцип, что у ответов: локальный день из UTC не восстановим.
    test('день хранится сам по себе, а не выводится из момента', () async {
      await log.append(
        _event(
          AppEventKind.appOpen,
          at: DateTime.utc(2026, 8, 26, 21),
          day: StreakDay(2026, 8, 27),
        ),
      );

      final read = await log.forDay(StreakDay(2026, 8, 27));
      expect(read, hasLength(1));
      expect(
        read.single.localDay,
        StreakDay(2026, 8, 27),
        reason:
            'выборка по колонке нашла бы строку и при неверном разборе — '
            'проверять надо то, что прочитано, а не то, что нашлось',
      );
      expect(await log.forDay(StreakDay(2026, 8, 26)), isEmpty);
    });

    test('все роды событий возвращаются теми же значениями', () async {
      for (final (index, kind) in AppEventKind.values.indexed) {
        await log.append(_event(kind, at: _t0.add(Duration(minutes: index))));
      }

      expect(
        (await log.forDay(StreakDay.of(_t0))).map((e) => e.kind),
        AppEventKind.values,
      );
    });
  });

  group('День', () {
    test('только этот день, в хронологическом порядке', () async {
      await log.append(
        _event(AppEventKind.roundStart, at: _t0.add(const Duration(hours: 2))),
      );
      await log.append(_event(AppEventKind.appOpen, at: _t0));
      await log.append(
        _event(AppEventKind.appOpen, at: _t0.add(const Duration(days: 1))),
      );

      final day = await log.forDay(StreakDay.of(_t0));

      expect(day.map((e) => e.kind), [
        AppEventKind.appOpen,
        AppEventKind.roundStart,
      ]);
    });

    test('при равных моментах — в порядке записи', () async {
      await log.append(_event(AppEventKind.roundStart));
      await log.append(_event(AppEventKind.appOpen));

      expect((await log.forDay(StreakDay.of(_t0))).map((e) => e.kind), [
        AppEventKind.roundStart,
        AppEventKind.appOpen,
      ]);
    });

    test('день без событий — пусто, а не ошибка', () async {
      await log.append(_event(AppEventKind.appOpen));

      expect(await log.forDay(StreakDay(2026, 9, 9)), isEmpty);
    });
  });

  group('Воронка', () {
    Future<void> on(StreakDay day, AppEventKind kind) => log.append(
      _event(
        kind,
        at: DateTime.utc(day.year, day.month, day.day, 12),
        day: day,
      ),
    );

    test('считает каждый род отдельно', () async {
      final day = StreakDay(2026, 8, 26);
      await on(day, AppEventKind.appOpen);
      await on(day, AppEventKind.roundStart);
      await on(day, AppEventKind.roundStart);
      await on(day, AppEventKind.roundOver);

      expect(await log.countsByKind(from: day, to: day), {
        AppEventKind.appOpen: 1,
        AppEventKind.roundStart: 2,
        AppEventKind.roundOver: 1,
      });
    });

    test('род без единого события в карту не попадает', () async {
      final day = StreakDay(2026, 8, 26);
      await on(day, AppEventKind.appOpen);

      final counts = await log.countsByKind(from: day, to: day);

      expect(counts.containsKey(AppEventKind.roundAbandon), isFalse);
    });

    test('границы отрезка включаются', () async {
      await on(StreakDay(2026, 8, 25), AppEventKind.appOpen);
      await on(StreakDay(2026, 8, 26), AppEventKind.appOpen);
      await on(StreakDay(2026, 8, 27), AppEventKind.appOpen);
      await on(StreakDay(2026, 8, 28), AppEventKind.appOpen);

      final counts = await log.countsByKind(
        from: StreakDay(2026, 8, 26),
        to: StreakDay(2026, 8, 27),
      );

      expect(counts[AppEventKind.appOpen], 2);
    });

    test('за отрезок ничего не случилось — пустая карта', () async {
      await on(StreakDay(2026, 8, 26), AppEventKind.appOpen);

      expect(
        await log.countsByKind(
          from: StreakDay(2026, 9, 1),
          to: StreakDay(2026, 9, 30),
        ),
        isEmpty,
      );
    });

    // Отрезок берётся сравнением строк `ГГГГ-ММ-ДД`; оно совпадает с
    // календарным только при ведущих нулях (`day_text.dart`).
    test('сентябрь и октябрь не путаются местами', () async {
      await on(StreakDay(2026, 9, 1), AppEventKind.appOpen);
      await on(StreakDay(2026, 10, 1), AppEventKind.roundStart);

      final counts = await log.countsByKind(
        from: StreakDay(2026, 9, 15),
        to: StreakDay(2026, 12, 31),
      );

      expect(counts, {AppEventKind.roundStart: 1});
    });
  });

  group('Дни с событием', () {
    Future<void> on(StreakDay day, AppEventKind kind) => log.append(
      _event(
        kind,
        at: DateTime.utc(day.year, day.month, day.day, 12),
        day: day,
      ),
    );

    test(
      'день попадает в множество один раз, сколько бы событий ни было',
      () async {
        final day = StreakDay(2026, 8, 26);
        await on(day, AppEventKind.roundOver);
        await on(day, AppEventKind.roundOver);
        await on(day, AppEventKind.roundOver);

        expect(
          await log.daysWith(kind: AppEventKind.roundOver, from: day, to: day),
          {day},
        );
      },
    );

    // Мутация «убрать фильтр по роду» краснеет только здесь: без этого теста
    // запрос отдавал бы дни, в которые партию начали и бросили, как дни с
    // законченной партией.
    test('другой род события день не приводит', () async {
      final day = StreakDay(2026, 8, 26);
      await on(day, AppEventKind.roundStart);
      await on(day, AppEventKind.roundAbandon);

      expect(
        await log.daysWith(kind: AppEventKind.roundOver, from: day, to: day),
        isEmpty,
      );
    });

    test('границы отрезка включаются, соседи — нет', () async {
      for (final d in [24, 25, 26, 27]) {
        await on(StreakDay(2026, 8, d), AppEventKind.roundOver);
      }

      expect(
        await log.daysWith(
          kind: AppEventKind.roundOver,
          from: StreakDay(2026, 8, 25),
          to: StreakDay(2026, 8, 26),
        ),
        {StreakDay(2026, 8, 25), StreakDay(2026, 8, 26)},
      );
    });

    test('за отрезок ничего не случилось — пустое множество', () async {
      await on(StreakDay(2026, 8, 26), AppEventKind.roundOver);

      expect(
        await log.daysWith(
          kind: AppEventKind.roundOver,
          from: StreakDay(2026, 9, 1),
          to: StreakDay(2026, 9, 30),
        ),
        isEmpty,
      );
    });

    test('день возвращается разобранным, а не строкой', () async {
      final day = StreakDay(2026, 3, 7);
      await on(day, AppEventKind.roundOver);

      final days = await log.daysWith(
        kind: AppEventKind.roundOver,
        from: StreakDay(2026, 3, 1),
        to: StreakDay(2026, 3, 31),
      );

      expect(days.single, day);
    });
  });

  group('Соседство с ответами', () {
    test('события не попадают в журнал ответов и наоборот', () async {
      await log.append(_event(AppEventKind.roundStart, sessionId: 'сессия-1'));

      final answers = await db.select(db.answers).get();

      expect(answers, isEmpty, reason: 'таблицы разные, и это видно');
    });
  });
}
