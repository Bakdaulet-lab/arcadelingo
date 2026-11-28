import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_field.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_run.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/bundled_fonts.dart';
import '../../../support/fake_review_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('whole falling answers at 320dp / $brightness / $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 800);
        addTearDown(tester.view.reset);
        const card = ReviewItem(
          word: Word(
            id: 'relevant',
            text: 'relevant',
            translation: 'непосредственно связанный с вопросом',
          ),
          distractors: [
            'профессионально-технический',
            'supplementary in case of a gap',
          ],
        );
        final run = BrickBreakerRun(FakeReviewSession([card]), Random(4));
        run.launch();
        while (run.phase == BrickPhase.flying) {
          run.advance(const Duration(milliseconds: 8));
        }
        expect(run.phase, BrickPhase.bonus);

        Future<void> display() => tester.pumpWidget(
          MaterialApp(
            theme: wordarcadeTheme(brightness: brightness),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: BrickBreakerField(run: run, onMove: run.movePaddle),
                ),
              ),
            ),
          ),
        );
        await display();
        List<Rect> readAll() {
          final field = tester.getRect(find.byType(BrickBreakerField));
          final rects = <Rect>[];
          for (final answer in run.choices) {
            final text = find.text(answer);
            final rich = find.descendant(
              of: text,
              matching: find.byType(RichText),
            );
            final p = tester.renderObject<RenderParagraph>(rich);
            final size = p.text.style!.fontSize!;
            final a = p.localToGlobal(Offset.zero);
            final b = p.localToGlobal(Offset(0, p.textScaler.scale(size)));
            expect(
              (b - a).distance,
              greaterThanOrEqualTo(14 * scale - .1),
              reason: 'printed font size of $answer',
            );
            // Flutter retains invisible trailing spaces beyond a wrapped line.
            // Check every printed character, including punctuation and accents.
            final boxes = [
              for (final token in RegExp(r'\S+').allMatches(answer))
                ...p.getBoxesForSelection(
                  TextSelection(
                    baseOffset: token.start,
                    extentOffset: token.end,
                  ),
                ),
            ];
            expect(boxes, isNotEmpty);
            for (final box in boxes) {
              for (final corner in [
                box.toRect().topLeft,
                box.toRect().bottomRight,
              ]) {
                expect(
                  field.inflate(.1).contains(p.localToGlobal(corner)),
                  isTrue,
                  reason: 'inside board: $answer',
                );
                expect(
                  (Offset.zero & p.size).inflate(.1).contains(corner),
                  isTrue,
                  reason: 'inside text box: $answer',
                );
              }
            }
            // Every word which fits the field at this scale stays on one line.
            for (final word in RegExp(r'[^\s-]+').allMatches(answer)) {
              final tp = TextPainter(
                text: TextSpan(text: word.group(0), style: p.text.style),
                textDirection: TextDirection.ltr,
                textScaler: p.textScaler,
              )..layout();
              final fits = tp.width <= field.width - 24;
              tp.dispose();
              if (fits) {
                final lines =
                    p
                        .getBoxesForSelection(
                          TextSelection(
                            baseOffset: word.start,
                            extentOffset: word.end,
                          ),
                        )
                        .map((b) => b.top)
                        .toSet();
                expect(
                  lines,
                  hasLength(1),
                  reason: 'split word "${word.group(0)}"',
                );
              }
            }
            rects.add(tester.getRect(rich));
          }
          for (var i = 0; i < rects.length; i++) {
            for (var j = i + 1; j < rects.length; j++) {
              expect(rects[i].overlaps(rects[j]), isFalse);
            }
          }
          return rects;
        }

        final start = readAll();
        final firstY = run.dropY;
        while (run.phase == BrickPhase.bonus && run.dropY < firstY + 100) {
          run.advance(const Duration(milliseconds: 8));
        }
        expect(run.phase, BrickPhase.bonus);
        await display();
        final middle = readAll();
        for (var i = 0; i < start.length; i++) {
          expect(middle[i].top - start[i].top, greaterThan(12));
        }
        final choice = run.choices.indexOf(card.word.translation);
        await tester.tap(find.text(card.word.translation));
        expect(
          run.catchLane,
          choice,
          reason: 'tap lands in the lane of the full-width phrase',
        );
        final fieldAtCatch = tester.getRect(find.byType(BrickBreakerField));
        while (run.phase == BrickPhase.bonus) {
          run.advance(const Duration(milliseconds: 8));
        }
        expect(run.phase, BrickPhase.feedback);
        await display();
        expect(tester.getRect(find.byType(BrickBreakerField)), fieldAtCatch);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
