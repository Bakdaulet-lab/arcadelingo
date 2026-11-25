@Tags(['peek'])
library;

import 'package:arcadelingo/app/confused_words_view.dart';
import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_answer_log.dart';
import 'peek_harness.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Confused pairs and their practice in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = peekPhysicalSize;
      tester.view.devicePixelRatio = peekDevicePixelRatio;
      addTearDown(tester.view.reset);
      const words = [
        Word(id: 'traer', text: 'traer', translation: 'приносить'),
        Word(id: 'tomar', text: 'tomar', translation: 'брать'),
      ];
      final log = InMemoryAnswerLog();
      for (final word in words) {
        final other = words.firstWhere((other) => other != word);
        final at = DateTime.utc(2026, 11, 25, 12);
        log.records.add(
          AnswerRecord(
            wordId: word.id,
            at: at,
            localDay: StreakDay.of(at),
            correct: false,
            grade: ReviewGrade.again,
            timeLimit: const Duration(seconds: 4),
            responseTime: const Duration(seconds: 1),
            hintsUsed: 0,
            selectedAnswer: other.translation,
            gameId: 'ninja_slash',
            sessionId: 'example',
          ),
        );
      }
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
                                  (_) => ConfusedWordsScreen(
                                    course: StudyCourse.spanishFromRussian,
                                    level: CefrLevel.a1,
                                    vocabulary: words,
                                    answers: log,
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
      await peek(tester, 'confused_pairs_${brightness.name}');
      await tester.tap(find.text('Разобрать пару'));
      await tester.pumpAndSettle();
      await peek(tester, 'confusion_practice_${brightness.name}');
    });
  }
}
