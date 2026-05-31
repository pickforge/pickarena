import 'package:flutter/material.dart';

class ScoreChip extends StatelessWidget {
  const ScoreChip({super.key, required this.evaluatorId, required this.score});

  final String evaluatorId;
  final double? score;

  Color _bg() {
    final s = score;
    if (s == null) return Colors.grey.shade700;
    if (s >= 0.8) return Colors.green.shade700;
    if (s >= 0.5) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final label = score == null ? '\u2014' : score!.toStringAsFixed(2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _bg(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            evaluatorId,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
