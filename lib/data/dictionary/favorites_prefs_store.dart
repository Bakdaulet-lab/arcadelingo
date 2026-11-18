import 'package:arcadelingo/domain/ports/favorites_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesPrefsStore implements FavoritesStore {
  FavoritesPrefsStore(this._prefs, {String? courseId})
    : _storageKey = courseId == null ? key : '$key.$courseId';

  static const key = 'favorite_word_ids';
  final SharedPreferences _prefs;
  final String _storageKey;

  @override
  Set<String> load() =>
      _prefs.getStringList(_storageKey)?.toSet() ?? <String>{};

  @override
  Future<bool> save(Set<String> wordIds) async {
    var saved = false;
    try {
      saved = await _prefs.setStringList(_storageKey, wordIds.toList()..sort());
      return saved;
    } finally {
      // setStringList обновляет кэш до ответа платформы.
      if (!saved) await _prefs.reload();
    }
  }
}
