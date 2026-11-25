/// Реестр игр: что вообще умеет запускать приложение.
///
/// Живёт в композиционном корне, и это единственное место, которое знает
/// обо всех играх сразу. Сами игры друг о друге не знают — это пункт 5
/// «Архитектурного закона», и его сторожит `arch_check.sh`.
///
/// Смысл реестра — сделать проверяемым обещание Фазы 2: вторую игру можно
/// добавить, не трогая ядро. Добавление сводится к одной записи здесь;
/// `lib/domain/` и первая игра при этом не меняются ни на строку, и это
/// доказывается пустым `git diff`, а не словами.
///
/// Экрана выбора игры тут нет: он появляется на Этапе 4.4 и живёт на
/// домашнем экране, а не здесь. Реестр отвечает на «что можно запустить», а
/// не на «что выбрал человек».
library;

import 'package:arcadelingo/domain/challenges/challenge_session.dart';
import 'package:arcadelingo/domain/ports/sounds.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/brick_breaker/brick_breaker_game.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_game.dart';
import 'package:arcadelingo/features/games/match_three/match_three_game.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_game.dart';
import 'package:arcadelingo/features/games/snake/snake_game.dart';
import 'package:arcadelingo/features/games/word_mahjong/word_mahjong_game.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:flutter/material.dart';

/// Всё, что игре нужно от хоста, одним значением.
///
/// Игра не знает ни про хранилище, ни про размер сессии, ни про то, что
/// будет после выхода: она получает готовую [ReviewSession] и три способа
/// сказать хосту, что партия кончилась.
class GameLaunch {
  const GameLaunch({
    required this.session,
    required this.summaryFooter,
    required this.onPlayAgain,
    required this.onExit,
    required this.onRoundOver,
    this.sounds = const NoopSounds(),
    this.mistakeCount,
    this.onReviewMistakes,
    this.onChallengeComplete,
    this.onRoundScore,
    this.speech = const NoopWordSpeech(),
    this.listeningMode = false,
    this.course,
    this.level,
    this.vocabulary = const [],
  });

  /// Сессия, уже собранная usecase'ом и обёрнутая наблюдателями.
  final ReviewSession session;
  final StudyCourse? course;
  final CefrLevel? level;
  final Iterable<Word> vocabulary;

  /// Строка «что дальше» на итогах; считает её хост.
  final String Function() summaryFooter;

  /// «Ещё раз»: новую партию строит хост.
  final VoidCallback onPlayAgain;

  /// «Выйти» с экранов конца партии.
  final VoidCallback onExit;

  /// Число разных слов с ошибками; хост читает его после ответов партии.
  final int Function()? mistakeCount;

  /// Открыть разбор, не создавая новую игровую сессию.
  final VoidCallback? onReviewMistakes;
  final Widget Function(int score)? onChallengeComplete;
  final Widget Function(int score)? onRoundScore;
  final WordSpeech speech;
  final bool listeningMode;

  /// Партия дошла до конца: игра показала экран итогов или «жизни кончились».
  ///
  /// **Обязательный шаг ритуала.** День серии засчитывает законченная партия,
  /// а выход на восьмом слове днём не считается, — и узнать о конце раунда
  /// хост может только от игры: жизни живут внутри неё.
  ///
  /// Отклонённая альтернатива записана вместе с причиной: считать конец
  /// снаружи, по трём событиям с `correct == false` в одной партии, дешевле
  /// сегодня, но дублирует правило жизней вне игры и начнёт врать молча в
  /// день, когда жизней станет пять.
  ///
  /// Зовётся **ровно один раз** за партию, в момент показа экрана конца.
  /// Уход с середины — не конец: там игра докладывает неответ и молчит,
  /// а «бросил» считает хост по тому, что этого вызова не было.
  final VoidCallback onRoundOver;

  /// Звук для игры, уже с учётом настройки: выключенный звук приходит сюда
  /// нулевым объектом. Игра про настройку не знает и знать не должна.
  final Sounds sounds;
}

/// Одна игра в реестре.
class GameEntry {
  const GameEntry({
    required this.id,
    required this.title,
    required this.build,
    this.artwork,
    this.instruction,
    this.challenge,
    this.tracksRoundScore = false,
  });

  /// Идентификатор в событиях ответа.
  ///
  /// Уезжает в `ReviewEvent.gameId`, а с Этапа 2.3 — в журнал ответов.
  /// Переименование расходится с уже записанной историей, поэтому id живёт
  /// здесь и нигде больше не дублируется.
  final String id;

  /// Название для человека: подпись сегмента выбора на домашнем экране.
  final String title;

  final String? artwork;
  final String? instruction;
  final ArcadeChallenge? challenge;
  final bool tracksRoundScore;

  ArcadeChallenge? get challengeRecordMode =>
      tracksRoundScore ? challenge : null;

  String titleFor(AppStrings strings) => switch (id) {
    'falling_words' => strings.fallingWords,
    'ninja_slash' => strings.ninjaSlash,
    'claw_machine' => strings.clawMachine,
    'brick_breaker' => strings.brickBreaker,
    'match_three' => strings.matchThree,
    'word_mahjong' => strings.wordMahjong,
    'snake' => strings.snake,
    _ => title,
  };

  String? instructionFor(AppStrings strings) => switch (id) {
    'falling_words' => strings.fallingInstruction,
    'ninja_slash' => strings.ninjaInstruction,
    'claw_machine' => strings.clawInstruction,
    'brick_breaker' => strings.brickInstruction,
    'match_three' => strings.matchInstruction,
    'word_mahjong' => strings.mahjongInstruction,
    'snake' => strings.snakeInstruction,
    _ => instruction,
  };

  /// Экран игры на готовом [GameLaunch].
  final Widget Function(GameLaunch launch) build;
}

/// Падающие слова — игра Гейта-0.
const GameEntry fallingWordsEntry = GameEntry(
  id: 'falling_words',
  title: 'Падающие слова',
  build: _buildFallingWords,
  challenge: ArcadeChallenge.sprint,
  artwork: 'assets/images/home/falling-words.png',
  instruction: 'Нажми на верный перевод',
);

/// Ниндзя-слэш — вторая игра, Фаза 4.
///
/// Вся её регистрация — эти пять строк и одна строка в списке ниже. Ядро,
/// падающие слова и одиннадцать эталонов при этом не тронуты, и это
/// доказывается пустым `git diff`, а не словами: ровно то обещание, которое
/// Фаза 2 давала фейком в `test/app/games_test.dart`.
const GameEntry ninjaSlashEntry = GameEntry(
  id: 'ninja_slash',
  title: 'Ниндзя-слэш',
  build: _buildNinjaSlash,
  challenge: ArcadeChallenge.streak,
  artwork: 'assets/images/home/ninja.png',
  instruction: 'Разрежь правильный перевод',
);

const clawMachineEntry = GameEntry(
  id: 'claw_machine',
  title: 'Автомат с клешнёй',
  build: _buildClawMachine,
  challenge: ArcadeChallenge.claw,
  artwork: 'assets/images/home/claw-machine.webp',
  instruction: 'Собери слово из букв',
);

const brickBreakerEntry = GameEntry(
  id: 'brick_breaker',
  title: 'Арканоид',
  build: _buildBrickBreaker,
  challenge: ArcadeChallenge.brick,
  artwork: 'assets/images/home/brick-breaker.webp',
  instruction: 'Разбивай кирпичи и лови переводы',
  tracksRoundScore: true,
);

const matchThreeEntry = GameEntry(
  id: 'match_three',
  title: 'Три в ряд',
  build: _buildMatchThree,
  artwork: 'assets/images/home/match-three.webp',
  instruction: 'Собирай кристаллы и открывай словесные бонусы',
  tracksRoundScore: true,
);

const wordMahjongEntry = GameEntry(
  id: 'word_mahjong',
  title: 'Маджонг со словами',
  build: _buildWordMahjong,
  artwork: 'assets/images/home/word-mahjong.webp',
  instruction: 'Снимай пары из слова и его перевода',
  tracksRoundScore: true,
);

const snakeEntry = GameEntry(
  id: 'snake',
  title: 'Змейка',
  build: _buildSnake,
  artwork: 'assets/images/home/snake.webp',
  instruction: 'Поймай яблоко с нужным переводом',
  tracksRoundScore: true,
);

/// Все игры приложения.
///
/// Порядок значим: первая запись — умолчание домашнего экрана. Выбор другой
/// игры живёт в HomeScreen, а не в реестре, и не меняет этот список.
const List<GameEntry> wordarcadeGames = [
  fallingWordsEntry,
  ninjaSlashEntry,
  clawMachineEntry,
  brickBreakerEntry,
  matchThreeEntry,
  wordMahjongEntry,
  snakeEntry,
];

Widget _buildFallingWords(GameLaunch launch) => FallingWordsGame(
  session: launch.session,
  listeningMode: launch.listeningMode,
  speech: launch.speech,
  studyLanguage: launch.course?.studyLanguage ?? 'en',
  summaryFooter:
      launch.onChallengeComplete == null ? launch.summaryFooter : null,
  onChallengeComplete: launch.onChallengeComplete,
  onPlayAgain: launch.onPlayAgain,
  onExit: launch.onExit,
  onRoundOver: launch.onRoundOver,
  mistakeCount: launch.mistakeCount,
  onReviewMistakes: launch.onReviewMistakes,
);

Widget _buildNinjaSlash(GameLaunch launch) => NinjaSlashGame(
  session: launch.session,
  sounds: launch.sounds,
  summaryFooter:
      launch.onChallengeComplete == null ? launch.summaryFooter : null,
  onChallengeComplete: launch.onChallengeComplete,
  onPlayAgain: launch.onPlayAgain,
  onExit: launch.onExit,
  onRoundOver: launch.onRoundOver,
  mistakeCount: launch.mistakeCount,
  onReviewMistakes: launch.onReviewMistakes,
);

Widget _buildClawMachine(GameLaunch launch) => ClawMachineGame(
  session: launch.session,
  sounds: launch.sounds,
  summaryFooter:
      launch.onChallengeComplete == null ? launch.summaryFooter : null,
  onChallengeComplete: launch.onChallengeComplete,
  onPlayAgain: launch.onPlayAgain,
  onExit: launch.onExit,
  onRoundOver: launch.onRoundOver,
  mistakeCount: launch.mistakeCount,
  onReviewMistakes: launch.onReviewMistakes,
);

Widget _buildBrickBreaker(GameLaunch launch) => BrickBreakerGame(
  session: launch.session,
  sounds: launch.sounds,
  speech: launch.speech,
  summaryFooter:
      launch.onChallengeComplete == null ? launch.summaryFooter : null,
  onRoundScore: launch.onRoundScore,
  onChallengeComplete: launch.onChallengeComplete,
  onPlayAgain: launch.onPlayAgain,
  onExit: launch.onExit,
  onRoundOver: launch.onRoundOver,
  mistakeCount: launch.mistakeCount,
  onReviewMistakes: launch.onReviewMistakes,
);

Widget _buildMatchThree(GameLaunch launch) => MatchThreeGame(
  session: launch.session,
  course: launch.course,
  level: launch.level,
  speech: launch.speech,
  sounds: launch.sounds,
  summaryFooter: launch.summaryFooter,
  onRoundScore: launch.onRoundScore,
  onPlayAgain: launch.onPlayAgain,
  onExit: launch.onExit,
  onRoundOver: launch.onRoundOver,
  mistakeCount: launch.mistakeCount,
  onReviewMistakes: launch.onReviewMistakes,
);

Widget _buildWordMahjong(GameLaunch launch) => WordMahjongGame(
  session: launch.session as BoardReviewSession,
  course: launch.course,
  level: launch.level,
  speech: launch.speech,
  sounds: launch.sounds,
  summaryFooter: launch.summaryFooter,
  onRoundScore: launch.onRoundScore,
  onPlayAgain: launch.onPlayAgain,
  onExit: launch.onExit,
  onRoundOver: launch.onRoundOver,
  mistakeCount: launch.mistakeCount,
  onReviewMistakes: launch.onReviewMistakes,
);

Widget _buildSnake(GameLaunch launch) => SnakeGame(
  session: launch.session as BoardReviewSession,
  vocabulary: launch.vocabulary.toList(growable: false),
  course: launch.course,
  level: launch.level,
  speech: launch.speech,
  sounds: launch.sounds,
  summaryFooter: launch.summaryFooter,
  onRoundScore: launch.onRoundScore,
  onPlayAgain: launch.onPlayAgain,
  onExit: launch.onExit,
  onRoundOver: launch.onRoundOver,
  mistakeCount: launch.mistakeCount,
  onReviewMistakes: launch.onReviewMistakes,
);
