// СПАЙК. Проверяет ровно одно: открывается ли drift на NativeDatabase.memory()
// в обычном test() под `flutter test`.
//
// Намеренно `test()`, а не `testWidgets()`, и намеренно нет
// TestWidgetsFlutterBinding.ensureInitialized(): весь смысл вопроса в том,
// нужен ли drift'у Flutter-рантайм. Если тест зелёный в таком виде —
// не нужен, и хранилище Фазы 2 тестируется как чистый Dart.
//
// package:drift/native.dart тянет sqlite3 через dart:ffi. Это значит, что
// на хосте обязана найтись нативная библиотека sqlite3 — и вот она уже
// может быть платформенно-зависимой. Ровно это и меряем.
import 'package:arcadelingo/spike/spike_db.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'drift на NativeDatabase.memory(): вставить строку и прочитать',
    () async {
      final db = SpikeDb(NativeDatabase.memory());
      addTearDown(db.close);

      await db.into(db.notes).insert(NotesCompanion.insert(body: 'привет'));

      final rows = await db.select(db.notes).get();

      expect(rows, hasLength(1));
      expect(rows.single.body, 'привет');
    },
  );
}
