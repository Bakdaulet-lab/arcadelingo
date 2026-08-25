# -*- coding: utf-8 -*-
"""Сверка черновиков порций со всем сидом и друг с другом.

Валидатор ловит точные совпадения: столкновение переводов, одинаковый набор
из четырёх вариантов, взаимные обманки. Приблизительные совпадения —
однокоренные переводы, почти-синонимы, слова, различающиеся одной буквой, —
механически не видны, а на сиде в двести с лишним слов глазами уже не
проверяются.

Порций можно передать несколько, и это не удобство, а необходимость: при
двойном заходе валидатор увидит столкновение между порцией 6 и порцией 7
только при сведении второй — то есть после того, как обе вычитаны. Здесь они
сверяются друг с другом до вычитки.

Скрипт ничего не решает и ничего не пишет: он печатает кандидатов, а решение
принимает вычитывающий. Найденные пары уходят либо в правки порции, либо в
`tool/confusables.csv` как ловушки.

Запуск (шаг чеклиста порции, до `--dry-run`):

    python scripts/crosscheck.py assets/words_seed.json tool/out/portion_NN.json
    python scripts/crosscheck.py assets/words_seed.json tool/out/portion_06.json \
        tool/out/portion_07.json

Отклонённые записи и нерешённые ничьи пропускаются: у них нечего сверять.
"""
import io
import json
import os
import sys

# Режем приставки и окончания, чтобы сравнивать корни, а не словоформы.
# Список грубый намеренно: цель — поднять кандидата на глаза, а не разобрать
# русскую морфологию. Ложные срабатывания дешевле пропусков.
PREFIXES = ('при', 'пере', 'раз', 'из', 'об', 'от', 'по', 'на', 'за', 'до',
            'про', 'под', 'вы', 'не', 'у', 'с', 'в', 'о')
ENDINGS = ('ться', 'ать', 'ять', 'ить', 'еть', 'ый', 'ий', 'ой', 'ая', 'ое',
           'ые', 'ик', 'ка', 'ко', 'о', 'а', 'ь', 'ы', 'и', 'е')

MIN_STEM = 4


def stem(word):
    w = word.lower().replace('ё', 'е').strip()
    for prefix in sorted(PREFIXES, key=len, reverse=True):
        if len(w) - len(prefix) >= MIN_STEM and w.startswith(prefix):
            w = w[len(prefix):]
            break
    # Окончание снимается дважды, а не один раз: «тренироваться» после «ться»
    # оставляет «тренирова», и от «тренировки» («трениров») это уже отличается
    # одной буквой. На порции 5 пара practice/exercise так и не нашлась —
    # скрипт молчал ровно там, где обязан был говорить.
    for _ in range(2):
        for ending in sorted(ENDINGS, key=len, reverse=True):
            if len(w) - len(ending) >= 3 and w.endswith(ending):
                w = w[:-len(ending)]
                break
        else:
            break
    return w


class Entry:
    """Слово с указанием, откуда оно: из сида или из конкретной порции."""

    def __init__(self, source, word):
        self.source = source
        self.id = word['id']
        self.translation = word['translation']
        self.distractors = list(word['distractors'])

    def __str__(self):
        return '%s (%s)' % (self.id, self.source)


def read_words(path):
    return json.loads(io.open(path, encoding='utf-8').read())['words']


def entries_of(path, source, drafts_only):
    """Записи, которые вообще подлежат сверке."""
    result = []
    skipped = 0
    for word in read_words(path):
        if drafts_only and ('reject' in word
                            or not word.get('translation')
                            or not word.get('part_of_speech')):
            skipped += 1
            continue
        result.append(Entry(source, word))
    return result, skipped


def section(title):
    print()
    print('=== %s ===' % title)


def report(lines):
    print('\n'.join(lines) if lines else '  нет')


def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except AttributeError:
        pass
    seed, _ = entries_of(sys.argv[1], 'сид', drafts_only=False)

    drafts = []
    for path in sys.argv[2:]:
        name = 'порция ' + os.path.basename(path).replace(
            'portion_', '').replace('.json', '').lstrip('0')
        words, skipped = entries_of(path, name, drafts_only=True)
        drafts.append((name, words, skipped))
        print('%s: к сверке %d (пропущено %d — отказы и ничьи)'
              % (name, len(words), skipped))
    print('сид: %d слов' % len(seed))

    checked = [word for _, words, _ in drafts for word in words]
    everything = seed + checked

    def others(word):
        """Всё, с чем сверяется запись: сид и все прочие черновики."""
        return [other for other in everything if other.id != word.id]

    seen_pairs = set()

    def once(a, b):
        """Пара «черновик против черновика» не должна печататься дважды."""
        key = tuple(sorted((a.id, b.id)))
        if key in seen_pairs:
            return False
        seen_pairs.add(key)
        return True

    section('1. точное столкновение переводов (это же поймает валидатор)')
    lines = []
    for word in checked:
        for other in others(word):
            if other.translation == word.translation and once(word, other):
                lines.append('  %s и %s — оба «%s»'
                             % (word, other, word.translation))
    report(lines)

    seen_pairs.clear()
    section('2. общий корень перевода')
    lines = []
    for word in checked:
        st = stem(word.translation)
        if len(st) < MIN_STEM:
            continue
        for other in others(word):
            if stem(other.translation) == st and once(word, other):
                lines.append('  %s «%s» ~ %s «%s» (корень «%s»)'
                             % (word, word.translation, other,
                                other.translation, st))
    report(lines)

    seen_pairs.clear()
    section('3. общий корень английского слова')
    lines = []
    for word in checked:
        for other in others(word):
            a, b = word.id, other.id
            if (a.startswith(b) or b.startswith(a)
                    or (len(a) >= MIN_STEM and len(b) >= MIN_STEM
                        and a[:MIN_STEM] == b[:MIN_STEM])):
                if once(word, other):
                    lines.append('  %s ~ %s' % (word, other))
    report(lines)

    seen_pairs.clear()
    section('4. зеркальные пары, которые появятся')
    lines = []
    for word in checked:
        for other in others(word):
            if (other.translation in word.distractors
                    and word.translation in other.distractors
                    and once(word, other)):
                lines.append('  %s ↔ %s' % (word, other))
    report(lines)

    seen_pairs.clear()
    section('5. одинаковый набор из четырёх (это же поймает валидатор)')
    lines = []
    for word in checked:
        key = frozenset([word.translation] + word.distractors)
        for other in others(word):
            if frozenset([other.translation] + other.distractors) == key:
                if once(word, other):
                    lines.append('  %s = %s' % (word, other))
    report(lines)

    section('6. перевод уже стоит обманкой у другого слова (одностороннее)')
    lines = []
    for word in checked:
        owners = [str(other) for other in others(word)
                  if word.translation in other.distractors]
        if owners:
            lines.append('  «%s» (%s) — обманка у: %s'
                         % (word.translation, word, ', '.join(owners)))
    report(lines)

    print()
    print('Ничего не записано: это отчёт. Пары, которые решишь считать')
    print('ловушками, вносятся в tool/confusables.csv с причиной.')


main()
