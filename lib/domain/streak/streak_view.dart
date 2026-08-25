/// Серия глазами сегодняшнего дня — чистое представление, без записи.
///
/// Зачем отдельная функция, если состояние и так лежит рядом. Затем, что
/// `StreakState` описывает **последний засчитанный день**, а не сегодняшний, и
/// показывать его как есть значит врать. Человек, игравший три дня подряд и
/// пропустивший позавчера и вчера, откроет приложение и увидит «Серия: 3 дня»:
/// серии уже нет, а состояние об этом не знает — оно узнает только в момент
/// следующей игры, потому что в полночь у нас ничего не выполняется.
///
/// Здесь же решается вторая половина того же вопроса: заморозка, потраченная
/// молча, — несуществующая заморозка. Игрок обязан узнать и что его спасли, и
/// какой ценой, а значит состояние запаса выносится наружу явным типом, а не
/// остаётся арифметикой внутри перехода.
///
/// Чистый слой: сегодняшний день приходит параметром, как и везде в `domain/`.
library;

import 'streak.dart';

/// Что с запасом заморозок прямо сейчас.
class FreezeStatus {
  const FreezeStatus({
    required this.available,
    required this.spentOn,
    required this.daysToNext,
  });

  /// Заморозка в запасе есть.
  final bool available;

  /// День текущей серии, который прикрыла заморозка; null — такого не было.
  final StreakDay? spentOn;

  /// Сколько засчитанных дней осталось до следующей заморозки. Ноль, если
  /// она уже есть.
  final int daysToNext;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FreezeStatus &&
          available == other.available &&
          spentOn == other.spentOn &&
          daysToNext == other.daysToNext;

  @override
  int get hashCode => Object.hash(available, spentOn, daysToNext);

  @override
  String toString() =>
      'FreezeStatus(available: $available, spentOn: $spentOn, '
      'daysToNext: $daysToNext)';
}

/// Серия на сегодня: что показывать и что случится, если сыграть.
class StreakView {
  const StreakView({
    required this.days,
    required this.best,
    required this.playedToday,
    required this.alive,
    required this.freezeWillCover,
    required this.freeze,
  });

  /// Сколько дней показывать сегодня. Ноль — серии нет: либо её не было
  /// вовсе, либо она уже оборвана и сегодняшняя игра начнёт новую.
  final int days;

  /// Рекорд за всё время. Обрывом не сбрасывается.
  final int best;

  /// Сегодняшний день уже засчитан.
  final bool playedToday;

  /// Серия жива: сегодняшняя игра её продлит, а не начнёт заново.
  final bool alive;

  /// Сегодняшняя игра **потратит** заморозку — пропущен ровно один день, и
  /// прикрыть его есть чем. Это и есть «серия под угрозой, но спасём».
  final bool freezeWillCover;

  final FreezeStatus freeze;

  @override
  String toString() =>
      'StreakView(days: $days, best: $best, playedToday: $playedToday, '
      'alive: $alive, freezeWillCover: $freezeWillCover, freeze: $freeze)';
}

/// Как выглядит [state] в день [today].
///
/// Ничего не записывает и ничего не тратит: заморозка уходит в момент игры
/// ([advanceStreak]), а не в момент показа экрана. Здесь только предсказание —
/// то самое, которое человек должен увидеть до того, как решит играть.
StreakView streakAsOf(StreakState state, StreakDay today) {
  throw UnimplementedError('streakAsOf');
}
