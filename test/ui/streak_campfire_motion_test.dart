import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/ui/home_ritual_card.dart';
import 'package:arcadelingo/ui/streak_card.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ritual_views.dart';

Future<void> _show(
  WidgetTester tester, {
  bool compact = true,
  Brightness brightness = Brightness.dark,
  required int days,
  int lastOffset = 0,
  bool reduceMotion = false,
  bool visible = true,
}) {
  final ritual = ritualView(days: days, lastOffset: lastOffset);
  return tester.pumpWidget(
    MaterialApp(
      theme: wordarcadeTheme(brightness: brightness),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: TickerMode(
            enabled: visible,
            child: Center(
              child:
                  compact
                      ? HomeRitualCard(ritual: ritual)
                      : StreakCard(ritual: ritual),
            ),
          ),
        ),
      ),
    ),
  );
}

double _intensity(WidgetTester tester) {
  final fire = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is FlamePainter,
    ),
  );
  return (fire.painter! as FlamePainter).intensity;
}

void main() {
  for (final brightness in Brightness.values) {
    for (final compact in [false, true]) {
      testWidgets(
        'new day lights the campfire once ($brightness, compact $compact)',
        (tester) async {
          Future<void> show(int days, {int lastOffset = 0}) => _show(
            tester,
            days: days,
            lastOffset: lastOffset,
            brightness: brightness,
            compact: compact,
          );
          await show(6, lastOffset: 1);
          await tester.pump(const Duration(milliseconds: 216));
          expect(_intensity(tester), 0);
          await show(7);
          await tester.pump(const Duration(milliseconds: 216));
          expect(_intensity(tester), closeTo(1, .01));
          await show(7);
          await tester.pump(const Duration(milliseconds: 350));
          expect(_intensity(tester), inExclusiveRange(0, .5));
          await tester.pumpAndSettle();
          expect(_intensity(tester), 0);
          await show(7);
          await tester.pump(const Duration(milliseconds: 216));
          expect(_intensity(tester), 0);
        },
      );
    }
  }

  testWidgets('opening a saved streak is quiet, including the first frame', (
    tester,
  ) async {
    await _show(tester, days: 7);
    expect(_intensity(tester), 0);
    await tester.pump(const Duration(milliseconds: 216));
    expect(_intensity(tester), 0);
  });

  testWidgets('switching courses shows its saved streak at rest', (
    tester,
  ) async {
    Future<void> show(StudyCourse course, int days) => tester.pumpWidget(
      MaterialApp(
        theme: wordarcadeTheme(),
        home: PlayView(
          course: course,
          ritual: ritualView(days: days),
          onPlay: () {},
          onProgress: () {},
          onSettings: () {},
          onSources: () {},
        ),
      ),
    );
    await show(StudyCourse.englishFromRussian, 1);
    await show(StudyCourse.spanishFromRussian, 7);
    await tester.pump(const Duration(milliseconds: 216));
    expect(_intensity(tester), 0);
  });

  testWidgets('a day gained on a covered screen waits until reveal', (
    tester,
  ) async {
    await _show(tester, days: 6, lastOffset: 1, visible: false);
    await _show(tester, days: 7, visible: false);
    await tester.pump(const Duration(seconds: 2));
    expect(_intensity(tester), 0);
    await _show(tester, days: 7);
    await tester.pump(const Duration(milliseconds: 216));
    expect(_intensity(tester), closeTo(1, .01));
    await _show(tester, days: 7, visible: false);
    await _show(tester, days: 7);
    await tester.pump(const Duration(milliseconds: 216));
    expect(_intensity(tester), 0);
  });

  testWidgets('backgrounding settles a flare and prevents a stale replay', (
    tester,
  ) async {
    await _show(tester, days: 6, lastOffset: 1);
    await _show(tester, days: 7);
    await tester.pump(const Duration(milliseconds: 216));
    expect(_intensity(tester), greaterThan(.9));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(_intensity(tester), 0);
    await _show(tester, days: 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 216));
    expect(_intensity(tester), 0);
  });

  testWidgets('reduced motion clears a running or pending accent', (
    tester,
  ) async {
    await _show(tester, days: 6, lastOffset: 1);
    await _show(tester, days: 7);
    await tester.pump(const Duration(milliseconds: 216));
    expect(_intensity(tester), greaterThan(.9));
    await _show(tester, days: 7, reduceMotion: true);
    expect(_intensity(tester), 0);
    await _show(tester, days: 8, reduceMotion: true);
    await _show(tester, days: 8);
    await tester.pump(const Duration(milliseconds: 216));
    expect(_intensity(tester), 0);
  });
}
