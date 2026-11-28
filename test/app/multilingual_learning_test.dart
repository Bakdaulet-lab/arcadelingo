import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/ui/arcade_letter_wrap.dart';
import 'package:arcadelingo/ui/word_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the Chinese learning card prints Hanzi and marked pinyin', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WordPanel(
            word: Word(
              id: 'zh_xuexiao',
              text: '学校',
              translation: 'school',
              reading: 'xuéxiào',
            ),
          ),
        ),
      ),
    );
    expect(find.text('学校'), findsOneWidget);
    expect(find.text('xuéxiào'), findsOneWidget);
  });

  testWidgets('Arabic tiles start at the right inside a left-to-right UI', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArcadeLetterWrap(
            spelling: const ['ك', 'ت', 'ا', 'ب'],
            spacing: 6,
            runSpacing: 8,
            textDirection: TextDirection.rtl,
            slot:
                (_, index) =>
                    SizedBox(key: ValueKey(index), width: 32, height: 32),
          ),
        ),
      ),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey(0))).dx,
      greaterThan(tester.getCenter(find.byKey(const ValueKey(3))).dx),
    );
  });
}
