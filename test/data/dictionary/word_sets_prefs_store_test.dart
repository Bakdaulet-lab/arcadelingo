import 'dart:async';

import 'package:arcadelingo/data/dictionary/word_sets_prefs_store.dart';
import 'package:arcadelingo/domain/ports/word_sets_store.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const level = CefrLevel.a1;
  late SharedPreferences prefs;
  late WordSetsPrefsStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'favorite_word_ids': <String>['cat'],
    });
    prefs = await SharedPreferences.getInstance();
    store = WordSetsPrefsStore(prefs, courseId: 'ru-es');
  });

  test(
    'a set keeps its identity through renaming, editing, reload and deletion',
    () async {
      final personalId = 'custom:ru-es:a1:mi%20casa';
      expect(store.load(level), isEmpty);
      expect(
        await store.save(level: level, name: ' В   отпуск ', wordIds: {}),
        WordSetSaveResult.saved,
      );
      final original = store.load(level).single;
      expect(original.name, 'В отпуск');
      expect(original.wordIds, isEmpty);
      final ids = {'puerta', personalId};
      expect(
        await store.save(
          id: original.id,
          level: level,
          name: 'Viaje',
          wordIds: ids,
        ),
        WordSetSaveResult.saved,
      );
      ids.clear();
      await prefs.reload();
      final reopened = WordSetsPrefsStore(prefs, courseId: 'ru-es');
      final edited = reopened.load(level).single;
      expect((edited.id, edited.name), (original.id, 'Viaje'));
      expect(edited.wordIds, {'puerta', personalId});
      expect(await reopened.remove(level: level, id: original.id), isTrue);
      await prefs.reload();
      expect(reopened.load(level), isEmpty);
      expect(
        await store.save(
          id: original.id,
          level: level,
          name: 'Old editor',
          wordIds: {},
        ),
        WordSetSaveResult.missing,
      );
      expect(prefs.getStringList('favorite_word_ids'), ['cat']);
    },
  );

  test(
    'course and level protect reads, writes and deletions even with shared word IDs',
    () async {
      final secondCourse = WordSetsPrefsStore(prefs, courseId: 'en-es');
      for (final (scope, difficulty) in [
        (store, level),
        (store, CefrLevel.b1),
        (secondCourse, level),
      ]) {
        expect(
          await scope.save(
            level: difficulty,
            name: 'Travel',
            wordIds: {'hotel'},
          ),
          WordSetSaveResult.saved,
        );
      }
      final id = store.load(level).single.id;
      expect(
        await secondCourse.save(
          level: level,
          id: id,
          name: 'Wrong course',
          wordIds: {},
        ),
        WordSetSaveResult.missing,
      );
      expect(await store.remove(level: CefrLevel.b1, id: id), isFalse);
      expect(await secondCourse.remove(level: level, id: id), isFalse);
      expect(await store.remove(level: level, id: id), isTrue);
      expect(store.load(level), isEmpty);
      expect(secondCourse.load(level).single.name, 'Travel');
      expect(store.load(CefrLevel.b1).single.wordIds, {'hotel'});
    },
  );

  test(
    'concurrent writes preserve both sets, normalize names and reject duplicates',
    () async {
      final otherHandle = WordSetsPrefsStore(prefs, courseId: 'ru-es');
      expect(
        await Future.wait([
          store.save(level: level, name: '   El   viaje', wordIds: {'tren'}),
          otherHandle.save(level: level, name: 'EL VIAJE', wordIds: {'avión'}),
          store.save(level: level, name: 'Café', wordIds: {'té'}),
        ]),
        [
          WordSetSaveResult.saved,
          WordSetSaveResult.duplicate,
          WordSetSaveResult.saved,
        ],
      );
      expect(
        await store.save(level: level, name: ' \u200B\n', wordIds: {}),
        WordSetSaveResult.invalid,
      );
      final cafe = store.load(level).singleWhere((s) => s.name == 'Café');
      expect(
        await store.save(
          level: level,
          id: cafe.id,
          name: 'el viaje',
          wordIds: {},
        ),
        WordSetSaveResult.duplicate,
      );
      final travel = store.load(level).singleWhere((s) => s.name == 'El viaje');
      expect(travel.wordIds, {'tren'});
      expect(
        await Future.wait([
          store.save(
            level: level,
            id: travel.id,
            name: 'Train',
            wordIds: {'tren'},
          ),
          otherHandle.save(
            level: level,
            id: travel.id,
            name: 'Airport',
            wordIds: {'avión'},
          ),
        ]),
        [WordSetSaveResult.saved, WordSetSaveResult.saved],
      );
      await prefs.reload();
      expect(
        store.load(level).map((s) => s.name),
        unorderedEquals(['Café', 'Airport']),
      );
      expect(store.load(level).singleWhere((s) => s.id == travel.id).wordIds, {
        'avión',
      });
    },
  );

  test(
    'rejected writes keep the last saved set visible and allow retry',
    () async {
      final failingPrefs = _DelayedFailure();
      final store = WordSetsPrefsStore(failingPrefs, courseId: 'en-es');
      await store.save(level: level, name: 'Trip', wordIds: {'hotel'});
      final id = store.load(level).single.id;
      for (final deleting in [false, true]) {
        final wait = failingPrefs.delayNext();
        final operation =
            deleting
                ? store.remove(level: level, id: id)
                : store.save(
                  level: level,
                  id: id,
                  name: 'Rejected',
                  wordIds: {},
                );
        await wait.started.future;
        expect(store.load(level).single.name, 'Trip');
        wait.finish.complete(false);
        expect(await operation, deleting ? false : WordSetSaveResult.failed);
        expect(store.load(level).single.wordIds, {'hotel'});
      }
      expect(
        await store.save(
          level: level,
          id: id,
          name: 'Retry',
          wordIds: {'plane'},
        ),
        WordSetSaveResult.saved,
      );
      expect(store.load(level).single.name, 'Retry');
    },
  );
}

typedef _Pending = ({Completer<void> started, Completer<bool> finish});

// SharedPreferences changes its in-memory cache before the platform confirms.
class _DelayedFailure extends Fake implements SharedPreferences {
  final _cache = <String, List<String>>{};
  _Pending? _pending;
  _Pending delayNext() =>
      _pending = (started: Completer(), finish: Completer());
  Future<bool> _ack() async {
    final pending = _pending;
    _pending = null;
    if (pending == null) return true;
    pending.started.complete();
    return pending.finish.future;
  }

  @override
  Set<String> getKeys() => _cache.keys.toSet();
  @override
  bool containsKey(String key) => _cache.containsKey(key);
  @override
  Object? get(String key) => _cache[key];
  @override
  List<String>? getStringList(String key) => _cache[key]?.toList();
  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _cache[key] = value.toList();
    return _ack();
  }

  @override
  Future<bool> remove(String key) async {
    _cache.remove(key);
    return _ack();
  }
}
