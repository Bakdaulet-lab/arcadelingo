// Проводка звука: настройка → порт, который получает игра.
//
// Игра про настройку не знает — ей приходит либо адаптер, либо нулевой
// объект. Проверяется именно это: «выключено» значит «никто не зовёт», а не
// «зовут и молчат». Разница видна в день, когда кто-то добавит третий вызов
// мимо стража.
//
// Что здесь НЕ проверяется: что `AudioSounds` действительно издаёт звук.
// Он ходит в платформенные каналы, которых в `flutter test` нет, — ровно
// как `PluginReminders` в 3.5. Это ручная проверка на `--release`.

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/app/settings_view.dart';
import 'package:arcadelingo/data/settings/settings_codec.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/data/streak/streak_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/ports/sounds.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_views.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_review_session.dart';
import '../support/fake_sounds.dart';
import '../support/review_items.dart';

final DateTime _t0 = DateTime.utc(2026, 8, 27, 10);

/// Что игра получила при запуске.
GameLaunch? _lastLaunch;

/// Игра, которой в `lib/` нет: ей важно только то, что ей передали.
class _CaptureGame extends StatelessWidget {
  const _CaptureGame();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('игра'));
}

final GameEntry _entry = GameEntry(
  id: 'capture',
  title: 'Ловушка',
  build: (launch) {
    _lastLaunch = launch;
    return const _CaptureGame();
  },
);

Future<SharedPreferences> _pumpApp(
  WidgetTester tester, {
  required Sounds sounds,
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
      ports: AppPorts(
        cards: LeitnerPrefsStore(instance),
        streaks: StreakPrefsStore(instance),
        settings: SettingsPrefsStore(instance),
        sounds: sounds,
      ),
      seed: Ok(wordItems(3)),
      now: () => _t0,
      games: [_entry],
    ),
  );
  return instance;
}

Future<void> _play(WidgetTester tester) async {
  await tester.tap(find.byKey(AppKeys.play));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

String _doc({required bool soundOn}) => encodeSettings(
  AppSettings(enabled: false, at: const ReminderTime(20, 0), soundOn: soundOn),
);

void main() {
  testWidgets('звук включён — игра получает настоящий порт', (tester) async {
    final sounds = FakeSounds();
    await _pumpApp(
      tester,
      sounds: sounds,
      prefs: {SettingsPrefsStore.key: _doc(soundOn: true)},
    );

    await _play(tester);

    expect(_lastLaunch!.sounds, same(sounds));
  });

  testWidgets('звук выключен — игра получает нулевой объект', (tester) async {
    final sounds = FakeSounds();
    await _pumpApp(
      tester,
      sounds: sounds,
      prefs: {SettingsPrefsStore.key: _doc(soundOn: false)},
    );

    await _play(tester);

    expect(_lastLaunch!.sounds, isA<NoopSounds>());
    expect(
      sounds.played,
      isEmpty,
      reason: 'выключено значит «никто не зовёт», а не «зовут и молчат»',
    );
  });

  testWidgets('настройки не сохранены — звук включён по умолчанию', (
    tester,
  ) async {
    final sounds = FakeSounds();
    await _pumpApp(tester, sounds: sounds);

    await _play(tester);

    expect(_lastLaunch!.sounds, same(sounds));
  });

  // Испорченный документ означает «не знаем, что человек выбирал», а
  // умолчание у звука — включён. Отключить его из-за чужой поломки значило
  // бы наказать за неё игрока.
  testWidgets('битый документ настроек звук не отключает', (tester) async {
    final sounds = FakeSounds();
    await _pumpApp(
      tester,
      sounds: sounds,
      prefs: {SettingsPrefsStore.key: '{это не json'},
    );

    await _play(tester);

    expect(_lastLaunch!.sounds, same(sounds));
  });

  testWidgets('переключатель на экране настроек пишет выбор в документ', (
    tester,
  ) async {
    final prefs = await _pumpApp(
      tester,
      sounds: FakeSounds(),
      prefs: {SettingsPrefsStore.key: _doc(soundOn: true)},
    );

    await tester.tap(find.byKey(AppKeys.settings));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byKey(SettingsKeys.sound)).value,
      isTrue,
    );

    await tester.tap(find.byKey(SettingsKeys.sound));
    await tester.pumpAndSettle();

    expect(
      prefs.getString(SettingsPrefsStore.key),
      contains('"soundOn":false'),
    );
    expect(
      tester.widget<SwitchListTile>(find.byKey(SettingsKeys.sound)).value,
      isFalse,
    );
  });

  testWidgets('выбор доживает до следующей партии', (tester) async {
    final sounds = FakeSounds();
    await _pumpApp(
      tester,
      sounds: sounds,
      prefs: {SettingsPrefsStore.key: _doc(soundOn: true)},
    );

    await tester.tap(find.byKey(AppKeys.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SettingsKeys.sound));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _play(tester);

    expect(
      _lastLaunch!.sounds,
      isA<NoopSounds>(),
      reason:
          'настройка читается в момент запуска партии, а не при старте '
          'приложения',
    );
  });

  // Всё выше проверяло путь «настройка → GameLaunch» на подставной игре.
  // Здесь проверяется последнее звено: что **настоящая запись реестра**
  // отдаёт звук в игру. Мутация «sounds: const NoopSounds()» в билдере
  // проходила мимо всех тестов, потому что билдер никто не звал.
  testWidgets('запись реестра отдаёт звук настоящей игре', (tester) async {
    final sounds = FakeSounds();
    final session = FakeReviewSession(wordItems(3));
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: wordarcadeTheme(),
        home: ninjaSlashEntry.build(
          GameLaunch(
            session: session,
            summaryFooter: () => '',
            onPlayAgain: () {},
            onExit: () {},
            onRoundOver: () {},
            sounds: sounds,
          ),
        ),
      ),
    );
    await tester.pump(NinjaRun.windUpTime);
    await tester.pump(const Duration(seconds: 1));

    final field = tester.widget<NinjaField>(find.byType(NinjaField));
    final index = field.objects.indexWhere(
      (o) => o.label == wordTranslation(1),
    );
    final centre = tester.getCenter(find.byKey(NinjaKeys.objectAt(index)));
    final gesture = await tester.startGesture(centre - const Offset(60, 0));
    await gesture.moveTo(centre + const Offset(60, 0));
    await gesture.up();
    await tester.pump();

    expect(session.reports, hasLength(1), reason: 'рез состоялся');
    expect(sounds.played, [GameSound.slice]);
  });
}
