import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/settings_view.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_stores.dart';

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('theme applies immediately and survives rebuilding the app', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'reminder_settings':
          '{"version":2,"enabled":false,"hour":19,"minute":20,"soundOn":false,"interfaceLanguage":"en"}',
    });
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsPrefsStore(prefs);
    final ports = AppPorts(
      cards: InMemoryCardStore(),
      streaks: InMemoryStreakStore(),
      settings: settings,
    );

    WordarcadeApp app() => WordarcadeApp(
      ports: ports,
      seed: const Ok([
        ReviewItem(
          word: Word(id: 'apple', text: 'apple', translation: 'яблоко'),
        ),
      ]),
    );

    Brightness brightness(Finder surface) =>
        Theme.of(tester.element(surface)).brightness;

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(brightness(find.byType(PlayView)), Brightness.dark);

    await _tap(tester, AppKeys.settings);
    await _tap(tester, SettingsKeys.theme);
    await _tap(tester, const ValueKey('settings.theme.light'));
    expect(brightness(find.byKey(SettingsKeys.view)), Brightness.light);
    expect(find.text('Light'), findsOneWidget);
    expect(prefs.getString('reminder_settings'), contains('"theme":"light"'));
    expect(prefs.getString('reminder_settings'), contains('"hour":19'));
    expect(prefs.getString('reminder_settings'), contains('"soundOn":false'));

    await tester.pumpWidget(const SizedBox());
    await prefs.reload();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(brightness(find.byType(PlayView)), Brightness.light);
    expect(find.text('Choose a game'), findsOneWidget);

    await _tap(tester, AppKeys.settings);
    await _tap(tester, SettingsKeys.theme);
    await _tap(tester, const ValueKey('settings.theme.dark'));
    expect(brightness(find.byKey(SettingsKeys.view)), Brightness.dark);
    expect(prefs.getString('reminder_settings'), contains('"theme":"dark"'));
  });
}
