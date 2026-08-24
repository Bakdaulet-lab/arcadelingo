// Сторож того, что снималка экранов не попадает в гейт.
//
// Тест лежит в корне test/, а не в test/peek/, намеренно: каталог съёмки
// отсекается от обычных прогонов, и сторож, положенный внутрь него, молчал бы
// ровно тогда, когда нужен.
//
// Почему сторож вообще нужен. Файлы в test/peek/ ничего не проверяют и всегда
// зелёные. Попав в обычный прогон, они не покраснеют — они просто молча
// добавят три зелёных строки к счётчику и запишут PNG. Ни один существующий
// тест этого не заметит: провала нет, есть враньё про покрытие.
//
// Почему исключение живёт в scripts/verify.sh, а не в dart_test.yaml. Измерено
// на flutter test 3.29.2, дважды:
//
//   exclude_tags: peek  +  flutter test --tags peek test/peek/
//   -> No tests ran.  include: "peek", exclude: "peek"
//
// Исключение из конфига побеждает явный запрос с командной строки, и
// санкционированная ручная съёмка перестала бы работать вовсе. Обхода нет:
// `--exclude-tags ""` — ошибка разбора аргументов, а `--preset` и
// `--configuration` flutter test не поддерживает, в отличие от голого
// dart test. Поэтому исключение стоит там, где определяется прогон по
// умолчанию, а этот файл сторожит обе половины договорённости.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Файлы съёмки: всё, что `flutter test` в этом каталоге вообще запустит.
List<File> _peekSuites() =>
    Directory('test/peek')
        .listSync()
        .whereType<File>()
        .where((f) => f.uri.pathSegments.last.endsWith('_test.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  test('в test/peek/ есть что снимать', () {
    // Иначе весь остальной файл — набор из нуля проверок, зелёный и пустой.
    expect(
      _peekSuites(),
      isNotEmpty,
      reason: 'нет ни одного *_test.dart в test/peek/ — сторожить нечего',
    );
  });

  test('каждый файл съёмки помечен тегом peek', () {
    final untagged = <String>[];
    for (final suite in _peekSuites()) {
      if (!suite.readAsStringSync().contains("@Tags(['peek'])")) {
        untagged.add(suite.uri.pathSegments.last);
      }
    }
    expect(
      untagged,
      isEmpty,
      reason:
          'без @Tags([\'peek\']) файл попадёт в обычный прогон и добавит '
          'зелёных строк, ничего не проверив',
    );
  });

  // Тришка на текст скрипта, а не проверка поведения: запустить verify.sh
  // изнутри flutter test означало бы рекурсию. Названо своим именем.
  test('verify.sh отсекает peek в обоих режимах', () {
    final script = File('scripts/verify.sh').readAsStringSync();
    expect(
      script,
      contains("--exclude-tags 'golden || peek'"),
      reason: 'режим off перестал отсекать съёмку',
    );
    expect(
      script,
      contains('--exclude-tags peek'),
      reason: 'режим all перестал отсекать съёмку',
    );
  });

  test('снимки уходят в test/peek/out/, а не к эталонам', () {
    final harness = File('test/peek/peek_harness.dart').readAsStringSync();
    expect(
      harness,
      contains("const String peekOutDir = 'test/peek/out'"),
      reason:
          'снимки рядом с эталонами однажды примут за кандидатов и '
          'переименуют в эталон',
    );
    // Именно вызов, а не упоминание: в доке харнесса `matchesGoldenFile`
    // назван — там объяснено, почему съёмка повторяет его механику вручную.
    expect(
      harness,
      isNot(contains('matchesGoldenFile(')),
      reason: 'peek не сравнивает и не принимает эталоны — он пишет файл',
    );
    expect(
      harness,
      isNot(contains('goldenFileComparator')),
      reason: 'компаратор в съёмке не участвует вовсе',
    );
  });

  test('каталог снимков в .gitignore', () {
    expect(
      File('.gitignore').readAsStringSync(),
      contains('test/peek/out/'),
      reason: 'снимки не хранятся в истории: их делают, смотрят и выбрасывают',
    );
  });
}
