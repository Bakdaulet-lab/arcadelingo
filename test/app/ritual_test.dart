// Дневной ритуал: что засчитывает день и что видит человек, открыв приложение.
//
// Здесь проверяется главное правило Фазы 3 и его единственная альтернатива:
// день засчитывает **законченная партия**, а выход на середине — нет. Чистые
// тесты видят `CountPlayedDay`, но не видят, зовёт ли его кто-нибудь и в
// правильный ли момент; ответ только отсюда.
//
// Игра фейковая, из двух кнопок: «ответить» и «закончить раунд». Настоящая
// привела бы сюда падение, таймеры и подсветку, а вопрос теста к ним
// отношения не имеет — про настоящую игру есть `app_test.dart`, где партия
// играется целиком.

import 'dart:convert';

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/data/srs/leitner_codec.dart';
import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/data/streak/streak_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/events/app_event.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/ui/streak_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_event_log.dart';
import '../support/review_items.dart';

/// Среда, 26 августа 2026.
final DateTime _t0 = DateTime(2026, 8, 26, 10);
DateTime _now = _t0;

/// Игра из двух кнопок: ответить и закончить раунд.
class _TwoTapGame extends StatelessWidget {
  const _TwoTapGame(this.launch);

  final GameLaunch launch;

  static const Key answer = Key('two_tap.answer');
  static const Key finish = Key('two_tap.finish');

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
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
          FilledButton(
            key: finish,
            onPressed: launch.onRoundOver,
            child: const Text('закончить'),
          ),
        ],
      ),
    ),
  );
}

const GameEntry _entry = GameEntry(
  id: 'two_tap',
  title: 'Два тапа',
  build: _TwoTapGame.new,
);

void main() {
  late InMemoryEventLog events;

  Future<void> pumpApp(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    int words = 3,
    DateTime? now,
    List<AppEvent> history = const [],
  }) async {
    _now = now ?? _t0;
    events = InMemoryEventLog();
    // Журнал наполняется ДО первого кадра: домашний экран читает его в
    // initState, и дописанное потом он бы уже не увидел.
    events.events.addAll(history);
    SharedPreferences.setMockInitialValues(prefs);
    final instance = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      WordarcadeApp(
        ports: AppPorts(
          cards: LeitnerPrefsStore(instance),
          streaks: StreakPrefsStore(instance),
          events: events,
        ),
        seed: Ok(wordItems(words)),
        now: () => _now,
        games: const [_entry],
      ),
    );
  }

  Future<void> enterGame(WidgetTester tester) async {
    await tester.tap(find.byKey(AppKeys.play));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> leaveGame(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Future<Map<String, Object?>?> streakDoc() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      'streak_state',
    );
    return raw == null ? null : jsonDecode(raw) as Map<String, Object?>;
  }

  group('Что засчитывает день', () {
    testWidgets('законченная партия — засчитывает', (tester) async {
      await pumpApp(tester);
      await enterGame(tester);
      await tester.tap(find.byKey(_TwoTapGame.answer));
      await tester.pump();

      await tester.tap(find.byKey(_TwoTapGame.finish));
      await tester.pump();

      expect(await streakDoc(), containsPair('last_day', '2026-08-26'));
      expect(await streakDoc(), containsPair('current', 1));
    });

    // Главное следствие выбранного порога. До Фазы 3 первый же ответ двигал
    // серию, и человек, вышедший на восьмом слове, получал день даром.
    testWidgets('ответы без конца партии — не засчитывают', (tester) async {
      await pumpApp(tester);
      await enterGame(tester);

      await tester.tap(find.byKey(_TwoTapGame.answer));
      await tester.pump();
      await leaveGame(tester);

      expect(
        await streakDoc(),
        isNull,
        reason: 'вышел на середине — день не сыгран',
      );
      expect(find.byKey(AppKeys.streak), findsNothing);
    });

    // Разложенный по коробкам Лейтнер делает такие дни неизбежными: всё
    // отвечено, новых слов нет. Серия, наказывающая за прилежность, —
    // сломанная серия.
    testWidgets('пустая сессия («на сегодня всё») — засчитывает', (
      tester,
    ) async {
      // Все три слова уже отвечены и ждут через несколько суток: очередь
      // пуста. Документ пишется настоящим кодеком, а не руками: формат
      // хранилища — не то, что стоит копировать в тест.
      await pumpApp(
        tester,
        prefs: {
          LeitnerPrefsStore.key: encodeLeitnerState({
            for (final id in ['w01', 'w02', 'w03'])
              id: LeitnerCard(box: 3, due: DateTime.utc(2026, 8, 30)),
          }),
        },
      );

      await enterGame(tester);

      expect(
        await streakDoc(),
        containsPair('last_day', '2026-08-26'),
        reason: 'пришёл и сделал всё, что система позволила',
      );
    });

    testWidgets('вторая законченная партия в тот же день ничего не меняет', (
      tester,
    ) async {
      await pumpApp(tester, words: 20);
      await enterGame(tester);
      await tester.tap(find.byKey(_TwoTapGame.finish));
      await tester.pump();
      await leaveGame(tester);
      final afterFirst = await streakDoc();

      await enterGame(tester);
      await tester.tap(find.byKey(_TwoTapGame.finish));
      await tester.pump();

      expect(await streakDoc(), afterFirst);
    });

    testWidgets('партия назавтра продлевает серию', (tester) async {
      await pumpApp(tester, words: 20);
      await enterGame(tester);
      await tester.tap(find.byKey(_TwoTapGame.finish));
      await tester.pump();
      await leaveGame(tester);

      _now = _t0.add(const Duration(days: 1));
      await enterGame(tester);
      await tester.tap(find.byKey(_TwoTapGame.finish));
      await tester.pump();

      expect(await streakDoc(), containsPair('current', 2));
    });
  });

  group('События конца партии', () {
    testWidgets('законченная партия — roundOver, ровно один', (tester) async {
      await pumpApp(tester);
      await enterGame(tester);

      await tester.tap(find.byKey(_TwoTapGame.finish));
      await tester.pump();
      await leaveGame(tester);

      expect(events.kinds, [
        AppEventKind.appOpen,
        AppEventKind.roundStart,
        AppEventKind.roundOver,
      ]);
    });

    testWidgets('выход с середины — roundAbandon', (tester) async {
      await pumpApp(tester);
      await enterGame(tester);

      await leaveGame(tester);

      expect(events.kinds, [
        AppEventKind.appOpen,
        AppEventKind.roundStart,
        AppEventKind.roundAbandon,
      ]);
    });

    testWidgets('конец партии несёт ключ этой партии', (tester) async {
      await pumpApp(tester);
      await enterGame(tester);

      await tester.tap(find.byKey(_TwoTapGame.finish));
      await tester.pump();

      final start = events.events.firstWhere(
        (e) => e.kind == AppEventKind.roundStart,
      );
      final over = events.events.firstWhere(
        (e) => e.kind == AppEventKind.roundOver,
      );
      expect(over.sessionId, start.sessionId);
      expect(over.sessionId, isNotNull);
    });
  });

  group('Полоса недели', () {
    // Ровно то, ради чего полоса берёт данные из журнала. Серия оборвана
    // средой, `current` знает только про четверг, — но понедельник и вторник
    // человек отыграл, и галочки на них обязаны быть.
    testWidgets('сыгранные дни приходят из журнала, а не из длины серии', (
      tester,
    ) async {
      // Четверг. Серия оборвалась средой и знает только про четверг; журнал
      // помнит понедельник и вторник — до обрыва.
      await pumpApp(
        tester,
        now: DateTime(2026, 8, 27, 10),
        prefs: {
          'streak_state': jsonEncode({
            'version': 2,
            'current': 1,
            'best': 2,
            'last_day': '2026-08-27',
            'freezes': 0,
            'days_since_freeze': 1,
          }),
        },
        history: [
          for (final day in [24, 25])
            AppEvent(
              kind: AppEventKind.roundOver,
              at: DateTime.utc(2026, 8, day, 12),
              localDay: StreakDay(2026, 8, day),
            ),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        find.byIcon(Icons.check),
        findsNWidgets(2),
        reason: 'состояние серии этих дней не помнит, а журнал помнит',
      );
    });

    testWidgets('пустой журнал — неделя без галочек', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(weekStripKey), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    // Мутация «frozen: null» краснеет только здесь: полоса умеет рисовать щит
    // (это проверяет streak_card_test), но доезжает ли до неё замороженный
    // день из состояния — видно лишь с уровня хоста.
    testWidgets('замороженный день приходит из состояния серии', (
      tester,
    ) async {
      await pumpApp(
        tester,
        prefs: {
          'streak_state': jsonEncode({
            'version': 2,
            'current': 6,
            'best': 9,
            'last_day': '2026-08-26',
            'freezes': 0,
            'days_since_freeze': 1,
            'frozen_day': '2026-08-25',
          }),
        },
      );
      await tester.pumpAndSettle();

      expect(
        find.byIcon(Icons.shield),
        findsOneWidget,
        reason: 'журнал о замороженном дне не знает — в него ничего не писали',
      );
    });

    testWidgets('законченная партия ставит галочку на сегодня', (tester) async {
      await pumpApp(tester);
      await enterGame(tester);
      await tester.tap(find.byKey(_TwoTapGame.finish));
      await tester.pump();

      await leaveGame(tester);
      await tester.pumpAndSettle();

      expect(
        find.byIcon(Icons.check),
        findsOneWidget,
        reason: 'событие roundOver только что записано — журнал его видит',
      );
    });
  });

  group('Домашний экран', () {
    testWidgets('до первой партии — приглашение и ни одной цифры', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.byKey(AppKeys.streak), findsNothing);
      expect(find.byKey(AppKeys.freeze), findsNothing);
      expect(find.text('Сегодня ещё не сыграно'), findsOneWidget);
      expect(find.text('Играть'), findsOneWidget);
    });

    testWidgets('после партии — серия, отметка дня и другое приглашение', (
      tester,
    ) async {
      await pumpApp(tester);
      await enterGame(tester);
      await tester.tap(find.byKey(_TwoTapGame.finish));
      await tester.pump();

      await leaveGame(tester);

      expect(
        tester.widget<Text>(find.byKey(AppKeys.streak)).data,
        'день подряд',
        reason: 'число уже нарисовано в пламени, подпись его не повторяет',
      );
      expect(tester.widget<Text>(find.byKey(flameDigitKey)).data, '1');
      expect(find.text('Сегодня сыграно'), findsOneWidget);
      expect(find.text('Сыграть ещё раз'), findsOneWidget);
    });

    // Ровно та причина, по которой `streakAsOf` вообще появилась: состояние
    // знает последний засчитанный день и об обрыве само не узнает.
    testWidgets('оборванная серия не показывается живой', (tester) async {
      await pumpApp(
        tester,
        prefs: {
          'streak_state': jsonEncode({
            'version': 2,
            'current': 4,
            'best': 9,
            'last_day': '2026-08-22',
            'freezes': 0,
            'days_since_freeze': 4,
          }),
        },
      );

      expect(find.byKey(AppKeys.streak), findsNothing);
      expect(find.text('Играть'), findsOneWidget);
    });

    testWidgets('серия под угрозой зовёт её спасти', (tester) async {
      await pumpApp(
        tester,
        prefs: {
          'streak_state': jsonEncode({
            'version': 2,
            'current': 4,
            'best': 9,
            'last_day': '2026-08-24',
            'freezes': 1,
            'days_since_freeze': 0,
          }),
        },
      );

      expect(tester.widget<Text>(find.byKey(flameDigitKey)).data, '4');
      expect(find.text('Спасти серию'), findsOneWidget);
      expect(find.text('Заморозка в запасе'), findsOneWidget);
    });

    testWidgets('потраченная заморозка названа вслух', (tester) async {
      await pumpApp(
        tester,
        prefs: {
          'streak_state': jsonEncode({
            'version': 2,
            'current': 6,
            'best': 9,
            'last_day': '2026-08-26',
            'freezes': 0,
            'days_since_freeze': 1,
            'frozen_day': '2026-08-25',
          }),
        },
      );

      expect(
        tester.widget<Text>(find.byKey(AppKeys.freeze)).data,
        'Заморозка потрачена за 25 августа',
      );
    });
  });
}
