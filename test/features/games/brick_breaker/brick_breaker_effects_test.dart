import 'dart:math';
import 'dart:ui' as ui;

import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_field.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_run.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';
import '../../../support/review_items.dart';

/// Read the strip above the capture point and exclude the paddle itself.
Future<List<int>> _sample(WidgetTester tester, Key key, int x) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final data =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final pixels = data.buffer.asUint32List(
        data.offsetInBytes,
        data.lengthInBytes ~/ 4,
      );
      return [
        for (var y = 309; y < 356; y++)
          for (var dx = -28; dx <= 28; dx++) pixels[y * image.width + x + dx],
      ];
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  for (final brightness in Brightness.values) {
    for (final reduced in [false, true]) {
      testWidgets('catch stays at its lane in $brightness, reduced=$reduced', (
        tester,
      ) async {
        final run = BrickBreakerRun(FakeReviewSession(wordItems(2)), Random(4));
        const key = ValueKey('field-pixels');
        Future<void> draw() => tester.pumpWidget(
          MaterialApp(
            theme: wordarcadeTheme(brightness: brightness),
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Center(
                child: SizedBox(
                  width: BrickBreakerRun.width,
                  child: RepaintBoundary(
                    key: key,
                    child: BrickBreakerField(run: run, onMove: run.movePaddle),
                  ),
                ),
              ),
            ),
          ),
        );
        run.launch();
        run.advance(const Duration(seconds: 2));
        expect(run.phase, BrickPhase.bonus);
        final target = run.laneCenter(run.choices.indexOf(wordTranslation(1)));
        run.movePaddle(target);
        while (run.phase == BrickPhase.bonus) {
          run.advance(const Duration(milliseconds: 12));
        }
        expect(run.caughtCorrect, isTrue);
        // Sliding away during feedback must not drag the celebration with it.
        run.movePaddle(target < 180 ? 310 : 50);
        run.advance(const Duration(milliseconds: 45));
        await draw();
        final first = await _sample(tester, key, target.round());
        run.advance(const Duration(milliseconds: 150));
        await draw();
        final later = await _sample(tester, key, target.round());
        run.advance(const Duration(seconds: 2));
        await draw();
        final empty = await _sample(tester, key, target.round());
        expect(first, isNot(empty), reason: 'the catch should mark its lane');
        expect(later, reduced ? equals(first) : isNot(first));
      });
    }
  }
}
