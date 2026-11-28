import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/data/dictionary/favorites_prefs_store.dart';
import 'package:arcadelingo/data/dictionary/word_sets_prefs_store.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_word_speech.dart';
import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';

const _clockTick = Duration(milliseconds: 400);
const _answersReady = Duration(milliseconds: 750);

Future<void> _tap(
  WidgetTester tester,
  Finder target, {
  bool settle = true,
}) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
  await tester.pump(_clockTick);
  if (settle) await tester.pumpAndSettle();
}

void main() {
  for (final fromSet in [false, true]) {
    testWidgets(
      'listening through ${fromSet ? "word set" : "home"} uses the selected deck and repeats in audio',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final settings = SettingsPrefsStore(prefs);
        await settings.save(
          AppSettings.defaults.copyWith(
            soundOn: false,
            interfaceLanguage: InterfaceLanguage.russian,
          ),
        );
        final now = DateTime(2026, 11, 25);
        final english = FakeWordSpeech();
        final spanish = FakeWordSpeech();
        final englishLog = InMemoryAnswerLog();
        final spanishLog = InMemoryAnswerLog();
        const course = StudyCourse.spanishFromRussian;
        final sets = WordSetsPrefsStore(prefs, courseId: course.id);
        await sets.save(
          level: CefrLevel.a2,
          name: 'В дороге',
          wordIds: {'key'},
        );
        const target = ReviewItem(
          word: Word(
            id: 'key',
            text: 'llave',
            translation: 'ключ',
            level: CefrLevel.a2,
          ),
        );
        await tester.pumpWidget(
          WordarcadeApp(
            now: () => now,
            seed: const Ok([
              ReviewItem(
                word: Word(id: 'key', text: 'key', translation: 'ключ'),
              ),
            ]),
            ports: AppPorts(
              cards: InMemoryCardStore(),
              streaks: InMemoryStreakStore(),
              answers: englishLog,
              speech: english,
              settings: settings,
            ),
            additionalDecks: [
              CourseDeck(
                course: course,
                items: [
                  const ReviewItem(
                    word: Word(id: 'a1', text: 'hola', translation: 'привет'),
                  ),
                  target,
                  if (fromSet)
                    const ReviewItem(
                      word: Word(
                        id: 'other',
                        text: 'puerta',
                        translation: 'дверь',
                        level: CefrLevel.a2,
                      ),
                    ),
                ],
                speech: spanish,
                answers: spanishLog,
                cards: InMemoryCardStore({
                  'key': LeitnerCard(
                    box: 3,
                    due: now.add(const Duration(days: 8)),
                  ),
                }),
                streaks: InMemoryStreakStore(),
                favorites: FavoritesPrefsStore(prefs, courseId: course.id),
                wordSets: sets,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await _tap(tester, find.byKey(AppKeys.course));
        await _tap(tester, find.byKey(ValueKey('course.${course.id}')));
        await _tap(tester, find.text('A2'));
        if (fromSet) {
          await _tap(tester, find.byKey(AppKeys.progress));
          await _tap(tester, find.text('Личный словарь'));
          await _tap(tester, find.text('Мои наборы'));
          await _tap(
            tester,
            find.byKey(
              ValueKey('wordSets.play.${sets.load(CefrLevel.a2).single.id}'),
            ),
          );
          await _tap(
            tester,
            find.byKey(const ValueKey('set-game.falling_words.listening')),
            settle: false,
          );
        } else {
          await _tap(
            tester,
            find.byKey(const Key('app.listening')),
            settle: false,
          );
        }
        await tester.pump(_answersReady);
        await tester.pump();
        expect(spanish.spoken, ['llave']);
        expect(english.spoken, isEmpty);
        expect(find.text('llave'), findsNothing);
        expect(find.text('дверь'), findsNothing);
        expect(find.text('привет'), findsNothing);
        await _tap(tester, find.text('ключ'));
        expect(spanishLog.records.single.wordId, 'key');
        expect(spanishLog.records.single.correct, isTrue);
        expect(englishLog.records, isEmpty);
        expect(find.textContaining('llave'), findsWidgets);
        await _tap(tester, find.byKey(const Key('falling.listening.next')));
        await _tap(
          tester,
          find.byKey(FallingWordsKeys.playAgain),
          settle: false,
        );
        await tester.pump(_answersReady);
        expect(spanish.spoken, ['llave', 'llave']);
        expect((settings.load() as Ok<AppSettings>).value.soundOn, isFalse);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }
}
