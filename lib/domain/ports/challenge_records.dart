import '../review/review_contract.dart';

typedef ChallengeKey = ({String gameId, String courseId, CefrLevel level});

abstract class ChallengeRecords {
  int? load(ChallengeKey key);

  /// Returns the saved best. Null means a new result could not be saved.
  Future<int?> submit(ChallengeKey key, int score);
}
