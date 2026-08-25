// Проводка журнала событий: кто и когда его зовёт.
//
// Все события порождает **хост**, ни одного — игра. Проверять это можно
// только отсюда: чистые тесты видят порт и фейк, но не видят, зовёт ли их
// кто-нибудь вообще.
//
// Игра — фейковая, из одной кнопки. Настоящая привела бы сюда падение,
// таймеры и подсветку, а вопрос теста к игре отношения не имеет.
//
// Чего здесь ещё нет: `roundOver` и `roundAbandon`. Хост сегодня не умеет
// отличить доигранную партию от брошенной — для этого игре нужен
// `onRoundOver`, и это Этап 3.3. Роды заведены в перечислении заранее, чтобы
// схему не менять дважды.

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/data/streak/streak_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/events/app_event.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_event_log.dart';
import '../support/review_items.dart';

final DateTime _t0 = DateTime.utc(2026, 8, 26, 10);

/// Часы хоста. Подвижные: ключ партии — это момент её старта, и две партии с
/// одинаковым ключом ничего не доказали бы.
DateTime _now = _t0;

/// Игра из одной кнопки: спросить слово и доложить верный ответ.
class _OneTapGame extends StatelessWidget {
  const _OneTapGame(this.launch);

  final GameLaunch launch;

  static const Key answer = Key('one_tap.answer');

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        key: answer,
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

const GameEntry _entry = GameEntry(
  id: 'one_tap',
  title: 'Один тап',
  build: _OneTapGame.new,
);

void main() {
  late InMemoryEventLog log;

  Future<void> pumpApp(
    WidgetTester tester, {
    Result<List<ReviewItem>>? seed,
    Map<String, Object> prefs = const {},
  }) async {
    log = InMemoryEventLog();
    _now = _t0;
    SharedPreferences.setMockInitialValues(prefs);
    final instance = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      WordarcadeApp(
        store: LeitnerPrefsStore(instance),
        streakStore: StreakPrefsStore(instance),
        seed: seed ?? Ok(wordItems(3)),
        now: () => _now,
        games: const [_entry],
        eventLog: log,
      ),
    );
  }

  Future<void> startRound(WidgetTester tester) async {
    await tester.tap(find.byKey(AppKeys.play));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('Открытие приложения', () {
    testWidgets('домашний экран записывает appOpen ровно один раз', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(log.kinds, [AppEventKind.appOpen]);
      expect(log.events.single.sessionId, isNull);
      expect(log.events.single.localDay, StreakDay.of(_t0));
    });

    testWidgets('момент берётся у часов хоста, а не у настоящих', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(log.events.single.at, _t0);
    });
  });

  group('Начало партии', () {
    testWidgets('тап «Играть» записывает roundStart', (tester) async {
      await pumpApp(tester);

      await startRound(tester);

      expect(log.kinds, [AppEventKind.appOpen, AppEventKind.roundStart]);
    });

    // Тот же ключ, что у ответов этой партии: без него «начал, но не доиграл»
    // ниоткуда не видно, сколько бы событий ни писали.
    testWidgets('событие несёт идентификатор партии', (tester) async {
      await pumpApp(tester);

      await startRound(tester);

      final start = log.events.last;
      expect(start.sessionId, isNotNull);
      expect(start.sessionId, _t0.toIso8601String());
    });

    testWidgets('вторая партия — второе событие со своим ключом', (
      tester,
    ) async {
      await pumpApp(tester);
      await startRound(tester);
      await tester.tap(find.byKey(_OneTapGame.answer));
      await tester.pump();
      // Системное «назад», а не `pageBack()`: у фейковой игры нет AppBar,
      // да и уходят из партии именно так.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      _now = _t0.add(const Duration(minutes: 5));

      await startRound(tester);

      final starts =
          log.events
              .where((e) => e.kind == AppEventKind.roundStart)
              .map((e) => e.sessionId)
              .toList();
      expect(starts, hasLength(2));
      expect(
        starts.toSet(),
        hasLength(2),
        reason:
            'ключ у каждой партии свой — иначе события двух партий '
            'склеятся в одну',
      );
    });

    testWidgets('партия, которая не собралась, началом не считается', (
      tester,
    ) async {
      // Битый документ карточек: usecase вернёт Err, игра не запустится.
      await pumpApp(tester, prefs: const {'leitner_state': 'не json'});

      await startRound(tester);

      expect(find.byType(_OneTapGame), findsNothing);
      expect(
        log.kinds,
        orderedEquals(const [AppEventKind.appOpen]),
        reason: 'экран ошибки — не начало партии',
      );
    });
  });

  group('Чего журнал не пишет', () {
    testWidgets('битый сид: домашнего экрана нет, и события тоже', (
      tester,
    ) async {
      await pumpApp(tester, seed: const Err(Failure('сид не читается')));

      expect(
        log.events,
        isEmpty,
        reason:
            'appOpen живёт в initState домашнего экрана, а его на битом сиде '
            'не существует. Это дефект сборки, и терять на нём событие можно',
      );
    });
  });
}
