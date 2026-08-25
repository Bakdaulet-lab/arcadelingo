// Событие приложения: что именно в нём фиксируется.
//
// Тип маленький, и проверять в нём стоит ровно одно — что день берётся из
// живого момента, пока при нём ещё есть зона хоста. После записи он не
// восстановим, и ошибка здесь была бы невидимой до первого экрана прогресса.

import 'package:arcadelingo/domain/events/app_event.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('день считается из момента события', () {
    final at = DateTime.utc(2026, 8, 26, 23, 59, 59);

    final event = AppEvent.at(AppEventKind.appOpen, at);

    expect(event.localDay, StreakDay(2026, 8, 26));
    expect(event.at, at);
  });

  test('партия проставляется, когда она есть', () {
    final event = AppEvent.at(
      AppEventKind.roundStart,
      DateTime.utc(2026, 8, 26),
      sessionId: 'сессия-1',
    );

    expect(event.sessionId, 'сессия-1');
  });

  test('без партии — null, а не пустая строка', () {
    final event = AppEvent.at(AppEventKind.appOpen, DateTime.utc(2026, 8, 26));

    expect(event.sessionId, isNull);
  });

  test('равенство по полям', () {
    final at = DateTime.utc(2026, 8, 26, 12);

    expect(
      AppEvent.at(AppEventKind.appOpen, at),
      AppEvent.at(AppEventKind.appOpen, at),
    );
    expect(
      AppEvent.at(AppEventKind.appOpen, at).hashCode,
      AppEvent.at(AppEventKind.appOpen, at).hashCode,
    );
    expect(
      AppEvent.at(AppEventKind.roundStart, at),
      isNot(AppEvent.at(AppEventKind.appOpen, at)),
    );
    expect(
      AppEvent.at(AppEventKind.appOpen, at, sessionId: 'a'),
      isNot(AppEvent.at(AppEventKind.appOpen, at)),
    );
  });

  // Имена значений уезжают в хранилище: переименование расходится с уже
  // записанной историей ровно так же, как переименование gameId в реестре.
  test('имена родов событий — часть формата хранения', () {
    expect(AppEventKind.values.map((k) => k.name), [
      'appOpen',
      'roundStart',
      'roundOver',
      'roundAbandon',
      'reminderScheduled',
      'reminderOpened',
    ]);
  });
}
