// Разбор ATTRIBUTION.md: что рендер умеет, чего не умеет, и сторож на
// настоящем файле.
//
// Главный здесь — последний group. Разбор частичный намеренно, и его
// честность держится не на аккуратности, а на том, что незнакомая
// конструкция попадает в отдельный вид блока, а тест разбирает живой файл и
// требует ноль таких блоков. Появится в файле таблица — красный тест в тот
// же день, а не мусор на экране через полгода.
//
// Дословность цитаты CEFR-J проверяется тоже здесь, а не только на экране:
// условие лицензии — про текст, и текст обязан пережить разбор целым.

import 'dart:io';

import 'package:arcadelingo/app/attribution.dart';
import 'package:flutter_test/flutter_test.dart';

/// Первый блок разбора [source] — большинству тестов больше и не нужно.
AttributionBlock _first(String source) => parseAttribution(source).first;

/// Разбор настоящего `assets/ATTRIBUTION.md`.
///
/// Файл читается с диска, а не из бандла: сторожить надо ровно тот документ,
/// который лежит в репозитории и который читает ревьюер.
///
/// Функцией, а не полем группы: вычисление в теле `group` падает на этапе
/// сборки набора и уносит весь файл, не дойдя ни до одного ассерта.
List<AttributionBlock> _realFile() =>
    parseAttribution(File('assets/ATTRIBUTION.md').readAsStringSync());

/// Цитата CEFR-J, дословно. Литералом, а не чтением из файла: тест обязан
/// сломаться и в том случае, если кто-то «поправит» цитату в самом файле.
const String _citation =
    'The CEFR-J Wordlist Version 1.5. Compiled by Yukio Tono, Tokyo '
    'University of Foreign Studies. Retrieved from '
    'http://www.cefr-j.org/download.html';

void main() {
  group('Блоки', () {
    test('# — заголовок первого уровня, решётка съедена', () {
      final block = _first('# Источники');

      expect(block.kind, AttributionBlockKind.heading1);
      expect(block.text, 'Источники');
    });

    test('## — заголовок второго уровня', () {
      final block = _first('## Шрифт Rubik');

      expect(block.kind, AttributionBlockKind.heading2);
      expect(block.text, 'Шрифт Rubik');
    });

    test('обычная строка — абзац', () {
      expect(_first('просто текст').kind, AttributionBlockKind.paragraph);
    });

    test('мягкий перенос склеивается пробелом в один абзац', () {
      final blocks = parseAttribution('первая строка\nвторая строка');

      expect(blocks, hasLength(1));
      expect(blocks.single.text, 'первая строка вторая строка');
    });

    test('пустая строка разделяет абзацы', () {
      final blocks = parseAttribution('первый\n\nвторой');

      expect(blocks, hasLength(2));
      expect(blocks.first.text, 'первый');
      expect(blocks.last.text, 'второй');
    });

    test('> — цитата, и она не склеивается с соседним абзацем', () {
      final blocks = parseAttribution('перед\n\n> цитата\n\nпосле');

      expect(blocks.map((b) => b.kind), [
        AttributionBlockKind.paragraph,
        AttributionBlockKind.quote,
        AttributionBlockKind.paragraph,
      ]);
      expect(blocks[1].text, 'цитата');
    });

    test('- — пункт списка', () {
      final block = _first('- пункт');

      expect(block.kind, AttributionBlockKind.bullet);
      expect(block.text, 'пункт');
    });

    test('продолжение пункта с отступом остаётся тем же пунктом', () {
      final blocks = parseAttribution('- начало пункта\n  продолжение');

      expect(blocks, hasLength(1));
      expect(blocks.single.kind, AttributionBlockKind.bullet);
      expect(blocks.single.text, 'начало пункта продолжение');
    });

    test('CRLF не ломает разбор', () {
      final blocks = parseAttribution('# Заголовок\r\n\r\nабзац\r\n');

      expect(blocks.first.kind, AttributionBlockKind.heading1);
      expect(blocks.first.text, 'Заголовок');
      expect(blocks.last.text, 'абзац');
    });
  });

  group('Разметка внутри строки', () {
    test('жирный: звёздочки съедены, стиль проставлен', () {
      expect(_first('**Автор:** имя').spans, const [
        AttributionSpan('Автор:', AttributionStyle.bold),
        AttributionSpan(' имя'),
      ]);
    });

    test('код: обратные кавычки съедены', () {
      expect(_first('файл `OFL.txt` рядом').spans, const [
        AttributionSpan('файл '),
        AttributionSpan('OFL.txt', AttributionStyle.code),
        AttributionSpan(' рядом'),
      ]);
    });

    test('ссылка: угловые скобки съедены', () {
      expect(_first('см. <https://example.org>').spans, const [
        AttributionSpan('см. '),
        AttributionSpan('https://example.org', AttributionStyle.link),
      ]);
    });

    test('незакрытый маркер остаётся текстом, а не съедает остаток', () {
      expect(_first('текст ** без пары').text, 'текст ** без пары');
      expect(_first('текст ` без пары').text, 'текст ` без пары');
      expect(_first('текст < без пары').text, 'текст < без пары');
    });

    test('угловые скобки не вокруг ссылки текстом и остаются', () {
      expect(_first('<не ссылка>').text, '<не ссылка>');
    });
  });

  group('Конструкции, которых рендер не знает', () {
    for (final line in const [
      '### третий уровень',
      '| ячейка | ячейка |',
      '[текст](https://example.org)',
      '![картинка](x.png)',
      '1. нумерованный пункт',
      '---',
      '* пункт звёздочкой',
    ]) {
      test('«$line» — unsupported, а не молча абзац', () {
        expect(_first(line).kind, AttributionBlockKind.unsupported);
      });
    }
  });

  group('Файл доезжает до приложения', () {
    // Widget-тест экрана подсовывает бандл, читающий с диска: настоящий
    // ввод-вывод внутри pump() не успевает. Значит незарегистрированный
    // ассет он не поймает — на экране всё будет, а в приложении пусто.
    // Ловит это здесь.
    test('ATTRIBUTION.md зарегистрирован в pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(
        pubspec,
        contains('assets/ATTRIBUTION.md'),
        reason:
            'файл есть в репозитории, но в бандл не попадёт: экран покажет '
            'ошибку чтения, а условие лицензии останется невыполненным',
      );
    });

    test('файл на месте и не пуст', () {
      final file = File('assets/ATTRIBUTION.md');

      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync().trim(), isNotEmpty);
    });
  });

  group('Сторож на настоящем файле', () {
    test('разбирается целиком, без единой незнакомой конструкции', () {
      final unsupported =
          _realFile()
              .where((b) => b.kind == AttributionBlockKind.unsupported)
              .map((b) => b.text)
              .toList();

      expect(
        unsupported,
        isEmpty,
        reason:
            'в ATTRIBUTION.md появилась разметка, которую экран нарисовать '
            'не умеет: либо научи разбор, либо перепиши эти строки',
      );
    });

    test('файл не пуст и начинается заголовком', () {
      final blocks = _realFile();

      expect(blocks, isNotEmpty);
      expect(blocks.first.kind, AttributionBlockKind.heading1);
    });

    test('цитата CEFR-J пережила разбор дословно, одним блоком', () {
      expect(
        _realFile().map((b) => b.text),
        contains(_citation),
        reason:
            'условие лицензии — про дословность: цитата не переносится по '
            'строкам и не переводится (assets/ATTRIBUTION.md)',
      );
    });

    test('условия использования пережили разбор дословно', () {
      final terms = _realFile()
          .map((b) => b.text)
          .where(
            (text) => text.startsWith('CEFR-J vocabulary and grammar profile'),
          );

      expect(terms, hasLength(1));
      expect(
        terms.single,
        endsWith('any damage resulting from using the dataset.'),
        reason: 'условия обрезаны разбором — значит показаны будут неполными',
      );
    });
  });
}
