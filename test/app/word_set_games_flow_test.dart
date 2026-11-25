import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/data/dictionary/custom_words_prefs_store.dart';
import 'package:arcadelingo/data/dictionary/favorites_prefs_store.dart';
import 'package:arcadelingo/data/dictionary/word_sets_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('all games and replay launch from the selected saved set', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const level = CefrLevel.b1;
    const course = StudyCourse.spanishFromRussian;
    final spanishSets = WordSetsPrefsStore(prefs, courseId: course.id);
    final englishSets = WordSetsPrefsStore(
      prefs,
      courseId: StudyCourse.englishFromRussian.id,
    );
    final personal = CustomWordsPrefsStore(prefs, courseId: course.id);
    await personal.add(
      level: level,
      text: 'mi barrio',
      translation: 'мой район',
    );
    final own = personal.load(level).single;
    await spanishSets.save(
      level: level,
      name: 'В городе',
      wordIds: {'plaza', own.id},
    );
    await spanishSets.save(
      level: level,
      name: 'Другой набор',
      wordIds: {'cine'},
    );
    await spanishSets.save(
      level: CefrLevel.a1,
      name: 'Начало',
      wordIds: {'uno'},
    );
    await englishSets.save(level: level, name: 'Town', wordIds: {'plaza'});
    final setId =
        spanishSets.load(level).singleWhere((s) => s.name == 'В городе').id;
    final expectedIds = {'plaza', own.id};
    const translations = {'площадь', 'мой район'};
    const items = [
      ReviewItem(
        word: Word(
          id: 'plaza',
          text: 'plaza',
          translation: 'площадь',
          level: level,
        ),
        distractors: ['кинотеатр', 'чужой вариант'],
      ),
      ReviewItem(
        word: Word(
          id: 'cine',
          text: 'cine',
          translation: 'кинотеатр',
          level: level,
        ),
      ),
      ReviewItem(word: Word(id: 'uno', text: 'uno', translation: 'один')),
    ];
    final now = DateTime(2026, 11, 25);
    final spanishAnswers = InMemoryAnswerLog();
    final englishAnswers = InMemoryAnswerLog();
    late GameLaunch current;
    final launches = <String>[];
    ReviewSession? previous;
    final games = [
      for (final real in wordarcadeGames)
        GameEntry(
          id: real.id,
          title: real.title,
          build: (launch) {
            if (!identical(previous, launch.session)) {
              previous = launch.session;
              current = launch;
              launches.add(real.id);
              expect(launch.course, course);
              expect(launch.level, level);
              expect(
                launch.vocabulary.map((word) => word.id),
                unorderedEquals(expectedIds),
              );
              final items =
                  (launch.session as BoardReviewSession).remainingItems;
              expect(
                items.map((item) => item.word.id),
                unorderedEquals(expectedIds),
              );
              for (final item in items) {
                expect(
                  item.distractors,
                  unorderedEquals(
                    translations.difference({item.word.translation}),
                  ),
                );
              }
            }
            return real.build(launch);
          },
        ),
    ];
    await tester.pumpWidget(
      WordarcadeApp(
        ports: AppPorts(
          cards: InMemoryCardStore(),
          streaks: InMemoryStreakStore(),
          answers: englishAnswers,
          favorites: FavoritesPrefsStore(prefs),
          wordSets: englishSets,
        ),
        seed: const Ok([
          ReviewItem(
            word: Word(
              id: 'plaza',
              text: 'square',
              translation: 'площадь',
              level: level,
            ),
          ),
        ]),
        now: () => now,
        games: games,
        additionalDecks: [
          CourseDeck(
            course: course,
            items: items,
            wordSets: spanishSets,
            customWords: personal,
            favorites: FavoritesPrefsStore(prefs, courseId: course.id),
            answers: spanishAnswers,
            streaks: InMemoryStreakStore(),
            cards: InMemoryCardStore({
              'plaza': LeitnerCard(
                box: 3,
                due: now.add(const Duration(days: 8)),
              ),
            }),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(AppKeys.course));
    await _tap(tester, find.byKey(ValueKey('course.${course.id}')));
    await _tap(tester, find.text('B1'));
    await _tap(tester, find.byKey(AppKeys.progress));
    await _tap(tester, find.text('Личный словарь'));
    await _tap(tester, find.text('Мои наборы'));
    expect(find.text('Town'), findsNothing);
    expect(find.text('Начало'), findsNothing);
    for (final game in games) {
      await _tap(tester, find.byKey(ValueKey('wordSets.play.$setId')));
      final option = find.byKey(ValueKey('set-game.${game.id}'));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(launches.last, game.id);
      if (game.id == 'snake' || game.id == 'word_maze') {
        current.onPlayAgain();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(launches.where((id) => id == game.id), hasLength(2));
      }
      current.onExit();
      await tester.pumpAndSettle();
      expect(find.text('В городе'), findsOneWidget);
    }
    expect(launches.toSet(), wordarcadeGames.map((g) => g.id).toSet());
    expect(englishAnswers.records, isEmpty);
    expect(
      spanishAnswers.records.map((r) => r.wordId),
      everyElement(isIn(expectedIds)),
    );
    expect(tester.takeException(), isNull);
  });
}
