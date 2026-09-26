// Выбор до создания сессии и id именно выбранной игры в журнале.
import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/observed_session.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';
import '../support/review_items.dart';
import '../support/ritual_views.dart';

final _today = DateTime(2026, 8, 26, 10);
const _answer = Key('selection.answer');
const _again = Key('selection.again');
const _exit = Key('selection.exit');

class _CountingCards extends InMemoryCardStore {
  int reads = 0;
  @override
  Result<Map<String, LeitnerCard>> load() {
    reads++;
    return super.load();
  }
}

class _Fixture {
  final cards = _CountingCards();
  final streaks = InMemoryStreakStore();
  final answers = InMemoryAnswerLog();
  final launches = <(String, GameLaunch)>[];

  List<GameEntry> get games => [
    entry('alpha', 'Первая игра'),
    entry('beta', 'Вторая игра'),
  ];

  GameEntry entry(String id, String title) => GameEntry(
    id: id,
    title: title,
    build: (launch) {
      launches.add((id, launch));
      return Scaffold(
        body: Column(
          children: [
            Text(id),
            FilledButton(
              key: _answer,
              onPressed: () {
                if (launch.session.nextItem() == null) return;
                launch.session.report(
                  const ReviewOutcome(
                    correct: true,
                    responseTime: Duration(seconds: 1),
                    timeLimit: Duration(seconds: 6),
                  ),
                );
              },
              child: const Text('Ответить'),
            ),
            FilledButton(
              key: _again,
              onPressed: launch.onPlayAgain,
              child: const Text('Ещё раз'),
            ),
            FilledButton(
              key: _exit,
              onPressed: launch.onExit,
              child: const Text('Выйти'),
            ),
          ],
        ),
      );
    },
  );

  Widget app(List<GameEntry> entries) => WordarcadeApp(
    ports: AppPorts(cards: cards, streaks: streaks, answers: answers),
    seed: Ok(wordItems(3)),
    now: () => _today,
    games: entries,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget app, {
  double height = 780,
}) async {
  tester.view.physicalSize = Size(1080, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

SegmentedButton<String> _selector(WidgetTester tester) =>
    tester.widget<SegmentedButton<String>>(find.byKey(AppKeys.gameSelector));

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('реестр задаёт подписи, значения и первое умолчание', (
    tester,
  ) async {
    final f = _Fixture();
    await _pump(tester, f.app(f.games.reversed.toList()));
    final selector = _selector(tester);
    expect(selector.segments.map((s) => s.value), ['beta', 'alpha']);
    expect(selector.selected, {'beta'});
    expect(find.text('Первая игра'), findsOneWidget);
    expect(find.text('Вторая игра'), findsOneWidget);
  });

  for (final count in [0, 1]) {
    testWidgets('при $count игре переключатель скрыт', (tester) async {
      final f = _Fixture();
      await _pump(tester, f.app(f.games.take(count).toList()));
      expect(find.byKey(AppKeys.gameSelector), findsNothing);
    });
  }

  testWidgets('переключение не читает карты и не пишет прогресс', (
    tester,
  ) async {
    final f = _Fixture();
    await _pump(tester, f.app(f.games));
    expect(f.cards.reads, 0);
    await _tap(tester, find.text('Вторая игра'));
    expect(_selector(tester).selected, {'beta'});
    expect(f.cards.reads, 0);
    expect(f.cards.saves, isEmpty);
    expect(f.streaks.saves, isEmpty);
    expect(f.answers.records, isEmpty);
    expect(f.launches, isEmpty);
  });

  testWidgets('Играть запускает выбранную запись, ответ получает её gameId', (
    tester,
  ) async {
    final f = _Fixture();
    await _pump(tester, f.app(f.games));
    await _tap(tester, find.text('Вторая игра'));
    await _tap(tester, find.byKey(AppKeys.play));
    expect(f.launches.last.$1, 'beta');
    expect((f.launches.last.$2.session as ObservedSession).gameId, 'beta');
    await _tap(tester, find.byKey(_answer));
    expect(f.answers.records, hasLength(1));
    expect(f.answers.records.single.gameId, 'beta');
  });

  testWidgets('возврат из игры сохраняет выбор, можно выбрать первую обратно', (
    tester,
  ) async {
    final f = _Fixture();
    await _pump(tester, f.app(f.games));
    await _tap(tester, find.text('Вторая игра'));
    await _tap(tester, find.byKey(AppKeys.play));
    await _tap(tester, find.byKey(_exit));
    expect(_selector(tester).selected, {'beta'});
    await _tap(tester, find.text('Первая игра'));
    await _tap(tester, find.byKey(AppKeys.play));
    expect(f.launches.last.$1, 'alpha');
  });

  testWidgets('Ещё раз строит новую сессию для той же выбранной игры', (
    tester,
  ) async {
    final f = _Fixture();
    await _pump(tester, f.app(f.games));
    await _tap(tester, find.text('Вторая игра'));
    await _tap(tester, find.byKey(AppKeys.play));
    final firstSession = f.launches.last.$2.session;
    await _tap(tester, find.byKey(_again));
    expect(f.launches.last.$1, 'beta');
    expect(f.launches.last.$2.session, isNot(same(firstSession)));
    expect(f.cards.reads, 2);
  });

  testWidgets('возврат с прогресса сохраняет выбор', (tester) async {
    final f = _Fixture();
    await _pump(tester, f.app(f.games));
    await _tap(tester, find.text('Вторая игра'));
    await _tap(tester, find.byKey(AppKeys.progress));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_selector(tester).selected, {'beta'});
  });

  testWidgets('новый корень сбрасывает выбор, прогресс остаётся', (
    tester,
  ) async {
    final f = _Fixture();
    await _pump(tester, f.app(f.games));
    await _tap(tester, find.text('Вторая игра'));
    await _tap(tester, find.byKey(AppKeys.play));
    await _tap(tester, find.byKey(_answer));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(f.app(f.games));
    await tester.pumpAndSettle();
    expect(_selector(tester).selected, {'alpha'});
    expect(f.answers.records, hasLength(1));
  });

  testWidgets('исчезновение выбранного id возвращает первое умолчание', (
    tester,
  ) async {
    final f = _Fixture();
    await _pump(tester, f.app(f.games));
    await _tap(tester, find.text('Вторая игра'));
    await tester.pumpWidget(
      f.app([f.games.first, f.entry('gamma', 'Третья игра')]),
    );
    await tester.pumpAndSettle();
    expect(_selector(tester).selected, {'alpha'});
    await _tap(tester, find.byKey(AppKeys.play));
    expect(f.launches.last.$1, 'alpha');
  });

  testWidgets('настоящий реестр запускает ниндзя по выбору', (tester) async {
    final f = _Fixture();
    await _pump(tester, f.app(wordarcadeGames));
    await _tap(tester, find.text('Ниндзя-слэш'));
    await tester.tap(find.byKey(AppKeys.play));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(NinjaSlashGame), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final selected in ['falling_words', 'ninja_slash']) {
    testWidgets('контраст и цели сегментов: $selected', (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      final f = _Fixture();
      await _pump(tester, f.app(wordarcadeGames));
      await _tap(
        tester,
        find.text(
          selected == 'falling_words' ? 'Падающие слова' : 'Ниндзя-слэш',
        ),
      );
      expect(_selector(tester).selected, {selected});
      expect(
        tester.getRect(find.byKey(AppKeys.gameSelector)).height,
        greaterThanOrEqualTo(48),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  }

  testWidgets('2× на 360 dp: подписи целиком, действия доступны прокруткой', (
    tester,
  ) async {
    var selected = 'falling_words';
    await _pump(
      tester,
      MaterialApp(
        theme: wordarcadeTheme(platform: TargetPlatform.android),
        home: StatefulBuilder(
          builder:
              (context, setState) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: PlayView(
                  onPlay: () {},
                  onProgress: () {},
                  onSettings: () {},
                  onSources: () {},
                  ritual: ritualView(days: 14, lastOffset: 2, freezes: 1),
                  games: wordarcadeGames,
                  selectedGameId: selected,
                  onGameSelected: (id) => setState(() => selected = id),
                ),
              ),
        ),
      ),
      height: 640,
    );
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Ниндзя-слэш'));
    final selectorRect = tester.getRect(find.byKey(AppKeys.gameSelector));
    for (final title in ['Падающие слова', 'Ниндзя-слэш']) {
      final finder = find.text(title);
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(selectorRect.left));
      expect(rect.right, lessThanOrEqualTo(selectorRect.right));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      expect(tester.widget<Text>(finder).maxLines, isNull);
      expect(
        tester.widget<Text>(finder).overflow,
        isNot(TextOverflow.ellipsis),
      );
    }
    expect(selected, 'ninja_slash');
    await _tap(tester, find.byKey(AppKeys.play));
    await _tap(tester, find.byKey(AppKeys.settings));
    expect(tester.takeException(), isNull);
  });
}
