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
  bool get isRussian => language == InterfaceLanguage.russian;

  String _text({required String en, required String ru, required String es}) =>
      switch (language) {
        InterfaceLanguage.english => en,
        InterfaceLanguage.spanish => es,
        InterfaceLanguage.russian || InterfaceLanguage.system => ru,
      };

  String get sources => _text(en: 'Sources', ru: 'Источники', es: 'Fuentes');
  String get chooseGame =>
      _text(en: 'Choose a game', ru: 'Выбери игру', es: 'Elige un juego');
  String get learnAndPlay => _text(
    en: 'Preview words and play',
    ru: 'Знакомство и игра',
    es: 'Aprende las palabras y juega',
  );
  String get play => _text(en: 'Play', ru: 'Играть', es: 'Jugar');
  String get games => _text(en: 'Games', ru: 'Игры', es: 'Juegos');
  String get progress => _text(en: 'Progress', ru: 'Прогресс', es: 'Progreso');
  String get settings => _text(en: 'Settings', ru: 'Настройки', es: 'Ajustes');
  String get progressUnreadable => _text(
    en: 'Unable to read progress',
    ru: 'Прогресс не читается',
    es: 'No se pudo leer el progreso',
  );
  String get resetHint => _text(
    en: 'Resetting starts your word practice over.',
    ru: 'После сброса слова начнутся заново, как при первом запуске.',
    es:
        'Si restableces el progreso, volverás a practicar las palabras desde el principio.',
  );
  String get resetProgress => _text(
    en: 'Reset progress',
    ru: 'Сбросить прогресс',
    es: 'Restablecer progreso',
  );
  String get dictionaryUnreadable => _text(
    en: 'Unable to read the course dictionary',
    ru: 'Словарь не читается',
    es: 'No se pudo leer el diccionario del curso',
  );
  String get dictionaryRepairHint => _text(
    en: 'The course data in this version is invalid. Please update the app.',
    ru: 'Это дефект сборки: сбрасывать нечего, поможет только обновление.',
    es:
        'Los datos del curso de esta versión presentan un error. Actualiza la aplicación.',
  );
  String get fallingWords =>
      _text(en: 'Falling Words', ru: 'Падающие слова', es: 'Palabras que caen');
  String get fallingInstruction => _text(
    en: 'Tap the correct translation',
    ru: 'Нажми на верный перевод',
    es: 'Toca la traducción correcta',
  );
  String get ninjaSlash =>
      _text(en: 'Ninja Slash', ru: 'Ниндзя-слэш', es: 'Corte ninja');
  String get ninjaInstruction => _text(
    en: 'Swipe through the correct translation',
    ru: 'Разрежь правильный перевод',
    es: 'Desliza el dedo para cortar la traducción correcta',
  );
  String get clawMachine => _text(
    en: 'Claw Machine',
    ru: 'Автомат с клешнёй',
    es: 'Máquina de garra',
  );
  String get clawInstruction => _text(
    en: 'Collect letters to spell the word',
    ru: 'Собери слово из букв',
    es: 'Atrapa letras para formar la palabra',
  );
  String get chooseCourse =>
      _text(en: 'Choose a course', ru: 'Выбери курс', es: 'Elige un curso');
  String get appLanguage => _text(
    en: 'App language',
    ru: 'Язык приложения',
    es: 'Idioma de la aplicación',
  );
  String get systemLanguage => _text(
    en: 'Device language',
    ru: 'Язык устройства',
    es: 'Idioma del dispositivo',
  );
  String get settingsSaveFailed => _text(
    en: 'Couldn’t save your preference. Try again.',
    ru: 'Не удалось сохранить настройку. Попробуй ещё раз.',
    es: 'No se pudo guardar el ajuste. Vuelve a intentarlo.',
  );
  String get reminderTime => _text(
    en: 'Reminder time',
    ru: 'Время напоминания',
    es: 'Hora del recordatorio',
  );
  String get cancel => _text(en: 'Cancel', ru: 'Отмена', es: 'Cancelar');
  String get save => _text(en: 'Save', ru: 'Сохранить', es: 'Guardar');
  String get hours => _text(en: 'Hour', ru: 'Часы', es: 'Hora');
  String get minutes => _text(en: 'Minute', ru: 'Минуты', es: 'Minutos');
  String get dailyReminder => _text(
    en: 'Daily reminder',
    ru: 'Ежедневное напоминание',
    es: 'Recordatorio diario',
  );
  String get time => _text(en: 'Time', ru: 'Время', es: 'Hora');
  String get gameSounds => _text(
    en: 'Game sounds',
    ru: 'Звуки в играх',
    es: 'Sonidos de los juegos',
  );
  String get notificationsDenied => _text(
    en: 'Notifications are blocked. You can allow them in your device settings.',
    ru:
        'Система не разрешила уведомления. Включить их можно в настройках телефона.',
    es:
        'Las notificaciones están bloqueadas. Puedes activarlas en los ajustes del dispositivo.',
  );
  String get licenses => _text(
    en: 'Full license texts',
    ru: 'Полные тексты лицензий',
    es: 'Textos completos de las licencias',
  );
  String get loadingSources => _text(
    en: 'Loading sources',
    ru: 'Загрузка источников',
    es: 'Cargando las fuentes',
  );
  String get sourcesLoadFailed => _text(
    en: 'Couldn’t load sources',
    ru: 'Источники не читаются',
    es: 'No se pudieron cargar las fuentes',
  );
  String get progressLoadFailed => _text(
    en: 'Couldn’t load progress',
    ru: 'Прогресс не загрузился',
    es: 'No se pudo cargar el progreso',
  );
  String get reopenProgress => _text(
    en: 'Close this screen and open it again.',
    ru: 'Попробуй открыть экран ещё раз.',
    es: 'Cierra esta pantalla y vuelve a abrirla.',
  );
  String get loadingProgress => _text(
    en: 'Loading progress',
    ru: 'Загрузка прогресса',
    es: 'Cargando el progreso',
  );
  String get personalDictionary =>
      _text(en: 'My Word List', ru: 'Личный словарь', es: 'Mi diccionario');
  String get firstRoundProgress => _text(
    en: 'Play your first round to see your progress here',
    ru: 'Сыграй первую партию, и здесь появится, сколько пройдено',
    es: 'Juega tu primera ronda para ver tu progreso aquí',
  );
  String get allTime =>
      _text(en: 'All time', ru: 'За всё время', es: 'Desde el inicio');
  String get words => _text(en: 'Words', ru: 'Слова', es: 'Palabras');
  String get learned => _text(en: 'Learned', ru: 'Выучено', es: 'Aprendidas');
  String get learning =>
      _text(en: 'Learning', ru: 'В работе', es: 'En práctica');
  String get hardWords =>
      _text(en: 'Difficult', ru: 'Трудные', es: 'Difíciles');
  String get twoWeeks =>
      _text(en: 'Two weeks', ru: 'Две недели', es: 'Dos semanas');
  String get answersByDay => _text(
    en: 'Answers by day',
    ru: 'Ответы по дням',
    es: 'Respuestas por día',
  );
  String get answers => _text(en: 'Answers', ru: 'Ответы', es: 'Respuestas');
  String get total => _text(en: 'Total', ru: 'Всего', es: 'Total');
  String get correctCount => _text(en: 'Correct', ru: 'Верных', es: 'Aciertos');
  String get days => _text(en: 'Days', ru: 'Дни', es: 'Días');
  String get daysWithAnswers =>
      _text(en: 'With answers', ru: 'С ответами', es: 'Con respuestas');
  String get bestStreak =>
      _text(en: 'Best streak', ru: 'Лучшая серия', es: 'Mejor racha');
  String get recentWords => _text(
    en: 'Recently seen',
    ru: 'Недавно встретил',
    es: 'Vistas recientemente',
  );
  String get noRecentWords => _text(
    en: 'Words you encounter will appear here',
    ru: 'Пока нет встреченных слов',
    es: 'Todavía no has visto ninguna palabra',
  );
  String get oftenMissed =>
      _text(en: 'Often missed', ru: 'Часто ошибаюсь', es: 'Errores frecuentes');
  String get noDifficultWords => _text(
    en: 'No frequently missed words yet',
    ru: 'Пока нет слов с частыми ошибками',
    es: 'Todavía no hay palabras en las que suelas fallar',
  );
  String get favorites =>
      _text(en: 'Favorites', ru: 'Избранное', es: 'Favoritas');
  String get noFavorites => _text(
    en: 'No favorites yet',
    ru: 'В избранном пока пусто',
    es: 'Todavía no tienes palabras favoritas',
  );
  String get wordListLoadFailed => _text(
    en: 'Couldn’t load your word list',
    ru: 'Словарь не загрузился',
    es: 'No se pudo cargar tu diccionario',
  );
  String get retry => _text(
    en: 'Try again',
    ru: 'Попробовать ещё раз',
    es: 'Volver a intentar',
  );
  String get loadingWordList => _text(
    en: 'Loading word list',
    ru: 'Загрузка словаря',
    es: 'Cargando el diccionario',
  );
  String get wordDetails => _text(
    en: 'Word details',
    ru: 'Карточка слова',
    es: 'Ficha de la palabra',
  );
  String get removeFavorite => _text(
    en: 'Remove from favorites',
    ru: 'Убрать из избранного',
    es: 'Quitar de favoritas',
  );
  String get addFavorite => _text(
    en: 'Add to favorites',
    ru: 'В избранное',
    es: 'Añadir a favoritas',
  );
  String get favoriteSaveFailed => _text(
    en: 'Couldn’t update your favorites. Try again.',
    ru: 'Не удалось сохранить избранное. Попробуй ещё раз.',
    es: 'No se pudo actualizar la lista de favoritas. Vuelve a intentarlo.',
  );
  String get answerHistory => _text(
    en: 'Answer history',
    ru: 'История ответов',
    es: 'Historial de respuestas',
  );
  String get correct => _text(en: 'Correct', ru: 'Верно', es: 'Correcto');
  String get mistake => _text(en: 'Incorrect', ru: 'Ошибка', es: 'Error');
  String get reviewMistakes => _text(
    en: 'Review mistakes',
    ru: 'Разбор ошибок',
    es: 'Revisión de errores',
  );
  String get wordPreview =>
      _text(en: 'Word preview', ru: 'Знакомство', es: 'Conoce las palabras');
  String get noMistakes => _text(
    en: 'No mistakes in this round',
    ru: 'В этом раунде нет ошибок',
    es: 'No hubo errores en esta ronda',
  );
  String get backToResults => _text(
    en: 'You can go back to the results.',
    ru: 'Можно вернуться к итогам.',
    es: 'Puedes volver a los resultados.',
  );
  String get yourAnswer =>
      _text(en: 'Your answer', ru: 'Твой ответ', es: 'Tu respuesta');
  String get timeUp =>
      _text(en: 'Time’s up', ru: 'Время вышло', es: 'Se acabó el tiempo');
  String get reviewWithoutTimer => _text(
    en: 'Review the words at your own pace.',
    ru: 'Повтори слова без таймера.',
    es: 'Repasa las palabras a tu ritmo.',
  );
  String get readAndListen => _text(
    en: 'Read the translation and listen to the word before playing.',
    ru: 'Прочитай перевод и послушай слово перед игрой.',
    es: 'Lee la traducción y escucha la palabra antes de jugar.',
  );
  String get next => _text(en: 'Next', ru: 'Дальше', es: 'Siguiente');
  String get startGame =>
      _text(en: 'Start game', ru: 'Начать игру', es: 'Empezar a jugar');
  String get back => _text(en: 'Back', ru: 'Назад', es: 'Atrás');
  String get done => _text(en: 'Done', ru: 'Готово', es: 'Listo');
  String get skipPreview =>
      _text(en: 'Skip to game', ru: 'Сразу в игру', es: 'Ir directo al juego');
  String get playAgain =>
      _text(en: 'Play again', ru: 'Ещё раз', es: 'Volver a jugar');
  String get exit => _text(en: 'Exit', ru: 'Выйти', es: 'Salir');
  String get nothingToday => _text(
    en: 'You’re all caught up',
    ru: 'На сегодня всё',
    es: 'Estás al día',
  );
  String get reviewsDone => _text(
    en: 'There are no words due for review. Come back tomorrow.',
    ru: 'Слова к повторению кончились. Возвращайся завтра.',
    es: 'No quedan palabras pendientes de repaso. Vuelve mañana.',
  );
  String get left =>
      _text(en: 'Move left', ru: 'Влево', es: 'Mover a la izquierda');
  String get right =>
      _text(en: 'Move right', ru: 'Вправо', es: 'Mover a la derecha');
  String get grab => _text(en: 'Grab', ru: 'Захватить', es: 'Atrapar');
  String get hint => _text(en: 'Hint', ru: 'Подсказка', es: 'Pista');
  String get roundComplete =>
      _text(en: 'Round complete', ru: 'Раунд окончен', es: 'Fin de la ronda');
  String get outOfLives => _text(
    en: 'Out of lives',
    ru: 'Жизни кончились',
    es: 'Te quedaste sin vidas',
  );
  String get wordsReady => _text(
    en: 'More words are ready. Play another round.',
    ru: 'Ещё есть слова — сыграй ещё раунд',
    es: 'Hay más palabras para practicar. Juega otra ronda.',
  );
  String get dailyWordsDone => _text(
    en: 'No more words for today',
    ru: 'Слова на сегодня кончились',
    es: 'No quedan más palabras por hoy',
  );
  String get comeBackTomorrow => _text(
    en: 'Come back tomorrow',
    ru: 'Возвращайся завтра',
    es: 'Vuelve mañana',
  );
  String get correctTranslation => _text(
    en: 'Correct translation',
    ru: 'Правильный перевод',
    es: 'Traducción correcta',
  );
  String get noun => _text(en: 'Noun', ru: 'Существительное', es: 'Sustantivo');
  String get verb => _text(en: 'Verb', ru: 'Глагол', es: 'Verbo');
  String get adjective =>
      _text(en: 'Adjective', ru: 'Прилагательное', es: 'Adjetivo');
  String get adverb => _text(en: 'Adverb', ru: 'Наречие', es: 'Adverbio');
  String get numeral => _text(en: 'Numeral', ru: 'Числительное', es: 'Numeral');
  String get pronoun =>
      _text(en: 'Pronoun', ru: 'Местоимение', es: 'Pronombre');
  String get preposition =>
      _text(en: 'Preposition', ru: 'Предлог', es: 'Preposición');
  String get conjunction =>
      _text(en: 'Conjunction', ru: 'Союз', es: 'Conjunción');
  String get interjection =>
      _text(en: 'Interjection', ru: 'Междометие', es: 'Interjección');
  String get determiner =>
      _text(en: 'Determiner', ru: 'Определитель', es: 'Determinante');
  String voiceUnavailable(String studyLanguage) => switch (studyLanguage) {
    'en' => _text(
      en:
          'English speech is unavailable. Check your device’s text-to-speech settings for a local English voice.',
      ru:
          'Английский голос недоступен. Проверь настройки синтеза речи на устройстве и установи английский голос.',
      es:
          'El audio en inglés no está disponible. Instala una voz en inglés en los ajustes de síntesis de voz del dispositivo.',
    ),
    'es' => _text(
      en:
          'Spanish speech is unavailable. Install a local Spanish voice in your device’s text-to-speech settings.',
      ru:
          'Испанский голос недоступен. Установи испанский голос в настройках синтеза речи устройства.',
      es:
          'El audio en español no está disponible. Instala una voz en español en los ajustes de síntesis de voz del dispositivo.',
    ),
    _ => _text(
      en:
          'Speech is unavailable. Install a voice for the course language in your device’s text-to-speech settings.',
      ru:
          'Озвучка недоступна. Установи голос для языка курса в настройках синтеза речи устройства.',
      es:
          'El audio no está disponible. Instala una voz en el idioma del curso en los ajustes de síntesis de voz del dispositivo.',
    ),
  };
  String get speechFailed => _text(
    en: 'Couldn’t play the pronunciation. Try again.',
    ru: 'Не удалось произнести слово. Попробуй ещё раз.',
    es: 'No se pudo reproducir la pronunciación. Vuelve a intentarlo.',
  );
  String get listen => _text(en: 'Listen', ru: 'Послушать', es: 'Escuchar');
  String get listenAgain =>
      _text(en: 'Listen again', ru: 'Ещё раз', es: 'Escuchar de nuevo');
  String get noStreak => _text(
    en: 'No streak yet',
    ru: 'Серии нет',
    es: 'Aún no tienes una racha',
  );
  String get startStreak => _text(
    en: 'Start your streak',
    ru: 'Начни свою серию',
    es: 'Empieza tu racha',
  );
  String get playedToday =>
      _text(en: 'Played today', ru: 'Сегодня сыграно', es: 'Ya jugaste hoy');
  String get notPlayedToday => _text(
    en: 'Not played today',
    ru: 'Сегодня ещё не сыграно',
    es: 'Aún no has jugado hoy',
  );
  String get continueStreak => _text(
    en: 'Keep your streak going',
    ru: 'Продолжить серию',
    es: 'Mantener la racha',
  );
  String get saveStreak =>
      _text(en: 'Save your streak', ru: 'Спасти серию', es: 'Salvar la racha');
  String get playAnotherRound => _text(
    en: 'Play another round',
    ru: 'Сыграть ещё раз',
    es: 'Jugar otra ronda',
  );
  String get freezeAvailable => _text(
    en: 'Streak Freeze available',
    ru: 'Заморозка в запасе',
    es: 'Protección de racha disponible',
  );
  String get playedDay => _text(en: 'played', ru: 'сыграно', es: 'día jugado');
  String get frozenDay =>
      _text(en: 'streak frozen', ru: 'заморозка', es: 'racha protegida');
  String get missedDay =>
      _text(en: 'missed', ru: 'пропущено', es: 'día sin jugar');
  String get pendingDay => _text(
    en: 'today, not played yet',
    ru: 'сегодня, ещё не сыграно',
    es: 'hoy, aún sin jugar',
  );
  String get futureDay =>
      _text(en: 'upcoming', ru: 'ещё не наступил', es: 'día próximo');
  String get reminderSavedByFreeze => _text(
    en: 'Play today. A Streak Freeze will cover the day you missed.',
    ru: 'Сыграй сегодня — заморозка прикроет вчерашний пропуск',
    es: 'Juega hoy. La protección de racha cubrirá el día que faltaste.',
  );
  String get oneRoundCounts => _text(
    en: 'One round is all it takes to count today.',
    ru: 'Одна партия — и день засчитан',
    es: 'Juega una ronda para sumar el día de hoy.',
  );
  String get timeToReturn => _text(
    en: 'Ready to play again?',
    ru: 'Пора вернуться',
    es: '¿Todo listo para volver a jugar?',
  );
  String get restartStreak => _text(
    en: 'Play one round to start a new streak.',
    ru: 'Одна партия, и серия начнётся заново',
    es: 'Juega una ronda para empezar una nueva racha.',
  );

  String courseName(StudyCourse course) {
    final study = languageName(course.studyLanguage);
    final translation = languageName(course.translationLanguage);
    return _text(
      en: '$study · $translation translations',
      ru: '$study · переводы на ${translation.toLowerCase()}',
      es: '$study · traducciones al ${translation.toLowerCase()}',
    );
  }

  String languageName(String tag) => switch (tag) {
    'en' => _text(en: 'English', ru: 'Английский', es: 'Inglés'),
    'ru' => _text(en: 'Russian', ru: 'Русский', es: 'Ruso'),
    'es' => _text(en: 'Spanish', ru: 'Испанский', es: 'Español'),
    _ => tag,
  };

  String levelOf(String tag) => _text(
    en: '${languageName(tag)} level',
    ru: switch (tag) {
      'en' => 'Уровень английского',
      'ru' => 'Уровень русского',
      'es' => 'Уровень испанского',
      _ => 'Уровень языка ($tag)',
    },
    es: 'Nivel de ${languageName(tag).toLowerCase()}',
  );

  String weekday(int weekday, String russianLabel) => _text(
    en: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1],
    ru: russianLabel,
    es: const ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'][weekday - 1],
  );

  String noWordsForLevel(String level) => _text(
    en: 'No $level words in this course yet',
    ru: 'Для $level пока нет слов',
    es: 'Aún no hay palabras de nivel $level en este curso',
  );

  String level(String level) =>
      _text(en: 'Level $level', ru: 'Уровень $level', es: 'Nivel $level');

  String correctAnswers(int count, int total) => _text(
    en: 'Correct answers: $count of $total',
    ru: 'Верных ответов: $count из $total',
    es: 'Aciertos: $count de $total',
  );

  String reviewMistakesCount(int count) => _text(
    en: 'Review mistakes ($count)',
    ru: 'Разобрать ошибки ($count)',
    es: 'Revisar errores ($count)',
  );

  String score(int value) =>
      _text(en: 'Score: $value', ru: 'Счёт: $value', es: 'Puntos: $value');

  String bestCombo(int value) => _text(
    en: 'Best combo: $value',
    ru: 'Лучшая серия: $value',
    es: 'Mejor combo: $value',
  );

  String lives(int value, int total) => _text(
    en: 'Lives: $value of $total',
    ru: 'Жизни: $value из $total',
    es: 'Vidas: $value de $total',
  );

  String wordNumber(int index, int total) => _text(
    en: 'Word $index of $total',
    ru: 'Слово $index из $total',
    es: 'Palabra $index de $total',
  );

  String lettersCollected(int count, int total) => _text(
    en: 'Letters collected: $count of $total',
    ru: 'Собрано букв: $count из $total',
    es: 'Letras atrapadas: $count de $total',
  );

  String letterMiss(String letter) => _text(
    en: 'Letter $letter doesn’t fit',
    ru: 'Буква $letter не подошла',
    es: 'La letra $letter no encaja',
  );

  String capsule(String letter, {required bool hintShown}) => _text(
    en: hintShown ? 'Capsule $letter, hint' : 'Capsule $letter',
    ru: hintShown ? 'Капсула $letter, подсказка' : 'Капсула $letter',
    es:
        hintShown
            ? 'Cápsula con la letra $letter, pista'
            : 'Cápsula con la letra $letter',
  );

  String attemptCounts(int count, int mistakes) => _text(
    en: 'Attempts: $count · Mistakes: $mistakes',
    ru: 'Попыток: $count · Ошибок: $mistakes',
    es: 'Intentos: $count · Errores: $mistakes',
  );

  String answersForDay(String date, int count) => _text(
    en: '$date, $count ${count == 1 ? 'answer' : 'answers'}',
    ru: '$date, ответов $count',
    es: '$date, $count ${count == 1 ? 'respuesta' : 'respuestas'}',
  );

  String pronounce(String word) => _text(
    en: 'Pronounce $word',
    ru: 'Произнести $word',
    es: 'Pronunciar $word',
  );
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
