import 'dart:math' as math;

import 'package:equatable/equatable.dart';

class ConfidenceInterval extends Equatable {
  const ConfidenceInterval({
    required this.lower,
    required this.upper,
    required this.confidenceLevel,
  });

  final double lower;
  final double upper;
  final double confidenceLevel;

  @override
  List<Object?> get props => [lower, upper, confidenceLevel];
}

const double wilson95Z = 1.95996;
const double confidence95 = 0.95;
const int lowSampleThreshold = 5;

ConfidenceInterval? wilsonPassRateInterval({
  required int successes,
  required int samples,
  double z = wilson95Z,
  double confidenceLevel = confidence95,
}) {
  if (samples <= 0) return null;
  final boundedSuccesses = successes.clamp(0, samples);
  final n = samples.toDouble();
  final phat = boundedSuccesses / n;
  final z2 = z * z;
  final denominator = 1 + z2 / n;
  final center = (phat + z2 / (2 * n)) / denominator;
  final halfWidth =
      z * math.sqrt((phat * (1 - phat) + z2 / (4 * n)) / n) / denominator;
  return ConfidenceInterval(
    lower: (center - halfWidth).clamp(0.0, 1.0).toDouble(),
    upper: (center + halfWidth).clamp(0.0, 1.0).toDouble(),
    confidenceLevel: confidenceLevel,
  );
}

bool isLowSample(int samples) => samples < lowSampleThreshold;
