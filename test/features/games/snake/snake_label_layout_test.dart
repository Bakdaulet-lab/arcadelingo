import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/leitner_review_session.dart';
import 'package:arcadelingo/features/games/snake/snake_field.dart';
import 'package:arcadelingo/features/games/snake/snake_game.dart';
import 'package:arcadelingo/features/games/snake/snake_run.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/bundled_fonts.dart';

const _words = [
  Word(
    id: 'disculparse',
    text: 'disculparse públicamente ante los afectados',
    translation: 'публично извиниться перед пострадавшими',
  ),
  Word(
    id: 'obedecer',
    text: 'obedecer instrucciones de emergencia',
    translation: 'следовать инструкциям для экстренных ситуаций',
  ),
  Word(
    id: 'independientemente',
    text: 'independientemente',
    translation: 'независимо',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'full apple labels and usable board ($brightness at $scale)',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 800);
          addTearDown(tester.view.reset);
          final session = LeitnerReviewSession.start(
            cards: {},
            items: [ReviewItem(word: _words.first)],
            target: 1,
            now: () => DateTime(2026, 11, 21),
            onCardsChanged: (_) {},
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: wordarcadeTheme(brightness: brightness),
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
              home: SnakeGame(
                session: session,
                vocabulary: _words,
                onPlayAgain: () {},
                onExit: () {},
                continuous: brightness == Brightness.dark,
                seed: 4,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final field = find.byKey(SnakeKeys.field);
          final run = tester.widget<SnakeField>(field).run;
          final rect = tester.getRect(field);
          for (final (index, apple) in run.apples.indexed) {
            final text = find.text(apple.word.text);
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: text, matching: find.byType(RichText)),
            );
            expect(paragraph.textScaler.scale(16), 16 * scale);
            expect(paragraph.text.style!.fontSize, greaterThanOrEqualTo(16));
            final label = tester.getRect(text);
            expect(
              label.overlaps(rect),
              isFalse,
              reason: 'Large labels must leave walkable cells visible',
            );
            final marker = find.byKey(ValueKey('snake.apple.$index'));
            expect(marker, findsOneWidget);
            final unit = rect.width / SnakeRun.size;
            final position = Offset(
              rect.left + (apple.cell.x + .5) * unit,
              rect.top + (apple.cell.y + .5) * unit,
            );
            expect(tester.getRect(marker).contains(position), isTrue);
            for (final word in RegExp(r'\S+').allMatches(apple.word.text)) {
              for (final box in paragraph.getBoxesForSelection(
                TextSelection(baseOffset: word.start, extentOffset: word.end),
              )) {
                expect(
                  (Offset.zero & paragraph.size)
                      .inflate(.2)
                      .contains(box.toRect().bottomRight),
                  isTrue,
                );
              }
            }
          }
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          await tester.drag(field, const Offset(30, 0));
          await tester.pump();
          expect(run.phase, SnakePhase.moving);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
