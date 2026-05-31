import 'package:dart_arena/review/review_battle.dart';
import 'package:flutter/material.dart';

class ReviewComparisonBundle {
  const ReviewComparisonBundle({
    required this.taskTitle,
    required this.taskPrompt,
    required this.benchmarkTrack,
    required this.taskVersion,
    required this.left,
    required this.right,
  });

  final String taskTitle;
  final String taskPrompt;
  final String benchmarkTrack;
  final int taskVersion;
  final ReviewSubmissionViewData left;
  final ReviewSubmissionViewData right;
}

class ReviewSubmissionViewData {
  const ReviewSubmissionViewData({
    required this.label,
    required this.artifactTitle,
    required this.artifactText,
    required this.correctnessLabel,
    required this.evaluationSummary,
    required this.providerId,
    required this.modelId,
  });

  final String label;
  final String artifactTitle;
  final String artifactText;
  final String correctnessLabel;
  final String evaluationSummary;
  final String providerId;
  final String modelId;
}

class ReviewComparisonView extends StatefulWidget {
  const ReviewComparisonView({
    super.key,
    required this.bundle,
    required this.onVote,
    this.showIdentityReveal = false,
    this.onNext,
  });

  final ReviewComparisonBundle bundle;
  final Future<void> Function(ReviewVote vote, String rationale) onVote;
  final bool showIdentityReveal;
  final VoidCallback? onNext;

  @override
  State<ReviewComparisonView> createState() => _ReviewComparisonViewState();
}

class _ReviewComparisonViewState extends State<ReviewComparisonView> {
  final _rationaleController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _rationaleController.dispose();
    super.dispose();
  }

  Future<void> _submit(ReviewVote vote) async {
    setState(() {
      _submitting = true;
    });
    try {
      await widget.onVote(vote, _rationaleController.text);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.bundle.taskTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${widget.bundle.benchmarkTrack} · task version '
                '${widget.bundle.taskVersion}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Pick the solution you would rather merge, assuming both are '
                'intended to solve the same task.',
              ),
              const SizedBox(height: 8),
              const Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Chip(label: Text('UI/UX polish')),
                  Chip(label: Text('Idiomatic Flutter')),
                  Chip(label: Text('Accessibility')),
                  Chip(label: Text('Maintainability')),
                  Chip(label: Text('Architecture/state management')),
                  Chip(label: Text('Test quality')),
                  Chip(label: Text('Merge readiness')),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('review-comparison-scroll'),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExpansionTile(
                  initiallyExpanded: true,
                  title: const Text('Task prompt'),
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SelectableText(widget.bundle.taskPrompt),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 700;
                    final cards = [
                      _SubmissionCard(
                        data: widget.bundle.left,
                        showIdentityReveal: widget.showIdentityReveal,
                      ),
                      _SubmissionCard(
                        data: widget.bundle.right,
                        showIdentityReveal: widget.showIdentityReveal,
                      ),
                    ];
                    if (narrow) {
                      return Column(
                        children: [
                          cards[0],
                          const SizedBox(height: 12),
                          cards[1],
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 12),
                        Expanded(child: cards[1]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rationaleController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Optional rationale',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: _submitting || widget.showIdentityReveal
                          ? null
                          : () => _submit(ReviewVote.left),
                      child: const Text('A is better'),
                    ),
                    FilledButton(
                      onPressed: _submitting || widget.showIdentityReveal
                          ? null
                          : () => _submit(ReviewVote.right),
                      child: const Text('B is better'),
                    ),
                    OutlinedButton(
                      onPressed: _submitting || widget.showIdentityReveal
                          ? null
                          : () => _submit(ReviewVote.tie),
                      child: const Text('Tie'),
                    ),
                    OutlinedButton(
                      onPressed: _submitting || widget.showIdentityReveal
                          ? null
                          : () => _submit(ReviewVote.skip),
                      child: const Text('Skip'),
                    ),
                    if (widget.showIdentityReveal && widget.onNext != null)
                      TextButton(
                        onPressed: widget.onNext,
                        child: const Text('Next comparison'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.data, required this.showIdentityReveal});

  final ReviewSubmissionViewData data;
  final bool showIdentityReveal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Submission ${data.label}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(data.correctnessLabel, style: theme.textTheme.bodySmall),
            if (data.evaluationSummary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(data.evaluationSummary, style: theme.textTheme.bodySmall),
            ],
            if (showIdentityReveal) ...[
              const Divider(),
              Text(
                'Identity: ${data.providerId} / ${data.modelId}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Text(data.artifactTitle, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _CodeBlock(text: data.artifactText),
          ],
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 180, maxHeight: 280),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 900,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: SelectableText(
                text.isEmpty ? '(empty artifact)' : text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
