# -*- coding: utf-8 -*-
"""Сверка черновика порции со всем сидом — то, чего валидатор увидеть не может.

Валидатор ловит точные совпадения: столкновение переводов, одинаковый набор
из четырёх вариантов, взаимные обманки. Приблизительные совпадения —
однокоренные переводы, почти-синонимы, слова, различающиеся одной буквой, —
механически не видны, а на сиде в двести слов глазами уже не проверяются.

Скрипт ничего не решает и ничего не пишет: он печатает кандидатов, а решение
принимает вычитывающий. Найденные пары уходят либо в правки порции, либо в
`tool/confusables.csv` как ловушки.

Запуск (шаг чеклиста порции, до `--dry-run`):

    python scripts/crosscheck.py assets/words_seed.json tool/out/portion_NN.json

Отклонённые записи и нерешённые ничьи пропускаются: у них нечего сверять.
"""
import io
import json
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
    for ending in sorted(ENDINGS, key=len, reverse=True):
        if len(w) - len(ending) >= 3 and w.endswith(ending):
            return w[:-len(ending)]
    return w


def read_words(path):
    document = json.loads(io.open(path, encoding='utf-8').read())
    return document['words']


def draft_of(words):
    """Записи порции, которые вообще подлежат сверке."""
    ready = {}
    for word in words:
        if 'reject' in word:
            continue
        if not word.get('translation') or not word.get('part_of_speech'):
            continue
        ready[word['id']] = (word['translation'], list(word['distractors']))
    return ready


def section(title):
    print()
    print('=== %s ===' % title)


def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except AttributeError:
        pass
    seed = read_words(sys.argv[1])
    words = read_words(sys.argv[2])
    draft = draft_of(words)

    skipped = len(words) - len(draft)
    print('сид: %d слов; в порции к сверке: %d (пропущено %d — отказы и ничьи)'
          % (len(seed), len(draft), skipped))

    seed_by_translation = {w['translation']: w['id'] for w in seed}

    section('1. точное столкновение переводов (это же поймает валидатор)')
    hits = [(i, t) for i, (t, _) in draft.items() if t in seed_by_translation]
    for i, t in hits:
        print('  %s → «%s» уже перевод слова %s' % (i, t, seed_by_translation[t]))
    if not hits:
        print('  нет')

    section('2. общий корень перевода со словом сида')
    found = []
    for i, (t, _) in draft.items():
        st = stem(t)
        if len(st) < MIN_STEM:
            continue
        for w in seed:
            if stem(w['translation']) == st:
                found.append('  %s «%s» ~ %s «%s» (корень «%s»)'
                             % (i, t, w['id'], w['translation'], st))
    print('\n'.join(found) if found else '  нет')

    section('3. общий корень английского слова со словом сида')
    found = []
    for i in draft:
        for w in seed:
            sid = w['id']
            if i == sid:
                continue
            if (i.startswith(sid) or sid.startswith(i)
                    or (len(i) >= MIN_STEM and len(sid) >= MIN_STEM
                        and i[:MIN_STEM] == sid[:MIN_STEM])):
                found.append('  %s ~ %s' % (i, sid))
    print('\n'.join(found) if found else '  нет')

    section('4. зеркальные пары, которые появятся')
    found = []
    for i, (t, ds) in draft.items():
        for w in seed:
            if w['translation'] in ds and t in w['distractors']:
                found.append('  %s ↔ %s' % (i, w['id']))
    print('\n'.join(found) if found else '  нет')

    section('5. одинаковый набор из четырёх (это же поймает валидатор)')
    sets = {frozenset([w['translation']] + w['distractors']): w['id'] for w in seed}
    found = []
    for i, (t, ds) in draft.items():
        key = frozenset([t] + ds)
        if key in sets:
            found.append('  %s = %s' % (i, sets[key]))
    print('\n'.join(found) if found else '  нет')

    section('6. мой перевод уже стоит обманкой у слова сида (одностороннее)')
    found = []
    for i, (t, _) in draft.items():
        owners = [w['id'] for w in seed if t in w['distractors']]
        if owners:
            found.append('  «%s» (%s) — обманка у: %s' % (t, i, ', '.join(owners)))
    print('\n'.join(found) if found else '  нет')

    print()
    print('Ничего не записано: это отчёт. Пары, которые решишь считать')
    print('ловушками, вносятся в tool/confusables.csv с причиной.')


main()
