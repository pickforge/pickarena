import 'package:dart_arena/review/review_battle.dart';
import 'package:equatable/equatable.dart';

class PreferenceBattleInput {
  const PreferenceBattleInput({
    required this.taskId,
    required this.taskVersion,
    required this.benchmarkTrack,
    required this.leftProviderId,
    required this.leftModelId,
    required this.rightProviderId,
    required this.rightModelId,
    required this.vote,
    this.rationale,
  });

  final String taskId;
  final int taskVersion;
  final String benchmarkTrack;
  final String leftProviderId;
  final String leftModelId;
  final String rightProviderId;
  final String rightModelId;
  final ReviewVote vote;
  final String? rationale;

  String get leftModelKey => '$leftProviderId:$leftModelId';
  String get rightModelKey => '$rightProviderId:$rightModelId';
}

class QualityRanking extends Equatable {
  const QualityRanking({
    required this.benchmarkTrack,
    required this.taskVersion,
    required this.providerId,
    required this.modelId,
    required this.wins,
    required this.losses,
    required this.ties,
    required this.skipVotes,
    required this.minimumVotes,
    this.rationales = const [],
  });

  final String benchmarkTrack;
  final int taskVersion;
  final String providerId;
  final String modelId;
  final double wins;
  final double losses;
  final double ties;
  final int skipVotes;
  final int minimumVotes;
  final List<String> rationales;

  String get modelKey => '$providerId:$modelId';
  int get nonSkipVotes => (wins + losses + ties).round();
  bool get lowVoteCount => nonSkipVotes < minimumVotes;
  double get preferenceScore {
    final denominator = wins + losses + ties;
    if (denominator == 0) return 0;
    return (wins + 0.5 * ties) / denominator;
  }

  double? get displayScore => lowVoteCount ? null : preferenceScore;

  @override
  List<Object?> get props => [
    benchmarkTrack,
    taskVersion,
    providerId,
    modelId,
    wins,
    losses,
    ties,
    skipVotes,
    minimumVotes,
    rationales,
  ];
}

List<QualityRanking> computePreferenceRankings(
  Iterable<PreferenceBattleInput> battles, {
  int minimumVotes = 3,
  String? taskId,
  Set<String>? taskIds,
  String? benchmarkTrack,
  int? taskVersion,
}) {
  final summaries = <_QualityKey, _MutableQualitySummary>{};

  _MutableQualitySummary summaryFor(_QualityKey key) {
    return summaries.putIfAbsent(key, () => _MutableQualitySummary());
  }

  for (final battle in battles) {
    if (taskId != null && battle.taskId != taskId) continue;
    if (taskIds != null && !taskIds.contains(battle.taskId)) continue;
    if (benchmarkTrack != null && battle.benchmarkTrack != benchmarkTrack) {
      continue;
    }
    if (taskVersion != null && battle.taskVersion != taskVersion) continue;

    final leftKey = _QualityKey(
      benchmarkTrack: battle.benchmarkTrack,
      taskVersion: battle.taskVersion,
      providerId: battle.leftProviderId,
      modelId: battle.leftModelId,
    );
    final rightKey = _QualityKey(
      benchmarkTrack: battle.benchmarkTrack,
      taskVersion: battle.taskVersion,
      providerId: battle.rightProviderId,
      modelId: battle.rightModelId,
    );
    final left = summaryFor(leftKey);
    final right = summaryFor(rightKey);

    if (battle.vote == ReviewVote.skip) {
      left.skipVotes++;
      right.skipVotes++;
      continue;
    }

    if (battle.leftModelKey == battle.rightModelKey) {
      continue;
    }

    final rationale = battle.rationale?.trim();
    if (rationale != null && rationale.isNotEmpty) {
      left.rationales.add(rationale);
      right.rationales.add(rationale);
    }

    switch (battle.vote) {
      case ReviewVote.left:
        left.wins++;
        right.losses++;
        break;
      case ReviewVote.right:
        right.wins++;
        left.losses++;
        break;
      case ReviewVote.tie:
        left.ties++;
        right.ties++;
        break;
      case ReviewVote.skip:
        break;
    }
  }

  final rankings = summaries.entries
      .map(
        (entry) => QualityRanking(
          benchmarkTrack: entry.key.benchmarkTrack,
          taskVersion: entry.key.taskVersion,
          providerId: entry.key.providerId,
          modelId: entry.key.modelId,
          wins: entry.value.wins,
          losses: entry.value.losses,
          ties: entry.value.ties,
          skipVotes: entry.value.skipVotes,
          minimumVotes: minimumVotes,
          rationales: entry.value.rationales.take(5).toList(),
        ),
      )
      .where((ranking) => ranking.nonSkipVotes > 0 || ranking.skipVotes > 0)
      .toList();

  rankings.sort((a, b) {
    final eligible = _compareBoolDesc(!a.lowVoteCount, !b.lowVoteCount);
    if (eligible != 0) return eligible;
    final score = b.preferenceScore.compareTo(a.preferenceScore);
    if (score != 0) return score;
    final votes = b.nonSkipVotes.compareTo(a.nonSkipVotes);
    if (votes != 0) return votes;
    final track = a.benchmarkTrack.compareTo(b.benchmarkTrack);
    if (track != 0) return track;
    final version = a.taskVersion.compareTo(b.taskVersion);
    if (version != 0) return version;
    return a.modelKey.compareTo(b.modelKey);
  });
  return rankings;
}

class _QualityKey extends Equatable {
  const _QualityKey({
    required this.benchmarkTrack,
    required this.taskVersion,
    required this.providerId,
    required this.modelId,
  });

  final String benchmarkTrack;
  final int taskVersion;
  final String providerId;
  final String modelId;

  @override
  List<Object?> get props => [benchmarkTrack, taskVersion, providerId, modelId];
}

class _MutableQualitySummary {
  double wins = 0;
  double losses = 0;
  double ties = 0;
  int skipVotes = 0;
  final List<String> rationales = [];
}

int _compareBoolDesc(bool a, bool b) {
  if (a == b) return 0;
  return a ? -1 : 1;
}
