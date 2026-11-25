import 'package:arcadelingo/data/day_text.dart';
import 'package:arcadelingo/domain/daily_word/daily_word.dart';
import 'package:arcadelingo/domain/ports/daily_word_store.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:shared_preferences/shared_preferences.dart';

class DailyWordPrefsStore implements DailyWordStore {
  factory DailyWordPrefsStore(
    SharedPreferences prefs, {
    required String courseId,
  }) {
    // Screens returning to this course must share any writes still in flight.
    final courses = _stores[prefs] ??= {};
    return courses.putIfAbsent(
      courseId,
      () => DailyWordPrefsStore._(prefs, courseId),
    );
  }

  DailyWordPrefsStore._(this._prefs, String courseId)
    : _prefix = 'daily_word.v1:${Uri.encodeComponent(courseId)}:';

  static final _stores = Expando<Map<String, DailyWordPrefsStore>>();
  final SharedPreferences _prefs;
  final String _prefix;
  Future<void> _writes = Future.value();
  ({String key, DailyWordRecord? before})? _pending;

  String _key(CefrLevel level, DateTime day) =>
      '$_prefix${level.name}:${encodeDay(StreakDay.of(day))}';

  @override
  DailyWordRecord? load({required CefrLevel level, required DateTime day}) {
    final key = _key(level, day);
    final pending = _pending;
    if (pending != null && key == pending.key) return pending.before;
    return _read(key);
  }

  DailyWordRecord? _read(String key) {
    final raw = _prefs.get(key);
    if (raw is! List ||
        raw.length < 3 ||
        raw.length > DailyWordRound.maxAttempts + 2 ||
        raw.any((field) => field is! String || field.trim().isEmpty)) {
      return null;
    }
    final fields = raw.cast<String>();
    if (fields[1] != 'open' && fields[1] != 'done') return null;
    final guesses = fields.sublist(2);
    if (guesses.toSet().length != guesses.length) return null;
    return DailyWordRecord(
      targetId: fields.first,
      guesses: guesses,
      finished:
          fields[1] == 'done' || guesses.length == DailyWordRound.maxAttempts,
    );
  }

  @override
  Future<DailyWordSaveResult> append({
    required CefrLevel level,
    required DateTime day,
    required String targetId,
    required List<String> previousGuesses,
    required String guess,
    required bool finished,
  }) {
    if (targetId.trim().isEmpty ||
        guess.trim().isEmpty ||
        previousGuesses.length >= DailyWordRound.maxAttempts ||
        previousGuesses.contains(guess)) {
      return Future.value(DailyWordSaveResult.conflict);
    }
    final key = _key(level, day);
    final previous = List<String>.of(previousGuesses);
    final next = DailyWordRecord(
      targetId: targetId,
      guesses: [...previous, guess],
      finished: finished || previous.length + 1 == DailyWordRound.maxAttempts,
    );
    final result = _writes.then((_) async {
      final current = _read(key);
      if (current != null && current.targetId != targetId) {
        return DailyWordSaveResult.conflict;
      }
      if (current?.finished == next.finished &&
          listEquals(current?.guesses, next.guesses)) {
        return DailyWordSaveResult.saved;
      }
      if (current?.finished == true ||
          !listEquals(current?.guesses ?? const [], previous)) {
        return DailyWordSaveResult.conflict;
      }
      return _persist(key, current, next);
    });
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> _tryWrite(String key, DailyWordRecord? record) async {
    try {
      if (record == null) return await _prefs.remove(key);
      return await _prefs.setStringList(key, [
        record.targetId,
        record.finished ? 'done' : 'open',
        ...record.guesses,
      ]);
    } on Exception {
      // Backends may reject by exception or by returning false.
      return false;
    }
  }

  Future<DailyWordSaveResult> _persist(
    String key,
    DailyWordRecord? before,
    DailyWordRecord next,
  ) async {
    // SharedPreferences updates its cache before the platform acknowledges.
    // Readers keep the confirmed board until persistence or rollback finishes.
    _pending = (key: key, before: before);
    try {
      if (await _tryWrite(key, next)) return DailyWordSaveResult.saved;
      await _tryWrite(key, before);
      return DailyWordSaveResult.failed;
    } finally {
      _pending = null;
    }
  }
}
