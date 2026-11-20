@Tags(['peek'])
library;

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/session/leitner_review_session.dart';
import 'package:arcadelingo/features/games/word_mahjong/word_mahjong_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'peek_harness.dart';

const _pairs = {
  'llave': 'ключ',
  'viaje': 'поездка',
  'playa': 'пляж',
  'cuchara': 'ложка',
  'puente': 'мост',
  'jardín': 'сад',
};

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('маджонг — ${brightness.name}', (tester) async {
      tester.view.physicalSize = peekPhysicalSize;
      tester.view.devicePixelRatio = peekDevicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: wordarcadeTheme(
            brightness: brightness,
            platform: TargetPlatform.android,
          ),
          home: WordMahjongGame(
            session: LeitnerReviewSession.start(
              cards: {},
              items: [
                for (final entry in _pairs.entries)
                  ReviewItem(
                    word: Word(
                      id: entry.key,
                      text: entry.key,
                      translation: entry.value,
                    ),
                  ),
              ],
              target: _pairs.length,
              now: () => DateTime(2026, 11, 21),
              onCardsChanged: (_) {},
            ),
            onPlayAgain: () {},
            onExit: () {},
            course: StudyCourse.spanishFromRussian,
            level: CefrLevel.a1,
            seed: 12,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await peek(tester, 'word_mahjong_${brightness.name}_board');
      await tester.tap(find.byKey(WordMahjongKeys.hint));
      await tester.pumpAndSettle();
      await peek(tester, 'word_mahjong_${brightness.name}_hint');
    });
  }
}
