/// Сессия повторения поверх Лейтнера — реализация [ReviewSession].
///
/// Здесь, и только здесь, живёт порядок показа: состав очереди на старте и
/// правило «коробка 1 всплывает в этой же сессии, не раньше чем через три
/// других». Планировщик (`schedule`) знает про коробки и сроки, но не про
/// очередь; игра не знает ни того, ни другого — она видит контракт. Правила
/// очереди — `.claude/skills/srs-engine/SKILL.md`, «Очередь сессии».
///
/// Чистый слой (`.claude/rules/domain.md`): ни Flutter, ни хранилища, ни
/// часов. Время приходит функцией `now` и берётся заново на каждый ответ —
/// сессия может провисеть в фоне сутки, а `schedule` обязан считать от
/// момента ответа. Изменения состояния уходят колбэком `onCardsChanged`;
/// хост подключает `DateTime.now` и сохранение в стор.
library;

import 'dart:collection';

import '../review/review_contract.dart';
import '../srs/grade_outcome.dart';
import '../srs/leitner.dart';

/// Сколько других карточек должно пройти, прежде чем слово из коробки 1
/// всплывёт снова. Таблица скилла: «не раньше чем через 3 других».
const int _repeatAfter = 3;

/// Готовая к повтору карточка вместе с позицией слова в сиде — ключ
/// сортировки: по `due`, при равных — по сиду. `List.sort` нестабилен,
/// без второго ключа равные `due` дали бы произвольный порядок.
typedef _Ready = ({ReviewItem item, DateTime due, int index});

class LeitnerReviewSession implements ReviewSession {
  LeitnerReviewSession._({
    required Map<String, LeitnerCard> cards,
    required List<ReviewItem> queue,
    required DateTime Function() now,
    required void Function(Map<String, LeitnerCard>) onCardsChanged,
  }) : _cards = cards,
       _queue = queue,
       _now = now,
       _onCardsChanged = onCardsChanged,
       total = queue.length;

  /// Собирает очередь по состоянию [cards] и сиду [items] на момент `now()`.
  ///
  /// Сначала готовые к повтору — слова с карточкой, у которой `due` не позже
  /// `now`, — самые просроченные первыми, при равных `due` в порядке сида, но
  /// не больше [target]. Потом новые (карточки нет) в порядке сида, пока
  /// очередь не наберёт [target]. Не вошедшие — и готовые сверх потолка, и
  /// новые — остаются нетронутыми до следующей сессии; вторая сессия в тот же
  /// день возьмёт их первыми. Новое слово получает карточку только в [report]:
  /// выданное и не отвеченное следов в состоянии не оставляет.
  ///
  /// Карта копируется: сессия владеет своим состоянием, и что хост делает с
  /// исходной после старта — его дело. Карточки без слова в сиде в очередь не
  /// идут, но в карте остаются и уходят в каждый [onCardsChanged] — смена сида
  /// не теряет прогресс.
  ///
  /// [target] — размер сессии, его задаёт хост (SPEC: 15). Отрицательный —
  /// ошибка вызывающего, [ArgumentError]; ноль — пустая сессия.
  factory LeitnerReviewSession.start({
    required Map<String, LeitnerCard> cards,
    required List<ReviewItem> items,
    required int target,
    required DateTime Function() now,
    required void Function(Map<String, LeitnerCard> cards) onCardsChanged,
  }) {
    if (target < 0) {
      throw ArgumentError.value(target, 'target', 'размер сессии меньше нуля');
    }
    final startedAt = now();
    final ready = <_Ready>[];
    final fresh = <ReviewItem>[];
    for (final (index, item) in items.indexed) {
      final card = cards[item.word.id];
      if (card == null) {
        fresh.add(item);
      } else if (!card.due.isAfter(startedAt)) {
        ready.add((item: item, due: card.due, index: index));
      }
    }
    ready.sort((a, b) {
      final byDue = a.due.compareTo(b.due);
      return byDue != 0 ? byDue : a.index.compareTo(b.index);
    });
    final queue = [for (final r in ready.take(target)) r.item];
    queue.addAll(fresh.take(target - queue.length));
    return LeitnerReviewSession._(
      cards: Map.of(cards),
      queue: queue,
      now: now,
      onCardsChanged: onCardsChanged,
    );
  }

  final Map<String, LeitnerCard> _cards;
  final List<ReviewItem> _queue;
  final DateTime Function() _now;
  final void Function(Map<String, LeitnerCard>) _onCardsChanged;

  /// Слова, уже вставленные на повтор в этой сессии: один повтор на слово,
  /// и по этому же множеству ожидающие повторы отличаются от остальной очереди.
  final Set<String> _repeated = {};

  /// Выданное и ещё не отвеченное слово — страж протокола «ровно один
  /// `report()` на каждый непустой `nextItem()`».
  ReviewItem? _current;

  int _answered = 0;

  /// Размер очереди на старте. Не меняется до конца сессии: повтор вытесняет
  /// карточку, а не добавляется, — поэтому док контракта «сколько
  /// запланировано» верен буквально.
  @override
  final int total;

  @override
  int get answered => _answered;

  @override
  bool get isFinished => _current == null && _queue.isEmpty;

  @override
  ReviewItem? nextItem() {
    final pending = _current;
    if (pending != null) {
      throw StateError(
        'nextItem() до report(): слово "${pending.word.id}" выдано, ответа нет',
      );
    }
    if (_queue.isEmpty) return null;
    final item = _queue.removeAt(0);
    _current = item;
    return item;
  }

  /// Оценивает ответ ([gradeOutcome]), переводит карточку ([schedule]) от
  /// момента ответа, при необходимости ставит слово на повтор и отдаёт
  /// полную карту в колбэк.
  ///
  /// Без выданного слова — [StateError]: game-contract называет ноль и два
  /// `report()` самой частой ошибкой, которая портит расписание молча; здесь
  /// она становится громкой. Молчаливое «считаем как again» прятало бы баг
  /// игры в расписании.
  @override
  void report(ReviewOutcome outcome) {
    final item = _current;
    if (item == null) {
      throw StateError(
        'report() без выданного слова: nextItem() не вызывался '
        'или ответ по нему уже доложен',
      );
    }
    final now = _now();
    final id = item.word.id;
    final before = _cards[id] ?? LeitnerCard(box: LeitnerCard.minBox, due: now);
    final after = schedule(before, gradeOutcome(outcome), now: now);
    _cards[id] = after;
    _current = null;
    _answered++;
    // Коробка 1 — это `due == now`: again, а также hard на карточке коробки 1.
    // Правило по карточке, не по оценке: при SM-2, где ничего не бывает
    // готово немедленно, оно исчезнет само.
    if (!after.due.isAfter(now)) _requeue(item);
    // Колбэк последним: если он бросит, сессия уже в согласованном
    // состоянии, а не «в полёте» с неотвеченным словом.
    _onCardsChanged(UnmodifiableMapView(_cards));
  }

  /// Возвращает [item] в очередь: на позицию после [_repeatAfter] других,
  /// вместо последней не-повторной карточки — наименее срочной, она уйдёт в
  /// следующую сессию, — так что размер очереди и [total] не меняются.
  ///
  /// Повтора нет, если слово уже повторялось (один повтор на слово за
  /// сессию — иначе `hard`-петля на одном слове бесконечна) или если
  /// не-повторной карточки на позиции не ниже [_repeatAfter] нет: впереди
  /// меньше четырёх, и вставка дала бы повтор сразу после подсветки ответа —
  /// проверку кратковременной памяти вместо знания. Карточка и так в коробке
  /// 1 и всплывёт в следующей сессии.
  ///
  /// Ожидающие повторы невытесняемы. По динамике «вставка на третью позицию,
  /// снятие с головы каждый раунд» они и так всегда в голове очереди, но
  /// правило записано буквально, а не выведено из этого.
  void _requeue(ReviewItem item) {
    final id = item.word.id;
    if (_repeated.contains(id)) return;
    final victim = _queue.lastIndexWhere(
      (queued) => !_repeated.contains(queued.word.id),
    );
    if (victim < _repeatAfter) return;
    _queue.removeAt(victim);
    _queue.insert(_repeatAfter, item);
    _repeated.add(id);
  }
}
