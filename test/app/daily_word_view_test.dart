import 'dart:async';

import 'package:arcadelingo/app/daily_word_view.dart';
import 'package:arcadelingo/domain/ports/daily_word_store.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/daily_word_fixture.dart';

final input = find.byKey(const Key('dailyWord.input'));
final submit = find.byKey(const Key('dailyWord.submit'));
final share = find.byKey(const Key('dailyWord.share'));

Future<void> open(
  WidgetTester tester,
  MemoryDailyStore store, {
  String locale = 'ru',
  Brightness brightness = Brightness.dark,
  Future<void> Function(String)? onShare,
}) => tester.pumpWidget(
  MaterialApp(
    locale: Locale(locale),
    supportedLocales: const [Locale('ru'), Locale('en'), Locale('es')],
    localizationsDelegates: const [
      AppStrings.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    theme: wordarcadeTheme(brightness: brightness),
    home: DailyWordScreen(
      key: UniqueKey(),
      puzzle: dailyFixture(),
      store: store,
      onShare: onShare ?? (_) async {},
    ),
  ),
);

Future<void> type(WidgetTester tester, String word) async {
  await tester.ensureVisible(input);
  await tester.enterText(input, word);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('six rows, validation, saved win and spoiler-free share', (
    tester,
  ) async {
    final store = MemoryDailyStore();
    String? payload;
    Future<void> capture(String text) async => payload = text;
    await open(tester, store, onShare: capture);
    await tester.pumpAndSettle();
    expect(find.text('пляж'), findsOneWidget);
    expect(find.text('playa'), findsNothing);
    expect(share, findsNothing);
    for (var row = 0; row < 6; row++) {
      for (var col = 0; col < 5; col++) {
        expect(
          find.byKey(ValueKey('dailyWord.cell.$row.$col')),
          findsOneWidget,
        );
      }
    }
    await type(tester, 'zzzzz');
    expect(store.writes, 0);
    await type(tester, 'plaza');
    expect(store.record!.guesses, ['plaza']);
    final cell = find.byKey(const ValueKey('dailyWord.cell.0.0'));
    expect(tester.getSemantics(cell).label, contains('На месте'));
    await type(tester, 'plaza');
    expect(store.writes, 1);
    await type(tester, 'playa');
    expect(store.record!.finished, isTrue);
    await open(tester, store, onShare: capture);
    await tester.pumpAndSettle();
    expect(input, findsNothing);
    expect(find.text('playa'), findsOneWidget);
    await tester.ensureVisible(share);
    await tester.tap(share);
    await tester.pump();
    expect(payload, contains('2/6'));
    expect(payload, contains('🟩'));
    for (final secret in ['playa', 'пляж', 'plaza']) {
      expect(payload!.toLowerCase(), isNot(contains(secret)));
    }
  });

  testWidgets(
    'Spanish letters insert at the caret; failed save can be retried once',
    (tester) async {
      final store = MemoryDailyStore()..result = DailyWordSaveResult.failed;
      await open(tester, store);
      await tester.pumpAndSettle();
      await tester.ensureVisible(input);
      await tester.enterText(input, 'baos');
      final field = tester.widget<TextField>(input);
      field.controller!.selection = const TextSelection.collapsed(offset: 2);
      final enye = find.byKey(const Key('dailyWord.accent.ñ'));
      await tester.ensureVisible(enye);
      await tester.tap(enye);
      await tester.pump();
      expect(field.controller!.text, 'baños');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(store.record, isNull);
      expect(field.controller!.text, 'baños');
      store.result = DailyWordSaveResult.saved;
      store.gate = Completer<void>();
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      await tester.tap(submit);
      expect(store.writes, 2);
      store.gate!.complete();
      await tester.pumpAndSettle();
      expect(store.record!.guesses, ['baños']);
    },
  );

  testWidgets('losing attempt reveals answer, restore and share the loss', (
    tester,
  ) async {
    final store = MemoryDailyStore(
      record: DailyWordRecord(
        targetId: 'playa',
        guesses: ['plaza', 'baños', 'calor', 'campo', 'carta'],
        finished: false,
      ),
    );
    String? payload;
    await open(
      tester,
      store,
      locale: 'en',
      onShare: (text) async => payload = text,
    );
    await tester.pumpAndSettle();
    await type(tester, 'banco');
    expect(store.record!.finished, isTrue);
    expect(find.text('playa'), findsOneWidget);
    expect(input, findsNothing);
    await tester.ensureVisible(share);
    await tester.tap(share);
    await tester.pump();
    expect(payload, contains('X/6'));
    expect(payload, isNot(contains('playa')));
  });

  testWidgets('write conflict restores winner and rejects stale target', (
    tester,
  ) async {
    final store = MemoryDailyStore();
    await open(tester, store);
    await tester.pumpAndSettle();
    store.result = DailyWordSaveResult.conflict;
    store.record = DailyWordRecord(
      targetId: 'playa',
      guesses: ['playa'],
      finished: true,
    );
    await type(tester, 'plaza');
    expect(share, findsOneWidget);
    store.record = DailyWordRecord(
      targetId: 'other',
      guesses: ['playa'],
      finished: true,
    );
    await open(tester, store);
    await tester.pumpAndSettle();
    expect(find.text('playa'), findsNothing);
    expect(share, findsNothing);
    expect(input, findsNothing);
  });

  for (final locale in ['ru', 'en', 'es']) {
    testWidgets('narrow phone with keyboard, $locale interface', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 245);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await open(
        tester,
        MemoryDailyStore(),
        locale: locale,
        brightness: Brightness.light,
      );
      await tester.pumpAndSettle();
      final title =
          {
            'ru': 'Слово дня',
            'en': 'Word of the day',
            'es': 'Palabra del día',
          }[locale]!;
      expect(find.text(title), findsOneWidget);
      await type(tester, 'playa');
      await tester.ensureVisible(share);
      expect(tester.takeException(), isNull);
      expect(share.hitTestable(), findsOneWidget);
    });
  }
}
