import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/data/dictionary/custom_words_prefs_store.dart';
import 'package:arcadelingo/data/dictionary/favorites_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'home, course switch and immediate dictionary replay use the selected vocabulary',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = CustomWordsPrefsStore(
        prefs,
        courseId: StudyCourse.englishFromRussian.id,
      );
      final second = CustomWordsPrefsStore(
        prefs,
        courseId: StudyCourse.spanishFromRussian.id,
      );
      await first.add(
        level: CefrLevel.a1,
        text: 'front door',
        translation: 'входная дверь',
      );
      await first.add(
        level: CefrLevel.b1,
        text: 'caretaker',
        translation: 'смотритель',
      );
      await second.add(
        level: CefrLevel.a1,
        text: 'mi barrio',
        translation: 'мой район',
      );
      GameLaunch? current;
      final sample = GameEntry(
        id: 'sample',
        title: 'Тестовая игра',
        build: (launch) {
          current = launch;
          return const Scaffold(body: Text('Раунд'));
        },
      );
      await tester.pumpWidget(
        WordarcadeApp(
          ports: AppPorts(
            cards: InMemoryCardStore(),
            streaks: InMemoryStreakStore(),
            answers: InMemoryAnswerLog(),
            favorites: FavoritesPrefsStore(prefs),
            customWords: first,
          ),
          games: [sample],
          seed: const Ok([
            ReviewItem(
              word: Word(id: 'bed', text: 'bed', translation: 'кровать'),
            ),
          ]),
          additionalDecks: [
            CourseDeck(
              course: StudyCourse.spanishFromRussian,
              items: const [
                ReviewItem(
                  word: Word(id: 'casa', text: 'casa', translation: 'дом'),
                ),
              ],
              cards: InMemoryCardStore(),
              streaks: InMemoryStreakStore(),
              answers: InMemoryAnswerLog(),
              favorites: FavoritesPrefsStore(
                prefs,
                courseId: StudyCourse.spanishFromRussian.id,
              ),
              customWords: second,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(AppKeys.play));
      expect(current!.session.nextItem()!.word.text, 'front door');
      expect(current!.vocabulary.map((w) => w.text), ['front door', 'bed']);
      current!.onExit();
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(AppKeys.course));
      await _tap(
        tester,
        find.byKey(ValueKey('course.${StudyCourse.spanishFromRussian.id}')),
      );
      await _tap(tester, find.byKey(AppKeys.progress));
      await _tap(tester, find.text('Личный словарь'));
      await _tap(tester, find.text('Свои слова'));
      await _tap(tester, find.byKey(const ValueKey('dictionary.play-custom')));
      await _tap(tester, find.byKey(const ValueKey('custom-game.sample')));
      final launch = current!;
      expect(launch.course, StudyCourse.spanishFromRussian);
      expect(launch.session.total, 1);
      expect(launch.session.nextItem()!.word.text, 'mi barrio');
      expect(launch.vocabulary.map((w) => w.text), ['mi barrio', 'casa']);
      launch.session.report(
        const ReviewOutcome.untimed(
          correct: true,
          responseTime: Duration(seconds: 1),
        ),
      );
      launch.onRoundOver();
      launch.onPlayAgain();
      await tester.pumpAndSettle();
      expect(current!.session.nextItem()!.word.text, 'mi barrio');
      current!.onExit();
      await tester.pumpAndSettle();
      expect(find.text('mi barrio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
