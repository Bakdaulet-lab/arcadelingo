// Общий setup для всех тестов, которые открывают настоящую БД.
//
// Зачем это вообще нужно. `package:drift/native.dart` берёт sqlite через
// `dart:ffi`, то есть нативную библиотеку с хоста. На Linux пакет `sqlite3`
// по умолчанию ищет `libsqlite3.so` — а это имя из **пакета разработки**
// (`libsqlite3-dev`), которого на голой системе нет. Рантайм-библиотека
// называется `libsqlite3.so.0` и есть везде.
//
// Спайк Этапа 2.3 показал, что на CI тесты зелёные и без этого — но зелёные
// по случайности: образ раннера GitHub Actions таскает `libsqlite3-dev` за
// другими пакетами. Зависеть от состава чужого образа значит однажды получить
// красный прогон от смены базового образа, к нашему коду отношения не
// имеющей.
//
// Windows и macOS не трогаем: там библиотека системная и находится сама
// (`winsqlite3.dll` / `libsqlite3.dylib`).
//
// ВНИМАНИЕ: три разных sqlite. Тесты на Windows, CI на Linux и телефон с
// `sqlite3_flutter_libs` — это три сборки разных версий. SQL держим в объёме,
// одинаковом для всех (`lib/data/log/answer_database.dart`).

import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';

/// Зовётся один раз перед первым открытием БД в файле тестов.
///
/// Идемпотентна: повторный вызов просто переставляет тот же обработчик.
void useTestSqlite() {
  if (!Platform.isLinux) return;
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so.0'),
  );
}
