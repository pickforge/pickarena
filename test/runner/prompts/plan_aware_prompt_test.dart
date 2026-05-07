import 'package:dart_arena/runner/prompts/plan_aware_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('null plan returns the prompt unchanged', () {
    final out = buildPromptWithPlan(taskPrompt: 'do thing', planMarkdown: null);
    expect(out, 'do thing');
  });

  test('non-null plan injects a fenced plan block exactly once', () {
    final out = buildPromptWithPlan(
      taskPrompt: 'do thing',
      planMarkdown: '1. step one\n2. step two',
    );
    expect(out.contains('do thing'), isTrue);
    expect(
      RegExp(r'```plan').allMatches(out).length,
      1,
      reason: 'plan fence opener should appear exactly once',
    );
    expect(out.contains('1. step one'), isTrue);
    expect(out.contains('2. step two'), isTrue);
  });

  test('null plan is the only no-op case', () {
    final out = buildPromptWithPlan(
      taskPrompt: 'unrelated input',
      planMarkdown: null,
    );
    expect(out, 'unrelated input');
    expect(out.contains('REFERENCE PLAN'), isFalse);
  });
}
