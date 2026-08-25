/// Композиционный корень: здесь, и только здесь, хранилище, сид, часы и
/// игра соединяются друг с другом.
///
/// Два `Result` разбираются по отдельности, и это решение 0.6, а не
/// экономия кода: реакция на них разная. Битый сид — дефект сборки, играть
/// нечем, и дальше стартового экрана приложение не идёт. Битое состояние —
/// повод показать причину и предложить сброс, который нажимает пользователь:
/// автосброса в коде нет, молчаливый сброс уничтожил бы улики
/// (`lib/data/srs/leitner_prefs_store.dart`). Склейка двух `Result` в один
/// стёрла бы, что именно упало.
///
/// Сессия создаётся по тапу «Играть», а не при старте приложения: очередь
/// собирается на `now()`, и приложение, оставленное на стартовом экране до
/// полуночи, играло бы по вчерашней очереди.
library;

import 'dart:async';

import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/attribution_view.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/events/app_event.dart';
import 'package:arcadelingo/domain/ports/answer_log.dart';
import 'package:arcadelingo/domain/ports/event_log.dart';
import 'package:arcadelingo/domain/ports/streak_store.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/observed_session.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/usecases/start_session.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

/// Размер сессии из SPEC. Его задаёт хост: игра про эту цифру не знает и
/// заканчивает партию только по `nextItem() == null` и нулю жизней.
const int sessionTarget = 15;

class WordarcadeApp extends StatelessWidget {
  /// [seed] уже разобран: читать ассет — работа `loadWordsSeed`, а этому
  /// слою остаётся решить, что делать с результатом.
  ///
  /// [now] — шов для тестов, продакшн его не передаёт. Без него нельзя
  /// показать, что очередь строится в момент тапа, а не при старте.
  const WordarcadeApp({
    required this.store,
    required this.streakStore,
    required this.seed,
    super.key,
    this.now = DateTime.now,
    this.games = wordarcadeGames,
    this.answerLog = const NoopAnswerLog(),
    this.eventLog = const NoopEventLog(),
  });

  final LeitnerPrefsStore store;

  /// Второй документ прогресса. Портом, а не конкретным стором: корень —
  /// единственное место, которое знает и о `data/`, и о `domain/`.
  final StreakStore streakStore;
  final Result<List<ReviewItem>> seed;
  final DateTime Function() now;

  /// Что приложение умеет запускать. Умолчание — реестр из `games.dart`;
  /// тест подменяет список, чтобы проверить подключение второй игры.
  final List<GameEntry> games;

  /// История ответов. Умолчание — нулевой объект: приложение полноценно и
  /// без неё, а тесты, которые о журнале не знают, о нём и не узнают.
  /// Настоящий журнал подключает `main.dart` — корень знает и о `data/`.
  final AnswerLog answerLog;

  /// История событий: открыл, начал, доиграл, бросил. Тоже с нулевым
  /// объектом умолчанием — приложение полноценно и без приборов.
  final EventLog eventLog;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Подпись в списке недавних задач Android. Это тоже отображаемое имя
      // приложения, просто второе: под иконкой стоит @string/app_name.
      title: 'Arcadelingo',
      theme: wordarcadeTheme(),
      // Баннер перекрывает верхний правый угол, где живёт счёт, и попадал бы
      // в каждый голден (задача 0.9). Пользы от него нет и в отладке: то,
      // что сборка отладочная, видно по фреймтаймам.
      debugShowCheckedModeBanner: false,
      home: switch (seed) {
        Ok(:final value) => HomeScreen(
          store: store,
          streakStore: streakStore,
          items: value,
          now: now,
          games: games,
          answerLog: answerLog,
          eventLog: eventLog,
        ),
        Err(:final failure) => SeedErrorView(message: failure.message),
      },
    );
  }
}

/// Стартовый экран и всё, что нужно, чтобы начать партию.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.store,
    required this.streakStore,
    required this.items,
    required this.now,
    required this.games,
    required this.answerLog,
    required this.eventLog,
    super.key,
  });

  final LeitnerPrefsStore store;

  final StreakStore streakStore;

  /// Сид целиком: сессия сама решает, что из него взять.
  final List<ReviewItem> items;

  final DateTime Function() now;

  final List<GameEntry> games;

  final AnswerLog answerLog;

  final EventLog eventLog;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Сколько дней подряд человек играл; null — серии нет или документ не
  /// читается. Строка — украшение, и ошибка чтения здесь молчит намеренно:
  /// громкой она станет на тапе «Играть», а экран ошибки при входе в
  /// приложение появлялся бы раньше, чем человек о чём-либо попросил.
  int? _streakDays;

  /// Причина, по которой не читается состояние; null — экран «Играть».
  Failure? _stateFailure;

  @override
  Widget build(BuildContext context) {
    final failure = _stateFailure;
    return failure == null
        ? PlayView(
          onPlay: _start,
          onSources: _openSources,
          streakDays: _streakDays,
        )
        : StateErrorView(message: failure.message, onReset: _reset);
  }

  /// Тап «Источники»: показать содержимое `assets/ATTRIBUTION.md`.
  ///
  /// Маршрутом, а не заменой домашнего экрана: стрелка «назад» в `AppBar`
  /// достаётся даром, и уйти с экрана можно всегда.
  void _openSources() {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => const AttributionScreen(),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _refreshStreak();
    // «Открыл приложение» — здесь, а не в `main.dart`: оттуда событие не
    // увидел бы ни один тест, а проводку без приборов проверять нечем.
    // Цена решения названа: на битом сиде домашнего экрана не существует, и
    // события не будет. Битый сид — дефект сборки, играть всё равно нечем.
    _record(AppEventKind.appOpen);
  }

  /// Пишет событие часами хоста и не ждёт записи.
  ///
  /// `unawaited` по той же причине, что у карточек и серии: обработчики
  /// синхронны, ждать их некому. Потерянная при убийстве приложения строка —
  /// это потерянное наблюдение, а не потерянный прогресс.
  void _record(AppEventKind kind, {String? sessionId}) {
    unawaited(
      widget.eventLog.append(
        AppEvent.at(kind, widget.now(), sessionId: sessionId),
      ),
    );
  }

  /// Перечитывает серию для строки на экране.
  ///
  /// Тихо глотает [Err] — и только здесь. Это украшение: битый документ
  /// станет громким на тапе «Играть», где usecase вернёт причину и человек
  /// увидит экран ошибки. Падать при входе в приложение, до того как он о
  /// чём-либо попросил, было бы хуже.
  void _refreshStreak() {
    final days = switch (widget.streakStore.load()) {
      Ok(:final value) => value.current,
      Err() => 0,
    };
    setState(() => _streakDays = days > 0 ? days : null);
  }

  /// Тап «Играть»: собрать партию и показать её.
  ///
  /// Вся проводка — в usecase; здесь остаётся только навигация и разбор
  /// результата. Это и было целью Этапа 1: «после ответа серия продлилась»
  /// проверяется без дерева виджетов.
  void _start() {
    // Последнее состояние, приехавшее из сессии: по нему считается строка
    // итогов. До первого ответа это то, что прочитано из хранилища.
    var latest = <String, LeitnerCard>{};
    // Первая из реестра: экрана выбора пока нет, а порядок в списке значим.
    // Пустой реестр — дефект сборки, и молчать о нём хуже, чем упасть.
    if (widget.games.isEmpty) {
      throw StateError('реестр игр пуст: запускать нечего');
    }
    final game = widget.games.first;
    final started = StartSession(
      cards: widget.store,
      streaks: widget.streakStore,
      now: widget.now,
      target: sessionTarget,
      answerLog: widget.answerLog,
    )(
      items: widget.items,
      gameId: game.id,
      onCardsChanged: (changed) => latest = changed,
    );
    switch (started) {
      case Ok(:final value):
        // Партия считается начатой, когда она собралась: экран ошибки — не
        // начало. Ключ берётся у самой сессии, чтобы у события и у её
        // ответов он был один, а не посчитан дважды.
        _record(
          AppEventKind.roundStart,
          sessionId: value is ObservedSession ? value.sessionId : null,
        );
        _play(game, value, () => _footer(latest));
      case Err(:final failure):
        setState(() => _stateFailure = failure);
    }
  }

  /// Единственный в приложении вызов [LeitnerPrefsStore.reset] — и тот по
  /// нажатию человека. Сразу после сброса пробуем снова: повторный тап
  /// «Играть» ничего не добавил бы.
  /// Сбрасывает **оба** документа прогресса. Серия — это прогресс, и
  /// оставить её после «Сбросить прогресс» значило бы сбросить наполовину.
  Future<void> _reset() async {
    await widget.store.reset();
    await widget.streakStore.reset();
    if (!mounted) return;
    setState(() => _stateFailure = null);
    _refreshStreak();
    _start();
  }

  void _play(GameEntry game, ReviewSession session, String Function() footer) {
    final navigator = Navigator.of(context);
    unawaited(
      navigator
          .push(
            MaterialPageRoute<void>(
              builder:
                  (context) => game.build(
                    GameLaunch(
                      session: session,
                      summaryFooter: footer,
                      onPlayAgain: () {
                        navigator.pop();
                        _start();
                      },
                      onExit: navigator.pop,
                    ),
                  ),
            ),
          )
          .then((_) {
            // Вернулись с партии: серия могла продлиться.
            if (mounted) _refreshStreak();
          }),
    );
  }

  /// Что писать под статистикой итогов.
  ///
  /// Считает хост, а не игра: игра не знает ни сида, ни размера сессии.
  /// Отвеченные в этом раунде слова из подсчёта НЕ исключаются — и это
  /// главное здесь. Промах отправляет карточку в коробку 1 с `due == now`:
  /// слово честно готово прямо сейчас, следующий раунд его покажет, и
  /// «Возвращайся завтра» было бы ложью ровно наоборот. Верные ответы
  /// уходят в коробку 2 и выше, со сроком от суток, и из «готовых»
  /// выпадают сами.
  String _footer(Map<String, LeitnerCard> cards) {
    final now = widget.now();
    var fresh = false;
    for (final item in widget.items) {
      final card = cards[item.word.id];
      if (card == null) {
        fresh = true;
      } else if (!card.due.isAfter(now)) {
        return 'Ещё есть слова — сыграй ещё раунд';
      }
    }
    return fresh ? 'Слова на сегодня кончились' : 'Возвращайся завтра';
  }
}
