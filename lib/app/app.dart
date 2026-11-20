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
import 'dart:math';

import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/attribution_view.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/app/dictionary_view.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/app/learning_views.dart';
import 'package:arcadelingo/app/progress_view.dart';
import 'package:arcadelingo/app/settings_view.dart';
import 'package:arcadelingo/domain/challenges/challenge_session.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/events/app_event.dart';
import 'package:arcadelingo/domain/learning/learning_plan.dart';
import 'package:arcadelingo/domain/learning/mistake_review_observer.dart';
import 'package:arcadelingo/domain/ports/challenge_records.dart';
import 'package:arcadelingo/domain/ports/sounds.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/reminders/reminder_policy.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/session/observed_session.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/domain/streak/streak_view.dart';
import 'package:arcadelingo/domain/usecases/count_played_day.dart';
import 'package:arcadelingo/domain/usecases/start_session.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_choice_dialog.dart';
import 'package:arcadelingo/ui/reminder_labels.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:arcadelingo/ui/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Размер сессии из SPEC. Его задаёт хост: игра про эту цифру не знает и
/// заканчивает партию только по `nextItem() == null` и нулю жизней.
const int sessionTarget = 15;

class WordarcadeApp extends StatefulWidget {
  /// [seed] уже разобран: читать ассет — работа `loadWordsSeed`, а этому
  /// слою остаётся решить, что делать с результатом.
  ///
  /// [now] — шов для тестов, продакшн его не передаёт. Без него нельзя
  /// показать, что очередь строится в момент тапа, а не при старте.
  const WordarcadeApp({
    required this.ports,
    required this.seed,
    super.key,
    this.now = DateTime.now,
    this.games = wordarcadeGames,
    this.additionalDecks = const [],
    this.followSystemLocale = false,
  });

  /// Всё, что приложение получает снаружи (`app_ports.dart`).
  final AppPorts ports;

  final Result<List<ReviewItem>> seed;
  final DateTime Function() now;

  /// Что приложение умеет запускать. Умолчание — реестр из `games.dart`;
  /// тест подменяет список, чтобы проверить подключение второй игры.
  final List<GameEntry> games;
  final List<CourseDeck> additionalDecks;
  final bool followSystemLocale;

  @override
  State<WordarcadeApp> createState() => _WordarcadeAppState();
}

class _WordarcadeAppState extends State<WordarcadeApp>
    with WidgetsBindingObserver {
  late AppSettings _preferences = _readPreferences();

  AppSettings _readPreferences() => switch (widget.ports.settings?.load()) {
    Ok(:final value) => value,
    Err() || null => AppSettings.defaults,
  };

  InterfaceLanguage _resolveLanguage(InterfaceLanguage choice) {
    if (choice != InterfaceLanguage.system) return choice;
    if (!widget.followSystemLocale) return InterfaceLanguage.russian;
    for (final locale in WidgetsBinding.instance.platformDispatcher.locales) {
      final language = InterfaceLanguage.fromTag(locale.languageCode);
      if (language != InterfaceLanguage.system) return language;
    }
    return InterfaceLanguage.english;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (widget.followSystemLocale &&
        _preferences.interfaceLanguage == InterfaceLanguage.system) {
      setState(() {});
    }
  }

  void _reloadPreferences() {
    if (mounted) setState(() => _preferences = _readPreferences());
  }

  Future<bool> _saveCourse(StudyCourse course) async {
    final store = widget.ports.settings;
    final next = _readPreferences().copyWith(courseId: course.id);
    if (store != null && !await store.save(next)) return false;
    if (mounted) setState(() => _preferences = next);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final language = _resolveLanguage(_preferences.interfaceLanguage);
    final extras = widget.additionalDecks.where(
      (deck) =>
          deck.course.id != StudyCourse.englishFromRussianId &&
          deck.items.isNotEmpty,
    );
    final deck =
        extras
            .where((deck) => deck.course.id == _preferences.courseId)
            .firstOrNull;
    final paper = _preferences.theme == AppTheme.light;
    return MaterialApp(
      title: 'Arcadelingo',
      theme: wordarcadeTheme(
        brightness: paper ? Brightness.light : Brightness.dark,
      ),
      builder:
          (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: (paper
                    ? SystemUiOverlayStyle.dark
                    : SystemUiOverlayStyle.light)
                .copyWith(
                  systemNavigationBarColor:
                      Theme.of(context).colorScheme.surface,
                  systemNavigationBarIconBrightness:
                      paper ? Brightness.dark : Brightness.light,
                ),
            child: child!,
          ),
      debugShowCheckedModeBanner: false,
      locale: Locale(language.tag),
      supportedLocales: [
        for (final option in InterfaceLanguage.values)
          if (option != InterfaceLanguage.system) Locale(option.tag),
      ],
      localizationsDelegates: const [
        AppStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: switch (widget.seed) {
        Ok(:final value) => HomeScreen(
          ports: deck == null ? widget.ports : widget.ports.forDeck(deck),
          items: deck?.items ?? value,
          now: widget.now,
          games: widget.games,
          course: deck?.course ?? StudyCourse.englishFromRussian,
          courses: [
            StudyCourse.englishFromRussian,
            for (final extra in extras) extra.course,
          ],
          saveCourse: _saveCourse,
          onPreferencesChanged: _reloadPreferences,
          interfaceLanguage: language,
          resolveLanguage: _resolveLanguage,
        ),
        Err(:final failure) => SeedErrorView(message: failure.message),
      },
    );
  }
}

/// Стартовый экран и всё, что нужно, чтобы начать партию.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.ports,
    required this.items,
    required this.now,
    required this.games,
    this.course = StudyCourse.englishFromRussian,
    this.courses = const [StudyCourse.englishFromRussian],
    this.saveCourse,
    this.onPreferencesChanged,
    this.interfaceLanguage = InterfaceLanguage.russian,
    this.resolveLanguage,
    super.key,
  });

  final AppPorts ports;

  /// Словарь всех уровней. Выбранный уровень передаётся при старте партии.
  final List<ReviewItem> items;

  final DateTime Function() now;

  final List<GameEntry> games;

  final StudyCourse course;
  final List<StudyCourse> courses;
  final Future<bool> Function(StudyCourse)? saveCourse;
  final VoidCallback? onPreferencesChanged;
  final InterfaceLanguage interfaceLanguage;
  final InterfaceLanguage Function(InterfaceLanguage)? resolveLanguage;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedGameId;
  CefrLevel _selectedLevel = CefrLevel.a1;
  bool _preparingLearning = false;
  bool _selectingCourse = false;
  bool _selectingChallenge = false;

  GameEntry get _selectedGame => widget.games.firstWhere(
    (game) => game.id == _selectedGameId,
    orElse: () => widget.games.first,
  );

  void _selectGame(String id) => setState(() => _selectedGameId = id);

  bool get _hasWordsForLevel =>
      widget.items.any((item) => item.word.level == _selectedLevel);

  void _selectLevel(CefrLevel level) => setState(() => _selectedLevel = level);

  /// Серия глазами сегодняшнего дня; null — документ не читается.
  ///
  /// Не `state.current`, а пересчёт на сегодня: состояние знает последний
  /// **засчитанный** день и об оборванной серии само не узнает — в полночь
  /// у нас ничего не выполняется (`domain/streak/streak_view.dart`).
  ///
  /// Ошибка чтения здесь молчит намеренно: ритуал — украшение, громкой она
  /// станет на тапе «Играть», а экран ошибки при входе в приложение
  /// появлялся бы раньше, чем человек о чём-либо попросил.
  StreakView? _ritual;
  int _weekRequest = 0;

  /// Семь дней недели для полосы; null — журнал ещё читается.
  ///
  /// Отдельным полем и асинхронно, потому что источник другой: сыгранные дни
  /// знает журнал событий, а состояние серии помнит только длину текущей и
  /// ничего до её обрыва. Человек, игравший в понедельник и вторник,
  /// сорвавшийся в среду и вернувшийся в четверг, обязан увидеть галочки на
  /// понедельнике и вторнике — вывод из `current` показал бы там пусто.
  List<WeekDay>? _week;

  /// Причина, по которой не читается состояние; null — экран «Играть».
  Failure? _stateFailure;

  @override
  Widget build(BuildContext context) {
    final failure = _stateFailure;
    return failure == null
        ? PlayView(
          onPlay: _hasWordsForLevel ? _start : null,
          onLearn:
              _hasWordsForLevel && !_preparingLearning
                  ? () => _start(learning: true)
                  : null,
          onChallenge:
              _hasWordsForLevel &&
                      !_preparingLearning &&
                      widget.ports.challengeRecords != null &&
                      widget.games.isNotEmpty &&
                      _selectedGame.challenge != null
                  ? _openChallenge
                  : null,
          onProgress: _openProgress,
          onSettings: _openSettings,
          onSources: _openSources,
          ritual: _ritual,
          week: _week,
          games: widget.games,
          selectedGameId: widget.games.isEmpty ? null : _selectedGame.id,
          onGameSelected: _selectGame,
          selectedLevel: _selectedLevel,
          levels:
              widget.course.id == StudyCourse.englishFromRussianId
                  ? CefrLevel.values
                  : _availableLevels,
          onLevelSelected: _selectLevel,
          course: widget.course,
          onCourseSelected: widget.saveCourse == null ? null : _openCourses,
        )
        : StateErrorView(message: failure.message, onReset: _reset);
  }

  Future<void> _openCourses() async {
    if (_selectingCourse) return;
    _selectingCourse = true;
    try {
      final strings = context.strings;
      final selected = await showArcadeChoice<StudyCourse>(
        context,
        title: strings.chooseCourse,
        choices: widget.courses,
        selected: widget.course,
        label: strings.courseName,
        optionKey: (course) => ValueKey('course.${course.id}'),
      );
      if (!mounted || selected == null) return;
      final saved = await widget.saveCourse!(selected);
      if (!saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.settingsSaveFailed)),
        );
      }
    } finally {
      _selectingCourse = false;
    }
  }

  /// Тап «Источники»: показать содержимое `assets/ATTRIBUTION.md`.
  ///
  /// Маршрутом, а не заменой домашнего экрана: стрелка «назад» в `AppBar`
  /// достаётся даром, и уйти с экрана можно всегда.
  /// Тап «Прогресс»: показать, сколько пройдено за всё время.
  ///
  /// Маршрутом, как и «Источники»: стрелка «назад» в `AppBar` достаётся
  /// даром, и уйти с экрана можно всегда.
  void _openProgress() {
    final navigator = Navigator.of(context);
    final favorites = widget.ports.favorites;
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder:
              (context) => ProgressScreen(
                answers: widget.ports.answers,
                cards: widget.ports.cards,
                streaks: widget.ports.streaks,
                now: widget.now,
                onDictionary:
                    favorites == null
                        ? null
                        : () {
                          unawaited(
                            navigator.push(
                              MaterialPageRoute<void>(
                                builder:
                                    (context) => DictionaryScreen(
                                      items: widget.items,
                                      level: _selectedLevel,
                                      answers: widget.ports.answers,
                                      favorites: favorites,
                                      speech: widget.ports.speech,
                                      studyLanguage:
                                          widget.course.studyLanguage,
                                      gameTitles: {
                                        for (final game in widget.games)
                                          game.id: game.titleFor(
                                            context.strings,
                                          ),
                                      },
                                    ),
                              ),
                            ),
                          );
                        },
              ),
        ),
      ),
    );
  }

  /// Тап «Настройки»: единственная настройка — напоминание.
  ///
  /// Экрана нет, если хост не дал стор настроек: тесты, которые о них не
  /// знают, кнопку не увидят вовсе.
  void _openSettings() {
    final store = widget.ports.settings;
    if (store == null) {
      return;
    }
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder:
              (context) =>
                  SettingsScreen(store: store, onApply: _applySettings),
        ),
      ),
    );
  }

  /// Применяет выбор человека: спрашивает разрешение, сохраняет, ставит или
  /// снимает напоминание.
  ///
  /// Возвращает `false`, если система не дала разрешения: экран настроек
  /// обязан это показать, а не притвориться, что переключатель включился.
  /// Разрешение спрашивается ровно здесь — в момент, когда человек попросил
  /// напоминания, и нигде больше.
  Future<bool> _applySettings(AppSettings next) async {
    final store = widget.ports.settings;
    if (store == null) return false;
    final previous = switch (store.load()) {
      Ok(:final value) => value,
      Err() => AppSettings.defaults,
    };
    final reminderChanged =
        previous.enabled != next.enabled || previous.at != next.at;
    if (next.enabled &&
        reminderChanged &&
        !await widget.ports.askReminderPermission()) {
      return false;
    }
    if (!await store.save(next)) return false;
    widget.onPreferencesChanged?.call();
    if (previous.theme != next.theme &&
        previous.copyWith(theme: next.theme) == next) {
      return true;
    }
    final language =
        widget.resolveLanguage?.call(next.interfaceLanguage) ??
        widget.interfaceLanguage;
    await _rescheduleReminder(next, language: language);
    return true;
  }

  /// Ставит напоминание по текущему состоянию или снимает его.
  ///
  /// Зовётся на открытии приложения и после каждой партии: повод считается
  /// на день срабатывания, и чем свежее расписание, тем меньше шансов, что
  /// уведомление скажет про серию, которой уже нет.
  Future<void> _rescheduleReminder(
    AppSettings settings, {
    InterfaceLanguage? language,
  }) async {
    final streak = switch (widget.ports.streaks.load()) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (streak == null) return;
    final plan = planReminder(
      settings: settings,
      streak: streak,
      now: widget.now(),
    );
    if (plan == null) {
      await widget.ports.reminders.cancelAll();
      _record(AppEventKind.reminderScheduled);
      return;
    }
    final (title, body) = reminderText(
      plan,
      strings: AppStrings(language ?? widget.interfaceLanguage),
    );
    await widget.ports.reminders.schedule(
      at: plan.at,
      title: title,
      body: body,
    );
    _record(AppEventKind.reminderScheduled);
  }

  /// Перепланирует по тому, что лежит в хранилище настроек.
  void _refreshReminder() {
    final store = widget.ports.settings;
    if (store == null) {
      return;
    }
    final settings = switch (store.load()) {
      Ok(:final value) => value,
      Err() => AppSettings.defaults,
    };
    unawaited(_rescheduleReminder(settings));
  }

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
    _selectFirstAvailableLevel();
    _refreshRitual();
    // «Открыл приложение» — здесь, а не в `main.dart`: оттуда событие не
    // увидел бы ни один тест, а проводку без приборов проверять нечем.
    // Цена решения названа: на битом сиде домашнего экрана не существует, и
    // события не будет. Битый сид — дефект сборки, играть всё равно нечем.
    _record(AppEventKind.appOpen);
    _refreshReminder();
  }

  List<CefrLevel> get _availableLevels {
    final available = widget.items.map((item) => item.word.level).toSet();
    return CefrLevel.values.where(available.contains).toList();
  }

  void _selectFirstAvailableLevel() {
    _selectedLevel = _availableLevels.firstOrNull ?? CefrLevel.a1;
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.course.id != widget.course.id) {
      _selectFirstAvailableLevel();
      _stateFailure = null;
      _week = null;
      _refreshRitual();
      _refreshReminder();
    }
  }

  /// Пишет событие часами хоста и не ждёт записи.
  ///
  /// `unawaited` по той же причине, что у карточек и серии: обработчики
  /// синхронны, ждать их некому. Потерянная при убийстве приложения строка —
  /// это потерянное наблюдение, а не потерянный прогресс.
  void _record(AppEventKind kind, {String? sessionId}) {
    unawaited(
      widget.ports.events.append(
        AppEvent.at(kind, widget.now(), sessionId: sessionId),
      ),
    );
  }

  /// Перечитывает серию и пересчитывает её на сегодня.
  ///
  /// Тихо глотает [Err] — и только здесь. Это украшение: битый документ
  /// станет громким на тапе «Играть», где usecase вернёт причину и человек
  /// увидит экран ошибки. Падать при входе в приложение, до того как он о
  /// чём-либо попросил, было бы хуже.
  void _refreshRitual() {
    final today = StreakDay.of(widget.now());
    final state = switch (widget.ports.streaks.load()) {
      Ok(:final value) => value,
      Err() => null,
    };
    setState(() => _ritual = state == null ? null : streakAsOf(state, today));
    final request = ++_weekRequest;
    if (state != null) unawaited(_refreshWeek(state, today, request));
  }

  /// Собирает полосу недели: сыгранные дни — из журнала, замороженный — из
  /// состояния.
  ///
  /// Журнал ведётся с Этапа 3.2, и дни до него в полосе пусты, сколько бы их
  /// ни было сыграно. Восстанавливать их неоткуда, и притворяться, что
  /// можно, хуже, чем показать пустой кружок (`SPEC.md`).
  Future<void> _refreshWeek(
    StreakState state,
    StreakDay today,
    int request,
  ) async {
    var monday = today;
    while (monday.weekday != DateTime.monday) {
      monday = monday.previous;
    }
    var sunday = monday;
    for (var i = 0; i < 6; i++) {
      sunday = sunday.next;
    }
    final played = await widget.ports.events.daysWith(
      kind: AppEventKind.roundOver,
      from: monday,
      to: sunday,
    );
    if (!mounted || request != _weekRequest) return;
    setState(() {
      _week = weekStrip(
        today: today,
        played: played,
        frozen: state.lastFrozenDay,
      );
    });
  }

  /// Партия кончилась: записать событие и засчитать день.
  ///
  /// Один путь на все концы партии — итоги, потерянные жизни и «на сегодня
  /// всё». Разводить их значило бы завести второе правило «что считается
  /// сыгранным днём», а второе правило однажды разойдётся с первым.
  void _finishRound(String? sessionId) {
    _record(AppEventKind.roundOver, sessionId: sessionId);
    final counted =
        CountPlayedDay(streaks: widget.ports.streaks, now: widget.now)();
    if (counted case Err(:final failure)) {
      // Досюда добраться нечем: документ читался при старте партии. Но если
      // добрались — молчать хуже, чем показать причину, когда человек
      // вернётся с итогов на домашний экран.
      setState(() => _stateFailure = failure);
    }
    // Серия изменилась — значит изменился и повод напоминания: сегодня уже
    // сыграно, звать сегодня незачем.
    _refreshReminder();
  }

  Future<void> _openChallenge() async {
    if (_selectingCourse || _selectingChallenge || _preparingLearning) return;
    final game = _selectedGame;
    final mode = game.challenge;
    final records = widget.ports.challengeRecords;
    if (mode == null || records == null) return;

    final course = widget.course;
    final items = widget.items;
    final key = (gameId: game.id, courseId: course.id, level: _selectedLevel);
    final best = records.load(key, mode: game.challengeRecordMode);
    _selectingChallenge = true;
    try {
      final start = await showChallengeDialog(
        context,
        game: game,
        mode: mode,
        course: course,
        level: key.level,
        best: best,
      );
      if (start == true && mounted) {
        _launchChallenge(game, mode, key, items, records);
      }
    } finally {
      _selectingChallenge = false;
    }
  }

  void _launchChallenge(
    GameEntry game,
    ArcadeChallenge mode,
    ChallengeKey key,
    List<ReviewItem> items,
    ChallengeRecords records,
  ) {
    final now = widget.now();
    final mistakes = MistakeReviewObserver(level: key.level);
    final session = ObservedSession(
      inner: ChallengeSession(
        items: items,
        level: key.level,
        random: Random(now.microsecondsSinceEpoch),
        limit: mode.wordLimit,
      ),
      observers: [mistakes],
      now: widget.now,
      gameId: game.id,
      sessionId: now.toIso8601String(),
    );
    _record(AppEventKind.roundStart, sessionId: session.sessionId);
    _play(
      game,
      session,
      () => '',
      mistakes: mistakes,
      level: key.level,
      learning: false,
      replayChallenge: () => _launchChallenge(game, mode, key, items, records),
      onChallengeComplete:
          (score) => ChallengeRecordLine(
            best: records.submit(key, score, mode: game.challengeRecordMode),
          ),
    );
  }

  /// Тап «Играть»: собрать партию и показать её.
  ///
  /// Вся проводка — в usecase; здесь остаётся только навигация и разбор
  /// результата. Это и было целью Этапа 1: «после ответа серия продлилась»
  /// проверяется без дерева виджетов.
  void _start({
    bool learning = false,
    GameEntry? chosenGame,
    CefrLevel? chosenLevel,
  }) {
    if (!_hasWordsForLevel ||
        _preparingLearning ||
        _selectingCourse ||
        _selectingChallenge) {
      return;
    }
    if (widget.games.isEmpty) {
      throw StateError('реестр игр пуст: запускать нечего');
    }
    unawaited(
      _startRound(
        learning: learning,
        game: chosenGame ?? _selectedGame,
        level: chosenLevel ?? _selectedLevel,
      ),
    );
  }

  Future<void> _startRound({
    required bool learning,
    required GameEntry game,
    required CefrLevel level,
  }) async {
    // Последнее состояние, приехавшее из сессии: по нему считается строка
    // итогов. До первого ответа это то, что прочитано из хранилища.
    var latest = <String, LeitnerCard>{};
    var roundItems = widget.items;
    if (learning) {
      switch (widget.ports.cards.load()) {
        case Err(:final failure):
          setState(() => _stateFailure = failure);
          return;
        case Ok(:final value):
          latest = value;
          final plan = LearningPlan.build(
            items: widget.items,
            cards: value,
            level: level,
            now: widget.now(),
            target: sessionTarget,
          );
          roundItems = plan.selectedItems;
          if (plan.newWords.isNotEmpty) {
            setState(() => _preparingLearning = true);
            final start = await Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(
                builder:
                    (context) => WordIntroductionScreen(
                      words: plan.newWords,
                      level: level,
                      speech: widget.ports.speech,
                      studyLanguage: widget.course.studyLanguage,
                      onStart: () => Navigator.of(context).pop(true),
                    ),
              ),
            );
            if (!mounted) return;
            setState(() => _preparingLearning = false);
            if (start != true) return;
          }
      }
    }
    final mistakes = MistakeReviewObserver(level: level);
    final started = StartSession(
      cards: widget.ports.cards,
      streaks: widget.ports.streaks,
      now: widget.now,
      target: sessionTarget,
      answerLog: widget.ports.answers,
    )(
      items: roundItems,
      level: level,
      gameId: game.id,
      onCardsChanged: (changed) => latest = changed,
      observers: [mistakes],
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
        _play(
          game,
          value,
          () => _footer(latest, level),
          mistakes: mistakes,
          level: level,
          learning: learning,
        );
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
    await widget.ports.cards.reset();
    await widget.ports.streaks.reset();
    if (!mounted) return;
    setState(() => _stateFailure = null);
    _refreshRitual();
    _start();
  }

  void _play(
    GameEntry game,
    ReviewSession session,
    String Function() footer, {
    required MistakeReviewObserver mistakes,
    required CefrLevel level,
    required bool learning,
    VoidCallback? replayChallenge,
    Widget Function(int score)? onChallengeComplete,
  }) {
    final navigator = Navigator.of(context);
    final settings = switch (widget.ports.settings?.load()) {
      Ok(value: final it) => it,
      Err() || null => AppSettings.defaults,
    };
    final records = widget.ports.challengeRecords;
    final recordKey = (
      gameId: game.id,
      courseId: widget.course.id,
      level: level,
    );
    final sessionId = session is ObservedSession ? session.sessionId : null;
    // Дошла ли партия до конца. По нему же отличается «бросил на середине»:
    // ухода игра не сообщает, и не сообщать — правильно, потому что
    // отсутствие конца и есть весь признак.
    var finished = false;

    // Сессия, пустая с самого начала: игра покажет «на сегодня всё». Это
    // тоже законченный раунд — человек пришёл и сделал всё, что система
    // позволила, а разложенный по коробкам Лейтнер делает такие дни
    // неизбежными. Серия, наказывающая за прилежность, — сломанная серия.
    if (session.isFinished) {
      finished = true;
      _finishRound(sessionId);
    }

    unawaited(
      navigator
          .push(
            MaterialPageRoute<void>(
              builder:
                  (context) => game.build(
                    GameLaunch(
                      session: session,
                      course: widget.course,
                      level: level,
                      vocabulary: widget.items
                          .map((item) => item.word)
                          .where((word) => word.level == level),
                      summaryFooter: footer,
                      onPlayAgain: () {
                        navigator.pop();
                        if (replayChallenge != null) {
                          replayChallenge();
                          return;
                        }
                        _start(
                          learning: learning,
                          chosenGame: game,
                          chosenLevel: level,
                        );
                      },
                      onExit: navigator.pop,
                      onChallengeComplete: onChallengeComplete,
                      onRoundScore:
                          onChallengeComplete == null &&
                                  game.tracksRoundScore &&
                                  records != null
                              ? (score) => ChallengeRecordLine(
                                best: records.submit(recordKey, score),
                              )
                              : null,
                      mistakeCount: () => mistakes.mistakes.length,
                      onReviewMistakes: () {
                        unawaited(
                          navigator.push(
                            MaterialPageRoute<void>(
                              builder:
                                  (context) => MistakesReviewScreen(
                                    words: mistakes.mistakes,
                                    outcomes: mistakes.outcomes,
                                    level: level,
                                    speech: widget.ports.speech,
                                    studyLanguage: widget.course.studyLanguage,
                                  ),
                            ),
                          ),
                        );
                      },
                      onRoundOver: () {
                        finished = true;
                        _finishRound(sessionId);
                      },
                      // Выключённый звук приходит в игру нулевым объектом,
                      // а не флагом: «выключено» тогда значит «никто не
                      // зовёт», а не «зовут и молчат». Настройка читается в
                      // момент запуска партии — ровно как очередь слов.
                      sounds:
                          settings.soundOn
                              ? widget.ports.sounds
                              : const NoopSounds(),
                      speech:
                          settings.soundOn
                              ? widget.ports.speech
                              : const NoopWordSpeech(),
                    ),
                  ),
            ),
          )
          .then((_) {
            if (!mounted) return;
            if (!finished) {
              _record(AppEventKind.roundAbandon, sessionId: sessionId);
            }
            // Вернулись с партии: серия могла продлиться.
            _refreshRitual();
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
  String _footer(Map<String, LeitnerCard> cards, CefrLevel level) {
    final now = widget.now();
    var fresh = false;
    for (final item in widget.items) {
      if (item.word.level != level) continue;
      final card = cards[item.word.id];
      if (card == null) {
        fresh = true;
      } else if (!card.due.isAfter(now)) {
        return context.strings.wordsReady;
      }
    }
    return fresh
        ? context.strings.dailyWordsDone
        : context.strings.comeBackTomorrow;
  }
}
