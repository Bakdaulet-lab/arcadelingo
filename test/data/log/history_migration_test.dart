// Первая настоящая миграция схемы: v1 → v2.
//
// Проверяется то, что случится на телефоне: файл, записанный версией с одной
// таблицей `answers`, открывается версией с двумя и обязан получить `events`,
// не потеряв ни строки и не тронув `answers`.
//
// База настоящая и файловая, не `memory()`: миграция — это про файл, который
// пережил обновление приложения, и проверять её на базе, создаваемой с нуля
// при каждом открытии, значит не проверять вовсе.
//
// Как получен файл схемы v1. Кода v1 в репозитории больше нет — он и был
// предыдущей версией этого же класса. Поэтому файл собирается наоборот:
// открыть текущую базу, **удалить** `events` и вернуть `user_version` в
// единицу. Ограничение отсюда прямое и названное: тест доказывает путь
// обновления (файл на v1 получает таблицу, не теряя строк), но не то, что
// DDL `answers` в v1 был байт-в-байт сегодняшним. Последнее подтверждает
// диффом: `answers` этим этапом не тронута ни одной строкой.

import 'dart:io';

import 'package:arcadelingo/data/log/drift_answer_log.dart';
import 'package:arcadelingo/data/log/history_database.dart';
import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/sqlite_for_tests.dart';

final DateTime _t0 = DateTime.utc(2026, 8, 26, 10);

AnswerRecord _answer() => AnswerRecord(
  wordId: 'w01',
  at: _t0,
  localDay: StreakDay.of(_t0),
  grade: ReviewGrade.good,
  correct: true,
  responseTime: const Duration(seconds: 2),
  timeLimit: const Duration(seconds: 6),
  hintsUsed: 0,
  gameId: 'falling_words',
  sessionId: 'сессия-1',
);

/// DDL таблицы, как её видит сама база.
Future<String> _ddlOf(HistoryDatabase db, String table) async {
  final rows =
      await db
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
            variables: [Variable<String>(table)],
          )
          .get();
  return rows.isEmpty ? '' : (rows.single.data['sql'] as String? ?? '');
}

Future<int> _userVersion(HistoryDatabase db) async {
  final rows = await db.customSelect('PRAGMA user_version').get();
  return rows.single.data.values.first! as int;
}

void main() {
  setUpAll(useTestSqlite);

  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('wordarcade_migration');
    file = File('${dir.path}/history.sqlite');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// Файл схемы v1: только `answers`, `user_version` = 1, одна строка внутри.
  /// Возвращает DDL этой таблицы — эталон для сверки после миграции.
  Future<String> makeVersionOne() async {
    final db = HistoryDatabase(NativeDatabase(file));
    await DriftAnswerLog(db).append(_answer());
    final ddl = await _ddlOf(db, 'answers');
    await db.customStatement('DROP TABLE events');
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();
    return ddl;
  }

  test('файл v1 после открытия получает таблицу событий', () async {
    await makeVersionOne();

    final upgraded = HistoryDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final events = await upgraded.select(upgraded.events).get();

    expect(events, isEmpty, reason: 'таблица создана и пуста');
    expect(await _userVersion(upgraded), 2);
  });

  test('строки ответов переживают миграцию', () async {
    await makeVersionOne();

    final upgraded = HistoryDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);

    expect(await DriftAnswerLog(upgraded).all(), [_answer()]);
  });

  test('миграция не трогает таблицу ответов', () async {
    final before = await makeVersionOne();

    final upgraded = HistoryDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);

    expect(
      await _ddlOf(upgraded, 'answers'),
      before,
      reason: 'обещание «answers не трогаем» проверяется, а не декларируется',
    );
  });

  test(
    'индексы событий создаются и при обновлении, а не только с нуля',
    () async {
      await makeVersionOne();

      final upgraded = HistoryDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final indexes =
          (await upgraded
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type = 'index' "
                    "AND tbl_name = 'events'",
                  )
                  .get())
              .map((row) => row.data['name'] as String)
              .toSet();

      expect(
        indexes,
        containsAll(<String>['events_kind', 'events_day']),
        reason:
            'иначе на новых устройствах индексы есть, а на обновившихся нет, и '
            'разница проявится медленным экраном, а не ошибкой',
      );
    },
  );

  test('повторное открытие миграцию не повторяет', () async {
    await makeVersionOne();

    final first = HistoryDatabase(NativeDatabase(file));
    await first.select(first.events).get();
    await first.close();

    final second = HistoryDatabase(NativeDatabase(file));
    addTearDown(second.close);

    expect(await _userVersion(second), 2);
    expect(await DriftAnswerLog(second).all(), hasLength(1));
  });

  test('свежая база создаётся сразу второй версией', () async {
    final fresh = HistoryDatabase(NativeDatabase(file));
    addTearDown(fresh.close);

    await fresh.select(fresh.events).get();

    expect(await _userVersion(fresh), 2);
  });
}
