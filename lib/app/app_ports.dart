/// Всё, что приложение получает снаружи, одним значением.
///
/// Заведено на 3.6, когда сработал триггер, записанный в Фазе 2: «корень
/// перевалит за восемь зависимостей». К концу Фазы 3 их стало десять, и
/// конструктор перестал читаться глазами — а именно читаемость корня, а не
/// число само по себе, тем триггером и охранялась (`docs/dev/context.md`).
///
/// Это **не** DI-контейнер и не шаг к нему. Разница простая: контейнер
/// умеет собирать зависимости сам, а здесь просто запись из семи полей,
/// которую заполняет `main.dart`. Riverpod по-прежнему отложен, и триггер у
/// него другой — одно состояние, живое в двух местах одновременно.
///
/// Умолчания — нулевые объекты. Тест, которому журнал не нужен, о журнале не
/// узнаёт; приложение с нулевым объектом работает полностью, просто молча.
/// Обязательны только два: без карточек и без серии играть не во что.
library;

import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/domain/ports/answer_log.dart';
import 'package:arcadelingo/domain/ports/card_store.dart';
import 'package:arcadelingo/domain/ports/challenge_records.dart';
import 'package:arcadelingo/domain/ports/custom_words_store.dart';
import 'package:arcadelingo/domain/ports/event_log.dart';
import 'package:arcadelingo/domain/ports/favorites_store.dart';
import 'package:arcadelingo/domain/ports/reminders.dart';
import 'package:arcadelingo/domain/ports/settings_store.dart';
import 'package:arcadelingo/domain/ports/sounds.dart';
import 'package:arcadelingo/domain/ports/streak_store.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/ports/word_sets_store.dart';

/// Умолчание для спроса разрешения на уведомления: платформы, у которой
/// нечего спрашивать, для теста не существует.
Future<bool> alwaysAllowed() async => true;

class AppPorts {
  const AppPorts({
    required this.cards,
    required this.streaks,
    this.answers = const NoopAnswerLog(),
    this.events = const NoopEventLog(),
    this.favorites,
    this.customWords,
    this.wordSets,
    this.reminders = const NoopReminders(),
    this.sounds = const NoopSounds(),
    this.speech = const NoopWordSpeech(),
    this.settings,
    this.challengeRecords,
    this.askReminderPermission = alwaysAllowed,
  });

  AppPorts forDeck(CourseDeck deck) => AppPorts(
    cards: deck.cards,
    answers: deck.answers,
    favorites: deck.favorites,
    customWords: deck.customWords,
    wordSets: deck.wordSets,
    speech: deck.speech,
    streaks: deck.streaks,
    events: deck.events,
    reminders: reminders,
    sounds: sounds,
    settings: settings,
    challengeRecords: challengeRecords,
    askReminderPermission: askReminderPermission,
  );

  /// Состояние повторения. Портом, а не конкретным стором: корень —
  /// единственное место, которое знает и о `data/`, и о `domain/`, и это
  /// не повод забывать, что между ними интерфейс.
  final CardStore cards;

  /// Второй документ прогресса.
  final StreakStore streaks;

  /// История ответов.
  final AnswerLog answers;

  /// История событий: открыл, начал, доиграл, бросил.
  final EventLog events;

  final FavoritesStore? favorites;
  final CustomWordsStore? customWords;
  final WordSetsStore? wordSets;

  /// Напоминания.
  final Reminders reminders;

  /// Звук игр. Всегда настоящий: выключает его хост подменой на нулевой
  /// объект в момент запуска партии, а не страж внутри адаптера.
  final Sounds sounds;

  /// Произношение по явному нажатию на учебной карточке.
  final WordSpeech speech;

  /// Настройки напоминания; null — экран настроек недоступен, и это
  /// умолчание тестов, которые о них не знают.
  final SettingsStore? settings;
  final ChallengeRecords? challengeRecords;

  /// Спросить у системы разрешение на уведомления.
  ///
  /// Функцией, а не методом порта: разрешение — понятие платформы, а не
  /// домена, и [Reminders] о нём знать не должен.
  final Future<bool> Function() askReminderPermission;
}
