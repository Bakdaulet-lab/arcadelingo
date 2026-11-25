import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _show(
  WidgetTester tester,
  Widget body, {
  String language = 'ru',
}) => tester.pumpWidget(
  MaterialApp(
    theme: wordarcadeTheme(),
    locale: Locale(language),
    supportedLocales: const [Locale('en'), Locale('es'), Locale('ru')],
    localizationsDelegates: const [
      AppStrings.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    home: Scaffold(body: body),
  ),
);

void main() {
  testWidgets(
    'moving sound marker and stationary replay button are independent',
    (tester) async {
      var plays = 0;
      Future<void> show(double progress, bool speaking) async {
        await _show(
          tester,
          ListeningField(
            progress: progress,
            speaking: speaking,
            onReplay: speaking ? null : () => plays++,
          ),
        );
        await tester.pumpAndSettle();
      }

      final marker = find.byKey(FallingWordsKeys.listeningMarker);
      final replay = find.byKey(FallingWordsKeys.listeningReplay);
      await show(0, true);
      expect(find.bySemanticsLabel(RegExp('llave')), findsNothing);
      await show(.1, false);
      final before = tester.getCenter(marker);
      final control = tester.getCenter(replay);
      await show(.7, false);
      expect(tester.getCenter(marker).dy, greaterThan(before.dy + 20));
      expect(tester.getCenter(replay), control);
      await tester.tap(replay);
      expect(plays, 1);
      expect(find.bySemanticsLabel(RegExp('Прослушать снова')), findsOneWidget);
    },
  );

  testWidgets('reveals spelling and meaning with the actual outcome', (
    tester,
  ) async {
    for (final (verdict, label) in [
      (Verdict.correct, 'Верно'),
      (Verdict.wrong, 'Ошибка'),
      (Verdict.timeout, 'Время вышло'),
    ]) {
      await _show(
        tester,
        ListeningReveal(word: 'llave', answer: 'ключ', verdict: verdict),
      );
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
      expect(find.text('llave'), findsOneWidget);
      expect(find.text('ключ'), findsOneWidget);
    }
  });

  testWidgets(
    'local voice errors keep retry and text fallback accessible on a small screen',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 500);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      var retries = 0;
      var usesText = 0;
      for (final (locale, words) in [
        ('ru', 'Испанский голос'),
        ('en', 'Spanish speech'),
        ('es', 'audio en español'),
      ]) {
        await _show(
          tester,
          ListeningAudioError(
            error: SpeechResult.unavailable,
            studyLanguage: 'es',
            onRetry: () => retries++,
            onUseText: () => usesText++,
          ),
          language: locale,
        );
        await tester.pumpAndSettle();
        expect(find.textContaining(words), findsOneWidget);
        for (final key in [
          FallingWordsKeys.listeningRetry,
          FallingWordsKeys.listeningText,
        ]) {
          final button = find.byKey(key);
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
        }
        expect(tester.takeException(), isNull);
      }
      expect(retries, 3);
      expect(usesText, 3);
    },
  );
}
