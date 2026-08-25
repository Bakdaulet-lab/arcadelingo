// In-memory реализации портов: хранилище в переменной, без prefs и без
// Flutter.
//
// Фейк, а не мок, по правилу `.claude/rules/domain.md`: usecase обязан
// проверяться без единого мока, иначе зависимость просочилась не туда.
//
// Строгость в одном месте важна и здесь: [FailingCardStore] и
// [FailingStreakStore] возвращают Err ровно так же, как настоящие сторы на
// битом документе, — молчаливого «ну и ладно» ни там, ни тут нет.

import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/ports/card_store.dart';
import 'package:arcadelingo/domain/ports/streak_store.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/streak/streak.dart';

/// Карточки в памяти. [saves] — журнал записей, по нему видно, сколько раз и
/// чем именно сохраняли.
class InMemoryCardStore implements CardStore {
  InMemoryCardStore([Map<String, LeitnerCard>? initial])
    : _cards = Map.of(initial ?? const {});

  Map<String, LeitnerCard> _cards;

  /// Каждая запись — копия карты на момент сохранения.
  final List<Map<String, LeitnerCard>> saves = [];

  int resets = 0;

  @override
  Result<Map<String, LeitnerCard>> load() => Ok(Map.of(_cards));

  @override
  Future<bool> save(Map<String, LeitnerCard> cards) async {
    _cards = Map.of(cards);
    saves.add(Map.of(cards));
    return true;
  }

  @override
  Future<bool> reset() async {
    _cards = {};
    resets++;
    return true;
  }
}

/// Серия в памяти.
class InMemoryStreakStore implements StreakStore {
  InMemoryStreakStore([StreakState? initial])
    : _state = initial ?? StreakState.empty;

  StreakState _state;

  /// Каждое сохранённое состояние по порядку.
  final List<StreakState> saves = [];

  int resets = 0;

  StreakState get state => _state;

  @override
  Result<StreakState> load() => Ok(_state);

  @override
  Future<bool> save(StreakState state) async {
    _state = state;
    saves.add(state);
    return true;
  }

  @override
  Future<bool> reset() async {
    _state = StreakState.empty;
    resets++;
    return true;
  }
}

/// Карточки, которые не читаются: документ побит.
class FailingCardStore implements CardStore {
  FailingCardStore([this.message = 'карточки не читаются']);

  final String message;

  @override
  Result<Map<String, LeitnerCard>> load() => Err(Failure(message));

  @override
  Future<bool> save(Map<String, LeitnerCard> cards) async => true;

  @override
  Future<bool> reset() async => true;
}

/// Серия, которая не читается.
class FailingStreakStore implements StreakStore {
  FailingStreakStore([this.message = 'серия не читается']);

  final String message;

  /// Сколько раз пытались сбросить. Молчаливого сброса на битом документе
  /// быть не должно ни у кого, и счётчик делает это проверяемым.
  int resets = 0;

  @override
  Result<StreakState> load() => Err(Failure(message));

  @override
  Future<bool> save(StreakState state) async => true;

  @override
  Future<bool> reset() async {
    resets++;
    return true;
  }
}
