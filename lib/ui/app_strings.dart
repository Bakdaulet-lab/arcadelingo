import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const russianStrings = AppStrings(InterfaceLanguage.russian);

/// Тексты ArcadeLingo. Язык курса задаёт данные карточки независимо от меню.
class AppStrings {
  const AppStrings(this.language);

  static const delegate = _AppStringsDelegate();
  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ?? russianStrings;

  final InterfaceLanguage language;
  bool get isEnglish => language == InterfaceLanguage.english;

  String get sources => isEnglish ? 'Sources' : 'Источники';
  String get chooseGame => isEnglish ? 'Choose a game' : 'Выбери игру';
  String get learnAndPlay =>
      isEnglish ? 'Preview words and play' : 'Знакомство и игра';
  String get play => isEnglish ? 'Play' : 'Играть';
  String get games => isEnglish ? 'Games' : 'Игры';
  String get progress => isEnglish ? 'Progress' : 'Прогресс';
  String get settings => isEnglish ? 'Settings' : 'Настройки';
  String get progressUnreadable =>
      isEnglish ? 'Unable to read progress' : 'Прогресс не читается';
  String get resetHint =>
      isEnglish
          ? 'Resetting starts your word practice over.'
          : 'После сброса слова начнутся заново, как при первом запуске.';
  String get resetProgress =>
      isEnglish ? 'Reset progress' : 'Сбросить прогресс';
  String get dictionaryUnreadable =>
      isEnglish
          ? 'Unable to read the course dictionary'
          : 'Словарь не читается';
  String get dictionaryRepairHint =>
      isEnglish
          ? 'The course data in this version is invalid. Please update the app.'
          : 'Это дефект сборки: сбрасывать нечего, поможет только обновление.';
  String get fallingWords => isEnglish ? 'Falling Words' : 'Падающие слова';
  String get fallingInstruction =>
      isEnglish ? 'Tap the correct translation' : 'Нажми на верный перевод';
  String get ninjaSlash => isEnglish ? 'Ninja Slash' : 'Ниндзя-слэш';
  String get ninjaInstruction =>
      isEnglish
          ? 'Swipe through the correct translation'
          : 'Разрежь правильный перевод';
  String get clawMachine => isEnglish ? 'Claw Machine' : 'Автомат с клешнёй';
  String get clawInstruction =>
      isEnglish ? 'Collect letters to spell the word' : 'Собери слово из букв';
  String get chooseCourse => isEnglish ? 'Choose a course' : 'Выбери курс';
  String get appLanguage => isEnglish ? 'App language' : 'Язык приложения';
  String get systemLanguage =>
      isEnglish ? 'Device language' : 'Язык устройства';
  String get settingsSaveFailed =>
      isEnglish
          ? 'Couldn’t save your preference. Try again.'
          : 'Не удалось сохранить настройку. Попробуй ещё раз.';
  String get reminderTime => isEnglish ? 'Reminder time' : 'Время напоминания';
  String get cancel => isEnglish ? 'Cancel' : 'Отмена';
  String get save => isEnglish ? 'Save' : 'Сохранить';
  String get hours => isEnglish ? 'Hour' : 'Часы';
  String get minutes => isEnglish ? 'Minute' : 'Минуты';
  String get dailyReminder =>
      isEnglish ? 'Daily reminder' : 'Ежедневное напоминание';
  String get time => isEnglish ? 'Time' : 'Время';
  String get gameSounds => isEnglish ? 'Game sounds' : 'Звуки в играх';
  String get notificationsDenied =>
      isEnglish
          ? 'Notifications are blocked. You can allow them in your device settings.'
          : 'Система не разрешила уведомления. Включить их можно в настройках телефона.';
  String get licenses =>
      isEnglish ? 'Full license texts' : 'Полные тексты лицензий';
  String get loadingSources =>
      isEnglish ? 'Loading sources' : 'Загрузка источников';
  String get sourcesLoadFailed =>
      isEnglish ? 'Couldn’t load sources' : 'Источники не читаются';
  String get progressLoadFailed =>
      isEnglish ? 'Couldn’t load progress' : 'Прогресс не загрузился';
  String get reopenProgress =>
      isEnglish
          ? 'Close this screen and open it again.'
          : 'Попробуй открыть экран ещё раз.';
  String get loadingProgress =>
      isEnglish ? 'Loading progress' : 'Загрузка прогресса';
  String get personalDictionary =>
      isEnglish ? 'My Word List' : 'Личный словарь';
  String get firstRoundProgress =>
      isEnglish
          ? 'Play your first round to see your progress here'
          : 'Сыграй первую партию, и здесь появится, сколько пройдено';
  String get allTime => isEnglish ? 'All time' : 'За всё время';
  String get words => isEnglish ? 'Words' : 'Слова';
  String get learned => isEnglish ? 'Learned' : 'Выучено';
  String get learning => isEnglish ? 'Learning' : 'В работе';
  String get hardWords => isEnglish ? 'Difficult' : 'Трудные';
  String get twoWeeks => isEnglish ? 'Two weeks' : 'Две недели';
  String get answersByDay => isEnglish ? 'Answers by day' : 'Ответы по дням';
  String get answers => isEnglish ? 'Answers' : 'Ответы';
  String get total => isEnglish ? 'Total' : 'Всего';
  String get correctCount => isEnglish ? 'Correct' : 'Верных';
  String get days => isEnglish ? 'Days' : 'Дни';
  String get daysWithAnswers => isEnglish ? 'With answers' : 'С ответами';
  String get bestStreak => isEnglish ? 'Best streak' : 'Лучшая серия';
  String get recentWords => isEnglish ? 'Recently seen' : 'Недавно встретил';
  String get noRecentWords =>
      isEnglish
          ? 'Words you encounter will appear here'
          : 'Пока нет встреченных слов';
  String get oftenMissed => isEnglish ? 'Often missed' : 'Часто ошибаюсь';
  String get noDifficultWords =>
      isEnglish
          ? 'No frequently missed words yet'
          : 'Пока нет слов с частыми ошибками';
  String get favorites => isEnglish ? 'Favorites' : 'Избранное';
  String get noFavorites =>
      isEnglish ? 'No favorites yet' : 'В избранном пока пусто';
  String get wordListLoadFailed =>
      isEnglish ? 'Couldn’t load your word list' : 'Словарь не загрузился';
  String get retry => isEnglish ? 'Try again' : 'Попробовать ещё раз';
  String get loadingWordList =>
      isEnglish ? 'Loading word list' : 'Загрузка словаря';
  String get wordDetails => isEnglish ? 'Word details' : 'Карточка слова';
  String get removeFavorite =>
      isEnglish ? 'Remove from favorites' : 'Убрать из избранного';
  String get addFavorite => isEnglish ? 'Add to favorites' : 'В избранное';
  String get favoriteSaveFailed =>
      isEnglish
          ? 'Couldn’t update your favorites. Try again.'
          : 'Не удалось сохранить избранное. Попробуй ещё раз.';
  String get answerHistory => isEnglish ? 'Answer history' : 'История ответов';
  String get correct => isEnglish ? 'Correct' : 'Верно';
  String get mistake => isEnglish ? 'Incorrect' : 'Ошибка';
  String get reviewMistakes => isEnglish ? 'Review mistakes' : 'Разбор ошибок';
  String get wordPreview => isEnglish ? 'Word preview' : 'Знакомство';
  String get noMistakes =>
      isEnglish ? 'No mistakes in this round' : 'В этом раунде нет ошибок';
  String get backToResults =>
      isEnglish
          ? 'You can go back to the results.'
          : 'Можно вернуться к итогам.';
  String get yourAnswer => isEnglish ? 'Your answer' : 'Твой ответ';
  String get timeUp => isEnglish ? 'Time’s up' : 'Время вышло';
  String get reviewWithoutTimer =>
      isEnglish
          ? 'Review the words at your own pace.'
          : 'Повтори слова без таймера.';
  String get readAndListen =>
      isEnglish
          ? 'Read the translation and listen to the word before playing.'
          : 'Прочитай перевод и послушай слово перед игрой.';
  String get next => isEnglish ? 'Next' : 'Дальше';
  String get startGame => isEnglish ? 'Start game' : 'Начать игру';
  String get back => isEnglish ? 'Back' : 'Назад';
  String get done => isEnglish ? 'Done' : 'Готово';
  String get skipPreview => isEnglish ? 'Skip to game' : 'Сразу в игру';
  String get playAgain => isEnglish ? 'Play again' : 'Ещё раз';
  String get exit => isEnglish ? 'Exit' : 'Выйти';
  String get nothingToday =>
      isEnglish ? 'You’re all caught up' : 'На сегодня всё';
  String get reviewsDone =>
      isEnglish
          ? 'There are no words due for review. Come back tomorrow.'
          : 'Слова к повторению кончились. Возвращайся завтра.';
  String get left => isEnglish ? 'Move left' : 'Влево';
  String get right => isEnglish ? 'Move right' : 'Вправо';
  String get grab => isEnglish ? 'Grab' : 'Захватить';
  String get hint => isEnglish ? 'Hint' : 'Подсказка';
  String get roundComplete => isEnglish ? 'Round complete' : 'Раунд окончен';
  String get outOfLives => isEnglish ? 'Out of lives' : 'Жизни кончились';
  String get wordsReady =>
      isEnglish
          ? 'More words are ready. Play another round.'
          : 'Ещё есть слова — сыграй ещё раунд';
  String get dailyWordsDone =>
      isEnglish ? 'No more words for today' : 'Слова на сегодня кончились';
  String get comeBackTomorrow =>
      isEnglish ? 'Come back tomorrow' : 'Возвращайся завтра';
  String get correctTranslation =>
      isEnglish ? 'Correct translation' : 'Правильный перевод';
  String get noun => isEnglish ? 'Noun' : 'Существительное';
  String get verb => isEnglish ? 'Verb' : 'Глагол';
  String get adjective => isEnglish ? 'Adjective' : 'Прилагательное';
  String get adverb => isEnglish ? 'Adverb' : 'Наречие';
  String get numeral => isEnglish ? 'Numeral' : 'Числительное';
  String get pronoun => isEnglish ? 'Pronoun' : 'Местоимение';
  String get preposition => isEnglish ? 'Preposition' : 'Предлог';
  String get conjunction => isEnglish ? 'Conjunction' : 'Союз';
  String get interjection => isEnglish ? 'Interjection' : 'Междометие';
  String get determiner => isEnglish ? 'Determiner' : 'Определитель';
  String voiceUnavailable(String language) => switch ((isEnglish, language)) {
    (true, 'en') =>
      'English speech is unavailable. Check your device’s text-to-speech settings for a local English voice.',
    (false, 'en') =>
      'Английский голос недоступен. Проверь настройки синтеза речи на устройстве и установи английский голос.',
    (true, 'es') =>
      'Spanish speech is unavailable. Install a local Spanish voice in your device’s text-to-speech settings.',
    (false, 'es') =>
      'Испанский голос недоступен. Установи испанский голос в настройках синтеза речи устройства.',
    (true, _) =>
      'Speech is unavailable. Install a voice for the course language in your device’s text-to-speech settings.',
    (false, _) =>
      'Озвучка недоступна. Установи голос для языка курса в настройках синтеза речи устройства.',
  };
  String get speechFailed =>
      isEnglish
          ? 'Couldn’t play the pronunciation. Try again.'
          : 'Не удалось произнести слово. Попробуй ещё раз.';
  String get listen => isEnglish ? 'Listen' : 'Послушать';
  String get listenAgain => isEnglish ? 'Listen again' : 'Ещё раз';
  String get noStreak => isEnglish ? 'No streak yet' : 'Серии нет';
  String get startStreak =>
      isEnglish ? 'Start your streak' : 'Начни свою серию';
  String get playedToday => isEnglish ? 'Played today' : 'Сегодня сыграно';
  String get notPlayedToday =>
      isEnglish ? 'Not played today' : 'Сегодня ещё не сыграно';
  String get continueStreak =>
      isEnglish ? 'Keep your streak going' : 'Продолжить серию';
  String get saveStreak => isEnglish ? 'Save your streak' : 'Спасти серию';
  String get playAnotherRound =>
      isEnglish ? 'Play another round' : 'Сыграть ещё раз';
  String get freezeAvailable =>
      isEnglish ? 'Streak Freeze available' : 'Заморозка в запасе';
  String get playedDay => isEnglish ? 'played' : 'сыграно';
  String get frozenDay => isEnglish ? 'streak frozen' : 'заморозка';
  String get missedDay => isEnglish ? 'missed' : 'пропущено';
  String get pendingDay =>
      isEnglish ? 'today, not played yet' : 'сегодня, ещё не сыграно';
  String get futureDay => isEnglish ? 'upcoming' : 'ещё не наступил';
  String get reminderSavedByFreeze =>
      isEnglish
          ? 'Play today. A Streak Freeze will cover the day you missed.'
          : 'Сыграй сегодня — заморозка прикроет вчерашний пропуск';
  String get oneRoundCounts =>
      isEnglish
          ? 'One round is all it takes to count today.'
          : 'Одна партия — и день засчитан';
  String get timeToReturn =>
      isEnglish ? 'Ready to play again?' : 'Пора вернуться';
  String get restartStreak =>
      isEnglish
          ? 'Play one round to start a new streak.'
          : 'Одна партия, и серия начнётся заново';

  String courseName(StudyCourse course) =>
      isEnglish
          ? '${languageName(course.studyLanguage)} · ${languageName(course.translationLanguage)} translations'
          : '${languageName(course.studyLanguage)} · переводы на ${languageName(course.translationLanguage).toLowerCase()}';

  String languageName(String tag) => switch (tag) {
    'en' => isEnglish ? 'English' : 'Английский',
    'ru' => isEnglish ? 'Russian' : 'Русский',
    'es' => isEnglish ? 'Spanish' : 'Испанский',
    _ => tag,
  };

  String levelOf(String tag) =>
      isEnglish
          ? '${languageName(tag)} level'
          : switch (tag) {
            'en' => 'Уровень английского',
            'ru' => 'Уровень русского',
            'es' => 'Уровень испанского',
            _ => 'Уровень языка ($tag)',
          };

  String weekday(int weekday, String russianLabel) =>
      isEnglish
          ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1]
          : russianLabel;

  String noWordsForLevel(String level) =>
      isEnglish
          ? 'No $level words in this course yet'
          : 'Для $level пока нет слов';
  String level(String level) => isEnglish ? 'Level $level' : 'Уровень $level';
  String correctAnswers(int count, int total) =>
      isEnglish
          ? 'Correct answers: $count of $total'
          : 'Верных ответов: $count из $total';
  String reviewMistakesCount(int count) =>
      isEnglish ? 'Review mistakes ($count)' : 'Разобрать ошибки ($count)';
  String score(int value) => isEnglish ? 'Score: $value' : 'Счёт: $value';
  String bestCombo(int value) =>
      isEnglish ? 'Best combo: $value' : 'Лучшая серия: $value';
  String lives(int value, int total) =>
      isEnglish ? 'Lives: $value of $total' : 'Жизни: $value из $total';
  String wordNumber(int index, int total) =>
      isEnglish ? 'Word $index of $total' : 'Слово $index из $total';
  String lettersCollected(int count, int total) =>
      isEnglish
          ? 'Letters collected: $count of $total'
          : 'Собрано букв: $count из $total';
  String letterMiss(String letter) =>
      isEnglish ? 'Letter $letter doesn’t fit' : 'Буква $letter не подошла';
  String capsule(String letter, {required bool hintShown}) =>
      isEnglish
          ? (hintShown ? 'Capsule $letter, hint' : 'Capsule $letter')
          : (hintShown ? 'Капсула $letter, подсказка' : 'Капсула $letter');
  String attemptCounts(int count, int mistakes) =>
      isEnglish
          ? 'Attempts: $count · Mistakes: $mistakes'
          : 'Попыток: $count · Ошибок: $mistakes';
  String answersForDay(String date, int count) =>
      isEnglish
          ? '$date, $count ${count == 1 ? 'answer' : 'answers'}'
          : '$date, ответов $count';
  String pronounce(String word) =>
      isEnglish ? 'Pronounce $word' : 'Произнести $word';
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      InterfaceLanguage.fromTag(locale.languageCode) !=
      InterfaceLanguage.system;

  @override
  Future<AppStrings> load(Locale locale) => SynchronousFuture(
    AppStrings(InterfaceLanguage.fromTag(locale.languageCode)),
  );

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

extension AppLocalization on BuildContext {
  AppStrings get strings => AppStrings.of(this);
}
