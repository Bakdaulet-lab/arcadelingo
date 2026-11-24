import 'package:arcadelingo/data/dictionary/custom_words_prefs_store.dart';
import 'package:arcadelingo/domain/ports/custom_words_store.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late CustomWordsPrefsStore russian;
  late CustomWordsPrefsStore english;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'favorite_word_ids': <String>['cat'],
    });
    prefs = await SharedPreferences.getInstance();
    russian = CustomWordsPrefsStore(prefs, courseId: 'ru-es');
    english = CustomWordsPrefsStore(prefs, courseId: 'en-es');
  });

  test('persists each scoped word with its own stable progress ID', () async {
    expect(russian.load(CefrLevel.a1), isEmpty);
    for (final (store, level, translation) in [
      (russian, CefrLevel.a1, '  чашка   чая  '),
      (russian, CefrLevel.b2, 'чайный напиток'),
      (english, CefrLevel.a1, 'cup of tea'),
    ]) {
      expect(
        await store.add(
          level: level,
          text: ' Una  taza de té ',
          translation: translation,
        ),
        CustomWordSaveResult.saved,
      );
    }
    final originalId = russian.load(CefrLevel.a1).single.id;
    await prefs.reload();
    final reopened = CustomWordsPrefsStore(prefs, courseId: 'ru-es');
    final basic = reopened.load(CefrLevel.a1).single;
    expect(
      (basic.id, basic.text, basic.translation, basic.level),
      (originalId, 'Una taza de té', 'чашка чая', CefrLevel.a1),
    );
    final advanced = reopened.load(CefrLevel.b2).single;
    final other = english.load(CefrLevel.a1).single;
    expect(
      (advanced.translation, advanced.level),
      ('чайный напиток', CefrLevel.b2),
    );
    expect(other.translation, 'cup of tea');
    expect({basic.id, advanced.id, other.id}, hasLength(3));
    expect(originalId, startsWith('custom:'));
    expect(english.load(CefrLevel.b2), isEmpty);
    expect(prefs.getStringList('favorite_word_ids'), ['cat']);
  });

  test(
    'concurrent saves keep both cards and do not overwrite a duplicate',
    () async {
      final results = await Future.wait([
        russian.add(
          level: CefrLevel.a1,
          text: '  La   cuenta',
          translation: 'счёт',
        ),
        russian.add(
          level: CefrLevel.a1,
          text: 'LA CUENTA ',
          translation: 'иная запись',
        ),
        russian.add(level: CefrLevel.a1, text: 'los días', translation: 'дни'),
      ]);
      expect(results, [
        CustomWordSaveResult.saved,
        CustomWordSaveResult.duplicate,
        CustomWordSaveResult.saved,
      ]);
      await prefs.reload();
      expect(
        russian.load(CefrLevel.a1).map((word) => word.translation),
        unorderedEquals(['счёт', 'дни']),
      );
    },
  );

  test(
    'rejects empty and unplayable input without persisting a card',
    () async {
      for (final (text, translation) in [
        (' \n\t', 'чашка'),
        ('café', ' \n'),
        ('  --?!', 'знаки'),
        ('abc', '\u200B'),
      ]) {
        expect(
          await russian.add(
            level: CefrLevel.c1,
            text: text,
            translation: translation,
          ),
          CustomWordSaveResult.invalid,
        );
      }
      expect(prefs.getKeys(), {'favorite_word_ids'});
    },
  );
}
