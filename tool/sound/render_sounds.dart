/// Рисует три звука ниндзя-слэша в `assets/sound/`.
///
/// Запуск из корня репозитория:
///
///     dart run tool/sound/render_sounds.dart
///
/// Не `flutter test`, в отличие от иконок: тем нужны `dart:ui` и шрифт из
/// ассетов, а здесь только арифметика — она живёт в `sound_synth.dart`.
///
/// Скрипт ничего не решает: все числа в `sound_synth.dart`, все причины —
/// в `SPEC.md`. Пересобрать файлы после правки числа обязательно, и забыть
/// это нельзя: `test/assets/sound_test.dart` пересобирает их в памяти и
/// сверяет байты с тем, что лежит в репозитории.
library;

import 'dart:io';

import 'sound_synth.dart';

const String _outDir = 'assets/sound';

void main() {
  // Из корня, а не откуда придётся: относительный путь в аргументах не
  // предусмотрен намеренно — ассеты лежат в одном месте, и второе место
  // означало бы, что в бандл поедет не то, что сверил тест.
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Запускать из корня репозитория: там лежит pubspec.yaml.');
    exit(2);
  }
  Directory(_outDir).createSync(recursive: true);
  for (final entry in sounds.entries) {
    final bytes = wav(entry.value());
    File('$_outDir/${entry.key}').writeAsBytesSync(bytes);
    stdout.writeln('$_outDir/${entry.key}: ${bytes.length} байт');
  }
}
