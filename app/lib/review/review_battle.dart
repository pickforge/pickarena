enum ReviewVote { left, right, tie, skip }

extension ReviewVoteStorage on ReviewVote {
  String get storageValue => name;

  static ReviewVote parse(String value) {
    return ReviewVote.values.firstWhere(
      (vote) => vote.name == value,
      orElse: () => ReviewVote.skip,
    );
  }
}

String canonicalReviewPairKey(String leftTaskRunId, String rightTaskRunId) {
  final ids = [leftTaskRunId, rightTaskRunId]..sort();
  return '${ids[0]}|${ids[1]}';
}
