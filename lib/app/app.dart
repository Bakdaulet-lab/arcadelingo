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
import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/domain/ports/streak_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/session/leitner_review_session.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_game.dart';
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
  });

  final LeitnerPrefsStore store;

  /// Второй документ прогресса. Портом, а не конкретным стором: корень —
  /// единственное место, которое знает и о `data/`, и о `domain/`.
  final StreakStore streakStore;
  final Result<List<ReviewItem>> seed;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wordarcade',
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
    super.key,
  });

  final LeitnerPrefsStore store;

  final StreakStore streakStore;

  /// Сид целиком: сессия сама решает, что из него взять.
  final List<ReviewItem> items;

  final DateTime Function() now;

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

  /// Тап «Играть»: прочитать состояние и начать партию.
  void _start() {
    switch (widget.store.load()) {
      case Ok(:final value):
        _play(value);
      case Err(:final failure):
        setState(() => _stateFailure = failure);
    }
  }

  /// Единственный в приложении вызов [LeitnerPrefsStore.reset] — и тот по
  /// нажатию человека. Сразу после сброса пробуем снова: повторный тап
  /// «Играть» ничего не добавил бы.
  Future<void> _reset() async {
    await widget.store.reset();
    if (!mounted) return;
    setState(() => _stateFailure = null);
    _start();
  }

  void _play(Map<String, LeitnerCard> cards) {
    // Последнее состояние, приехавшее из сессии: по нему считается строка
    // итогов. До первого ответа это то, что прочитано из хранилища.
    var latest = cards;
    final session = LeitnerReviewSession.start(
      cards: cards,
      items: widget.items,
      target: sessionTarget,
      now: widget.now,
      onCardsChanged: (changed) {
        latest = changed;
        // Ответ уже принят, ждать записи некому: report() не async, а
        // save() кодирует состояние синхронно, до первого await.
        unawaited(widget.store.save(changed));
      },
    );
    final navigator = Navigator.of(context);
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder:
              (context) => FallingWordsGame(
                session: session,
                summaryFooter: () => _footer(latest),
                onPlayAgain: () {
                  navigator.pop();
                  _start();
                },
                onExit: navigator.pop,
              ),
        ),
      ),
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
