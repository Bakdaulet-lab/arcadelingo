// Файлы прежних версий создаются явным SQL, независимо от текущей схемы.
import 'dart:io';

import 'package:arcadelingo/data/log/drift_answer_log.dart';
import 'package:arcadelingo/data/log/history_database.dart';
import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../support/sqlite_for_tests.dart';

final _at = DateTime.utc(2026, 8, 26, 10);

AnswerRecord _mistake({String? selectedAnswer}) => AnswerRecord(
  wordId: 'w01',
  at: _at,
  localDay: StreakDay.of(_at),
  grade: ReviewGrade.again,
  correct: false,
  responseTime: const Duration(seconds: 2),
  timeLimit: const Duration(seconds: 6),
  hintsUsed: 0,
  gameId: 'falling_words',
  sessionId: 'сессия-1',
  selectedAnswer: selectedAnswer,
);

void _writeLegacyFile(File file, int version) {
  final db = sqlite3.open(file.path);
  try {
    db.execute('''
      CREATE TABLE answers (
        id INTEGER PRIMARY KEY AUTOINCREMENT, word_id TEXT NOT NULL,
        at_utc_micros INTEGER NOT NULL, local_day TEXT NOT NULL,
        grade TEXT NOT NULL, correct INTEGER NOT NULL CHECK (correct IN (0,1)),
        response_micros INTEGER NOT NULL, limit_micros INTEGER NOT NULL,
        hints_used INTEGER NOT NULL, game_id TEXT NOT NULL, session_id TEXT NOT NULL
      )
    ''');
    db.execute('CREATE INDEX answers_word ON answers(word_id)');
    db.execute('CREATE INDEX answers_day ON answers(local_day)');
    db.execute(
      '''
      INSERT INTO answers VALUES
      (1,'w01',?,'2026-08-26','again',0,2000000,6000000,0,'falling_words','сессия-1')
    ''',
      [_at.microsecondsSinceEpoch],
    );

    if (version == 2) {
      db.execute('''
        CREATE TABLE events (
          id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL,
          at_utc_micros INTEGER NOT NULL, local_day TEXT NOT NULL, session_id TEXT
        )
      ''');
      db.execute('CREATE INDEX events_kind ON events(kind)');
      db.execute('CREATE INDEX events_day ON events(local_day)');
      db.execute(
        '''
        INSERT INTO events VALUES (1,'appOpen',?,'2026-08-26',NULL)
      ''',
        [_at.microsecondsSinceEpoch],
      );
    }
    db.execute('PRAGMA user_version = $version');
  } finally {
    db.dispose();
  }
}

Future<int> _userVersion(HistoryDatabase db) async {
  final row = await db.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
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

  for (final version in [1, 2]) {
    test(
      'v$version сохраняет историю и записывает новый выбор после обновления',
      () async {
        _writeLegacyFile(file, version);
        final upgraded = HistoryDatabase(NativeDatabase(file));
        final log = DriftAnswerLog(upgraded);
        try {
          expect(await _userVersion(upgraded), 3);
          expect(await log.all(), [_mistake()]);
          expect((await log.all()).single.selectedAnswer, isNull);
          final events = await upgraded.select(upgraded.events).get();
          expect(
            events.map((event) => event.kind.name),
            version == 2 ? ['appOpen'] : isEmpty,
          );
          final indexes =
              await upgraded
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type = 'index'",
                  )
                  .get();
          expect(
            indexes.map((row) => row.read<String>('name')),
            containsAll([
              'answers_word',
              'answers_day',
              'events_kind',
              'events_day',
            ]),
          );

          await log.append(_mistake(selectedAnswer: 'брать'));
        } finally {
          await upgraded.close();
        }
        final reopened = HistoryDatabase(NativeDatabase(file));
        addTearDown(reopened.close);
        expect(await _userVersion(reopened), 3);
        final rows = await DriftAnswerLog(reopened).forWord('w01');
        expect(rows, [_mistake(), _mistake(selectedAnswer: 'брать')]);
        expect(rows.last.selectedAnswer, 'брать');
      },
    );
  }

  test('свежая база создаётся сразу третьей версией', () async {
    final fresh = HistoryDatabase(NativeDatabase(file));
    addTearDown(fresh.close);
    expect(await _userVersion(fresh), 3);
    final log = DriftAnswerLog(fresh);
    await log.append(_mistake(selectedAnswer: 'año'));
    expect((await log.all()).single.selectedAnswer, 'año');
  });
}
