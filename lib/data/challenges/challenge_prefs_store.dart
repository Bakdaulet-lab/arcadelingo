import 'package:arcadelingo/domain/ports/challenge_records.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChallengePrefsStore implements ChallengeRecords {
  ChallengePrefsStore(this._prefs);

  final SharedPreferences _prefs;
  // Comparing and updating the best is one serialized operation.
  Future<void> _writes = Future.value();

  String _storageKey(ChallengeKey key) =>
      'challenge_records.${Uri.encodeComponent(key.courseId)}'
      ':${Uri.encodeComponent(key.gameId)}:${key.level.name}';

  @override
  int? load(ChallengeKey key) {
    final value = _prefs.get(_storageKey(key));
    return value is int && value >= 0 ? value : null;
  }

  @override
  Future<int?> submit(ChallengeKey key, int score) {
    assert(score >= 0);
    final write = _writes.then((_) async {
      final best = load(key);
      if (best != null && best >= score) return best;
      try {
        if (await _prefs.setInt(_storageKey(key), score)) return score;
      } catch (_) {
        // A failed platform write is reported on the results screen.
      }
      try {
        await _prefs.reload();
      } catch (_) {
        // The preference backend is unavailable.
      }
      return null;
    });
    _writes = write.then<void>((_) {});
    return write;
  }
}
