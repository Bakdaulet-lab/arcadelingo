import 'dart:async';

import 'package:arcadelingo/data/daily_word/daily_word_prefs_store.dart';
import 'package:arcadelingo/domain/ports/daily_word_store.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final today = DateTime(2026, 11, 25, 8);
  final tomorrow = DateTime(2026, 11, 26);
  late SharedPreferences prefs;
  late DailyWordStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'existing_progress': 'preserve'});
    prefs = await SharedPreferences.getInstance();
    store = DailyWordPrefsStore(prefs, courseId: 'ru-es');
  });

  Future<DailyWordSaveResult> add(
    String guess, {
    List<String> previous = const [],
    bool finished = false,
    String targetId = 'b1/playa',
    CefrLevel level = CefrLevel.b1,
    DailyWordStore? destination,
    DateTime? day,
  }) => (destination ?? store).append(
    level: level,
    day: day ?? today,
    targetId: targetId,
    previousGuesses: previous,
    guess: guess,
    finished: finished,
  );
  DailyWordRecord? read({
    DailyWordStore? source,
    DateTime? day,
    CefrLevel level = CefrLevel.b1,
  }) => (source ?? store).load(level: level, day: day ?? today);

  test(
    'same local day resumes while course, level and date are isolated',
    () async {
      final other = DailyWordPrefsStore(prefs, courseId: 'en-es');
      expect(read(), isNull);
      expect(await add('calle'), DailyWordSaveResult.saved);
      expect(read(day: DateTime(2026, 11, 25, 23, 59))!.guesses, ['calle']);
      expect(read(day: tomorrow), isNull);
      expect(read(level: CefrLevel.a2), isNull);
      expect(read(source: other), isNull);
      await add('playa', finished: true, day: tomorrow);
      await add('arena', level: CefrLevel.a2);
      await add('hotel', destination: other);

      // Recreate preferences and all store instances from the persisted keys.
      final disk = {for (final key in prefs.getKeys()) key: prefs.get(key)!};
      SharedPreferences.setMockInitialValues(disk);
      final reopened = await SharedPreferences.getInstance();
      store = DailyWordPrefsStore(reopened, courseId: 'ru-es');
      final active = read()!;
      expect(active.guesses, ['calle']);
      expect(active.targetId, 'b1/playa');
      expect(active.finished, isFalse);
      expect(() => active.guesses.add('otra'), throwsUnsupportedError);
      final solved = read(day: tomorrow)!;
      expect(solved.guesses, ['playa']);
      expect(solved.finished, isTrue);
      expect(read(level: CefrLevel.a2)!.guesses, ['arena']);
      expect(
        read(source: DailyWordPrefsStore(reopened, courseId: 'en-es'))!.guesses,
        ['hotel'],
      );
      expect(reopened.getString('existing_progress'), 'preserve');
    },
  );

  test(
    'double delivery is idempotent, stale editors cannot change the board',
    () async {
      final other = DailyWordPrefsStore(prefs, courseId: 'ru-es');
      expect(
        await Future.wait([
          add('calle'),
          add('verde', destination: other),
          add('calle'),
        ]),
        [
          DailyWordSaveResult.saved,
          DailyWordSaveResult.conflict,
          DailyWordSaveResult.saved,
        ],
      );
      expect(
        await add('arena', previous: ['calle'], targetId: 'other'),
        DailyWordSaveResult.conflict,
      );
      expect(
        await add('calle', previous: ['calle']),
        DailyWordSaveResult.conflict,
      );
      final mutablePrevious = ['calle'];
      final saving = add('playa', previous: mutablePrevious, finished: true);
      mutablePrevious.clear();
      expect(await saving, DailyWordSaveResult.saved);
      expect(
        await add('playa', previous: ['calle'], finished: true),
        DailyWordSaveResult.saved,
      );
      expect(
        await add('verde', previous: ['calle', 'playa']),
        DailyWordSaveResult.conflict,
      );
      expect(await add('verde'), DailyWordSaveResult.conflict);
      expect(read()!.guesses, ['calle', 'playa']);
      expect(read()!.finished, isTrue);
    },
  );

  test(
    'the sixth guess closes the board even if a stale writer marks it open',
    () async {
      final guesses = <String>[];
      for (final word in [
        'hotel',
        'verde',
        'calle',
        'arena',
        'leche',
        'barco',
      ]) {
        expect(await add(word, previous: guesses), DailyWordSaveResult.saved);
        guesses.add(word);
      }
      expect(read()!.finished, isTrue);
      expect(
        await add('playa', previous: guesses, finished: true),
        DailyWordSaveResult.conflict,
      );
      expect(read()!.guesses, guesses);
    },
  );

  test('a rejected platform save cannot expose or consume a guess', () async {
    final failing = _DelayedPrefs();
    store = DailyWordPrefsStore(failing, courseId: 'ru-es');
    expect(await add('calle'), DailyWordSaveResult.saved);
    final started = Completer<void>();
    final ack = Completer<bool>();
    failing.nextAck = () {
      started.complete();
      return ack.future;
    };
    final saving = add('arena', previous: ['calle']);
    await started.future;
    expect(read()!.guesses, ['calle']);
    ack.complete(false);
    expect(await saving, DailyWordSaveResult.failed);
    expect(read()!.guesses, ['calle']);
    expect(await add('arena', previous: ['calle']), DailyWordSaveResult.saved);
    expect(read()!.guesses, ['calle', 'arena']);
  });
}

class _DelayedPrefs extends Fake implements SharedPreferences {
  final values = <String, List<String>>{};
  Future<bool> Function()? nextAck;
  @override
  Object? get(String key) => values[key];
  @override
  Future<bool> setStringList(String key, List<String> value) async {
    values[key] = [...value];
    final ack = nextAck;
    nextAck = null;
    return ack == null || await ack();
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }
}
