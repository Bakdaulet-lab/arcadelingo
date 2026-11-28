@Tags(['peek'])
library;

import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/session/leitner_review_session.dart';
import 'package:arcadelingo/features/games/snake/snake_game.dart';
import 'package:arcadelingo/features/games/word_maze/word_maze_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'peek_harness.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final snake in [true, false]) {
      final game = snake ? 'snake' : 'maze';
      testWidgets('endless $game in ${brightness.name}', (tester) async {
        tester.view.physicalSize = peekPhysicalSize;
        tester.view.devicePixelRatio = peekDevicePixelRatio;
        addTearDown(tester.view.reset);
        const pairs = {
          'llave': 'ключ',
          'nube': 'облако',
          'hoja': 'лист',
          'silla': 'стул',
        };
        final words = [
          for (final pair in pairs.entries)
            Word(id: pair.key, text: pair.key, translation: pair.value),
        ];
        final session = LeitnerReviewSession.continuous(
          cards: {},
          items: [for (final word in words) ReviewItem(word: word)],
          random: Random(11),
          now: () => DateTime(2026, 11, 25),
          onCardsChanged: (_) {},
        );
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: wordarcadeTheme(
              brightness: brightness,
              platform: TargetPlatform.android,
            ),
            home:
                snake
                    ? SnakeGame(
                      session: session,
                      continuous: true,
                      vocabulary: words,
                      course: StudyCourse.spanishFromRussian,
                      level: CefrLevel.a1,
                      seed: 7,
                      onPlayAgain: () {},
                      onExit: () {},
                    )
                    : WordMazeGame(
                      session: session,
                      continuous: true,
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
        await tester.sendKeyEvent(
          snake ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowUp,
        );
        for (var frame = 0; frame < (snake ? 77 : 43); frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await peek(tester, 'endless_${game}_${brightness.name}');
      });
    }
  }
}
