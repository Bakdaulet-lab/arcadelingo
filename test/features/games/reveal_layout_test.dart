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
    testWidgets('$game: длинная пара целиком в поле 280×180 при шрифте 2×', (
      tester,
    ) async {
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
      final field = tester.getRect(find.byKey(_field));
      for (final label in [_word, _answer]) {
        final text = find.text(label);
        expect(text, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: text, matching: find.byType(RichText)),
        );
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: 'Пара после ошибки должна показывать слово и перевод целиком',
        );
        final rect = tester.getRect(text);
        expect(rect.left, greaterThanOrEqualTo(field.left - .1));
        expect(rect.right, lessThanOrEqualTo(field.right + .1));
        expect(rect.top, greaterThanOrEqualTo(field.top - .1));
        expect(rect.bottom, lessThanOrEqualTo(field.bottom + .1));
      }
    });
  }
}
