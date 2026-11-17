import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart'
    as falling;
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_views.dart'
    as ninja;
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/bundled_fonts.dart';

// Одно из двух самых длинных английских слов текущего словаря C2 — 19 букв.
const String _word = 'impressionistically';
const Key _fieldKey = Key('active-word-layout.field');

void main() {
  setUpAll(loadBundledFonts);

  for (final isNinja in [false, true]) {
    final game = isNinja ? 'ниндзя-слэш' : 'падающие слова';
    testWidgets('$game: длинное C2-слово целиком на 320 dp при шрифте 2×', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(960, 1704);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final field =
          isNinja
              ? const ninja.NinjaField(word: _word, objects: [], progress: .4)
              : const falling.FallingField(
                text: _word,
                progress: .5,
                fadeProgress: 0,
              );
      await tester.pumpWidget(
        MaterialApp(
          theme: wordarcadeTheme(platform: TargetPlatform.android),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                key: _fieldKey,
                width: 320,
                height: 350,
                child: field,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final text = find.text(_word);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: text, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      final available = tester.getRect(find.byKey(_fieldKey));
      final visibleText = tester.getRect(text);
      expect(visibleText.left, greaterThanOrEqualTo(available.left - .1));
      expect(visibleText.right, lessThanOrEqualTo(available.right + .1));
      expect(visibleText.top, greaterThanOrEqualTo(available.top - .1));
      expect(visibleText.bottom, lessThanOrEqualTo(available.bottom + .1));
    });
  }
}
