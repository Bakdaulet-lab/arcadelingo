import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart'
    as falling;
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_views.dart'
    as ninja;
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// Реальная карточка C2 из words_c2.json.
const String _word = 'counterproductively';
const String _answer = 'в ущерб желаемому результату';
const Key _field = Key('reveal-layout.field');

void main() {
  for (final isNinja in [false, true]) {
    final game = isNinja ? 'ниндзя-слэш' : 'падающие слова';
    testWidgets(
      '$game: длинная пара прокручивается в поле 280×180 при шрифте 2×',
      (tester) async {
        tester.view.physicalSize = const Size(960, 1704);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final pair =
            isNinja
                ? const ninja.RevealPair(word: _word, answer: _answer)
                : const falling.RevealPair(word: _word, answer: _answer);
        await tester.pumpWidget(
          MaterialApp(
            theme: wordarcadeTheme(platform: TargetPlatform.android),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  key: _field,
                  width: 280,
                  height: 180,
                  child: pair,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final field = tester.getRect(find.byKey(_field)).inflate(.1);
        final position =
            tester.state<ScrollableState>(find.byType(Scrollable)).position;
        expect(position.maxScrollExtent, greaterThan(0));
        for (final label in [_word, _answer]) {
          final text = find.text(label);
          expect(text, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: text, matching: find.byType(RichText)),
          );
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason:
                'Пара после ошибки должна показывать слово и перевод целиком',
          );
          final unit =
              paragraph.localToGlobal(const Offset(1, 0)) -
              paragraph.localToGlobal(Offset.zero);
          expect(unit.dx, closeTo(1, .01));
          for (final word in RegExp(r'\S+').allMatches(label)) {
            final boxes = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: word.start, extentOffset: word.end),
            );
            expect(boxes, isNotEmpty);
            for (final box in boxes) {
              final rect = box.toRect();
              final center = paragraph.localToGlobal(rect.center);
              final offset = (position.pixels + center.dy - field.center.dy)
                  .clamp(position.minScrollExtent, position.maxScrollExtent);
              position.jumpTo(offset);
              await tester.pumpAndSettle();
              expect(
                field.contains(paragraph.localToGlobal(rect.topLeft)),
                isTrue,
              );
              expect(
                field.contains(paragraph.localToGlobal(rect.bottomRight)),
                isTrue,
              );
            }
          }
        }
      },
    );
  }
}
