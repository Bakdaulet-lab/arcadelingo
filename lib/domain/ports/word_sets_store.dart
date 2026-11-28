import '../review/review_contract.dart';

/// A named collection of existing vocabulary cards in one course and level.
class WordSet {
  WordSet({required this.id, required this.name, required Set<String> wordIds})
    : wordIds = Set.unmodifiable(wordIds);

  final String id;
  final String name;
  final Set<String> wordIds;
}

enum WordSetSaveResult { saved, duplicate, invalid, missing, failed }

abstract interface class WordSetsStore {
  List<WordSet> load(CefrLevel level);

  /// Omitting [id] creates a set. Editing preserves its identity.
  Future<WordSetSaveResult> save({
    required CefrLevel level,
    String? id,
    required String name,
    required Set<String> wordIds,
  });

  Future<bool> remove({required CefrLevel level, required String id});
}
