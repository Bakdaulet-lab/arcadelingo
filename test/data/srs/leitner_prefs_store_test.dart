// Стор состояния Лейтнера поверх shared_preferences.
//
// In-memory фейк из самого пакета (setMockInitialValues) вместо мока:
// он сбрасывает синглтон SharedPreferences, поэтому вызывается перед каждым
// тестом, иначе порядок тестов начинает их связывать.

import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/result.dart';

/// Имя ключа — литералом, не `LeitnerPrefsStore.key`: это контракт
/// персистентности. Переименование в коде обязано сломать этот тест, иначе
/// пользователи молча потеряют прогресс.
const _key = 'leitner_state';

final _now = DateTime.utc(2026, 3, 8, 12);

Future<LeitnerPrefsStore> _storeWith(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  return LeitnerPrefsStore(await SharedPreferences.getInstance());
}

void main() {
  test('ключа нет → первый запуск: Ok, пустая изменяемая карта', () async {
    final store = await _storeWith({});

    final cards = ok(store.load());

    expect(cards, isEmpty);
    // Сессия будет дописывать карточки прямо в эту карту; const {} упал бы
    // здесь с UnsupportedError — и только на первом запуске.
    expect(
      () => cards['apple'] = LeitnerCard(box: 1, due: _now),
      returnsNormally,
    );
  });

  test('save → load возвращает то же состояние', () async {
    final store = await _storeWith({});
    final cards = {
      'apple': LeitnerCard(box: 2, due: _now.add(const Duration(days: 1))),
      'bread': LeitnerCard(box: 1, due: _now),
    };

    expect(await store.save(cards), isTrue);

    expect(ok(store.load()), cards);
  });

  test('save заменяет документ целиком, а не сливает с прежним', () async {
    final store = await _storeWith({});
    await store.save({'apple': LeitnerCard(box: 2, due: _now)});

    await store.save({'bread': LeitnerCard(box: 3, due: _now)});

    final cards = ok(store.load());
    expect(cards.keys, ['bread']);
  });

  test('под ключом мусор → Err, стор ничего не перезаписывает', () async {
    final store = await _storeWith({_key: '{bad'});

    err(store.load());

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_key), '{bad', reason: 'улики должны остаться');
  });

  test('reset() удаляет документ: следующий load() — первый запуск', () async {
    final store = await _storeWith({_key: '{bad'});

    expect(await store.reset(), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(_key),
      isNull,
      reason: 'ключа нет, не пустая строка',
    );
    expect(ok(store.load()), isEmpty);
  });

  test(
    'save() кодирует карту до первого await: поздняя мутация не попадает',
    () async {
      // Сессия отдаёт хосту живую карту, а хост делает unawaited(save(cards)).
      // Это безопасно, только пока кодирование идёт синхронно, до первого
      // await: иначе следующий report() успеет изменить карту до записи.
      final store = await _storeWith({});
      final cards = {'apple': LeitnerCard(box: 2, due: _now)};

      final pending = store.save(cards);
      cards['apple'] = LeitnerCard(box: 5, due: _now);
      cards['bread'] = LeitnerCard(box: 1, due: _now);
      await pending;

      expect(ok(store.load()), {'apple': LeitnerCard(box: 2, due: _now)});
    },
  );
}
