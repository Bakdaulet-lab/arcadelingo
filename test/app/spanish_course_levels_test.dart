import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/data/log/history_database.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/data/speech/device_word_speech.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/main.dart'
    show loadSpanishCourse, loadSpanishFromEnglishCourse;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/claw_actions.dart';
import '../support/in_memory_stores.dart';
import '../support/sqlite_for_tests.dart';

final _now = DateTime(2026, 11, 20, 10);

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(useTestSqlite);

  for (final courseId in ['ru-es', 'en-es']) {
    for (final (level, game, title, wordId, spanish, russian, english) in [
      (
        CefrLevel.a2,
        'falling_words',
        'Falling Words',
        'es_buzon',
        'buzón',
        'почтовый ящик',
        'mailbox',
      ),
      (
        CefrLevel.a2,
        'ninja_slash',
        'Ninja Slash',
        'es_venda',
        'venda',
        'бинт',
        'bandage',
      ),
      (
        CefrLevel.a2,
        'claw_machine',
        'Claw Machine',
        'es_cumpleanos',
        'cumpleaños',
        'день рождения',
        'birthday',
      ),
      (
        CefrLevel.b1,
        'falling_words',
        'Falling Words',
        'es_cuota',
        'cuota',
        'взнос',
        'membership fee',
      ),
      (
        CefrLevel.b1,
        'ninja_slash',
        'Ninja Slash',
        'es_gotera',
        'gotera',
        'протечка',
        'roof leak',
      ),
      (
        CefrLevel.b1,
        'claw_machine',
        'Claw Machine',
        'es_resena',
        'reseña',
        'рецензия',
        'written review',
      ),
      (
        CefrLevel.b2,
        'falling_words',
        'Falling Words',
        'es_hipoteca',
        'hipoteca',
        'ипотека',
        'mortgage',
      ),
      (
        CefrLevel.b2,
        'ninja_slash',
        'Ninja Slash',
        'es_desahucio',
        'desahucio',
        'выселение',
        'eviction',
      ),
      (
        CefrLevel.b2,
        'claw_machine',
        'Claw Machine',
        'es_hazana',
        'hazaña',
        'подвиг',
        'feat',
      ),
      (
        CefrLevel.c1,
        'falling_words',
        'Falling Words',
        'es_desgravacion',
        'desgravación',
        'налоговый вычет',
        'tax deduction',
      ),
      (
        CefrLevel.c1,
        'ninja_slash',
        'Ninja Slash',
        'es_convalecer',
        'convalecer',
        'оправляться после болезни',
        'convalesce',
      ),
      (
        CefrLevel.c1,
        'claw_machine',
        'Claw Machine',
        'es_socavon',
        'socavón',
        'провал грунта',
        'sinkhole',
      ),
    ]) {
      final levelLabel = level.name.toUpperCase();
      testWidgets(
        '$courseId $levelLabel in $title uses its own words and progress',
        (tester) async {
          SharedPreferences.setMockInitialValues({
            SettingsPrefsStore.key:
                '{"version":2,"enabled":false,"hour":20,"minute":0,"interfaceLanguage":"en"}',
          });
          final prefs = await SharedPreferences.getInstance();
          final ruDb = HistoryDatabase(NativeDatabase.memory());
          final enDb = HistoryDatabase(NativeDatabase.memory());
          addTearDown(ruDb.close);
          addTearDown(enDb.close);
          final speech = DeviceWordSpeech(platform: TargetPlatform.linux);
          final (ru, en) =
              (await tester.runAsync(() async {
                final ru = await loadSpanishCourse(
                  prefs: prefs,
                  history: ruDb,
                  speech: speech,
                );
                final en = await loadSpanishFromEnglishCourse(
                  prefs: prefs,
                  history: enDb,
                  speech: speech,
                );
                return (
                  (ru as Ok<CourseDeck>).value,
                  (en as Ok<CourseDeck>).value,
                );
              }))!;
          final (selected, other) = courseId == 'ru-es' ? (ru, en) : (en, ru);
          final translation = courseId == 'ru-es' ? russian : english;

          final target = selected.items.singleWhere(
            (item) => item.word.id == wordId,
          );
          final dueOutsideLevel =
              selected.items
                  .where(
                    (item) =>
                        item.word.level != level &&
                        const [
                          'es_nino',
                          'es_buzon',
                          'es_cuota',
                          'es_hipoteca',
                        ].contains(item.word.id),
                  )
                  .toList();
          expect(dueOutsideLevel, hasLength(level == CefrLevel.c1 ? 4 : 3));
          expect(target.word.level, level);
          expect(target.word.text, spanish);
          expect(target.word.translation, translation);
          final dueToday = LeitnerCard(box: 3, due: _now);
          await selected.cards.save({
            for (final item in selected.items)
              if (item.word.id != target.word.id)
                item.word.id: LeitnerCard(
                  box: 2,
                  due: _now.add(const Duration(days: 1)),
                ),
            for (final item in dueOutsideLevel) item.word.id: dueToday,
          });
          await other.cards.save({
            target.word.id: LeitnerCard(box: 4, due: _now),
          });
          final otherProgress = prefs.getString(
            'leitner_state.${other.course.id}',
          );

          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            WordarcadeApp(
              ports: AppPorts(
                cards: InMemoryCardStore(),
                streaks: InMemoryStreakStore(),
                settings: SettingsPrefsStore(prefs),
              ),
              seed: const Ok([
                ReviewItem(
                  word: Word(id: 'apple', text: 'apple', translation: 'яблоко'),
                ),
              ]),
              additionalDecks: [ru, en],
              now: () => _now,
            ),
          );
          await tester.pumpAndSettle();
          await _tap(tester, find.byKey(AppKeys.course));
          await _tap(tester, find.byKey(ValueKey('course.$courseId')));
          if (level == CefrLevel.c1) {
            expect(find.widgetWithText(ChoiceChip, 'C2'), findsNothing);
          }
          await _tap(tester, find.widgetWithText(ChoiceChip, levelLabel));
          await _tap(tester, find.text(title));
          final play = find.byKey(AppKeys.play);
          await tester.ensureVisible(play);
          await tester.tap(play);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          if (game == 'claw_machine') {
            expect(find.text(translation), findsOneWidget);
            for (final item in dueOutsideLevel) {
              expect(find.text(item.word.translation), findsNothing);
            }
            await spellWithClaw(tester, target.word.text);
            await tapClaw(tester, ClawKeys.next);
          } else {
            final ninja = game == 'ninja_slash';
            await tester.pump(
              ninja ? NinjaRun.windUpTime : FallingWordsRun.windUpTime,
            );
            await tester.pump(const Duration(milliseconds: 850));
            expect(find.text(spanish), findsOneWidget);
            for (final item in dueOutsideLevel) {
              expect(find.text(item.word.text), findsNothing);
            }
            expect(
              target.distractors.where(
                (choice) => find.text(choice).evaluate().isNotEmpty,
              ),
              hasLength(ninja ? NinjaRun.maxObjects - 1 : 3),
            );
            final answer = find.text(translation);
            expect(answer, findsOneWidget);
            if (ninja) {
              final center = tester.getCenter(answer);
              final slash = await tester.startGesture(
                center - const Offset(30, 0),
              );
              await slash.moveTo(center + const Offset(30, 0));
              await slash.up();
            } else {
              await tester.tap(answer);
            }
            await tester.pump();
            await tester.pump(
              ninja ? NinjaRun.correctReveal : FallingWordsRun.correctReveal,
            );
          }

          final records = (await tester.runAsync(selected.answers.all))!;
          expect(records.single.wordId, target.word.id);
          expect(records.single.gameId, game);
          expect(records.single.correct, isTrue);
          expect(await tester.runAsync(other.answers.all), isEmpty);
          await prefs.reload();
          final saved =
              (selected.cards.load() as Ok<Map<String, LeitnerCard>>).value;
          for (final item in dueOutsideLevel) {
            expect(saved[item.word.id], dueToday);
          }
          expect(saved[target.word.id], isNotNull);
          expect(
            prefs.getString('leitner_state.${other.course.id}'),
            otherProgress,
          );
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
