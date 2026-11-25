import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/bundled_fonts.dart';

const _phrase = 'непосредственно связанный с вопросом';
const _prompt = 'declare a state of emergency';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);

  for (final appearance in Brightness.values) {
    testWidgets('a long falling word wraps without shrinking in $appearance', (
      tester,
    ) async {
      await tester.pumpWidget(
        _phone(
          appearance,
          const SizedBox(
            width: 320,
            height: 300,
            child: FallingField(text: _prompt, progress: .85, fadeProgress: 0),
          ),
        ),
      );
      final label = _paragraph(tester, _prompt);
      expect(_scale(label), moreOrLessEquals(1));
      expect(_lineCount(label, _prompt), greaterThan(1));
    });

    testWidgets('a long answer opens a full-height tap target in $appearance', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _phone(
          appearance,
          SizedBox(
            width: 288,
            child: AnswerButton(
              label: _phrase,
              state: AnswerState.idle,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      final label = _paragraph(tester, _phrase);
      expect(_scale(label), moreOrLessEquals(1));
      expect(_lineCount(label, _phrase), greaterThan(2));
      await tester.tap(find.text(_phrase));
      expect(taps, 1);
    });
  }
}

Widget _phone(Brightness appearance, Widget child) => MaterialApp(
  theme: wordarcadeTheme(brightness: appearance),
  home: MediaQuery(
    data: const MediaQueryData(textScaler: TextScaler.linear(2)),
    child: Scaffold(body: Center(child: child)),
  ),
);

RenderParagraph _paragraph(WidgetTester tester, String value) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(value), matching: find.byType(RichText)),
    );

int _lineCount(RenderParagraph paragraph, String text) =>
    paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.length),
        )
        .map((box) => box.top)
        .toSet()
        .length;

double _scale(RenderParagraph paragraph) =>
    (paragraph.localToGlobal(const Offset(1, 0)) -
            paragraph.localToGlobal(Offset.zero))
        .distance;
