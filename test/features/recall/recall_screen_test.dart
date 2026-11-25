import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/recall/recall_screen.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_review_session.dart';

const _words = [
  Word(id: 'key', text: 'llave', translation: 'ключ'),
  Word(id: 'milk', text: 'leche', translation: 'молоко'),
  Word(id: 'bread', text: 'pan', translation: 'хлеб'),
];

void main() {
  for (final locale in ['ru', 'en', 'es']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'recall, assisted recognition and mistakes in $locale/$brightness',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final session = FakeReviewSession([
            for (final word in _words) ReviewItem(word: word),
          ]);
          var finished = 0;
          var exited = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: wordarcadeTheme(brightness: brightness),
              locale: Locale(locale),
              supportedLocales: const [
                Locale('ru'),
                Locale('en'),
                Locale('es'),
              ],
              localizationsDelegates: const [
                AppStrings.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(1.7)),
                    child: child!,
                  ),
              home: RecallScreen(
                session: session,
                vocabulary: _words,
                course: StudyCourse.spanishFromRussian,
                level: CefrLevel.a1,
                seed: 9,
                onComplete: () => finished++,
                onExit: () => exited++,
              ),
            ),
          );
          await tester.pumpAndSettle();
          Future<void> tap(Finder target) async {
            await tester.ensureVisible(target);
            await tester.tap(target);
            await tester.pumpAndSettle();
          }

          Future<void> button(String id) => tap(find.byKey(Key('recall.$id')));
          final strings = tester.element(find.byType(RecallScreen)).strings;
          expect(find.text(strings.activeRecall), findsOneWidget);
          expect(find.text('ключ'), findsOneWidget);
          expect(find.text('llave'), findsNothing);
          await tester.pump(const Duration(minutes: 2));
          expect(session.reports, isEmpty);
          await button('spell');
          Finder available(String letter) {
            final rack = find.byKey(const Key('recall.tiles'));
            return find
                .descendant(
                  of: rack,
                  matching: find.byWidgetPredicate(
                    (w) =>
                        w is OutlinedButton &&
                        w.onPressed != null &&
                        w.child is Text &&
                        (w.child! as Text).data!.toLowerCase() == letter,
                  ),
                )
                .first;
          }

          await tap(available('v'));
          await button('undo');
          for (final letter in 'llave'.split('')) {
            await tap(available(letter));
          }
          await button('check');
          expect(session.reports.single.outcome.correct, isTrue);
          expect(session.reports.single.outcome.hintsUsed, 0);
          expect(session.reports.single.outcome.isUntimed, isTrue);
          expect(finished, 0);
          await button('next');
          expect(find.text('молоко'), findsOneWidget);
          expect(find.text('leche'), findsNothing);
          await button('options');
          await tap(find.text('leche'));
          expect(session.reports.last.outcome.correct, isTrue);
          expect(session.reports.last.outcome.hintsUsed, 1);
          await button('next');
          expect(find.text('хлеб'), findsOneWidget);
          await button('spell');
          await button('options');
          await tap(find.text('leche'));
          expect(find.text('pan'), findsOneWidget);
          expect(session.reports.last.outcome.correct, isFalse);
          expect(session.reports.last.outcome.selectedAnswer, 'leche');
          expect(session.reports.last.outcome.hintsUsed, 1);
          expect(finished, 1);
          await button('next');
          expect(find.byKey(const Key('recall.summary')), findsOneWidget);
          expect(find.text(strings.recallIndependent), findsOneWidget);
          expect(find.text(strings.recallWithHelp), findsOneWidget);
          expect(find.text(strings.recallMistakes), findsOneWidget);
          expect(session.reports, hasLength(3));
          expect(finished, 1);
          await button('exit');
          expect(exited, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
