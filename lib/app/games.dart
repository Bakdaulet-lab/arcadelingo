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

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_game.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_slash_game.dart';
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
  });

  /// Сессия, уже собранная usecase'ом и обёрнутая наблюдателями.
  final ReviewSession session;

  /// Строка «что дальше» на итогах; считает её хост.
  final String Function() summaryFooter;

  /// «Ещё раз»: новую партию строит хост.
  final VoidCallback onPlayAgain;

  /// «Выйти» с экранов конца партии.
  final VoidCallback onExit;

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
}

/// Одна игра в реестре.
class GameEntry {
  const GameEntry({required this.id, required this.title, required this.build});

  /// Идентификатор в событиях ответа.
  ///
  /// Уезжает в `ReviewEvent.gameId`, а с Этапа 2.3 — в журнал ответов.
  /// Переименование расходится с уже записанной историей, поэтому id живёт
  /// здесь и нигде больше не дублируется.
  final String id;

  /// Название для человека. Понадобится экрану выбора в Фазе 4.
  final String title;

  /// Экран игры на готовом [GameLaunch].
  final Widget Function(GameLaunch launch) build;
}

/// Падающие слова — игра Гейта-0.
const GameEntry fallingWordsEntry = GameEntry(
  id: 'falling_words',
  title: 'Падающие слова',
  build: _buildFallingWords,
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
);

/// Все игры приложения.
///
/// Порядок значим: пока экрана выбора нет, запускается первая. Ниндзя-слэш
/// стоит вторым намеренно — падающие слова остаются умолчанием, и поэтому
/// домашний экран от появления второй игры не меняется вовсе.
const List<GameEntry> wordarcadeGames = [fallingWordsEntry, ninjaSlashEntry];

Widget _buildFallingWords(GameLaunch launch) => FallingWordsGame(
  session: launch.session,
  summaryFooter: launch.summaryFooter,
  onPlayAgain: launch.onPlayAgain,
  onExit: launch.onExit,
  onRoundOver: launch.onRoundOver,
);

Widget _buildNinjaSlash(GameLaunch launch) => NinjaSlashGame(
  session: launch.session,
  summaryFooter: launch.summaryFooter,
  onPlayAgain: launch.onPlayAgain,
  onExit: launch.onExit,
  onRoundOver: launch.onRoundOver,
);
