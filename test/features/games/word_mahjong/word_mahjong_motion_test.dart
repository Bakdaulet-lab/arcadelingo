import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/leitner_review_session.dart';
import 'package:arcadelingo/features/games/word_mahjong/word_mahjong_game.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final theme in Brightness.values) {
    for (final reduced in [false, true]) {
      testWidgets(
        'pair selection, retry and match ${theme.name}, reduced=$reduced',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          addTearDown(tester.view.reset);
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(disableAnimations: reduced);
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          const pairs = {'moon': 'луна', 'sun': 'солнце'};
          final session = LeitnerReviewSession.start(
            cards: {},
            items: [
              for (final pair in pairs.entries)
                ReviewItem(
                  word: Word(
                    id: pair.key,
                    text: pair.key,
                    translation: pair.value,
                  ),
                ),
            ],
            now: () => DateTime(2026, 11, 21),
            target: pairs.length,
            onCardsChanged: (_) {},
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: wordarcadeTheme(brightness: theme),
              home: WordMahjongGame(
                session: session,
                onPlayAgain: () {},
                onExit: () {},
                seed: 12,
              ),
            ),
          );
          final word = find.text('moon');
          final strings = tester.element(word).strings;
          final atRest = tester.getCenter(word).dy;
          await tester.tap(word);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 55));
          expect(
            tester.getCenter(word).dy,
            reduced ? atRest : lessThan(atRest),
          );
          await tester.tap(find.text('солнце'));
          await tester.pump();
          final error = find.text(strings.mahjongMismatch);
          expect(error, findsOneWidget);
          expect(session.answered, 0);
          await tester.pump(const Duration(milliseconds: 60));
          final errorMid = tester
              .renderObject<RenderBox>(error)
              .getTransformTo(null);
          await tester.pump(const Duration(milliseconds: 380));
          final errorEnd = tester
              .renderObject<RenderBox>(error)
              .getTransformTo(null);
          expect(
            errorMid,
            reduced ? equals(errorEnd) : isNot(equals(errorEnd)),
          );

          await tester.tap(find.text('луна'));
          await tester.pump();
          final matched = find.text('moon — луна');
          expect(matched, findsOneWidget);
          expect(session.answered, 1);
          // The next pair accepts input while the confirmed tiles leave the board.
          await tester.tap(find.text('sun'));
          await tester.pump();
          await tester.tap(find.text('солнце'));
          await tester.pumpAndSettle();
          expect(session.answered, 2);
          expect(find.byKey(WordMahjongKeys.summary), findsOneWidget);
        },
      );
    }
  }
}
