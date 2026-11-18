import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/learning_views.dart';
import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/claw_actions.dart';
import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';
import '../support/result.dart';

void main() {
  testWidgets('назад во время захвата докладывает именно неответ', (
    tester,
  ) async {
    final answers = InMemoryAnswerLog();
    final streaks = InMemoryStreakStore();
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      WordarcadeApp(
        ports: AppPorts(
          cards: InMemoryCardStore(),
          streaks: streaks,
          answers: answers,
        ),
        seed: const Ok([
          ReviewItem(word: Word(id: 'fish', text: 'fish', translation: 'рыба')),
        ]),
        now: () => DateTime(2026, 11, 18, 10),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.text('Автомат с клешнёй');
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tapClaw(tester, AppKeys.play);

    await spellWithClaw(tester, 'fis');
    await tester.tap(clawCapsule('H'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ClawKeys.grab));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 520));
    expect(answers.records, isEmpty);
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 70));
    await tester.pumpAndSettle();
    expect(answers.records.single.correct, isFalse);
    expect(streaks.saves, isEmpty);
    expect(find.byKey(AppKeys.play), findsOneWidget);
  });

  testWidgets('разбор показывает ошибочную букву из законченной партии', (
    tester,
  ) async {
    final answers = InMemoryAnswerLog();
    final streaks = InMemoryStreakStore();
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      WordarcadeApp(
        ports: AppPorts(
          cards: InMemoryCardStore(),
          streaks: streaks,
          answers: answers,
        ),
        seed: const Ok([
          ReviewItem(word: Word(id: 'fish', text: 'fish', translation: 'рыба')),
        ]),
        now: () => DateTime(2026, 11, 18, 10),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.text('Автомат с клешнёй');
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tapClaw(tester, AppKeys.play);

    final letter = [
      for (var lane = 0; lane < 5; lane++)
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(ClawKeys.topCapsule(lane)),
                matching: find.byType(Text),
              ),
            )
            .data!,
    ].firstWhere((letter) => letter != 'F');
    await catchClawLetter(tester, letter);
    await spellWithClaw(tester, 'fish');
    await tapClaw(tester, ClawKeys.next);
    expect(answers.records.single.correct, isFalse);
    expect(streaks.saves, isNotEmpty);
    await tapClaw(tester, const Key('game.review_mistakes'));
    expect(find.byKey(LearningKeys.mistakes), findsOneWidget);
    expect(find.text(letter), findsOneWidget);
    expect(find.text('fish'), findsOneWidget);
    expect(find.text('рыба'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(ClawKeys.summary), findsOneWidget);
    expect(answers.records, hasLength(1));
  });

  for (final level in CefrLevel.values) {
    testWidgets('Автомат: запуск из меню и карточки только ${level.name}', (
      tester,
    ) async {
      final bundled = ok((await tester.runAsync(loadWordsSeed))!);
      final items = [
        for (final band in CefrLevel.values)
          ...bundled.where((item) => item.word.level == band).take(2),
      ];
      final expected = items.where((item) => item.word.level == level);
      final answers = InMemoryAnswerLog();
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        WordarcadeApp(
          ports: AppPorts(
            cards: InMemoryCardStore(),
            streaks: InMemoryStreakStore(),
            answers: answers,
          ),
          seed: Ok(items),
          now: () => DateTime(2026, 11, 18, 10),
        ),
      );
      await tester.pumpAndSettle();

      for (final title in [level.name.toUpperCase(), 'Автомат с клешнёй']) {
        final target = find.text(title);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }
      await tapClaw(tester, AppKeys.play);
      for (final item in expected) {
        expect(
          tester.widget<Text>(find.byKey(ClawKeys.prompt)).data,
          item.word.translation,
        );
        await spellWithClaw(tester, item.word.text);
        expect(answers.records.last.wordId, item.word.id);
        expect(answers.records.last.gameId, 'claw_machine');
        expect(answers.records.last.correct, isTrue);
        await tapClaw(tester, ClawKeys.next);
      }
      expect(answers.records, hasLength(2));
      expect(find.byKey(ClawKeys.summary), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
