import 'package:dart_arena/review/review_battle.dart';
import 'package:dart_arena/ui/widgets/review_comparison_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ReviewComparisonBundle bundle() {
    return const ReviewComparisonBundle(
      taskTitle: 'Task title',
      taskPrompt: 'Build a Flutter widget.',
      benchmarkTrack: 'codegen',
      taskVersion: 1,
      left: ReviewSubmissionViewData(
        label: 'A',
        artifactTitle: 'Generated code',
        artifactText: 'class AWidget extends StatelessWidget {}',
        correctnessLabel: 'Primary correctness: pass',
        evaluationSummary: 'compile: pass (1.00)',
        providerId: 'openai',
        modelId: 'gpt-5',
      ),
      right: ReviewSubmissionViewData(
        label: 'B',
        artifactTitle: 'Generated code',
        artifactText: 'class BWidget extends StatelessWidget {}',
        correctnessLabel: 'Primary correctness: fail',
        evaluationSummary: 'compile: fail (0.00)',
        providerId: 'anthropic',
        modelId: 'claude-opus',
      ),
    );
  }

  testWidgets('hides provider and model identities before voting', (
    tester,
  ) async {
    ReviewVote? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewComparisonView(
            bundle: bundle(),
            onVote: (vote, rationale) async {
              submitted = vote;
            },
          ),
        ),
      ),
    );

    expect(find.text('Submission A'), findsOneWidget);
    expect(find.text('Submission B'), findsOneWidget);
    expect(find.textContaining('openai'), findsNothing);
    expect(find.textContaining('gpt-5'), findsNothing);
    expect(find.textContaining('anthropic'), findsNothing);
    expect(find.textContaining('claude-opus'), findsNothing);

    await tester.ensureVisible(find.text('A is better'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A is better'));
    await tester.pump();
    expect(submitted, ReviewVote.left);
  });

  testWidgets('reveals provider and model identities only after vote', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewComparisonView(
            bundle: bundle(),
            showIdentityReveal: true,
            onVote: (vote, rationale) async {},
          ),
        ),
      ),
    );

    expect(find.textContaining('openai / gpt-5'), findsOneWidget);
    expect(find.textContaining('anthropic / claude-opus'), findsOneWidget);
  });
}
