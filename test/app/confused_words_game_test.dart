import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/data/dictionary/favorites_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';

List<ReviewItem> _family(String mother, String father) => [
  ReviewItem(
    word: Word(id: 'mother', text: mother, translation: 'мать'),
    distractors: const ['отец', 'сын', 'дочь'],
  ),
  ReviewItem(
    word: Word(id: 'father', text: father, translation: 'отец'),
    distractors: const ['мать', 'сын', 'дочь'],
  ),
];

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('two wrong choices reach the pair from the round review, '
      'only in the course that was played', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final russianToEnglish = InMemoryAnswerLog();
    final russianToSpanish = InMemoryAnswerLog();
    await tester.pumpWidget(
      WordarcadeApp(
        ports: AppPorts(
          cards: InMemoryCardStore(),
          streaks: InMemoryStreakStore(),
          answers: russianToEnglish,
          favorites: FavoritesPrefsStore(prefs),
        ),
        seed: Ok(_family('mother', 'father')),
        additionalDecks: [
          CourseDeck(
            course: StudyCourse.spanishFromRussian,
            items: _family('madre', 'padre'),
            cards: InMemoryCardStore(),
            streaks: InMemoryStreakStore(),
            answers: russianToSpanish,
          ),
        ],
        now: () => DateTime(2026, 11, 25),
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(AppKeys.course));
    await _tap(tester, find.byKey(const ValueKey('course.ru-es')));
    await _tap(tester, find.text('Падающие слова'));

    final play = find.byKey(AppKeys.play);
    await tester.ensureVisible(play);
    await tester.tap(play);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(FallingWordsRun.windUpTime);
    for (final (prompt, wrong) in [('madre', 'отец'), ('padre', 'мать')]) {
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text(prompt), findsOneWidget);
      await tester.tap(find.text(wrong));
      await tester.pump();
      await tester.pump(FallingWordsRun.wrongReveal);
    }
    expect(find.byKey(FallingWordsKeys.summary), findsOneWidget);
    expect(russianToSpanish.records.map((r) => r.selectedAnswer), [
      'отец',
      'мать',
    ]);
    expect(russianToEnglish.records, isEmpty);
    await _tap(tester, find.byKey(const Key('game.review_mistakes')));
    await _tap(tester, find.text('Слова, которые я путаю'));
    expect(find.text('Разобрать пару'), findsOneWidget);
    expect(find.textContaining('madre'), findsOneWidget);
    expect(find.textContaining('padre'), findsOneWidget);

    // Same ids and same wrong labels could recreate the pair in the other
    // course if the dictionary accidentally reused the Spanish answer log.
    for (var route = 0; route < 3; route++) {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
    await _tap(tester, find.byKey(AppKeys.course));
    await _tap(tester, find.byKey(const ValueKey('course.ru-en')));
    await _tap(tester, find.byKey(AppKeys.progress));
    await _tap(tester, find.text('Личный словарь'));
    await _tap(tester, find.text('Слова, которые я путаю'));
    expect(find.text('Пока нет повторяющихся пар'), findsOneWidget);
    expect(find.text('Разобрать пару'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
