import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/domain/candy_delivery/candy_orders.dart';
import 'package:arcadelingo/domain/kitchen/kitchen_shift.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/session/leitner_review_session.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_game.dart';
import 'package:arcadelingo/features/games/candy_delivery/candy_delivery_game.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_views.dart';
import 'package:arcadelingo/features/games/order_kitchen/order_kitchen_game.dart';
import 'package:arcadelingo/features/games/order_kitchen/order_kitchen_strings.dart';
import 'package:arcadelingo/features/games/snake/snake_game.dart';
import 'package:arcadelingo/features/games/space_word/space_word_game.dart';
import 'package:arcadelingo/features/games/word_mahjong/word_mahjong_field.dart';
import 'package:arcadelingo/features/games/word_maze/word_maze_game.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/bundled_fonts.dart';

const _kazakh = AppStrings(InterfaceLanguage.kazakh);
const _course = StudyCourse.englishFromRussian;
const _level = CefrLevel.a1;
const _words = [
  Word(id: 'apple', text: 'apple', translation: 'яблоко'),
  Word(id: 'fish', text: 'fish', translation: 'рыба'),
  Word(id: 'key', text: 'key', translation: 'ключ'),
  Word(id: 'moon', text: 'moon', translation: 'луна'),
];

GameLaunch _launch() => GameLaunch(
  session: LeitnerReviewSession.start(
    cards: {},
    items: [
      ReviewItem(
        word: _words.first,
        distractors: [for (final word in _words.skip(1)) word.translation],
      ),
    ],
    target: 1,
    now: () => DateTime(2026, 11, 28),
    onCardsChanged: (_) {},
  ),
  course: _course,
  level: _level,
  vocabulary: _words,
  summaryFooter: () => '',
  onRoundOver: () {},
  onPlayAgain: () {},
  onExit: () {},
);

Future<void> _open(
  WidgetTester tester,
  Brightness brightness,
  Widget screen, {
  bool reduceMotion = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 780);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('kk'),
      supportedLocales: const [Locale('kk')],
      localizationsDelegates: const [
        AppStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      theme: wordarcadeTheme(
        brightness: brightness,
        platform: TargetPlatform.android,
      ),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
      home: screen,
    ),
  );
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder button) async {
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
}

void main() {
  setUpAll(loadBundledFonts);

  for (final brightness in Brightness.values) {
    for (final game in wordarcadeGames) {
      testWidgets('${game.id} plays with Kazakh UI in ${brightness.name}', (
        tester,
      ) async {
        expect(
          game.instructionFor(_kazakh),
          isNot(game.instructionFor(russianStrings)),
        );
        if (game != spaceWordEntry) {
          expect(game.titleFor(_kazakh), isNot(game.titleFor(russianStrings)));
        }

        await _open(tester, brightness, game.build(_launch()));
        if (game != fallingWordsEntry && game != ninjaSlashEntry) {
          expect(
            find.text(game.titleFor(_kazakh), findRichText: true),
            findsOneWidget,
          );
        }

        switch (game.id) {
          case 'falling_words':
            await tester.pump(FallingWordsRun.windUpTime);
            expect(find.text('apple'), findsOneWidget);
            await _tap(tester, find.text('яблоко').last);
            await tester.pump(const Duration(seconds: 1));
            expect(find.text(_kazakh.playAgain), findsOneWidget);
          case 'ninja_slash':
            await tester.pump(NinjaRun.windUpTime);
            await tester.pump(const Duration(milliseconds: 850));
            expect(find.text('apple'), findsOneWidget);
            final lives = tester.ensureSemantics();
            try {
              await tester.pump();
              expect(
                find.bySemanticsLabel(
                  RegExp(RegExp.escape(_kazakh.lives(3, 3))),
                ),
                findsOneWidget,
              );
            } finally {
              lives.dispose();
            }
            final object = find.byKey(NinjaKeys.objectAt(1));
            final center = tester.getCenter(object);
            await tester.dragFrom(
              center - const Offset(48, 0),
              const Offset(96, 0),
            );
            await tester.pump(const Duration(milliseconds: 180));
          case 'claw_machine':
            expect(find.text('яблоко'), findsOneWidget);
            expect(find.text(_kazakh.grab), findsOneWidget);
            await _tap(tester, find.byKey(ClawKeys.hint));
            await _tap(tester, find.byKey(ClawKeys.grab));
          case 'brick_breaker':
            expect(find.text(_kazakh.brickLaunch), findsOneWidget);
            await _tap(tester, find.byKey(BrickBreakerKeys.launch));
            expect(find.text(_kazakh.brickPause), findsOneWidget);
            await _tap(tester, find.byKey(BrickBreakerKeys.launch));
            expect(find.text(_kazakh.brickResume), findsOneWidget);
          case 'match_three':
            await _tap(tester, find.byTooltip(_kazakh.matchHowTo));
            expect(find.text(_kazakh.matchSwapRule), findsOneWidget);
            await _tap(tester, find.text(_kazakh.play));
            expect(find.text(_kazakh.matchSwapRule), findsNothing);
          case 'word_mahjong':
            expect(find.text('яблоко'), findsOneWidget);
            await _tap(tester, find.byKey(WordMahjongKeys.hint));
            expect(find.text(_kazakh.mahjongHintShown), findsOneWidget);
          case 'snake':
            expect(find.text(_kazakh.snakeGuide), findsOneWidget);
            await _tap(tester, find.byKey(SnakeKeys.pause));
            expect(find.byTooltip(_kazakh.snakePause), findsOneWidget);
            await _tap(tester, find.byKey(SnakeKeys.pause));
            expect(find.text(_kazakh.snakeResume), findsOneWidget);
          case 'word_maze':
            expect(find.text(_kazakh.mazeReadyGuide), findsOneWidget);
            await tester.drag(find.byKey(MazeKeys.field), const Offset(0, -48));
            await tester.pump(const Duration(milliseconds: 150));
            expect(find.byTooltip(_kazakh.snakePause), findsOneWidget);
          case 'space_word':
            expect(find.text(_kazakh.spaceLaunch), findsOneWidget);
            await _tap(tester, find.byKey(SpaceWordKeys.start));
            expect(find.text(_kazakh.spaceFire), findsOneWidget);
            await _tap(tester, find.byKey(SpaceWordKeys.pause));
            expect(find.text(_kazakh.snakeResume), findsOneWidget);
          default:
            fail('Missing Kazakh smoke test for ${game.id}');
        }

        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('kitchen keeps the order language in ${brightness.name}', (
      tester,
    ) async {
      const seed = 5;
      final order =
          kitchenOrdersFor(course: _course, level: _level, seed: seed).first;
      await _open(
        tester,
        brightness,
        OrderKitchenGame(course: _course, seed: seed, onExit: () {}),
      );
      expect(find.text(_kazakh.orderKitchen), findsOneWidget);
      expect(find.text(order.phrase('en')), findsOneWidget);
      expect(find.text(_kazakh.serveDrink), findsOneWidget);
      final serve = find.byKey(const Key('kitchen.serve'));
      final wrongIngredient = find.byKey(const Key('kitchen.ingredient.lemon'));
      await _tap(tester, wrongIngredient);
      await _tap(tester, serve);
      expect(find.text(_kazakh.adjustDrink), findsOneWidget);
      await _tap(tester, wrongIngredient);
      for (final ingredient in order.ingredients) {
        await _tap(
          tester,
          find.byKey(ValueKey('kitchen.ingredient.${ingredient.name}')),
        );
      }
      await _tap(tester, serve);
      expect(find.text(_kazakh.servedDrink), findsOneWidget);
      expect(find.text(order.phrase('ru')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('candy keeps its course clue in ${brightness.name}', (
      tester,
    ) async {
      const seed = 37;
      final order =
          candyOrdersFor(course: _course, level: _level, seed: seed).first;
      await _open(
        tester,
        brightness,
        CandyDeliveryGame(
          course: _course,
          level: _level,
          seed: seed,
          onExit: () {},
        ),
        reduceMotion: true,
      );
      expect(find.text(_kazakh.candyDelivery), findsOneWidget);
      expect(find.text(order.phrase), findsOneWidget);
      await _tap(tester, find.byKey(const Key('candy.hint')));
      expect(find.text(order.translation), findsOneWidget);
      await _tap(
        tester,
        find.byKey(
          ValueKey('candy.aim.${order.rabbits.indexOf(order.target)}'),
        ),
      );
      await _tap(tester, find.byKey(const Key('candy.cut')));
      await tester.pumpAndSettle();
      expect(find.text(_kazakh.candyDelivered), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
