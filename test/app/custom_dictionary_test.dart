import 'package:arcadelingo/app/dictionary_view.dart';
import 'package:arcadelingo/data/dictionary/favorites_prefs_store.dart';
import 'package:arcadelingo/domain/ports/custom_words_store.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_word_speech.dart';
import '../support/in_memory_answer_log.dart';

class _Store implements CustomWordsStore {
  final words = <Word>[];
  var result = CustomWordSaveResult.saved;

  @override
  List<Word> load(CefrLevel level) =>
      words.where((word) => word.level == level).toList();

  @override
  Future<CustomWordSaveResult> add({
    required CefrLevel level,
    required String text,
    required String translation,
  }) async {
    if (result == CustomWordSaveResult.saved) {
      words.add(
        Word(id: 'own', text: text, translation: translation, level: level),
      );
    }
    return result;
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['en', 'ru', 'es']) {
    testWidgets(
      'save a personal Spanish word with English translation in $language UI',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final store = _Store();
        var changes = 0;
        var games = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: wordarcadeTheme(),
            locale: Locale(language),
            supportedLocales: const [Locale('en'), Locale('ru'), Locale('es')],
            localizationsDelegates: const [
              AppStrings.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: DictionaryScreen(
              items: const [],
              level: CefrLevel.b1,
              course: StudyCourse.spanishFromEnglish,
              answers: InMemoryAnswerLog(),
              favorites: FavoritesPrefsStore(
                await SharedPreferences.getInstance(),
              ),
              speech: FakeWordSpeech(),
              gameTitles: const {},
              customWords: store,
              onCustomWordsChanged: () => changes++,
              onPlayCustom: () => games++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final strings = tester.element(find.byType(DictionaryScreen)).strings;
        await _tap(tester, find.text(strings.addWord));
        final wordField = find.byKey(const ValueKey('customWord.text'));
        final translationField = find.byKey(
          const ValueKey('customWord.translation'),
        );
        expect(find.text(strings.customWordLabel('es')), findsOneWidget);
        expect(find.text(strings.customTranslationLabel('en')), findsOneWidget);
        expect(find.textContaining('B1'), findsOneWidget);
        await _tap(tester, find.text(strings.save));
        expect(find.text(strings.enterWord), findsOneWidget);
        expect(find.text(strings.enterTranslation), findsOneWidget);
        await tester.enterText(wordField, 'la cuenta');
        await tester.enterText(translationField, 'the bill');
        store.result = CustomWordSaveResult.duplicate;
        await _tap(tester, find.text(strings.save));
        expect(find.text(strings.duplicateCustomWord), findsOneWidget);
        expect(find.text('la cuenta'), findsOneWidget);
        expect(changes, 0);
        store.result = CustomWordSaveResult.failed;
        await _tap(tester, find.text(strings.save));
        expect(find.text(strings.customWordSaveFailed), findsOneWidget);
        store.result = CustomWordSaveResult.saved;
        await _tap(tester, find.text(strings.save));
        expect(changes, 1);
        expect(store.words.single.level, CefrLevel.b1);
        expect(find.text('la cuenta'), findsOneWidget);
        expect(find.text('the bill'), findsOneWidget);
        await _tap(tester, find.text(strings.playCustomWords));
        expect(games, 1);
        await _tap(tester, find.text('la cuenta'));
        expect(find.text(strings.attemptCounts(0, 0)), findsOneWidget);
        await _tap(tester, find.text(strings.addFavorite));
        await _tap(tester, find.byType(BackButton));
        await _tap(tester, find.text(strings.recentWords));
        expect(find.text('la cuenta'), findsNothing);
        await _tap(tester, find.text(strings.favorites));
        expect(find.text('la cuenta'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
