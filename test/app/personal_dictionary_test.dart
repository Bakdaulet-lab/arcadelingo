import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/data/dictionary/favorites_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bundled_fonts.dart';
import '../support/fake_word_speech.dart';
import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';

const _words = [
  Word(
    id: 'climate',
    text: 'climate',
    translation: 'климат',
    level: CefrLevel.b1,
    example: 'The climate is changing.',
  ),
  Word(
    id: 'journey',
    text: 'journey',
    translation: 'путешествие',
    level: CefrLevel.b1,
  ),
  Word(
    id: 'duty',
    text: 'duty',
    translation: 'обязанность',
    level: CefrLevel.b1,
  ),
  Word(id: 'sun', text: 'sun', translation: 'солнце'),
];

final _date = DateTime(2026, 11, 17);

AnswerRecord _answer(
  String wordId, {
  bool correct = false,
  String game = 'ninja_slash',
}) => AnswerRecord(
  wordId: wordId,
  at: _date,
  localDay: StreakDay.of(_date),
  grade: correct ? ReviewGrade.good : ReviewGrade.again,
  correct: correct,
  responseTime: const Duration(seconds: 1),
  timeLimit: const Duration(seconds: 3),
  hintsUsed: 0,
  gameId: game,
  sessionId: 'test',
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, {String level = 'B1'}) async {
  await _tap(tester, find.text(level));
  await _tap(tester, find.byKey(AppKeys.progress));
  await _tap(tester, find.text('Личный словарь'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'словарь выбранного уровня, история обеих игр и избранное после перезапуска',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final log =
          InMemoryAnswerLog()
            ..records.addAll([
              _answer('sun'),
              _answer('journey', correct: true),
              _answer('climate'),
              _answer('climate', game: 'falling_words'),
            ]);
      final speech = FakeWordSpeech();
      final cards = InMemoryCardStore();
      final streaks = InMemoryStreakStore();
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      Future<void> launch(SharedPreferences currentPrefs) async {
        await tester.pumpWidget(
          WordarcadeApp(
            ports: AppPorts(
              cards: cards,
              streaks: streaks,
              answers: log,
              favorites: FavoritesPrefsStore(currentPrefs),
              speech: speech,
            ),
            seed: Ok([for (final word in _words) ReviewItem(word: word)]),
            now: () => _date,
          ),
        );
        await tester.pumpAndSettle();
      }

      await launch(prefs);
      await _open(tester);
      expect(find.text('climate'), findsOneWidget);
      expect(find.text('journey'), findsOneWidget);
      expect(find.text('duty'), findsNothing);
      expect(find.text('sun'), findsNothing);

      await _tap(tester, find.text('Часто ошибаюсь'));
      expect(find.text('climate'), findsOneWidget);
      expect(find.text('journey'), findsNothing);
      await _tap(tester, find.text('climate'));
      expect(find.text('The climate is changing.'), findsOneWidget);
      expect(find.textContaining('Падающие слова'), findsOneWidget);
      expect(find.textContaining('Ниндзя-слэш'), findsOneWidget);
      await _tap(tester, find.text('Послушать'));
      expect(speech.spoken, ['climate']);
      await _tap(tester, find.text('В избранное'));
      expect(find.text('Убрать из избранного'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(speech.stopCalls, greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
      await prefs.reload();
      await launch(prefs);
      await _open(tester);
      await _tap(tester, find.text('Избранное'));
      expect(find.text('climate'), findsOneWidget);
      expect(find.text('journey'), findsNothing);

      await _tap(tester, find.text('climate'));
      await _tap(tester, find.text('Убрать из избранного'));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('В избранном пока пусто'), findsOneWidget);
      expect(log.records, hasLength(4));
      expect(cards.saves, isEmpty);
      expect(streaks.saves, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('до первой партии словарь открывается из пустого прогресса', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 1704);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      WordarcadeApp(
        ports: AppPorts(
          cards: InMemoryCardStore(),
          streaks: InMemoryStreakStore(),
          favorites: FavoritesPrefsStore(await SharedPreferences.getInstance()),
        ),
        seed: Ok([for (final word in _words) ReviewItem(word: word)]),
        now: () => _date,
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester, level: 'A1');
    expect(find.text('Пока нет встреченных слов'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
