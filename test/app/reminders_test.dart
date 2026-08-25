// Проводка напоминаний: кто, когда и с чем зовёт расписание.
//
// Политика проверена чистыми тестами, слова — своими; здесь единственное,
// чего они не видят: зовёт ли их кто-нибудь и в правильный ли момент.
// Настоящий плагин сюда не приходит — он ходит в платформенные каналы,
// которых в `flutter test` нет, и проверяется руками на телефоне.

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/app/settings_view.dart';
import 'package:arcadelingo/data/settings/settings_codec.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/data/streak/streak_codec.dart';
import 'package:arcadelingo/data/streak/streak_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/reminders/reminder_settings.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_reminders.dart';
import '../support/review_items.dart';

/// Среда, 26 августа 2026, десять утра.
final DateTime _t0 = DateTime(2026, 8, 26, 10);

/// Игра из одной кнопки: ответить и закончить раунд.
class _OneTapGame extends StatelessWidget {
  const _OneTapGame(this.launch);

  final GameLaunch launch;

  static const Key finish = Key('one_tap.finish');

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        key: finish,
        onPressed: () {
          final item = launch.session.nextItem();
          if (item != null) {
            launch.session.report(
              const ReviewOutcome(
                correct: true,
                responseTime: Duration(seconds: 1),
                timeLimit: Duration(seconds: 6),
              ),
            );
          }
          launch.onRoundOver();
        },
        child: const Text('закончить'),
      ),
    ),
  );
}

const GameEntry _entry = GameEntry(
  id: 'one_tap',
  title: 'Один тап',
  build: _OneTapGame.new,
);

/// Документ настроек: включено, время [hour]:00.
String _settingsDoc({bool enabled = true, int hour = 20}) => encodeSettings(
  ReminderSettings(enabled: enabled, at: ReminderTime(hour, 0)),
);

/// Документ серии: [days] дней, последний засчитанный — [lastDay].
String _streakDoc({required int days, required StreakDay lastDay}) =>
    encodeStreakState(StreakState(current: days, best: days, lastDay: lastDay));

void main() {
  late FakeReminders reminders;
  late bool permissionGranted;

  Future<SharedPreferences> pumpApp(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    bool withSettings = true,
  }) async {
    reminders = FakeReminders();
    permissionGranted = true;
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
        games: const [_entry],
        reminders: reminders,
        settingsStore: withSettings ? SettingsPrefsStore(instance) : null,
        askReminderPermission: () async => permissionGranted,
      ),
    );
    await tester.pumpAndSettle();
    return instance;
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(AppKeys.settings));
    await tester.pumpAndSettle();
  }

  group('Перепланирование на открытии', () {
    testWidgets('напоминания выключены — расписание пусто', (tester) async {
      await pumpApp(tester);

      expect(reminders.scheduled, isEmpty);
      expect(
        reminders.cancels,
        greaterThan(0),
        reason: 'выключенное напоминание обязано быть снято, а не забыто',
      );
    });

    testWidgets('включены и сегодня не сыграно — ставится на сегодня', (
      tester,
    ) async {
      await pumpApp(tester, prefs: {SettingsPrefsStore.key: _settingsDoc()});

      expect(reminders.current!.at, DateTime(2026, 8, 26, 20));
    });

    // Семь утра сегодня уже прошло — значит завтра, и час из настроек.
    // Две проверки одним сценарием: и час не выдуман, и прошедшее время
    // уводит напоминание на следующий день.
    testWidgets('час берётся из настроек, прошедшее время — на завтра', (
      tester,
    ) async {
      await pumpApp(
        tester,
        prefs: {SettingsPrefsStore.key: _settingsDoc(hour: 7)},
      );

      expect(reminders.current!.at, DateTime(2026, 8, 27, 7));
    });

    testWidgets('текст говорит про серию, которая будет в тот день', (
      tester,
    ) async {
      await pumpApp(
        tester,
        prefs: {
          SettingsPrefsStore.key: _settingsDoc(),
          StreakPrefsStore.key: _streakDoc(
            days: 4,
            lastDay: StreakDay(2026, 8, 25),
          ),
        },
      );

      expect(reminders.current!.title, 'Серия: 4 дня');
      expect(reminders.current!.body, isNotEmpty);
    });

    testWidgets('битый документ серии напоминание не ставит', (tester) async {
      await pumpApp(
        tester,
        prefs: {
          SettingsPrefsStore.key: _settingsDoc(),
          StreakPrefsStore.key: 'битый документ',
        },
      );

      expect(
        reminders.scheduled,
        isEmpty,
        reason: 'о чём напоминать, неизвестно — молчим',
      );
    });
  });

  group('Перепланирование после партии', () {
    testWidgets('законченная партия уводит напоминание на завтра', (
      tester,
    ) async {
      await pumpApp(tester, prefs: {SettingsPrefsStore.key: _settingsDoc()});
      expect(reminders.current!.at, DateTime(2026, 8, 26, 20));

      await tester.tap(find.byKey(AppKeys.play));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(_OneTapGame.finish));
      await tester.pumpAndSettle();

      expect(
        reminders.current!.at,
        DateTime(2026, 8, 27, 20),
        reason: 'сегодня уже сыграно — звать сегодня незачем',
      );
    });
  });

  group('Экран настроек', () {
    testWidgets('кнопки нет, если стора настроек нет', (tester) async {
      await pumpApp(tester, withSettings: false);

      await tester.tap(find.byKey(AppKeys.settings));
      await tester.pumpAndSettle();

      expect(find.byKey(SettingsKeys.view), findsNothing);
    });

    testWidgets('открывается и показывает умолчание', (tester) async {
      await pumpApp(tester);

      await openSettings(tester);

      expect(find.byKey(SettingsKeys.view), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byKey(SettingsKeys.toggle)).value,
        isFalse,
      );
      expect(find.text('20:00'), findsOneWidget);
    });

    testWidgets('включение сохраняет настройку и ставит напоминание', (
      tester,
    ) async {
      final prefs = await pumpApp(tester);
      await openSettings(tester);

      await tester.tap(find.byKey(SettingsKeys.toggle));
      await tester.pumpAndSettle();

      expect(
        prefs.getString(SettingsPrefsStore.key),
        contains('"enabled":true'),
      );
      expect(reminders.current!.at, DateTime(2026, 8, 26, 20));
    });

    // Разрешение спрашивается ровно здесь — в момент, когда человек попросил
    // напоминания, и нигде больше.
    testWidgets('отказ системы не включает переключатель', (tester) async {
      final prefs = await pumpApp(tester);
      await openSettings(tester);
      permissionGranted = false;

      await tester.tap(find.byKey(SettingsKeys.toggle));
      await tester.pumpAndSettle();

      expect(
        tester.widget<SwitchListTile>(find.byKey(SettingsKeys.toggle)).value,
        isFalse,
      );
      expect(find.byKey(SettingsKeys.denied), findsOneWidget);
      expect(prefs.getString(SettingsPrefsStore.key), isNull);
      expect(reminders.scheduled, isEmpty);
    });

    testWidgets('выключение снимает напоминание', (tester) async {
      await pumpApp(tester, prefs: {SettingsPrefsStore.key: _settingsDoc()});
      await openSettings(tester);
      final before = reminders.cancels;

      await tester.tap(find.byKey(SettingsKeys.toggle));
      await tester.pumpAndSettle();

      expect(reminders.cancels, greaterThan(before));
      expect(
        reminders.current!.at,
        DateTime(2026, 8, 26, 20),
        reason: 'ставилось до выключения, после — только снятие',
      );
    });

    testWidgets('строка времени неактивна, пока напоминание выключено', (
      tester,
    ) async {
      await pumpApp(tester);

      await openSettings(tester);

      expect(
        tester.widget<ListTile>(find.byKey(SettingsKeys.time)).enabled,
        isFalse,
      );
    });

    testWidgets('битые настройки показывают умолчание, а не экран ошибки', (
      tester,
    ) async {
      await pumpApp(tester, prefs: {SettingsPrefsStore.key: 'битый документ'});

      await openSettings(tester);

      expect(find.byKey(SettingsKeys.view), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
    });
  });
}
