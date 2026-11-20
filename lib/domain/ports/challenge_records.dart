import '../challenges/challenge_session.dart';
import '../review/review_contract.dart';

typedef ChallengeKey = ({String gameId, String courseId, CefrLevel level});

abstract class ChallengeRecords {
  /// A mode has its own record when the same game also records regular rounds.
  int? load(ChallengeKey key, {ArcadeChallenge? mode});

  /// Returns the saved best. Null means a new result could not be saved.
  Future<int?> submit(ChallengeKey key, int score, {ArcadeChallenge? mode});
}
