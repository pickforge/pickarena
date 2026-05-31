import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('judge provider/model default to null', () async {
    final repo = SettingsRepository();
    expect(await repo.getJudgeProviderId(), isNull);
    expect(await repo.getJudgeModelId(), isNull);
  });

  test('judge provider/model roundtrip', () async {
    final repo = SettingsRepository();
    await repo.setJudgeProviderId('openai');
    await repo.setJudgeModelId('gpt-4o-mini');
    expect(await repo.getJudgeProviderId(), 'openai');
    expect(await repo.getJudgeModelId(), 'gpt-4o-mini');
  });

  test('judge provider/model can be cleared', () async {
    final repo = SettingsRepository();
    await repo.setJudgeProviderId('openai');
    await repo.setJudgeProviderId(null);
    expect(await repo.getJudgeProviderId(), isNull);
  });

  test('evaluator weights returns defaults when no overrides', () async {
    final repo = SettingsRepository();
    final weights = await repo.getEvaluatorWeights();
    expect(weights, equals(defaultEvaluatorWeights));
  });

  test('evaluator weights merges overrides on top of defaults', () async {
    final repo = SettingsRepository();
    await repo.setEvaluatorWeights({'compile': 0.9, 'unknown': 0.1});
    final weights = await repo.getEvaluatorWeights();
    expect(weights['compile'], 0.9);
    expect(weights['test'], defaultEvaluatorWeights['test']);
    expect(weights['unknown'], 0.1);
  });
}
