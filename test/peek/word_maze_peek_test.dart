@Tags(['peek'])
library;

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/word_maze/word_maze_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_review_session.dart';
import 'peek_harness.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('word maze in ${brightness.name}', (tester) async {
      tester.view.physicalSize = peekPhysicalSize;
      tester.view.devicePixelRatio = peekDevicePixelRatio;
      addTearDown(tester.view.reset);
      const words = [
        Word(id: 'llave', text: 'llave', translation: 'ключ'),
        Word(id: 'calle', text: 'calle', translation: 'улица'),
        Word(id: 'leche', text: 'leche', translation: 'молоко'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: wordarcadeTheme(
            brightness: brightness,
            platform: TargetPlatform.android,
          ),
          home: WordMazeGame(
            session: FakeReviewSession([
              for (final word in words) ReviewItem(word: word),
            ]),
            vocabulary: words,
            course: StudyCourse.spanishFromRussian,
            level: CefrLevel.a1,
            seed: 7,
            onPlayAgain: () {},
            onExit: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await peek(tester, 'word_maze_play_${brightness.name}');
      for (
        var i = 0;
        i < 300 && find.byKey(MazeKeys.next).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(find.byKey(MazeKeys.feedback), findsOneWidget);
      await peek(tester, 'word_maze_gate_${brightness.name}');
    });
  }
}
