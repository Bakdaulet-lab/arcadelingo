import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/leitner_review_session.dart';
import 'package:arcadelingo/features/games/snake/snake_field.dart';
import 'package:arcadelingo/features/games/snake/snake_run.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'subcell motion repaints the snake without redrawing the grid or fruit',
    (tester) async {
      const words = [
        Word(id: 'cat', text: 'cat', translation: 'кот'),
        Word(id: 'dog', text: 'dog', translation: 'собака'),
      ];
      final run = SnakeRun(
        LeitnerReviewSession.start(
          cards: {},
          items: [ReviewItem(word: words.first)],
          target: 1,
          now: () => DateTime.utc(2026),
          onCardsChanged: (_) {},
        ),
        words,
        Random(3),
      );
      final motion = AnimationController(vsync: tester);
      addTearDown(motion.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: wordarcadeTheme(),
          home: SnakeField(run: run, motion: motion, onTurn: (_) {}),
        ),
      );
      final layers = tester.renderObjectList<RenderCustomPaint>(
        find.descendant(
          of: find.byType(SnakeField),
          matching: find.byType(CustomPaint),
        ),
      );
      motion.value = .5;
      final changed = layers.where((layer) => layer.debugNeedsPaint).toList();
      expect(changed, hasLength(1));
      final layer = changed.single;
      void draw(Canvas canvas) => layer.painter!.paint(canvas, layer.size);
      expect(draw, paints..path());
      expect(draw, paintsExactlyCountTimes(#drawLine, 0));
    },
  );
}
