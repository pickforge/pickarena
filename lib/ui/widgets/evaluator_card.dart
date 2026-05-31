import 'dart:convert';

import 'package:dart_arena/storage/database.dart';
import 'package:flutter/material.dart';

class EvaluatorCard extends StatelessWidget {
  const EvaluatorCard({super.key, required this.evaluation});

  final Evaluation evaluation;

  Map<String, dynamic>? _decodedDetails() {
    try {
      final decoded = jsonDecode(evaluation.detailsJson);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  String _prettyJson() {
    try {
      final decoded = jsonDecode(evaluation.detailsJson);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } on FormatException {
      return evaluation.detailsJson;
    }
  }

  String? _statusLine() {
    final details = _decodedDetails();
    if (details == null) return null;
    final reason = details['reason'];
    final suffix = reason == null ? '' : ': $reason';
    if (details['ignored'] == true) return 'Ignored$suffix';
    if (details['skipped'] == true) return 'Skipped$suffix';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final statusLine = _statusLine();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  evaluation.evaluatorId,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                _PassBadge(passed: evaluation.passed),
                const Spacer(),
                Text(evaluation.score.toStringAsFixed(2)),
              ],
            ),
            if (evaluation.rationale != null) ...[
              const SizedBox(height: 8),
              Text(evaluation.rationale!),
            ],
            if (statusLine != null) ...[
              const SizedBox(height: 8),
              Text(
                statusLine,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Details'),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      _prettyJson(),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PassBadge extends StatelessWidget {
  const _PassBadge({required this.passed});
  final bool passed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: passed ? Colors.green.shade700 : Colors.red.shade700,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        passed ? 'PASS' : 'FAIL',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
