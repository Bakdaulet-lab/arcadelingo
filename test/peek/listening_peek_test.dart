@Tags(['peek'])
library;

import 'dart:async';

import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/leitner_review_session.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_word_speech.dart';
import 'peek_harness.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Listening round in ${brightness.name}', (tester) async {
      tester.view.physicalSize = peekPhysicalSize;
      tester.view.devicePixelRatio = peekDevicePixelRatio;
      addTearDown(tester.view.reset);
      final pronunciation = Completer<SpeechResult>();
      final speech = FakeWordSpeech()..pending = pronunciation;
      final session = LeitnerReviewSession.start(
        items: const [
          ReviewItem(
            word: Word(id: 'llave', text: 'llave', translation: 'ключ'),
            distractors: ['дверь', 'письмо', 'ручка'],
          ),
        ],
        cards: {},
        target: 1,
        now: () => DateTime.utc(2026, 11, 25),
        onCardsChanged: (_) {},
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: wordarcadeTheme(
            brightness: brightness,
            platform: TargetPlatform.android,
          ),
          home: FallingWordsGame(
            listeningMode: true,
            speech: speech,
            studyLanguage: 'es',
            session: session,
            seed: 45,
            onPlayAgain: () {},
            onExit: () {},
          ),
        ),
      );
      await tester.pump();
      await peek(tester, 'listening_audio_${brightness.name}');
      pronunciation.complete(SpeechResult.completed);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2400));
      await peek(tester, 'listening_play_${brightness.name}');
      await tester.tap(find.text('ключ'));
      await tester.pumpAndSettle();
      await peek(tester, 'listening_reveal_${brightness.name}');
    });
  }
}
