import 'package:dart_arena/review/preference_ranking.dart';
import 'package:dart_arena/review/review_battle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PreferenceBattleInput battle({
    String taskId = 'task.a',
    int taskVersion = 1,
    String track = 'codegen',
    String leftProvider = 'left-provider',
    String leftModel = 'left-model',
    String rightProvider = 'right-provider',
    String rightModel = 'right-model',
    ReviewVote vote = ReviewVote.left,
    String? rationale,
  }) {
    return PreferenceBattleInput(
      taskId: taskId,
      taskVersion: taskVersion,
      benchmarkTrack: track,
      leftProviderId: leftProvider,
      leftModelId: leftModel,
      rightProviderId: rightProvider,
      rightModelId: rightModel,
      vote: vote,
      rationale: rationale,
    );
  }

  test('left, right, and tie votes produce MVP win rates', () {
    final rankings = computePreferenceRankings([
      battle(vote: ReviewVote.left),
      battle(vote: ReviewVote.right),
      battle(vote: ReviewVote.tie),
    ], minimumVotes: 3);

    final left = rankings.singleWhere((row) => row.modelId == 'left-model');
    final right = rankings.singleWhere((row) => row.modelId == 'right-model');
    expect(left.nonSkipVotes, 3);
    expect(left.preferenceScore, 0.5);
    expect(left.displayScore, 0.5);
    expect(right.preferenceScore, 0.5);
  });

  test('skip votes count only as audit volume', () {
    final rankings = computePreferenceRankings([
      battle(vote: ReviewVote.skip),
    ], minimumVotes: 1);

    final left = rankings.singleWhere((row) => row.modelId == 'left-model');
    expect(left.nonSkipVotes, 0);
    expect(left.skipVotes, 1);
    expect(left.displayScore, isNull);
  });

  test('same-model battles are excluded from score denominators', () {
    final rankings = computePreferenceRankings([
      battle(
        leftProvider: 'openai',
        leftModel: 'gpt-5',
        rightProvider: 'openai',
        rightModel: 'gpt-5',
      ),
    ]);

    expect(rankings, isEmpty);
  });

  test('low-vote rows keep score separate from display eligibility', () {
    final rankings = computePreferenceRankings([
      battle(vote: ReviewVote.left),
    ], minimumVotes: 3);

    final left = rankings.singleWhere((row) => row.modelId == 'left-model');
    expect(left.preferenceScore, 1.0);
    expect(left.lowVoteCount, isTrue);
    expect(left.displayScore, isNull);
  });

  test('rankings are grouped by track and task version', () {
    final rankings = computePreferenceRankings([
      battle(track: 'codegen', taskVersion: 1),
      battle(track: 'agentic', taskVersion: 2),
    ], minimumVotes: 1);

    expect(
      rankings
          .where((row) => row.providerId == 'left-provider')
          .map((row) => '${row.benchmarkTrack}:${row.taskVersion}')
          .toSet(),
      {'codegen:1', 'agentic:2'},
    );
  });
}
