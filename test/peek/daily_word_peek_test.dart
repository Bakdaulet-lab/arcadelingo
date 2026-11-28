@Tags(['peek'])
library;

import 'package:arcadelingo/app/daily_word_view.dart';
import 'package:arcadelingo/domain/ports/daily_word_store.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/bundled_fonts.dart';
import '../support/daily_word_fixture.dart';
import 'peek_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);
  for (final brightness in Brightness.values) {
    testWidgets('daily word in ${brightness.name}', (tester) async {
      tester.view.physicalSize = peekPhysicalSize;
      tester.view.devicePixelRatio = peekDevicePixelRatio;
      addTearDown(tester.view.reset);
      final store = MemoryDailyStore(
        record: DailyWordRecord(
          targetId: 'playa',
          guesses: ['calor', 'plaza'],
          finished: false,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru')],
          localizationsDelegates: const [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: wordarcadeTheme(
            brightness: brightness,
            platform: TargetPlatform.android,
          ),
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed:
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder:
                                (_) => DailyWordScreen(
                                  puzzle: dailyFixture(),
                                  store: store,
                                  onShare: (_) async {},
                                ),
                          ),
                        ),
                    child: const Text('Открыть'),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      await peek(tester, 'daily_word_board_${brightness.name}');
      final input = find.byKey(const Key('dailyWord.input'));
      await tester.ensureVisible(input);
      await tester.enterText(input, 'playa');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await peek(tester, 'daily_word_result_${brightness.name}');
    });
  }
}
