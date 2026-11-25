import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_game.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_views.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_trajectory.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/bundled_fonts.dart';
import '../../../support/fake_review_session.dart';

const _options = [
  'профессионально-технический',
  'непосредственно связанный с вопросом',
  'desafortunadamente',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);

  test('the arc slows smoothly through its apex without stopping', () {
    Offset at(double t) =>
        wavePositions(count: 3, t: t, width: 360, height: 600).first;
    final nearTop = at(.5).dx - at(.49).dx;
    final approach = at(.21).dx - at(.2).dx;
    expect(nearTop, inExclusiveRange(approach * .35, approach * .8));
    expect(at(.4).dy - at(.5).dy, lessThan(10));
    expect(at(.6).dy, closeTo(at(.4).dy, 1e-8));
  });

  for (final brightness in Brightness.values) {
    testWidgets('whole words on narrow phone, ${brightness.name}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 620);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: wordarcadeTheme(brightness: brightness),
          home: Scaffold(
            body: NinjaField(
              word: 'vocational',
              objects: [
                for (final label in _options)
                  (label: label, state: ObjectState.idle),
              ],
              progress: .5,
            ),
          ),
        ),
      );
      final rects = <Rect>[];
      for (var i = 0; i < _options.length; i++) {
        final target = find.byKey(NinjaKeys.objectAt(i));
        expect(
          find.descendant(of: target, matching: find.text(_options[i])),
          findsOneWidget,
        );
        final shape = tester.getRect(target);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: target, matching: find.byType(RichText)),
        );
        final displayed = paragraph.text.toPlainText(
          includeSemanticsLabels: false,
        );
        expect(displayed, _options[i]);
        for (final word in RegExp(r'\S+').allMatches(displayed)) {
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: word.start, extentOffset: word.end),
          );
          expect(boxes, hasLength(1), reason: word.group(0));
          final top = paragraph.localToGlobal(boxes.single.toRect().topLeft);
          final bottom = paragraph.localToGlobal(
            boxes.single.toRect().bottomRight,
          );
          expect(shape.contains(top), isTrue);
          expect(shape.contains(bottom), isTrue);
          expect(bottom.dy - top.dy, greaterThan(8), reason: word.group(0));
        }
        expect(shape.left, greaterThanOrEqualTo(0));
        expect(shape.right, lessThanOrEqualTo(320));
        expect(rects.any(shape.overlaps), isFalse);
        rects.add(shape);
      }
    });
  }

  testWidgets('a slice through the widened end of a long answer scores', (
    tester,
  ) async {
    final session = FakeReviewSession([
      const ReviewItem(
        word: Word(
          id: 'v',
          text: 'vocational',
          translation: 'профессионально-технический',
        ),
        distractors: [
          'desafortunadamente',
          'непосредственно связанный с вопросом',
        ],
      ),
    ]);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 700);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: wordarcadeTheme(),
        home: NinjaSlashGame(
          session: session,
          seed: 3,
          onExit: () {},
          onPlayAgain: () {},
        ),
      ),
    );
    await tester.pump(NinjaRun.windUpTime);
    await tester.pump(const Duration(milliseconds: 1750));
    final field = tester.widget<NinjaField>(find.byType(NinjaField));
    final correct = field.objects.indexWhere((o) => o.label == _options.first);
    final rect = tester.getRect(find.byKey(NinjaKeys.objectAt(correct)));
    expect(rect.width, greaterThan(110));
    final start = rect.centerRight - const Offset(8, 12);
    await tester.dragFrom(start, const Offset(0, 24));
    expect(session.answered, 1);
    expect(session.reports.single.outcome.correct, isTrue);
  });
}
