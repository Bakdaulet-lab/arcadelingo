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


def write(path, text):
    io.open(path, 'w', encoding='utf-8', newline='\n').write(text)


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
    failures = []

    for case in plan:
        path, old, new = case['file'], case['old'], case['new']
        original = read(path)
        if original.count(old) != 1:
            failures.append('%s: якорь не найден (%d совпадений)'
                            % (case['name'], original.count(old)))
            continue
        write(path, original.replace(old, new))
        try:
            done = subprocess.run(['flutter', 'test', target],
                                  capture_output=True, text=True, shell=True)
            red = done.returncode != 0
        finally:
            write(path, original)
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
