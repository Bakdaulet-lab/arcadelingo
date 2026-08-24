# -*- coding: utf-8 -*-
"""Мутационная проверка тестов: ломаем реализацию и требуем красноты.

CLAUDE.md → «Тесты»: зелёный тест на сломанном коде — бутафория. Скрипт
делает эту проверку воспроизводимой, а не разовой: каждая мутация здесь
описана вместе с тем, какой тест обязан её поймать.

Запуск: python scripts/mutate.py <файл-с-мутациями.json> <путь-к-тестам>
"""
import io
import json
import subprocess
import sys


def read(path):
    return io.open(path, encoding='utf-8').read()


def eol_of(path):
    # Рабочая копия на Windows приходит с CRLF, а восстановление через '\n'
    # переписало бы переносы во всём файле: git показал бы правку там, где
    # раннер обещал ничего не трогать. На ассете это чуть не уехало в коммит.
    with io.open(path, 'rb') as handle:
        return '\r\n' if b'\r\n' in handle.read() else '\n'


def write(path, text, eol='\n'):
    io.open(path, 'w', encoding='utf-8', newline=eol).write(text)


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
    """
    dirty = []
    for path in sorted(set(paths)):
        done = subprocess.run(['git', 'diff', '--exit-code', '--', path],
                              capture_output=True, shell=True)
        if done.returncode != 0:
            dirty.append(path)
    if not dirty:
        return
    print('Мутации не запущены: целевые файлы изменены и не закоммичены.')
    for path in dirty:
        print('  %s' % path)
    print('')
    print('Прогон, убитый по таймауту, оставил бы в них мутацию, а вернуть')
    print('правку было бы неоткуда. Закоммить их и запусти снова.')
    sys.exit(2)


def main():
    # Консоль Windows по умолчанию cp1251, и одна стрелка в названии мутации
    # роняла бы прогон уже после того, как файл восстановлен, — то есть
    # молча съедала бы остаток списка.
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except AttributeError:
        pass
    plan = json.loads(read(sys.argv[1]))
    target = sys.argv[2]
    assert_committed(case['file'] for case in plan)
    failures = []

    for case in plan:
        path, old, new = case['file'], case['old'], case['new']
        original = read(path)
        eol = eol_of(path)
        if original.count(old) != 1:
            failures.append('%s: якорь не найден (%d совпадений)'
                            % (case['name'], original.count(old)))
            continue
        write(path, original.replace(old, new), eol)
        try:
            # encoding явно: text=True декодирует вывод кодировкой консоли
            # (на Windows cp1251), и первый же типографский символ в тексте
            # ассета роняет поток чтения. Вердикт брался бы из returncode и
            # остался бы верным, но прогон печатал бы traceback вместо отчёта.
            done = subprocess.run(['flutter', 'test', target],
                                  capture_output=True, text=True, shell=True,
                                  encoding='utf-8', errors='replace')
            red = done.returncode != 0
        finally:
            write(path, original, eol)
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
