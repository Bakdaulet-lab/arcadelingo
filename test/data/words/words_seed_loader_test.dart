// Реальный ассет через кодек: единственное место, где сид целиком проходит
// через parseWordsSeed. Число слов уже пинится в test/assets/words_seed_test.dart.

import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loadWordsSeed: ассет из бандла → 50 единиц показа, первая — apple',
    () async {
      final items = ok(await loadWordsSeed());

      expect(items, hasLength(50));
      expect(items.first.word.id, 'apple');
      expect(items.first.distractors, hasLength(3));
    },
  );
}
