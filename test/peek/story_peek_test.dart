@Tags(['peek'])
library;

import 'dart:math';

import 'package:arcadelingo/app/story_views.dart';
import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/stories/situation_story.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/bundled_fonts.dart';
import 'peek_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const course = StudyCourse.spanishFromRussian;
  const level = CefrLevel.a1;
  late List<SituationStory> stories;
  setUpAll(() async {
    await loadBundledFonts();
    final seed = await loadSpanishSeed() as Ok<List<ReviewItem>>;
    stories = buildSituationStories(
      course: course,
      level: level,
      courseItems: seed.value,
      random: Random(7),
    );
  });
  for (final brightness in Brightness.values) {
    testWidgets('situation menu and station decision in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = peekPhysicalSize;
      tester.view.devicePixelRatio = peekDevicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: wordarcadeTheme(
            platform: TargetPlatform.android,
            brightness: brightness,
          ),
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => SituationStoriesScreen(
                                course: course,
                                level: level,
                                stories: stories,
                                playStage: (_, _) async => true,
                              ),
                        ),
                      ),
                  child: const Text('Открыть'),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      await peek(tester, 'stories_picker_${brightness.name}');
      await tester.tap(find.byKey(const Key('story.station')));
      await tester.pumpAndSettle();
      for (int stage = 0; stage < 2; stage++) {
        await tester.tap(find.byKey(const Key('story.play')));
        await tester.pumpAndSettle();
      }
      await peek(tester, 'stories_station_${brightness.name}');
    });
  }
}
