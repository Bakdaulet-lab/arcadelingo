import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:arcadelingo/features/games/word_mahjong/word_mahjong_board.dart';
import 'package:arcadelingo/features/games/word_mahjong/word_mahjong_field.dart';
import 'package:arcadelingo/features/recall/recall_screen.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/bundled_fonts.dart';
import '../../support/claw_actions.dart';
import '../../support/fake_review_session.dart';

const _phrase = ReviewItem(
  word: Word(
    id: 'take_notice',
    text: 'take notice',
    translation: 'обратить особое внимание на происходящее',
  ),
);
const _case = ReviewItem(
  word: Word(
    id: 'enquiry',
    text: 'enquiry',
    translation: 'расследование непредвиденного случая',
  ),
);
const _other = ReviewItem(
  word: Word(id: 'home', text: 'home', translation: 'дом'),
);

Future<void> _show(
  WidgetTester tester,
  Widget page, {
  required Brightness brightness,
  double textScale = 2,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 780);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: wordarcadeTheme(brightness: brightness),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: child!,
          ),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

void _wholeWord(RenderParagraph paragraph, String word) {
  final start = paragraph.text.toPlainText().indexOf(word);
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: start + word.length),
  );
  expect(boxes.map((box) => box.top).toSet(), hasLength(1), reason: word);
  for (final box in boxes) {
    expect(
      (Offset.zero & paragraph.size).inflate(1).contains(box.toRect().topLeft),
      isTrue,
    );
    expect(
      (Offset.zero & paragraph.size)
          .inflate(1)
          .contains(box.toRect().bottomRight),
      isTrue,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);

  for (final brightness in Brightness.values) {
    testWidgets(
      'claw groups spelling by word on a narrow phone in $brightness',
      (tester) async {
        final session = FakeReviewSession([_phrase]);
        await _show(
          tester,
          ClawMachineGame(
            session: session,
            onExit: () {},
            onPlayAgain: () {},
            now: tester.binding.clock.now,
            seed: 11,
          ),
          brightness: brightness,
        );
        final slots = find.byKey(ClawKeys.slots);
        double rowOf(int index) =>
            tester
                .getCenter(
                  find.descendant(
                    of: slots,
                    matching: find.byKey(ValueKey((index, false))),
                  ),
                )
                .dy;
        expect(rowOf(0), rowOf(3));
        expect(rowOf(5), rowOf(10), reason: 'NOTICE should stay together');
        expect(rowOf(5), greaterThan(rowOf(0)));

        await spellWithClaw(tester, 'takenotice');
        expect(session.reports.single.outcome.correct, isTrue);
        final result = find.descendant(
          of: find.byKey(ClawKeys.result),
          matching: find.text('TAKE NOTICE'),
        );
        expect(result, findsOneWidget);
        expect(tester.getSize(result).height, greaterThan(30));
        await tester.ensureVisible(find.byKey(ClawKeys.next));
        expect(find.byKey(ClawKeys.next).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'mahjong fits intact long words and still matches in $brightness',
      (tester) async {
        final board = WordMahjongBoard.deal([_case, _other], Random(3));
        final field = find.byKey(WordMahjongKeys.field);
        await _show(
          tester,
          StatefulBuilder(
            builder:
                (context, setState) => Scaffold(
                  body: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      WordMahjongField(
                        key: WordMahjongKeys.field,
                        board: board,
                        enabled: true,
                        wordLanguage: 'en',
                        translationLanguage: 'ru',
                        onTap: (tile) {
                          final pair = board.hint!;
                          if (tile == pair.translation || tile == pair.word) {
                            setState(
                              () => board.match(pair.word, pair.translation),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
          ),
          brightness: brightness,
        );
        final longTile = find.text(_case.word.translation);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: longTile, matching: find.byType(RichText)),
        );
        _wholeWord(paragraph, 'расследование');
        _wholeWord(paragraph, 'непредвиденного');
        for (final tile in board.tiles) {
          final box = tester.getRect(
            find.byKey(WordMahjongKeys.tile(tile.index)),
          );
          expect(box.left, greaterThanOrEqualTo(tester.getRect(field).left));
          expect(box.right, lessThanOrEqualTo(tester.getRect(field).right));
        }

        final pair = board.hint!;
        final target = find.text(pair.translation.label);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(board.contains(pair.word), isFalse);
        expect(board.contains(pair.translation), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('active recall keeps an attainable word on one line', (
    tester,
  ) async {
    await _show(
      tester,
      RecallScreen(
        session: FakeReviewSession([_phrase]),
        course: StudyCourse.englishFromRussian,
        level: CefrLevel.a1,
        vocabulary: [_phrase.word],
        seed: 11,
        onComplete: () {},
        onExit: () {},
      ),
      brightness: Brightness.dark,
    );
    final change = find.byKey(const Key('recall.spell'));
    await tester.ensureVisible(change);
    await tester.tap(change);
    await tester.pumpAndSettle();
    final blanks = find.text(' ');
    expect(blanks, findsNWidgets(10));
    expect(
      tester.getCenter(blanks.at(4)).dy,
      tester.getCenter(blanks.at(9)).dy,
      reason: 'NOTICE should stay together',
    );
    expect(tester.takeException(), isNull);
  });
}
