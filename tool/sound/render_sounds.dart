/// Рисует прежние синтезированные звуки для сравнения в `tool/out/`.
///
/// Запуск из корня репозитория:
///
///     dart run tool/sound/render_sounds.dart
///
/// Не `flutter test`, в отличие от иконок: тем нужны `dart:ui` и шрифт из
/// ассетов, а здесь только арифметика — она живёт в `sound_synth.dart`.
///
/// Игровые звуки лежат в `assets/sound/`, их источники описаны в
/// `assets/ATTRIBUTION.md`. Этот скрипт пишет только в каталог сравнения.
library;

import 'dart:io';

import 'sound_synth.dart';

const String _outDir = 'tool/out/synthetic_sounds';

void main() {
  // Каталог сравнения отсчитывается от корня проекта.
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
