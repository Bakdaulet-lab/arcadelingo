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

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';

const _words = [
  Word(id: 'bring', text: 'bring', translation: 'приносить'),
  Word(id: 'take', text: 'take', translation: 'брать'),
  Word(id: 'trip', text: 'trip', translation: 'поездка', level: CefrLevel.b1),
];

final _today = DateTime(2026, 11, 25);

AnswerRecord _miss(String word, String selected) => AnswerRecord(
  wordId: word,
  at: _today,
  localDay: StreakDay.of(_today),
  correct: false,
  grade: ReviewGrade.again,
  timeLimit: const Duration(seconds: 5),
  responseTime: const Duration(seconds: 1),
  hintsUsed: 0,
  selectedAnswer: selected,
  gameId: 'falling_words',
  sessionId: 'round',
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('из словаря можно разобрать обе стороны повторяющейся ошибки', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 1800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final log =
        InMemoryAnswerLog()
          ..records.addAll([
            _miss('bring', 'брать'),
            _miss('take', 'приносить'),
            _miss('bring', 'поездка'),
            _miss('bring', 'поездка'),
          ]);
    await tester.pumpWidget(
      WordarcadeApp(
        ports: AppPorts(
          cards: InMemoryCardStore(),
          streaks: InMemoryStreakStore(),
          favorites: FavoritesPrefsStore(await SharedPreferences.getInstance()),
          answers: log,
        ),
        seed: Ok([for (final word in _words) ReviewItem(word: word)]),
        now: () => _today,
      ),
    );
    await tester.pumpAndSettle();
    Future<void> openPairs() async {
      await _tap(tester, find.byKey(AppKeys.progress));
      await _tap(tester, find.text('Личный словарь'));
      await _tap(tester, find.text('Слова, которые я путаю'));
    }

    await openPairs();
    expect(find.textContaining('bring'), findsOneWidget);
    expect(find.textContaining('take'), findsOneWidget);
    expect(find.textContaining('trip'), findsNothing);
    await _tap(tester, find.text('Разобрать пару'));
    final asked = <String>{};
    for (var i = 0; i < 2; i++) {
      final isBring =
          find
              .byKey(const ValueKey('confusions.prompt.bring'))
              .evaluate()
              .isNotEmpty;
      final right = isBring ? 'bring' : 'take';
      final wrong = isBring ? 'take' : 'bring';
      asked.add(right);
      if (i == 0) {
        await _tap(tester, find.text(wrong));
        expect(find.text('Попробуй другое слово'), findsOneWidget);
      }
      await _tap(tester, find.text(right));
      expect(find.text('Верно'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('confusions.next')));
    }
    expect(asked, {'bring', 'take'});
    expect(find.text('С первой попытки — 1 из 2'), findsOneWidget);
    expect(log.records, hasLength(4));
    await _tap(tester, find.text('К парам слов'));
    for (var i = 0; i < 3; i++) {
      await _tap(tester, find.byType(BackButton));
    }
    await _tap(tester, find.text('B1'));
    await openPairs();
    expect(find.text('Пока нет повторяющихся пар'), findsOneWidget);
    expect(find.text('Разобрать пару'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
