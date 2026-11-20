import 'package:arcadelingo/ui/arcade_answer_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const label = Key('answer');
  for (final correct in [true, false]) {
    testWidgets('ответ $correct читается и принимает ввод во время реакции', (
      tester,
    ) async {
      var taps = 0;
      Future<void> show({bool reduceMotion = false}) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: Center(
              child: ArcadeAnswerFeedback(
                correct: correct,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const SizedBox(key: label, width: 96, height: 48),
                ),
              ),
            ),
          ),
        ),
      );
      final target = find.byKey(label);
      await show();
      final rest = tester.getRect(target);
      await tester.pump(const Duration(milliseconds: 90));
      final moving = tester.getRect(target);
      if (correct) {
        expect(moving.width, greaterThan(rest.width));
        expect(moving.center.dy, lessThan(rest.center.dy));
      } else {
        expect(moving.center.dx, lessThan(rest.center.dx));
        expect(moving.width, closeTo(rest.width, .001));
      }
      await tester.tap(target);
      expect(taps, 1);
      await tester.pumpAndSettle();
      expect(tester.getRect(target), rest);
      await show();
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.getRect(target), rest);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  }
  testWidgets(
    'уменьшение движения останавливает реакцию до следующего ответа',
    (tester) async {
      const child = SizedBox(key: label, width: 96, height: 48);
      Future<void> show(bool reduce, bool correct) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: Center(
              child: ArcadeAnswerFeedback(correct: correct, child: child),
            ),
          ),
        ),
      );
      final target = find.byKey(label);
      await show(true, true);
      final rest = tester.getRect(target);
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.getRect(target), rest);
      await show(false, true);
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.getRect(target), rest);
      await show(false, false);
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.getRect(target).center.dx, lessThan(rest.center.dx));
      await show(true, false);
      expect(tester.getRect(target), rest);
    },
  );
}
