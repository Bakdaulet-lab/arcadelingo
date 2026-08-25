/// Одна строка журнала ответов: что именно сохраняется и что читается назад.
///
/// Журнал — улика, а не состояние. Карточка Лейтнера отвечает на вопрос «что
/// показать дальше», журнал — на вопрос «что было». Отсюда все решения ниже:
/// строки не меняются и не удаляются, а прочитанная строка обязана быть
/// достаточной, чтобы переиграть расписание с нуля (`replay.dart`).
///
/// Тип отдельный от [ReviewEvent] намеренно, хотя первый и рождается из
/// второго. Событие несёт целый [ReviewItem] — слово, перевод, обманки, — и
/// хранить это в каждой строке значит копировать контент в журнал; через год
/// он разойдётся с ассетом и станет врать. Запись хранит `wordId`, а слово по
/// нему всегда найдётся в сиде. Заодно это делает порт симметричным: что
/// пишем, то и читаем — а правило проекции живёт здесь, в `domain/`, а не в
/// реализации хранилища.
library;

import '../session/observed_session.dart';
import '../srs/review_grade.dart';
import '../streak/streak.dart';

/// Ответ, каким он ушёл в журнал.
class AnswerRecord {
  const AnswerRecord({
    required this.wordId,
    required this.at,
    required this.localDay,
    required this.grade,
    required this.correct,
    required this.responseTime,
    required this.timeLimit,
    required this.hintsUsed,
    required this.gameId,
    required this.sessionId,
  });

  /// Проекция события ответа в строку журнала.
  ///
  /// Единственное место, где решается, что из события переживёт запись.
  factory AnswerRecord.of(ReviewEvent event) => AnswerRecord(
    wordId: event.item.word.id,
    at: event.at,
    // День берётся из живого момента, пока при нём ещё есть зона хоста.
    // После записи он не восстановим (см. [localDay]).
    localDay: StreakDay.of(event.at),
    grade: event.grade,
    correct: event.outcome.correct,
    responseTime: event.outcome.responseTime,
    timeLimit: event.outcome.timeLimit,
    hintsUsed: event.outcome.hintsUsed,
    gameId: event.gameId,
    sessionId: event.sessionId,
  );

  /// Слово, по которому пришёл ответ. Само слово в журнале не лежит: оно
  /// живёт в сиде и меняется вместе с ним.
  final String wordId;

  /// Момент ответа.
  ///
  /// Прочитанный из хранилища — **всегда в UTC**, каким бы ни был записанный:
  /// момент один, а зона у него — свойство того, кто смотрит. Переигровке это
  /// безразлично, `LeitnerCard` нормализует `due` в UTC у себя.
  final DateTime at;

  /// Локальный календарный день игравшего — тот же тип и та же природа, что
  /// у дня серии: у момента зона есть, у дня её нет (`streak.dart`).
  ///
  /// **Хранится, а не считается из [at]**, и это не денормализация ради
  /// скорости. Из UTC-момента локальный день не восстановим: человек,
  /// игравший в 01:00 по своему времени, в UTC попадает во вчера. День — это
  /// факт об ответе, ровно как и момент.
  final StreakDay localDay;

  /// Оценка для планировщика, посчитанная один раз в момент ответа
  /// (`observed_session.dart`) и сохранённая как есть.
  ///
  /// Переигровка держится на этом поле: пересчитывать оценку из `correct` и
  /// времени значило бы прогнать старые ответы через сегодняшний
  /// `gradeOutcome`, а он к тому времени может стать другим.
  final ReviewGrade grade;

  /// Сырой факт от игры — то же, что в [ReviewOutcome].
  final bool correct;
  final Duration responseTime;
  final Duration timeLimit;
  final int hintsUsed;

  /// Какая игра спрашивала. Значение из реестра `lib/app/games.dart`.
  final String gameId;

  /// Партия, внутри которой случился ответ.
  final String sessionId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnswerRecord &&
          wordId == other.wordId &&
          at == other.at &&
          localDay == other.localDay &&
          grade == other.grade &&
          correct == other.correct &&
          responseTime == other.responseTime &&
          timeLimit == other.timeLimit &&
          hintsUsed == other.hintsUsed &&
          gameId == other.gameId &&
          sessionId == other.sessionId;

  @override
  int get hashCode => Object.hash(
    wordId,
    at,
    localDay,
    grade,
    correct,
    responseTime,
    timeLimit,
    hintsUsed,
    gameId,
    sessionId,
  );

  @override
  String toString() =>
      'AnswerRecord($wordId, $grade, at: $at, day: $localDay, '
      'game: $gameId, session: $sessionId)';
}

/// Сколько ответов и сколько верных за один календарный день.
///
/// Запросная модель: то, что нужно экрану прогресса Фазы 3, и ничего сверх.
class DayTally {
  const DayTally({
    required this.day,
    required this.answers,
    required this.correct,
  });

  final StreakDay day;

  /// Всего ответов за день. Слово, вернувшееся на повтор, — два ответа.
  final int answers;

  /// Из них верных.
  final int correct;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayTally &&
          day == other.day &&
          answers == other.answers &&
          correct == other.correct;

  @override
  int get hashCode => Object.hash(day, answers, correct);

  @override
  String toString() => 'DayTally($day: $correct/$answers)';
}
