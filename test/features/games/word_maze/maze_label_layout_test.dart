import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/word_maze/maze_field.dart';
import 'package:arcadelingo/features/games/word_maze/word_maze_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/bundled_fonts.dart';
import '../../../support/fake_review_session.dart';
import '../../../support/maze_actions.dart';

const _words = [
  Word(
    id: 'contingencia',
    text: 'contingencia presupuestaria',
    translation: 'непредвиденное обстоятельство',
  ),
  Word(id: 'llave', text: 'llave', translation: 'ключ'),
  Word(id: 'mesa', text: 'mesa', translation: 'стол'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);
  for (final brightness in Brightness.values) {
    testWidgets('whole words identify the numbered gates in $brightness', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(tester.view.reset);
      final session = FakeReviewSession(const [ReviewItem(word: _words.first)]);
      await tester.pumpWidget(
        MaterialApp(
          theme: wordarcadeTheme(brightness: brightness),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
          home: WordMazeGame(
            session: session,
            vocabulary: _words,
            onPlayAgain: () {},
            onExit: () {},
            seed: 9,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gates = mazeGateWords(tester);
      final rows = <Rect>[];
      for (var index = 0; index < gates.length; index++) {
        final label = find.byKey(MazeKeys.gate(index));
        final p = tester.renderObject<RenderParagraph>(
          find.descendant(of: label, matching: find.byType(RichText)),
        );
        expect(p.textScaler.scale(16), 32);
        expect(p.text.style!.fontSize, greaterThanOrEqualTo(16));
        final rect = tester.getRect(label);
        expect(rows.every((other) => other.bottom <= rect.top), isTrue);
        rows.add(rect);
        final badge = find.byWidgetPredicate(
          (widget) => widget is MazeGateBadge && widget.index == index,
        );
        expect(tester.getRect(badge).right, lessThan(rect.left));
      }
      final index = gates.indexOf(_words.first.text);
      expect(index, isNonNegative);
      await tester.ensureVisible(find.byKey(MazeKeys.field));
      await enterMazeGate(tester, index);
      expect(session.reports.single.outcome.correct, isTrue);
      expect(session.reports.single.item.word.id, _words.first.id);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
