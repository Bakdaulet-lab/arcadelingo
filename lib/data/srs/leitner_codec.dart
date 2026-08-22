/// Кодек состояния Лейтнера: JSON-документ хранилища ↔ карточки по id слова.
///
/// Реализации здесь ещё нет — только сигнатуры, на которых компилируются
/// тесты задачи 0.5. Тело появляется в той же задаче следующим коммитом,
/// тесты в этот момент не трогаются.
library;

import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';

/// Состояние → JSON-документ для хранилища.
String encodeLeitnerState(Map<String, LeitnerCard> cards) =>
    throw UnimplementedError('кодек Лейтнера не реализован — задача 0.5');

/// JSON-документ хранилища → состояние; битые данные — [Err].
Result<Map<String, LeitnerCard>> decodeLeitnerState(String json) =>
    throw UnimplementedError('кодек Лейтнера не реализован — задача 0.5');
