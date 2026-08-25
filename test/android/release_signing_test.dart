// Релизный ключ — единственный секрет проекта, который нельзя ни отозвать, ни
// перевыпустить: `applicationId` навсегда связан с подписью, и хранилище,
// однажды попавшее в историю git, делает публикацию скомпрометированной
// навсегда. Ошибка при этом тихая — `git add -A` в спешке, и всё.
//
// Поэтому здесь не «проверяется, что мы написали правильный .gitignore», а
// задаётся вопрос самому git: считаешь ли ты этот путь игнорируемым. Правило
// можно случайно ослабить (переставить строку, добавить `!`-исключение,
// переименовать каталог) — ответ git изменится, и тест покраснеет.
//
// Второй вопрос, который git тоже обязан задать, — не отслеживается ли такой
// файл уже: `check-ignore` про это ничего не знает, он смотрит только правила.
//
// Третья группа — про сообщение вместо гредловской каши. Оно ссылается на
// docs/dev/release.md, и ссылка, пережившая свой файл, хуже её отсутствия.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String gradleScript = 'android/app/build.gradle.kts';
const String releaseDoc = 'docs/dev/release.md';

/// Поля, которые сборочный скрипт читает из `android/key.properties`.
const List<String> keyPropertyNames = [
  'storeFile',
  'storePassword',
  'keyAlias',
  'keyPassword',
];

/// Пути, которые обязаны быть невидимы для git — где бы ни лежали.
///
/// Каталоги разные намеренно: `*.jks` без каталога в шаблоне проверял бы
/// только корневое правило, а хранилище кладут рядом с `android/`.
const List<String> mustBeIgnored = [
  'android/key.properties',
  'android/app/upload-keystore.jks',
  'upload-keystore.jks',
  'secrets/release.jks',
  'secrets/release.keystore',
  'android/app/release.keystore',
];

void main() {
  group('ключ подписи невидим для git', () {
    for (final path in mustBeIgnored) {
      test('$path игнорируется', () {
        expect(
          _checkIgnore(path),
          isTrue,
          reason:
              '$path не игнорируется. Один `git add -A` — и релизный ключ '
              'в истории навсегда; отозвать его нельзя, сменить после '
              'публикации тоже.',
        );
      });
    }

    test('ничего похожего уже не отслеживается', () {
      final tracked =
          _git(['ls-files'])
              .split('\n')
              .map((line) => line.trim())
              .where(
                (path) =>
                    path.endsWith('key.properties') ||
                    path.endsWith('.jks') ||
                    path.endsWith('.keystore') ||
                    path.endsWith('.p12'),
              )
              .toList();
      expect(
        tracked,
        isEmpty,
        reason:
            'check-ignore смотрит только правила и про уже добавленный файл '
            'молчит. Эти пути git знает — их надо убрать из индекса.',
      );
    });
  });

  group('сборка объясняет отказ, а не роняет стек', () {
    final gradle = _read(gradleScript);

    test('отказ ведёт человека в $releaseDoc', () {
      expect(
        gradle,
        contains('Создай ключ по $releaseDoc'),
        reason:
            'сообщение об отсутствии ключа обязано называть файл, где написано '
            'что делать. Общие слова вместо пути — это и есть та каша, '
            'вместо которой писалось сообщение',
      );
      expect(
        File(releaseDoc).existsSync(),
        isTrue,
        reason: 'ссылка, пережившая свой файл, хуже её отсутствия',
      );
    });

    test('каждое поле key.properties и проверяется, и читается', () {
      // Дважды — не придирка к числу вхождений, а сам инвариант: поле, попавшее
      // в список обязательных, но нигде не прочитанное, даёт подпись не тем
      // ключом при зелёной проверке; прочитанное, но не проверенное — пустой
      // пароль и гредловскую кашу вместо сообщения.
      for (final name in keyPropertyNames) {
        expect(
          '"$name"'.allMatches(gradle).length,
          greaterThanOrEqualTo(2),
          reason:
              '$name упомянут в $gradleScript меньше двух раз: он либо не '
              'в списке обязательных, либо не читается в signingConfig',
        );
      }
    });

    test('$releaseDoc называет те же четыре поля', () {
      final doc = _read(releaseDoc);
      for (final name in keyPropertyNames) {
        // Именно `имя=`, а не имя где-нибудь в тексте: инструкция обязана
        // показывать строку, которую человек скопирует, а не упоминать поле.
        expect(
          doc,
          contains('$name='),
          reason:
              'скрипт требует $name, а инструкция такой строки не показывает — '
              'человек напишет файл из трёх строк и получит отказ',
        );
      }
    });

    test('debug остаётся на отладочном ключе', () {
      expect(
        gradle.contains('signingConfigs.getByName("debug")'),
        isFalse,
        reason:
            'релиз, подписанный отладочным ключом, — ровно то, что чинит эта '
            'задача; ссылка на debug-конфиг означает возврат к нему',
      );
    });
  });
}

/// Игнорируется ли путь по мнению самого git.
///
/// Код возврата: 0 — игнорируется, 1 — нет, остальное — сломанный вызов, и
/// молчать о нём нельзя: «не игнорируется» и «git не ответил» — разные вещи,
/// а второе выглядело бы как зелёный тест.
bool _checkIgnore(String path) {
  final done = Process.runSync('git', ['check-ignore', '--quiet', path]);
  if (done.exitCode > 1) {
    fail('git check-ignore $path: код ${done.exitCode}, ${done.stderr}');
  }
  return done.exitCode == 0;
}

String _git(List<String> args) {
  final done = Process.runSync('git', args);
  if (done.exitCode != 0) {
    fail('git ${args.join(' ')}: код ${done.exitCode}, ${done.stderr}');
  }
  return done.stdout as String;
}

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) fail('нет файла $path');
  return file.readAsStringSync();
}
