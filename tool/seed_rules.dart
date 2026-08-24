/// Механические правила содержания `assets/words_seed.json` — одним файлом.
///
/// Единственный источник правды: их читает и `test/assets/words_seed_test.dart`
/// на живом ассете, и `tool/merge_portion.dart` на ещё не записанном документе.
/// Два независимых списка правил разошлись бы на первой же порции.
///
/// Чего здесь нет и быть не может: часть речи дистрактора, синонимия,
/// однокоренные слова, «этот перевод правильный». Это ручная вычитка. Зелёный
/// прогон означает «форма и инварианты в порядке», а не «контент выверен».
///
/// Форму записи (типы полей, разбор JSON) сторожит `lib/data/words/
/// words_seed_codec.dart`. Здесь — содержание конкретного сида.
library;

/// Правила, по одному на проверяемое свойство. Тест ассета держит по тесту на
/// правило: «сид сломан» без указания, чем именно, — бесполезное сообщение.
enum SeedRule {
  /// Корень документа: версия формата, языки, список слов на месте.
  document,

  /// `id`, `text`, `translation` непусты, `id == text` в нижнем регистре.
  identity,

  /// `id` и `text` не повторяются.
  uniqueIds,

  /// `part_of_speech` из закрытого набора.
  partOfSpeech,

  /// `level` из закрытого набора.
  level,

  /// Ровно три непустых различных дистрактора, ни один не равен переводу.
  distractors,

  /// `text` — латиница, перевод и дистракторы — кириллица.
  script,

  /// Два разных слова с одним переводом: игрок наказан за верный ответ.
  translationCollision,

  /// У двух слов совпал весь набор из четырёх вариантов — запоминается
  /// позиция кнопки, а не слово.
  identicalOptions,
}

/// Нарушение правила: что именно и у какого слова.
class SeedProblem {
  const SeedProblem(this.rule, this.message);

  final SeedRule rule;
  final String message;

  @override
  String toString() => '${rule.name}: $message';
}

/// Пара слов, взаимно стоящих друг у друга в дистракторах (`open` ↔ `close`).
///
/// Это **не** нарушение: в сиде такие пары сделаны намеренно. Лечится правилом
/// сессии «не показывать оба слова пары в один день» (задача Б1), а не
/// запретом в контенте, — поэтому здесь отчёт, а не правило.
class MirrorPair {
  const MirrorPair(this.first, this.second);

  final String first;
  final String second;

  @override
  String toString() => '$first ↔ $second';
}

/// Версия формата сида, которую понимает игра.
const int seedFormatVersion = 1;

/// Сколько вариантов-обманок обязано быть у слова.
const int seedDistractorCount = 3;

/// Части речи, с которыми умеет работать игра.
const Set<String> seedPartsOfSpeech = {'noun', 'verb', 'adj', 'adv'};

/// Уровни CEFR, нижним регистром — как `id`.
const Set<String> seedLevels = {'a1', 'a2', 'b1', 'b2', 'c1', 'c2'};

final RegExp _latinWord = RegExp(r'^[a-z]+$');
final RegExp _cyrillicPhrase = RegExp(r'^[а-яё][а-яё -]*$');

/// Разобранный JSON сида → список нарушений. Пустой список — правила соблюдены.
///
/// Если сломан сам корень, дальше идти некуда: возвращается один
/// [SeedRule.document] и больше ничего, иначе посыпались бы каскадом
/// нарушения всех остальных правил на данных, которых нет.
List<SeedProblem> validateSeed(Object? root) {
  if (root is! Map<String, Object?>) {
    return const [SeedProblem(SeedRule.document, 'корень сида не объект')];
  }
  final rootIssues = <String>[];
  if (root['version'] != seedFormatVersion) {
    rootIssues.add('version ${root['version']} вместо $seedFormatVersion');
  }
  if (root['source_lang'] != 'en') {
    rootIssues.add('source_lang ${root['source_lang']} вместо en');
  }
  if (root['target_lang'] != 'ru') {
    rootIssues.add('target_lang ${root['target_lang']} вместо ru');
  }
  final rawWords = root['words'];
  if (rawWords is! List<Object?>) {
    rootIssues.add('words отсутствует или не список');
    return [SeedProblem(SeedRule.document, rootIssues.join('; '))];
  }
  if (rootIssues.isNotEmpty) {
    return [SeedProblem(SeedRule.document, rootIssues.join('; '))];
  }

  final problems = <SeedProblem>[];
  final seenIds = <String>{};
  final seenTexts = <String>{};
  final byTranslation = <String, String>{};
  final byOptions = <String, String>{};

  for (final (index, raw) in rawWords.indexed) {
    if (raw is! Map<String, Object?>) {
      problems.add(SeedProblem(SeedRule.identity, 'запись #$index не объект'));
      continue;
    }
    final id = raw['id'];
    final text = raw['text'];
    final translation = raw['translation'];
    final name = id is String && id.isNotEmpty ? id : 'запись #$index';

    // identity
    if (id is! String || id.isEmpty) {
      problems.add(
        SeedProblem(SeedRule.identity, '$name: id пуст или не строка'),
      );
    }
    if (text is! String || text.isEmpty) {
      problems.add(
        SeedProblem(SeedRule.identity, '$name: text пуст или не строка'),
      );
    }
    if (translation is! String || translation.trim().isEmpty) {
      problems.add(
        SeedProblem(SeedRule.identity, '$name: translation пуст или не строка'),
      );
    }
    if (id is String && text is String && id != text.toLowerCase()) {
      problems.add(
        SeedProblem(SeedRule.identity, '$name: id не равен text ("$text")'),
      );
    }

    // uniqueIds
    if (id is String && id.isNotEmpty && !seenIds.add(id)) {
      problems.add(SeedProblem(SeedRule.uniqueIds, '$name: id повторяется'));
    }
    if (text is String && text.isNotEmpty && !seenTexts.add(text)) {
      problems.add(
        SeedProblem(SeedRule.uniqueIds, '$name: text "$text" повторяется'),
      );
    }

    // partOfSpeech и level
    final partOfSpeech = raw['part_of_speech'];
    if (!seedPartsOfSpeech.contains(partOfSpeech)) {
      problems.add(
        SeedProblem(
          SeedRule.partOfSpeech,
          '$name: part_of_speech "$partOfSpeech" вне набора '
          '${seedPartsOfSpeech.join(", ")}',
        ),
      );
    }
    final level = raw['level'];
    if (!seedLevels.contains(level)) {
      problems.add(
        SeedProblem(
          SeedRule.level,
          '$name: level "$level" вне набора ${seedLevels.join(", ")}',
        ),
      );
    }

    // distractors
    final rawDistractors = raw['distractors'];
    final distractors = <String>[];
    var distractorsUsable = true;
    if (rawDistractors is! List<Object?>) {
      distractorsUsable = false;
      problems.add(
        SeedProblem(
          SeedRule.distractors,
          '$name: distractors отсутствует или не список',
        ),
      );
    } else {
      for (final value in rawDistractors) {
        if (value is! String) {
          distractorsUsable = false;
          problems.add(
            SeedProblem(
              SeedRule.distractors,
              '$name: дистрактор не строка: $value',
            ),
          );
          continue;
        }
        distractors.add(value);
      }
      if (rawDistractors.length != seedDistractorCount) {
        distractorsUsable = false;
        problems.add(
          SeedProblem(
            SeedRule.distractors,
            '$name: дистракторов ${rawDistractors.length}, '
            'а должно быть $seedDistractorCount',
          ),
        );
      }
    }
    if (distractors.any((value) => value.trim().isEmpty)) {
      distractorsUsable = false;
      problems.add(
        SeedProblem(SeedRule.distractors, '$name: пустой дистрактор'),
      );
    }
    final normalized = distractors.map(_normalize).toSet();
    if (distractorsUsable && normalized.length != distractors.length) {
      problems.add(
        SeedProblem(SeedRule.distractors, '$name: дистракторы повторяются'),
      );
    }
    if (translation is String && normalized.contains(_normalize(translation))) {
      problems.add(
        SeedProblem(
          SeedRule.distractors,
          '$name: дистрактор совпадает с переводом "$translation"',
        ),
      );
    }

    // script
    if (text is String && !_latinWord.hasMatch(text)) {
      problems.add(
        SeedProblem(SeedRule.script, '$name: text "$text" не латиница'),
      );
    }
    if (translation is String && !_cyrillicPhrase.hasMatch(translation)) {
      problems.add(
        SeedProblem(
          SeedRule.script,
          '$name: translation "$translation" не кириллица',
        ),
      );
    }
    for (final value in distractors) {
      if (!_cyrillicPhrase.hasMatch(value)) {
        problems.add(
          SeedProblem(
            SeedRule.script,
            '$name: дистрактор "$value" не кириллица',
          ),
        );
      }
    }

    // translationCollision
    if (id is String &&
        translation is String &&
        translation.trim().isNotEmpty) {
      final key = _normalize(translation);
      final owner = byTranslation[key];
      if (owner == null) {
        byTranslation[key] = id;
      } else if (owner != id) {
        problems.add(
          SeedProblem(
            SeedRule.translationCollision,
            'слова "$owner" и "$id" переводятся одинаково: "$translation". '
            'Обманка к одному накажет за верный ответ на другом',
          ),
        );
      }
    }

    // identicalOptions
    if (id is String &&
        translation is String &&
        distractorsUsable &&
        distractors.length == seedDistractorCount) {
      final options = <String>{_normalize(translation), ...normalized};
      if (options.length == seedDistractorCount + 1) {
        final key = (options.toList()..sort()).join('|');
        final owner = byOptions[key];
        if (owner == null) {
          byOptions[key] = id;
        } else if (owner != id) {
          problems.add(
            SeedProblem(
              SeedRule.identicalOptions,
              'у слов "$owner" и "$id" совпал весь набор вариантов: '
              'запоминается позиция кнопки, а не слово',
            ),
          );
        }
      }
    }
  }
  return problems;
}

/// Зеркальные пары — отчёт для человека, не правило. См. [MirrorPair].
List<MirrorPair> findMirrorPairs(Object? root) {
  if (root is! Map<String, Object?>) return const [];
  final rawWords = root['words'];
  if (rawWords is! List<Object?>) return const [];

  final ids = <String>[];
  final translations = <String>[];
  final distractors = <Set<String>>[];
  for (final raw in rawWords) {
    if (raw is! Map<String, Object?>) continue;
    final id = raw['id'];
    final translation = raw['translation'];
    final rawDistractors = raw['distractors'];
    if (id is! String || translation is! String) continue;
    if (rawDistractors is! List<Object?>) continue;
    ids.add(id);
    translations.add(_normalize(translation));
    distractors.add({
      for (final value in rawDistractors)
        if (value is String) _normalize(value),
    });
  }

  // Порядок документа: пара называется в том же порядке, в каком слова лежат
  // в сиде, — так её проще найти глазами.
  final pairs = <MirrorPair>[];
  for (var i = 0; i < ids.length; i++) {
    for (var j = i + 1; j < ids.length; j++) {
      if (distractors[i].contains(translations[j]) &&
          distractors[j].contains(translations[i])) {
        pairs.add(MirrorPair(ids[i], ids[j]));
      }
    }
  }
  return pairs;
}

String _normalize(String value) => value.trim().toLowerCase();
