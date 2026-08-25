// Проводка журнала от корня до БД.
//
// Чистые тесты доказали каждое звено по отдельности: проекция события,
// наблюдатель, хранилище, переигровка. Здесь проверяется единственное, чего
// они не видят, — что корень действительно отдаёт журнал вниз. Мутация
// «`WordarcadeApp` не передаёт `answerLog` в `HomeScreen`» краснеет только
// тут: ниже по течению всё продолжает работать на нулевом объекте.
//
// Игра — фейковая, из одной кнопки: настоящая привела бы сюда падение,
// таймеры и подсветку, а вопрос теста к игре отношения не имеет.
//
// Чтение журнала идёт через `tester.runAsync`, и это не церемония. В
// widget-тесте время фальшивое: `Future.delayed` и работа драйвера БД ждут
// `pump()`, а `pumpEventQueue()` в таком окружении просто виснет — проверено.
// `runAsync` пускает настоящий цикл событий, единственный, в котором sqlite
// успевает ответить. Тот же шов и та же причина, что у чтения ассета в 0.14.

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/data/log/drift_answer_log.dart';
import 'package:arcadelingo/data/log/history_database.dart';
import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/data/streak/streak_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/review_items.dart';
import '../support/sqlite_for_tests.dart';

final DateTime _t0 = DateTime.utc(2026, 8, 25, 10);

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
  setUpAll(useTestSqlite);

  late HistoryDatabase db;

  setUp(() {
    db = HistoryDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> pumpApp(
    WidgetTester tester, {
    required DriftAnswerLog log,
  }) async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      WordarcadeApp(
        ports: AppPorts(
          cards: LeitnerPrefsStore(prefs),
          streaks: StreakPrefsStore(prefs),
          answers: log,
        ),
        seed: Ok(wordItems(3)),
        now: () => _t0,
        games: [_entry],
      ),
    );
  }

  testWidgets('ответ в игре доезжает до строки в БД', (tester) async {
    final log = DriftAnswerLog(db);
    await pumpApp(tester, log: log);

    await tester.tap(find.byKey(AppKeys.play));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(_OneTapGame.answer));
    await tester.pump();

    final all = (await tester.runAsync(log.all))!;
    expect(all, hasLength(1));
    expect(all.single.wordId, wordId(1));
    expect(
      all.single.gameId,
      'one_tap',
      reason: 'id пришёл из записи реестра, а не из константы',
    );
  });

  testWidgets('без ответов журнал пуст', (tester) async {
    final log = DriftAnswerLog(db);
    await pumpApp(tester, log: log);

    await tester.tap(find.byKey(AppKeys.play));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(await tester.runAsync(log.all), isEmpty);
  });
}
