// СПАЙК, не продакшн-код. Ветка spike/drift, в master не вливается.
//
// Вопрос спайка: заводится ли drift + NativeDatabase.memory() в обычном
// test() под `flutter test` — то есть на голом Dart VM хоста, без
// Flutter-рантайма и без устройства. Это блокер Этапа 3 Фазы 2.
//
// Минимум, на котором вопрос проверяется: одна таблица, одна колонка.
import 'package:drift/drift.dart';

part 'spike_db.g.dart';

/// Одна колонка. Больше для ответа на вопрос спайка не нужно.
class Notes extends Table {
  TextColumn get body => text()();
}

@DriftDatabase(tables: [Notes])
class SpikeDb extends _$SpikeDb {
  SpikeDb(super.e);

  @override
  int get schemaVersion => 1;
}
