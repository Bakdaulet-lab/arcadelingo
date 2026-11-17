// Выбор до создания сессии и id именно выбранной игры в журнале.
import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/observed_session.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_game.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_views.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';
import '../support/result.dart';
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

  Widget app(List<GameEntry> entries, {List<ReviewItem>? items}) =>
      WordarcadeApp(
        ports: AppPorts(cards: cards, streaks: streaks, answers: answers),
        seed: Ok(items ?? wordItems(3)),
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

Future<void> _startBundledGame(
  WidgetTester tester,
  GameEntry game,
  CefrLevel level,
  Result<List<ReviewItem>> seed, {
  required InMemoryCardStore cards,
  required InMemoryAnswerLog answers,
}) async {
  await _pump(
    tester,
    WordarcadeApp(
      ports: AppPorts(
        cards: cards,
        streaks: InMemoryStreakStore(),
        answers: answers,
      ),
      seed: seed,
      now: () => _today,
    ),
  );
  await _tap(tester, find.text(level.name.toUpperCase()));
  await _tap(tester, find.text(game.title));
  await tester.tap(find.byKey(AppKeys.play));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  final ninja = game.id == ninjaSlashEntry.id;
  expect(
    find.byType(ninja ? NinjaSlashGame : FallingWordsGame),
    findsOneWidget,
  );
  await tester.pump(ninja ? NinjaRun.windUpTime : FallingWordsRun.windUpTime);
}

Future<void> _answerBundledWord(
  WidgetTester tester, {
  required bool ninja,
  required String translation,
}) async {
  final answer = find.text(translation);
  expect(answer, findsOneWidget);
  if (ninja) {
    final center = tester.getCenter(answer);
    final slash = await tester.startGesture(center - const Offset(20, 0));
    await slash.moveTo(center + const Offset(20, 0));
    await slash.up();
  } else {
    await tester.tap(answer);
  }
  await tester.pump();
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

  testWidgets('видны шесть уровней; выбор пустого C2 не запускает партию', (
    tester,
  ) async {
    final f = _Fixture();
    await _pump(tester, f.app(f.games));
    for (final label in ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']) {
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
    }
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'A1')).selected,
      isTrue,
    );

    await _tap(tester, find.text('C2'));
    expect(find.text('Для C2 пока нет слов'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(AppKeys.play)).onPressed,
      isNull,
    );
    expect(f.cards.reads, 0);
    expect(f.launches, isEmpty);
    expect(f.streaks.saves, isEmpty);

    await _tap(tester, find.text('A1'));
    expect(
      tester.widget<FilledButton>(find.byKey(AppKeys.play)).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'выбор B1 и второй игры сохраняется на «Ещё раз» и при возврате',
    (tester) async {
      final f = _Fixture();
      const b1 = [
        ReviewItem(
          word: Word(
            id: 'climate',
            text: 'climate',
            translation: 'климат',
            level: CefrLevel.b1,
          ),
        ),
        ReviewItem(
          word: Word(
            id: 'engine',
            text: 'engine',
            translation: 'двигатель',
            level: CefrLevel.b1,
          ),
        ),
      ];
      await _pump(tester, f.app(f.games, items: [...wordItems(3), ...b1]));
      await _tap(tester, find.text('B1'));
      await _tap(tester, find.text('Вторая игра'));
      expect(f.cards.reads, 0);
      await _tap(tester, find.byKey(AppKeys.play));
      expect(f.launches.last.$1, 'beta');
      expect(f.launches.last.$2.session.total, 2);
      await _tap(tester, find.byKey(_answer));
      expect(f.answers.records.single.wordId, 'climate');

      await _tap(tester, find.byKey(_again));
      expect(f.launches.last.$1, 'beta');
      expect(f.launches.last.$2.session.total, 1);
      await _tap(tester, find.byKey(_answer));
      expect(f.answers.records.last.wordId, 'engine');

      await _tap(tester, find.byKey(_exit));
      expect(_selector(tester).selected, {'beta'});
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'B1'))
            .selected,
        isTrue,
      );
    },
  );

  for (final game in [fallingWordsEntry, ninjaSlashEntry]) {
    testWidgets('${game.title}: карточка A2 из бандла и верный ответ', (
      tester,
    ) async {
      final seed = (await tester.runAsync(loadWordsSeed))!;
      final answers = InMemoryAnswerLog();
      // Слово из последней порции ставим в очередь как просроченное.
      final cards = InMemoryCardStore({
        'bookcase': LeitnerCard(box: 2, due: _today),
      });
      await _startBundledGame(
        tester,
        game,
        CefrLevel.a2,
        seed,
        cards: cards,
        answers: answers,
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('bookcase'), findsOneWidget);
      await _answerBundledWord(
        tester,
        ninja: game.id == ninjaSlashEntry.id,
        translation: 'книжный шкаф',
      );

      final record = answers.records.single;
      expect(record.wordId, 'bookcase');
      expect(record.gameId, game.id);
      expect(record.correct, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    for (final (level, skip) in [
      (CefrLevel.b1, 38),
      (CefrLevel.b2, 0),
      (CefrLevel.c1, 0),
      (CefrLevel.c2, 0),
    ]) {
      final label = level.name.toUpperCase();
      testWidgets(
        '${game.title}: весь раунд только со словами $label из бандла',
        (tester) async {
          final seed = (await tester.runAsync(loadWordsSeed))!;
          final items = ok(seed);
          final selected =
              items.where((item) => item.word.level == level).toList();
          // Берём по карточке из начала, середины и конца пополнения. У B1
          // пропускаем первые 38 слов из отдельной стартовой порции.
          final added = selected.skip(skip).toList();
          final ready = [added.first, added[added.length ~/ 2], added.last];
          final fresh = selected.where((item) => !ready.contains(item));
          final expected = [
            ...ready,
            ...fresh.take(sessionTarget - ready.length),
          ];
          expect(expected, hasLength(sessionTarget));

          // Готовые к повтору слова других уровней стоят раньше выбранного
          // уровня по сроку, чтобы тест поймал попадание любого из них в раунд.
          final cards = InMemoryCardStore({
            for (final other in [
              CefrLevel.a1,
              CefrLevel.a2,
              CefrLevel.b1,
              CefrLevel.b2,
              CefrLevel.c1,
              CefrLevel.c2,
            ])
              if (other != level)
                items
                    .firstWhere((item) => item.word.level == other)
                    .word
                    .id: LeitnerCard(
                  box: 2,
                  due: _today.subtract(const Duration(days: 1)),
                ),
            for (final item in ready)
              item.word.id: LeitnerCard(box: 2, due: _today),
          });
          final answers = InMemoryAnswerLog();
          await _startBundledGame(
            tester,
            game,
            level,
            seed,
            cards: cards,
            answers: answers,
          );

          final ninja = game.id == ninjaSlashEntry.id;
          final prompt = find.byKey(
            ninja ? NinjaKeys.word : FallingWordsKeys.word,
          );
          for (final (index, item) in expected.indexed) {
            await tester.pump(const Duration(seconds: 1));
            expect(tester.widget<Text>(prompt).data, item.word.text);
            await _answerBundledWord(
              tester,
              ninja: ninja,
              translation: item.word.translation,
            );
            expect(answers.records, hasLength(index + 1));
            final record = answers.records.last;
            expect(record.wordId, item.word.id);
            expect(record.gameId, game.id);
            expect(record.correct, isTrue);
            await tester.pump(
              ninja ? NinjaRun.correctReveal : FallingWordsRun.correctReveal,
            );
          }
          expect(
            find.byKey(ninja ? NinjaKeys.summary : FallingWordsKeys.summary),
            findsOneWidget,
          );
          expect(answers.records, hasLength(sessionTarget));
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  for (final selected in ['falling_words', 'ninja_slash']) {
    testWidgets('контраст и цели сегментов: $selected', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final f = _Fixture();
        await _pump(tester, f.app(wordarcadeGames));
        await _tap(
          tester,
          find.text(
            selected == 'falling_words' ? 'Падающие слова' : 'Ниндзя-слэш',
          ),
        );
        expect(_selector(tester).selected, {selected});
        // Пиксельный guideline не видит исчезнувшие буквы, если текст
        // совпал с фоном. Читаем стиль самого рисуемого SegmentedButton,
        // а не исходную тему: оба состояния обязаны давать WCAG 4.5:1.
        final style = _selector(tester).style!;
        for (final states in [
          <WidgetState>{},
          {WidgetState.selected},
        ]) {
          final foreground = style.foregroundColor!.resolve(states)!;
          final background = style.backgroundColor!.resolve(states)!;
          final a = foreground.computeLuminance();
          final b = background.computeLuminance();
          final contrast =
              (a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05));
          expect(
            contrast,
            greaterThanOrEqualTo(4.5),
            reason: 'состояния $states',
          );
        }
        expect(
          tester.getRect(find.byKey(AppKeys.gameSelector)).height,
          greaterThanOrEqualTo(48),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('2× на 360 dp: подписи целиком, действия доступны прокруткой', (
    tester,
  ) async {
    var selected = 'falling_words';
    var level = CefrLevel.a1;
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
                  selectedLevel: level,
                  onLevelSelected: (value) => setState(() => level = value),
                ),
              ),
        ),
      ),
      height: 640,
    );
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('C2'));
    expect(level, CefrLevel.c2);
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
