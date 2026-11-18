@Tags(['peek'])
library;

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/settings_view.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_stores.dart';
import '../support/ritual_views.dart';
import 'peek_harness.dart';

const _fish = ReviewItem(
  word: Word(id: 'fish', text: 'fish', translation: 'рыба'),
  distractors: ['краб', 'улитка', 'кит'],
);

Future<void> _open(
  WidgetTester tester,
  String tag, {
  double textScale = 1,
  double height = 780,
}) async {
  SharedPreferences.setMockInitialValues({
    'reminder_settings':
        '{"version":2,"enabled":false,"hour":20,"minute":0,"interfaceLanguage":"$tag"}',
  });
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = Size(
    peekPhysicalSize.width,
    height * peekDevicePixelRatio,
  );
  tester.view.devicePixelRatio = peekDevicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    WordarcadeApp(
      ports: AppPorts(
        cards: InMemoryCardStore(),
        streaks: InMemoryStreakStore(),
        settings: SettingsPrefsStore(prefs),
      ),
      seed: const Ok([_fish]),
      now: () => DateTime(ritualToday.year, ritualToday.month, ritualToday.day),
    ),
  );
  await tester.runAsync(() async {
    final context = tester.element(find.byType(PlayView));
    await Future.wait([
      for (final path in [
        'falling-words.png',
        'ninja.png',
        'claw-machine.webp',
      ])
        precacheImage(
          ResizeImage(AssetImage('assets/images/home/$path'), width: 1200),
          context,
        ),
    ]);
  });
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final tag in ['ru', 'en']) {
    testWidgets('домашний экран, курс и настройки $tag', (tester) async {
      await _open(tester, tag);
      await peek(tester, 'localized_home_$tag');
      await _tap(tester, find.byKey(AppKeys.course));
      await peek(tester, 'localized_course_$tag');
      Navigator.of(tester.element(find.byType(SimpleDialog))).pop();
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(AppKeys.settings));
      await peek(tester, 'localized_settings_$tag');
      await _tap(tester, find.byKey(SettingsKeys.language));
      await peek(tester, 'localized_language_$tag');
    });
  }

  for (final tag in ['ru', 'en']) {
    testWidgets('компактные настройки $tag при шрифте 2×', (tester) async {
      await _open(tester, tag, textScale: 2, height: 640);
      await _tap(tester, find.byKey(AppKeys.settings));
      await peek(tester, 'localized_settings_${tag}_text2x');
    });
  }

  for (final (name, id) in [
    ('Falling Words', 'falling'),
    ('Ninja Slash', 'ninja'),
    ('Claw Machine', 'claw'),
  ]) {
    testWidgets(name, (tester) async {
      await _open(tester, 'en');
      await _tap(tester, find.text(name));
      await tester.tap(find.byKey(AppKeys.play));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      if (id != 'claw') {
        await tester.pump(
          id == 'ninja' ? NinjaRun.windUpTime : FallingWordsRun.windUpTime,
        );
        await tester.pump(const Duration(milliseconds: 600));
      }
      await peek(tester, 'localized_game_$id');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
