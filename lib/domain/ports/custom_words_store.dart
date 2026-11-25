import '../review/review_contract.dart';

enum CustomWordSaveResult { saved, duplicate, invalid, failed }

/// Personal cards belonging to a single study course.
abstract interface class CustomWordsStore {
  List<Word> load(CefrLevel level);

  Future<CustomWordSaveResult> add({
    required CefrLevel level,
    required String text,
    required String translation,
  });
}
