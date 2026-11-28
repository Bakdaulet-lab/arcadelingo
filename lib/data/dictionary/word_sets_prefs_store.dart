import 'dart:convert';
import 'dart:math';

import 'package:arcadelingo/domain/ports/word_sets_store.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WordSetsPrefsStore implements WordSetsStore {
  factory WordSetsPrefsStore(
    SharedPreferences prefs, {
    required String courseId,
  }) {
    // All handles to a course share a write queue, including during a switch
    // away from the course and back while a platform write is still pending.
    final courses = _stores[prefs] ??= {};
    return courses.putIfAbsent(
      courseId,
      () => WordSetsPrefsStore._(prefs, courseId),
    );
  }

  WordSetsPrefsStore._(this._prefs, String courseId)
    : _prefix = 'word_set:${Uri.encodeComponent(courseId)}:';

  static final _stores = Expando<Map<String, WordSetsPrefsStore>>();
  static final _random = Random.secure();
  static final _spaces = RegExp(r'\s+');
  static final _invisible = RegExp(r'[\p{Cc}\p{Cf}]', unicode: true);

  final SharedPreferences _prefs;
  final String _prefix;
  Future<void> _writes = Future.value();
  ({String key, List<String>? before})? _pending;

  String _scope(CefrLevel level) => '$_prefix${level.name}:';

  List<String>? _stored(String id) {
    final value = _prefs.get(id);
    if (value is! List ||
        value.isEmpty ||
        value.any((entry) => entry is! String)) {
      return null;
    }
    return value.cast<String>();
  }

  @override
  List<WordSet> load(CefrLevel level) {
    final scope = _scope(level);
    final pending = _pending;
    final keys = _prefs.getKeys();
    if (pending != null) keys.add(pending.key);
    final sets = <WordSet>[];
    for (final key in keys.where((key) => key.startsWith(scope))) {
      final fields = pending?.key == key ? pending!.before : _stored(key);
      if (fields != null) {
        sets.add(
          WordSet(id: key, name: fields.first, wordIds: fields.skip(1).toSet()),
        );
      }
    }
    return sets
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<WordSetSaveResult> save({
    required CefrLevel level,
    String? id,
    required String name,
    required Set<String> wordIds,
  }) {
    final title =
        name.replaceAll(_spaces, ' ').replaceAll(_invisible, '').trim();
    if (title.isEmpty || wordIds.any((word) => word.trim().isEmpty)) {
      return Future.value(WordSetSaveResult.invalid);
    }
    final fields = [title, ...wordIds];
    return _enqueue(() async {
      final scope = _scope(level);
      if (id != null && (!id.startsWith(scope) || _stored(id) == null)) {
        return WordSetSaveResult.missing;
      }
      final duplicate = load(level).any(
        (set) => set.id != id && set.name.toLowerCase() == title.toLowerCase(),
      );
      if (duplicate) return WordSetSaveResult.duplicate;
      final key =
          id ??
          '$scope${base64UrlEncode(List.generate(16, (_) => _random.nextInt(256)))}';
      return await _persist(key, fields)
          ? WordSetSaveResult.saved
          : WordSetSaveResult.failed;
    });
  }

  @override
  Future<bool> remove({required CefrLevel level, required String id}) =>
      _enqueue(() async {
        if (!id.startsWith(_scope(level))) return false;
        if (!_prefs.containsKey(id)) return true;
        return _persist(id, null);
      });

  Future<T> _enqueue<T>(Future<T> Function() update) {
    final result = _writes.then((_) => update());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> _writeFields(String key, List<String>? fields) =>
      fields == null ? _prefs.remove(key) : _prefs.setStringList(key, fields);

  Future<bool> _persist(String key, List<String>? fields) async {
    final before = _stored(key);
    _pending = (key: key, before: before);
    try {
      if (await _writeFields(key, fields)) return true;
    } on Exception {
      // Preferences backends may reject by exception or by returning false.
    } finally {
      _pending = null;
    }
    // SharedPreferences already mutated its in-memory cache. Restore just
    // this record; reloading all preferences could undo another course's write.
    try {
      await _writeFields(key, before);
    } on Exception {
      // The cache is restored before the platform call.
    }
    return false;
  }
}
