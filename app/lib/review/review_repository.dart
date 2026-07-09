import 'dart:math';

import 'package:dart_arena/review/preference_ranking.dart';
import 'package:dart_arena/review/review_battle.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/settings_store.dart';
import 'package:drift/drift.dart';

class ReviewSelection {
  const ReviewSelection({
    required this.taskId,
    required this.taskVersion,
    required this.benchmarkTrack,
    required this.left,
    required this.right,
    required this.leftEvaluations,
    required this.rightEvaluations,
    required this.canonicalPairKey,
    required this.reviewerId,
  });

  final String taskId;
  final int taskVersion;
  final String benchmarkTrack;
  final TaskRun left;
  final TaskRun right;
  final List<Evaluation> leftEvaluations;
  final List<Evaluation> rightEvaluations;
  final String canonicalPairKey;
  final String reviewerId;
}

class ReviewRepository {
  ReviewRepository(
    this._db, {
    SettingsStore? settings,
    Random? random,
    DateTime Function()? now,
    String Function()? idGenerator,
    int candidateLimit = 240,
    int groupCandidateLimit = 80,
  }) : _settings = settings,
       _random = random ?? Random(),
       _now = now ?? DateTime.now,
       _idGenerator = idGenerator,
       _candidateLimit = candidateLimit,
       _groupCandidateLimit = groupCandidateLimit;

  final AppDatabase _db;
  final SettingsStore? _settings;
  final Random _random;
  final DateTime Function() _now;
  final String Function()? _idGenerator;
  final int _candidateLimit;
  final int _groupCandidateLimit;

  Future<ReviewSelection?> nextBattle({String? reviewerId}) async {
    final resolvedReviewerId = reviewerId ?? await _requireReviewerId();
    final reviewedKeys = await reviewedPairKeysForReviewer(resolvedReviewerId);
    final candidates =
        await (_db.select(_db.taskRuns)
              ..orderBy([(t) => OrderingTerm.desc(t.completedAt)])
              ..limit(_candidateLimit))
            .get();
    final eligible = candidates.where(_hasReviewArtifact).toList();
    final groups = <_TaskGroupKey, List<TaskRun>>{};
    for (final taskRun in eligible) {
      final key = _TaskGroupKey(
        taskId: taskRun.taskId,
        taskVersion: taskRun.taskVersion,
        benchmarkTrack: taskRun.benchmarkTrack,
      );
      groups.putIfAbsent(key, () => <TaskRun>[]).add(taskRun);
    }

    final sortedGroups = groups.entries.toList()
      ..sort(
        (a, b) =>
            b.value.first.completedAt.compareTo(a.value.first.completedAt),
      );

    for (final entry in sortedGroups) {
      final pair = _selectPair(entry.value, reviewedKeys);
      if (pair == null) continue;
      final evals = await _evaluationsByTaskRunId([
        pair.left.id,
        pair.right.id,
      ]);
      return ReviewSelection(
        taskId: entry.key.taskId,
        taskVersion: entry.key.taskVersion,
        benchmarkTrack: entry.key.benchmarkTrack,
        left: pair.left,
        right: pair.right,
        leftEvaluations: evals[pair.left.id] ?? const [],
        rightEvaluations: evals[pair.right.id] ?? const [],
        canonicalPairKey: pair.canonicalPairKey,
        reviewerId: resolvedReviewerId,
      );
    }

    return null;
  }

  Future<ReviewBattle> submitVote({
    required ReviewSelection selection,
    required ReviewVote vote,
    String? rationale,
  }) async {
    return insertBattleForTaskRuns(
      left: selection.left,
      right: selection.right,
      reviewerId: selection.reviewerId,
      vote: vote,
      rationale: rationale,
    );
  }

  Future<ReviewBattle> insertBattleForTaskRuns({
    required TaskRun left,
    required TaskRun right,
    required String reviewerId,
    required ReviewVote vote,
    String? reviewerAlias,
    String? rationale,
    DateTime? createdAt,
  }) async {
    final alias = reviewerAlias ?? await _settings?.getReviewReviewerAlias();
    final pairKey = canonicalReviewPairKey(left.id, right.id);
    final now = createdAt ?? _now();
    return _db
        .into(_db.reviewBattles)
        .insertReturning(
          ReviewBattlesCompanion.insert(
            id: _idGenerator?.call() ?? _newBattleId(now),
            taskId: left.taskId,
            taskVersion: left.taskVersion,
            benchmarkTrack: left.benchmarkTrack,
            leftTaskRunId: left.id,
            rightTaskRunId: right.id,
            canonicalPairKey: pairKey,
            leftLabel: 'A',
            rightLabel: 'B',
            reviewerId: reviewerId,
            reviewerAlias: Value(alias),
            vote: vote.storageValue,
            rationale: Value(_emptyToNull(rationale)),
            createdAt: now,
          ),
        );
  }

  Future<List<ReviewBattle>> battlesForReviewer(String reviewerId) {
    return (_db.select(_db.reviewBattles)
          ..where((battle) => battle.reviewerId.equals(reviewerId))
          ..orderBy([(battle) => OrderingTerm.desc(battle.createdAt)]))
        .get();
  }

  Future<Set<String>> reviewedPairKeysForReviewer(String reviewerId) async {
    final rows = await battlesForReviewer(reviewerId);
    return rows.map((battle) => battle.canonicalPairKey).toSet();
  }

  Future<List<QualityRanking>> qualityRankings({
    int minimumVotes = 3,
    String? taskId,
    Set<String>? taskIds,
    String? benchmarkTrack,
    int? taskVersion,
  }) async {
    final battles = await (_db.select(
      _db.reviewBattles,
    )..orderBy([(battle) => OrderingTerm.desc(battle.createdAt)])).get();
    if (battles.isEmpty) return const [];
    final taskRunIds = <String>{
      for (final battle in battles) battle.leftTaskRunId,
      for (final battle in battles) battle.rightTaskRunId,
    };
    final taskRuns = await _taskRunsById(taskRunIds);
    final inputs = <PreferenceBattleInput>[];
    for (final battle in battles) {
      final left = taskRuns[battle.leftTaskRunId];
      final right = taskRuns[battle.rightTaskRunId];
      if (left == null || right == null) continue;
      inputs.add(
        PreferenceBattleInput(
          taskId: battle.taskId,
          taskVersion: battle.taskVersion,
          benchmarkTrack: battle.benchmarkTrack,
          leftProviderId: left.providerId,
          leftModelId: left.modelId,
          rightProviderId: right.providerId,
          rightModelId: right.modelId,
          vote: ReviewVoteStorage.parse(battle.vote),
          rationale: battle.rationale,
        ),
      );
    }
    return computePreferenceRankings(
      inputs,
      minimumVotes: minimumVotes,
      taskId: taskId,
      taskIds: taskIds,
      benchmarkTrack: benchmarkTrack,
      taskVersion: taskVersion,
    );
  }

  _CandidatePair? _selectPair(
    List<TaskRun> rawCandidates,
    Set<String> reviewedKeys,
  ) {
    final candidates = rawCandidates.take(_groupCandidateLimit).toList();
    if (candidates.length < 2) return null;

    final byBucket = <_PassBucket, List<TaskRun>>{};
    for (final candidate in candidates) {
      byBucket
          .putIfAbsent(_bucketFor(candidate), () => <TaskRun>[])
          .add(candidate);
    }

    for (final allowSameModel in [false, true]) {
      for (final bucket in [
        _PassBucket.pass,
        _PassBucket.fail,
        _PassBucket.unknown,
      ]) {
        final pair = _choosePair(
          byBucket[bucket] ?? const [],
          reviewedKeys,
          allowSameModel: allowSameModel,
        );
        if (pair != null) return _randomizeSides(pair);
      }
      final mixed = _choosePair(
        candidates,
        reviewedKeys,
        allowSameModel: allowSameModel,
        requireMixedBucket: true,
      );
      if (mixed != null) return _randomizeSides(mixed);
    }

    return null;
  }

  _CandidatePair? _choosePair(
    List<TaskRun> candidates,
    Set<String> reviewedKeys, {
    required bool allowSameModel,
    bool requireMixedBucket = false,
  }) {
    if (candidates.length < 2) return null;
    final pairs = <_CandidatePair>[];
    for (var i = 0; i < candidates.length; i++) {
      for (var j = i + 1; j < candidates.length; j++) {
        final left = candidates[i];
        final right = candidates[j];
        if (!allowSameModel && _modelKey(left) == _modelKey(right)) continue;
        if (requireMixedBucket && _bucketFor(left) == _bucketFor(right)) {
          continue;
        }
        final pairKey = canonicalReviewPairKey(left.id, right.id);
        if (reviewedKeys.contains(pairKey)) continue;
        pairs.add(
          _CandidatePair(left: left, right: right, canonicalPairKey: pairKey),
        );
      }
    }
    if (pairs.isEmpty) return null;
    return pairs[_random.nextInt(pairs.length)];
  }

  _CandidatePair _randomizeSides(_CandidatePair pair) {
    if (_random.nextBool()) return pair;
    return _CandidatePair(
      left: pair.right,
      right: pair.left,
      canonicalPairKey: pair.canonicalPairKey,
    );
  }

  Future<Map<String, List<Evaluation>>> _evaluationsByTaskRunId(
    Iterable<String> ids,
  ) async {
    final rows = await (_db.select(
      _db.evaluations,
    )..where((e) => e.taskRunId.isIn(ids))).get();
    final out = <String, List<Evaluation>>{};
    for (final row in rows) {
      out.putIfAbsent(row.taskRunId, () => <Evaluation>[]).add(row);
    }
    return out;
  }

  Future<Map<String, TaskRun>> _taskRunsById(Iterable<String> ids) async {
    final rows = await (_db.select(
      _db.taskRuns,
    )..where((taskRun) => taskRun.id.isIn(ids))).get();
    return {for (final row in rows) row.id: row};
  }

  Future<String> _requireReviewerId() async {
    final settings = _settings;
    if (settings == null) {
      throw StateError('SettingsStore is required to resolve reviewer ID');
    }
    return settings.getOrCreateReviewReviewerId();
  }

  String _newBattleId(DateTime now) {
    final suffix = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'review-${now.microsecondsSinceEpoch}-$suffix';
  }
}

bool _hasReviewArtifact(TaskRun taskRun) {
  if (taskRun.benchmarkTrack == 'agentic') {
    return taskRun.patchText != null;
  }
  return taskRun.responseText.trim().isNotEmpty;
}

String _modelKey(TaskRun taskRun) => '${taskRun.providerId}:${taskRun.modelId}';

_PassBucket _bucketFor(TaskRun taskRun) {
  return switch (taskRun.primaryPass) {
    true => _PassBucket.pass,
    false => _PassBucket.fail,
    null => _PassBucket.unknown,
  };
}

String? _emptyToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

enum _PassBucket { pass, fail, unknown }

class _TaskGroupKey {
  const _TaskGroupKey({
    required this.taskId,
    required this.taskVersion,
    required this.benchmarkTrack,
  });

  final String taskId;
  final int taskVersion;
  final String benchmarkTrack;

  @override
  bool operator ==(Object other) {
    return other is _TaskGroupKey &&
        other.taskId == taskId &&
        other.taskVersion == taskVersion &&
        other.benchmarkTrack == benchmarkTrack;
  }

  @override
  int get hashCode => Object.hash(taskId, taskVersion, benchmarkTrack);
}

class _CandidatePair {
  const _CandidatePair({
    required this.left,
    required this.right,
    required this.canonicalPairKey,
  });

  final TaskRun left;
  final TaskRun right;
  final String canonicalPairKey;
}
