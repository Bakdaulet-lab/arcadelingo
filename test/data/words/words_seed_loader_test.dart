// Реальный ассет через кодек: единственное место, где сид целиком проходит
// через parseWordsSeed. Число слов уже пинится в test/assets/words_seed_test.dart.

import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Второй счётчик размера сида. Первый — «ровно N слов» в
  // test/assets/words_seed_test.dart; правятся оба и в одном коммите порции.
  test('loadWordsSeed: 1740 единиц показа, B1 дописан после A2', () async {
    final items = ok(await loadWordsSeed());

    expect(items, hasLength(1740));
    expect(items.first.word.id, 'apple');
    expect(items.first.word.level, CefrLevel.a1);
    expect(items.first.distractors, hasLength(3));
    expect(items[719].word.id, 'skiing');
    expect(items[719].word.level, CefrLevel.a2);
    expect(items[1701].word.id, 'bookcase');
    expect(items[1701].word.level, CefrLevel.a2);
    expect(items[1702].word.id, 'climate');
    expect(items[1702].word.level, CefrLevel.b1);
    expect(items.last.word.id, 'exhausted');
    expect(items.last.word.level, CefrLevel.b1);
  });
}
