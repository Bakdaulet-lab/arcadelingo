// Стор серии на prefs. Устройство и поведение — те же, что у стора Лейтнера,
// и тесты это подтверждают поимённо: два документа в одном хранилище обязаны
// вести себя одинаково, иначе «прогресс не читается» будет значить разное в
// зависимости от того, какой из них побился.

import 'package:arcadelingo/data/streak/streak_prefs_store.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/result.dart';

/// Ключ документа — литералом, а не константой из lib/: переименование
/// означает потерю серии у всех, кто уже играл, и обязано ломать тест.
const String _key = 'streak_state';

Future<StreakPrefsStore> _store([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  return StreakPrefsStore(await SharedPreferences.getInstance());
}

void main() {
  test('ключа нет — первый запуск, а не ошибка', () async {
    final store = await _store();

    expect(ok(store.load()), StreakState.empty);
  });

  test('записанное читается обратно', () async {
    final store = await _store();
    final state = StreakState(
      current: 4,
      best: 9,
      lastDay: StreakDay(2026, 8, 25),
    );

    await store.save(state);

    expect(ok(store.load()), state);
  });

  test('запись заменяет документ целиком, а не сливается с прежним', () async {
    final store = await _store();
    await store.save(
      StreakState(current: 4, best: 9, lastDay: StreakDay(2026, 8, 25)),
    );

    await store.save(StreakState.empty);

    expect(ok(store.load()), StreakState.empty);
  });

  test('битый документ — Err, и стор ничего не сбрасывает', () async {
    final store = await _store({_key: 'не json'});

    expect(err(store.load()).message, isNotEmpty);
    expect(
      err(store.load()).message,
      isNotEmpty,
      reason: 'второе чтение даёт то же самое: улики на месте',
    );
  });

  test('reset удаляет документ: следующее чтение — первый запуск', () async {
    final store = await _store();
    await store.save(
      StreakState(current: 4, best: 9, lastDay: StreakDay(2026, 8, 25)),
    );

    await store.reset();

    expect(ok(store.load()), StreakState.empty);
  });

  test('пишет под своим ключом и не трогает чужой', () async {
    final store = await _store({'leitner_state': 'чужое'});
    await store.save(
      StreakState(current: 1, best: 1, lastDay: StreakDay(2026, 8, 25)),
    );

    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getString(_key), contains('2026-08-25'));
    expect(
      prefs.getString('leitner_state'),
      'чужое',
      reason: 'два документа в одном хранилище живут независимо',
    );
  });

  test('reset не трогает документ карточек', () async {
    final store = await _store({'leitner_state': 'чужое'});

    await store.reset();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('leitner_state'), 'чужое');
  });
}
