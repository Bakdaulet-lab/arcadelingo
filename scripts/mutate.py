# -*- coding: utf-8 -*-
"""Мутационная проверка тестов: ломаем реализацию и требуем красноты.

CLAUDE.md → «Тесты»: зелёный тест на сломанном коде — бутафория. Скрипт
делает эту проверку воспроизводимой, а не разовой: каждая мутация здесь
описана вместе с тем, какой тест обязан её поймать.

Запуск: python scripts/mutate.py <файл-с-мутациями.json> <путь-к-тестам>...

Путей может быть несколько. Раньше брался только первый, а лишние молча
терялись — и десять мутаций Этапа 2.3 отчитались «ТЕАТР» просто потому, что
их тесты не гонялись. Молчаливое сужение проверки хуже её отсутствия:
отсутствие видно.

Целиком `test` сюда передавать нельзя: голдены локально красные всегда
(эталоны Linux), и тогда КАЖДАЯ мутация отчитается пойманной.

## Виды случаев

Поле `kind` необязательное. Без него — `text`, поэтому все наборы, написанные
до появления поля, гоняются без единой правки.

    {"name": ..., "file": ...,      # обязательны всегда
     "kind": "text",                # по умолчанию
     "old": "...", "new": "..."}    # ровно одно вхождение old в файле

    {"kind": "bytes",               # для PNG и прочего двоичного
     "old": "00 00 00 48", "new": "00 00 00 30"}   # hex, пробелы можно

    {"kind": "create",              # мутация — само появление файла
     "content": "<resources/>\\n"}   # откат: файл удаляется

`bytes` появился потому, что раннер читает файлы как UTF-8 и на PNG падал:
три мутации иконок из задачи 0.15 пришлось гонять руками. `create` — потому
что «вернуть удалённый values-night/styles.xml» это мутация, у которой нет
`old`: ломает не правка файла, а его существование.

Две ловушки, обе стоили красноты не по делу:

* **`bytes` не чинит контрольные суммы.** Патч ширины в IHDR оставляет PNG с
  неверным CRC. Тест, который читает поле сам, покраснеет по делу; тест,
  который зовёт настоящий декодер, покраснеет на «файл битый» — то есть
  подтвердит не то, что проверял. Мутация честна ровно тогда, когда тест
  читает то самое поле, которое она правит.
* **длину `bytes` менять почти всегда нельзя.** В форматах со смещениями и
  длинами блоков сдвиг ломает всё после точки правки, и тест краснеет по
  причине, которой мутация не задумывала. Раннер это не запрещает — он не
  знает форматов, — но по умолчанию бери `old` и `new` одной длины.
"""
import io
import json
import os
import subprocess
import sys

KINDS = ('text', 'bytes', 'create')


class Refused(Exception):
    """Случай применить нельзя: план разошёлся с деревом."""


def read(path):
    return io.open(path, encoding='utf-8').read()


def read_bytes(path):
    with io.open(path, 'rb') as handle:
        return handle.read()


def eol_of(path):
    # Рабочая копия на Windows приходит с CRLF, а восстановление через '\n'
    # переписало бы переносы во всём файле: git показал бы правку там, где
    # раннер обещал ничего не трогать. На ассете это чуть не уехало в коммит.
    with io.open(path, 'rb') as handle:
        return '\r\n' if b'\r\n' in handle.read() else '\n'


def write(path, text, eol='\n'):
    io.open(path, 'w', encoding='utf-8', newline=eol).write(text)


def write_bytes(path, data):
    with io.open(path, 'wb') as handle:
        handle.write(data)


def kind_of(case):
    """Вид случая. Отсутствие поля — `text`, и это ради старых наборов."""
    return case.get('kind', 'text')


def hex_bytes(text):
    """Hex-строка в байты. Пробелы между байтами разрешены — так читаемее."""
    return bytes.fromhex(text)


def assert_committed(paths):
    """Мутировать можно только закоммиченный файл.

    Файл восстанавливается в finally, но finally не спасает от внешнего
    убийства процесса: прогон, снятый по таймауту, оставляет в файле
    применённую мутацию. Если при этом в файле лежала незакоммиченная
    правка, отличить её от остатка мутации нечем и восстановить неоткуда —
    копии нет нигде.

    Проверяется именно `git diff` (рабочая копия против индекса), а не
    `git diff HEAD`: заиндексированную правку `git checkout -- <файл>`
    вернёт из индекса, а неотслеживаемую — уже ниоткуда.

    Вопросов на самом деле два, и `git diff` отвечает только на второй.
    Про путь, которого в индексе нет, он молчит и выходит с нулём — то есть
    докладывает «чисто» о файле, которого не видел. Замерено на свежесозданном
    файле: код возврата 0. Задача 0.15 завела пять новых файлов ресурсов, и
    страж пропустил бы их все — дыра открывалась ровно в тех задачах, которые
    заводят файлы, то есть там, где мутации и нужны.

    Поэтому сначала `ls-files --error-unmatch` («знает ли git этот путь»), и
    только потом `git diff` («не разошёлся ли он с индексом»). Порядок не
    косметический: обратный вернул бы то же самое молчаливое «чисто».
    """
    dirty = []
    for path in sorted(set(paths)):
        known = subprocess.run(['git', 'ls-files', '--error-unmatch',
                                '--', path],
                               capture_output=True, shell=True)
        if known.returncode != 0:
            dirty.append((path, 'git этого пути не знает'))
            continue
        done = subprocess.run(['git', 'diff', '--exit-code', '--', path],
                              capture_output=True, shell=True)
        if done.returncode != 0:
            dirty.append((path, 'есть незакоммиченная правка'))
    if not dirty:
        return
    print('Мутации не запущены: целевой файл не тот, каким его вернёт git.')
    for path, why in dirty:
        print('  %s — %s' % (path, why))
    print('')
    print('Прогон, убитый по таймауту, оставил бы в них мутацию, а вернуть')
    print('правку было бы неоткуда. Закоммить их и запусти снова.')
    sys.exit(2)


def assert_absent(paths):
    """Страж для `create`: создаваемого файла быть не должно.

    `assert_committed` сюда не годится, и не потому, что его жалко трогать:
    он бы отказал всем create-случаям подряд. Он требует, чтобы git знал путь
    и не видел по нему расхождений, а у create-случая файла нет вовсе — по
    определению вида. Оба стража спрашивают одно и то же, «вернётся ли дерево
    в исходное», но исходное у них противоположное: там файл есть, здесь его
    нет.

    Опасность у create другая, зеркальная. Незавершённый прогон оставляет не
    испорченный файл, а лишний: он виден в `git status` как `??` и удаляется
    одной командой — это безопаснее текстового случая, а не опаснее.
    Невосстановимо ровно обратное: если файл по этому пути уже существует,
    мутация затрёт его своим содержимым, а откат — удалит. Отслеживаемый
    вернётся из индекса, неотслеживаемый не вернётся ниоткуда, и отличать эти
    два случая раннер не станет: и то и другое — чужой файл под удалением.

    Второе условие — чтобы git не считал по этому пути ничего ожидающего.
    Оно ловит путь, отслеживаемый в индексе, но удалённый в рабочей копии:
    файла на диске нет, первое условие молчит, а дерево при этом грязное
    ровно тем местом, куда собирается писать мутация.
    """
    taken = []
    for path in sorted(set(paths)):
        if os.path.exists(path):
            taken.append((path, 'файл уже существует'))
            continue
        done = subprocess.run(['git', 'status', '--porcelain', '--', path],
                              capture_output=True, shell=True)
        if done.stdout.strip():
            taken.append((path, 'git видит по этому пути незакоммиченное'))
    if not taken:
        return
    print('Мутации не запущены: create-случаю некуда создавать файл.')
    for path, why in taken:
        print('  %s — %s' % (path, why))
    print('')
    print('Мутация записала бы файл поверх, а откат удалил бы его вместе с')
    print('тем, что там лежало. Убери файл с дороги и запусти снова.')
    sys.exit(2)


def assert_plan_readable(plan):
    """План разбирается целиком до первой мутации, а не по ходу.

    Опечатка в `kind` на десятом случае, найденная на десятом случае, — это
    девять уже прогнанных мутаций и отчёт, в котором надо разбираться. Плана
    раннер либо не понял, либо начал: середины нет.
    """
    required = {'text': ('old', 'new'),
                'bytes': ('old', 'new'),
                'create': ('content',)}
    problems = []
    for index, case in enumerate(plan):
        where = case.get('name') or 'случай №%d' % (index + 1)
        for field in ('name', 'file'):
            if not case.get(field):
                problems.append('%s: нет поля «%s»' % (where, field))
        kind = kind_of(case)
        if kind not in KINDS:
            problems.append('%s: неизвестный kind «%s», есть %s'
                            % (where, kind, ', '.join(KINDS)))
            continue
        for field in required[kind]:
            if field not in case:
                problems.append('%s: для kind «%s» нужно поле «%s»'
                                % (where, kind, field))
        if kind == 'bytes':
            for field in ('old', 'new'):
                try:
                    hex_bytes(case.get(field, ''))
                except ValueError as error:
                    problems.append('%s: поле «%s» не hex — %s'
                                    % (where, field, error))
    if not problems:
        return
    print('План не разобран, не запущено ничего:')
    for line in problems:
        print('  %s' % line)
    sys.exit(2)


def apply_text(case):
    path, old, new = case['file'], case['old'], case['new']
    original = read(path)
    eol = eol_of(path)
    found = original.count(old)
    if found != 1:
        raise Refused('якорь не найден (%d совпадений)' % found)
    write(path, original.replace(old, new), eol)
    return lambda: write(path, original, eol)


def apply_bytes(case):
    path = case['file']
    old, new = hex_bytes(case['old']), hex_bytes(case['new'])
    original = read_bytes(path)
    found = original.count(old)
    if found != 1:
        raise Refused('байтовый якорь не найден (%d совпадений)' % found)
    write_bytes(path, original.replace(old, new))
    return lambda: write_bytes(path, original)


def apply_create(case):
    path = case['file']
    made = _missing_parents(path)
    for directory in made:
        os.mkdir(directory)
    # newline='' — писать ровно то, что в плане: файл живёт до конца прогона
    # и в репозиторий не попадает, так что переводу строк тут не с чем
    # согласовываться, а молчаливая замена сделала бы содержимое не тем,
    # что написано в JSON.
    write(path, case['content'], '')

    def undo():
        os.remove(path)
        # В обратном порядке: сначала внутренний каталог, потом внешний.
        # Пустой каталог не виден `git status`, поэтому забытый здесь он
        # остался бы на диске навсегда и молча.
        for directory in reversed(made):
            os.rmdir(directory)

    return undo


def _missing_parents(path):
    """Каталоги, которых не хватает для [path], от внешнего к внутреннему."""
    missing = []
    parent = os.path.dirname(path)
    while parent and not os.path.isdir(parent):
        missing.append(parent)
        parent = os.path.dirname(parent)
    return list(reversed(missing))


APPLY = {'text': apply_text, 'bytes': apply_bytes, 'create': apply_create}


def main():
    # Консоль Windows по умолчанию cp1251, и одна стрелка в названии мутации
    # роняла бы прогон уже после того, как файл восстановлен, — то есть
    # молча съедала бы остаток списка.
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except AttributeError:
        pass
    plan = json.loads(read(sys.argv[1]))
    targets = sys.argv[2:]
    if not targets:
        print('Не указано, какие тесты гонять.')
        sys.exit(2)
    assert_plan_readable(plan)
    assert_committed(case['file'] for case in plan
                     if kind_of(case) != 'create')
    assert_absent(case['file'] for case in plan
                  if kind_of(case) == 'create')
    failures = []

    for case in plan:
        try:
            undo = APPLY[kind_of(case)](case)
        except Refused as refusal:
            failures.append('%s: %s' % (case['name'], refusal))
            continue
        try:
            # encoding явно: text=True декодирует вывод кодировкой консоли
            # (на Windows cp1251), и первый же типографский символ в тексте
            # ассета роняет поток чтения. Вердикт брался бы из returncode и
            # остался бы верным, но прогон печатал бы traceback вместо отчёта.
            done = subprocess.run(['flutter', 'test'] + targets,
                                  capture_output=True, text=True, shell=True,
                                  encoding='utf-8', errors='replace')
            red = done.returncode != 0
        finally:
            undo()
        mark = 'OK  ' if red else 'ТЕАТР'
        print('%s %s' % (mark, case['name']))
        if not red:
            failures.append('%s: тесты остались зелёными на сломанном коде'
                            % case['name'])

    print('')
    if failures:
        for line in failures:
            print('ПРОВАЛ: %s' % line)
        sys.exit(1)
    print('Все %d мутаций пойманы.' % len(plan))


if __name__ == '__main__':
    main()
