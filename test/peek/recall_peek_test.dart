@Tags(['peek'])
library;

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/recall/recall_screen.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/bundled_fonts.dart';
import '../support/fake_review_session.dart';
import 'peek_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);
  const words = [
    Word(id: 'es_llave', text: 'llave', translation: 'ключ'),
    Word(id: 'es_mesa', text: 'mesa', translation: 'стол'),
    Word(id: 'es_puerta', text: 'puerta', translation: 'дверь'),
    Word(id: 'es_bolsa', text: 'bolsa', translation: 'сумка'),
  ];
  for (final brightness in Brightness.values) {
    testWidgets('recall a Spanish word in ${brightness.name}', (tester) async {
      tester.view.physicalSize = peekPhysicalSize;
      tester.view.devicePixelRatio = peekDevicePixelRatio;
      addTearDown(tester.view.reset);
      final session = FakeReviewSession([
        for (final word in words) ReviewItem(word: word),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: wordarcadeTheme(
            brightness: brightness,
            platform: TargetPlatform.android,
          ),
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => RecallScreen(
                                    session: session,
                                    vocabulary: words,
                                    seed: 5,
                                    course: StudyCourse.spanishFromRussian,
                                    level: CefrLevel.a1,
                                    onComplete: () {},
                                    onExit: () => Navigator.pop(context),
                                  ),
                            ),
                          ),
                      child: const Text('Открыть'),
                    ),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      await peek(tester, 'recall_prompt_${brightness.name}');
      await tester.tap(find.byKey(const Key('recall.spell')));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byKey(const Key('recall.tiles')),
              matching: find.text('l'),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await peek(tester, 'recall_letters_${brightness.name}');
      await tester.tap(find.byKey(const Key('recall.options')));
      await tester.pumpAndSettle();
      await peek(tester, 'recall_choices_${brightness.name}');
    });
  }
}
