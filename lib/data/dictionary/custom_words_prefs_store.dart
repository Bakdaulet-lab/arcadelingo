import 'package:arcadelingo/domain/ports/custom_words_store.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomWordsPrefsStore implements CustomWordsStore {
  CustomWordsPrefsStore(this._prefs, {required String courseId})
    : _coursePrefix = 'custom:${Uri.encodeComponent(courseId)}:';

  static final _spaces = RegExp(r'\s+');
  static final _invisible = RegExp(r'[\p{Cc}\p{Cf}]', unicode: true);
  static final _letter = RegExp(r'\p{L}', unicode: true);
  final SharedPreferences _prefs;
  final String _coursePrefix;
  Future<void> _writes = Future.value();
  String? _saving;

  static String _clean(String value) =>
      value.replaceAll(_spaces, ' ').replaceAll(_invisible, '').trim();

  @override
  List<Word> load(CefrLevel level) {
    final prefix = '$_coursePrefix${level.name}:';
    final words = <Word>[];
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(prefix) || key == _saving) continue;
      if (_prefs.get(key) case [final String text, final String translation]) {
        words.add(
          Word(id: key, level: level, text: text, translation: translation),
        );
      }
    }
    words.sort((a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()));
    return words;
  }

  @override
  Future<CustomWordSaveResult> add({
    required CefrLevel level,
    required String text,
    required String translation,
  }) {
    final term = _clean(text);
    final meaning = _clean(translation);
    if (!_letter.hasMatch(term) || meaning.isEmpty) {
      return Future.value(CustomWordSaveResult.invalid);
    }
    final key =
        '$_coursePrefix${level.name}:${Uri.encodeComponent(term.toLowerCase())}';
    final write = _writes.then((_) => _insert(key, term, meaning));
    _writes = write.then<void>((_) {});
    return write;
  }

  Future<CustomWordSaveResult> _insert(
    String key,
    String term,
    String meaning,
  ) async {
    if (_prefs.containsKey(key)) return CustomWordSaveResult.duplicate;
    _saving = key;
    try {
      if (await _prefs.setStringList(key, [term, meaning])) {
        return CustomWordSaveResult.saved;
      }
    } on Exception {
      // Android and desktop backends can throw or return false on a failed write.
    } finally {
      _saving = null;
    }
    // SharedPreferences caches even a rejected insert. Remove just this key so
    // a retry is possible while writes to other courses keep their own state.
    try {
      await _prefs.remove(key);
    } on Exception {
      // remove clears the local cache before contacting the platform.
    }
    return CustomWordSaveResult.failed;
  }
}
