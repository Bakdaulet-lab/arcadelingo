// Реестр игр: обещание Фазы 2, проверенное фейковой второй игрой.
//
// Обещание звучит так: игру добавляют одной записью в реестр, и ядро при
// этом не трогают. Здесь оно проверяется буквально — регистрируется игра,
// которой не существует в lib/, и она проходит весь путь: тап «Играть» →
// usecase → сессия с наблюдателями → доклад → серия в prefs.
//
// Три пустых `git diff` (lib/domain/review, lib/domain/srs,
// lib/features/games) — вторая половина того же доказательства, и она в
// отчёте: тестом файл, которого не тронули, не покажешь.

import 'dart:convert';

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/data/streak/streak_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/observed_session.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/review_items.dart';

final DateTime _t0 = DateTime.utc(2026, 8, 25, 10);

/// Ключ игры, которой в `lib/` нет и не будет.
const String _fakeId = 'ninja_slash';

/// Что фейковая игра получила при запуске: по этому значению видно, всё ли
/// хост передал и с каким id собрал сессию.
GameLaunch? _lastLaunch;

/// Игра из одной кнопки: спросить слово и доложить верный ответ.
///
/// Ровно тот цикл, который требует game-contract, и ничего сверх: цель —
/// показать, что подключиться можно чем угодно, а не написать вторую игру.
class _FakeGame extends StatelessWidget {
  const _FakeGame(this.launch);

  final GameLaunch launch;

  static const Key answerKey = Key('fake.answer');

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        key: answerKey,
        onPressed: () {
          final item = launch.session.nextItem();
          if (item == null) return;
          launch.session.report(
            const ReviewOutcome(
              correct: true,
              responseTime: Duration(seconds: 1),
              timeLimit: Duration(seconds: 6),
            ),
          );
        },
        child: const Text('ответить'),
      ),
    ),
  );
}

final GameEntry _fakeEntry = GameEntry(
  id: _fakeId,
  title: 'Ниндзя-слэш',
  build: (launch) {
    _lastLaunch = launch;
    return _FakeGame(launch);
  },
);

Future<void> _pumpApp(
  WidgetTester tester, {
  List<GameEntry>? games,
  Map<String, Object> prefs = const {},
}) async {
  _lastLaunch = null;
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    WordarcadeApp(
      store: LeitnerPrefsStore(instance),
      streakStore: StreakPrefsStore(instance),
      seed: Ok(wordItems(3)),
      now: () => _t0,
      games: games ?? wordarcadeGames,
    ),
  );
}

Future<void> _tapAndSettle(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('Реестр', () {
    test('по умолчанию не пуст и содержит падающие слова', () {
      expect(wordarcadeGames, isNotEmpty);
      expect(wordarcadeGames.map((g) => g.id), contains('falling_words'));
    });

    // Литералом: id уезжает в события, а с Этапа 2.3 — в журнал ответов.
    // Переименование разойдётся с уже записанной историей, и сломать тест
    // при этом обязано.
    test('id падающих слов — falling_words', () {
      expect(fallingWordsEntry.id, 'falling_words');
    });

    test('идентификаторы уникальны', () {
      final ids = wordarcadeGames.map((g) => g.id).toList();

      expect(ids.toSet(), hasLength(ids.length));
    });

    test('у каждой игры есть название для человека', () {
      for (final game in wordarcadeGames) {
        expect(game.title.trim(), isNotEmpty, reason: game.id);
      }
    });
  });

  group('Вторая игра подключается одной записью', () {
    testWidgets('запускается тем же путём, что и первая', (tester) async {
      await _pumpApp(tester, games: [_fakeEntry]);

      await _tapAndSettle(tester, AppKeys.play);

      expect(find.byType(_FakeGame), findsOneWidget);
      expect(
        find.byType(FallingWordsGame),
        findsNothing,
        reason: 'хост запускает игру из реестра, а не зашитую в код',
      );
    });

    testWidgets('получает готовую сессию и все колбэки хоста', (tester) async {
      await _pumpApp(tester, games: [_fakeEntry]);

      await _tapAndSettle(tester, AppKeys.play);

      final launch = _lastLaunch!;
      expect(launch.session.total, 3);
      expect(launch.summaryFooter(), isNotEmpty);
    });

    // Тот самый шов: id берётся из записи реестра, а не из константы в
    // обработчике тапа. Проверяется по сессии, потому что именно она несёт
    // его в каждое событие ответа.
    testWidgets('сессия собрана с id этой игры', (tester) async {
      await _pumpApp(tester, games: [_fakeEntry]);

      await _tapAndSettle(tester, AppKeys.play);

      expect((_lastLaunch!.session as ObservedSession).gameId, _fakeId);
    });

    testWidgets('доклад из неё доходит до наблюдателей: серия продлилась', (
      tester,
    ) async {
      await _pumpApp(tester, games: [_fakeEntry]);
      await _tapAndSettle(tester, AppKeys.play);

      await tester.tap(find.byKey(_FakeGame.answerKey));
      await tester.pump();

      final doc = (await SharedPreferences.getInstance()).getString(
        'streak_state',
      );
      expect(doc, isNotNull);
      expect(
        jsonDecode(doc!),
        containsPair('last_day', '2026-08-25'),
        reason: 'путь целиком: игра → сессия → наблюдатель → prefs',
      );
    });

    testWidgets('пока экрана выбора нет, запускается первая из реестра', (
      tester,
    ) async {
      await _pumpApp(tester, games: [_fakeEntry, fallingWordsEntry]);

      await _tapAndSettle(tester, AppKeys.play);

      expect(find.byType(_FakeGame), findsOneWidget);
      expect(find.byType(FallingWordsGame), findsNothing);
    });

    // Дыру нашла мутация «страж пустого реестра убран»: тесты остались
    // зелёными, потому что пустой реестр никто не пробовал.
    testWidgets('пустой реестр роняет с причиной, а не молчит', (tester) async {
      await _pumpApp(tester, games: const []);

      await tester.tap(find.byKey(AppKeys.play));
      await tester.pump();

      final thrown = tester.takeException();
      expect(thrown, isStateError);
      expect(
        (thrown as StateError).message,
        contains('реестр игр пуст'),
        reason: 'дефект сборки обязан назвать себя',
      );
    });

    testWidgets('падающие слова остаются игрой по умолчанию', (tester) async {
      await _pumpApp(tester);

      await _tapAndSettle(tester, AppKeys.play);

      expect(find.byType(FallingWordsGame), findsOneWidget);
      expect(
        (_lastLaunch?.session as ObservedSession?)?.gameId,
        isNull,
        reason: 'фейковую игру никто не звал',
      );
    });
  });
}
