import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_game.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_views.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/bundled_fonts.dart';
import '../../../support/fake_review_session.dart';

const _options = [
  'профессионально-технический',
  'непосредственно связанный с вопросом',
  'supplementary in case of a gap',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);
  testWidgets('the compact layout waits for a readable answer', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 380);
    addTearDown(tester.view.reset);
    final session = FakeReviewSession([
      ReviewItem(
        word: Word(
          id: 'pertinent',
          text: 'declare a state of emergency',
          translation: _options[1],
        ),
        distractors: [_options[0], _options[2]],
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: wordarcadeTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: NinjaSlashGame(
            session: session,
            seed: 3,
            onExit: () {},
            onPlayAgain: () {},
          ),
        ),
      ),
    );
    await tester.pump(NinjaRun.windUpTime);
    await tester.pump(const Duration(seconds: 12));
    expect(session.reports, isEmpty);
    final answer = find.text(_options[1]);
    await tester.ensureVisible(answer);
    await tester.pumpAndSettle();
    await tester.tap(answer);
    await tester.pump();
    expect(session.reports.single.outcome.correct, isTrue);
    expect(session.reports.single.outcome.selectedAnswer, _options[1]);
    expect(session.reports.single.outcome.timeLimit, Duration.zero);
    expect(tester.takeException(), isNull);
  });
  for (final appearance in Brightness.values) {
    testWidgets(
      'full translations remain readable at the apex in $appearance',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 620);
        addTearDown(tester.view.reset);
        const prompt = 'declare a state of emergency';
        await tester.pumpWidget(
          MaterialApp(
            theme: wordarcadeTheme(brightness: appearance),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: NinjaField(
                  word: prompt,
                  objects: [
                    for (final label in _options)
                      (label: label, state: ObjectState.idle),
                  ],
                  progress: .5,
                ),
              ),
            ),
          ),
        );

        final printedPrompt = tester.getRect(find.byKey(NinjaKeys.word));
        final bounds = Offset.zero & const Size(320, 620);
        final rects = [printedPrompt];
        for (final (i, option) in _options.indexed) {
          final target = find.byKey(NinjaKeys.objectAt(i));
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: target, matching: find.byType(RichText)),
          );
          final native =
              (paragraph.localToGlobal(const Offset(1, 0)) -
                      paragraph.localToGlobal(Offset.zero))
                  .distance;
          expect(native, moreOrLessEquals(1), reason: option);
          final shape = tester.getRect(target);
          expect(bounds.inflate(.05).contains(shape.topLeft), isTrue);
          expect(bounds.inflate(.05).contains(shape.bottomRight), isTrue);
          expect(rects.any(shape.overlaps), isFalse);
          rects.add(shape);
          for (final token in RegExp(r'\S+').allMatches(option)) {
            final boxes = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: token.start, extentOffset: token.end),
            );
            expect(boxes, isNotEmpty, reason: token.group(0));
            for (final box in boxes) {
              expect(
                shape
                    .inflate(.05)
                    .contains(paragraph.localToGlobal(box.toRect().topLeft)),
                isTrue,
              );
              expect(
                shape
                    .inflate(.05)
                    .contains(
                      paragraph.localToGlobal(box.toRect().bottomRight),
                    ),
                isTrue,
              );
            }
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
