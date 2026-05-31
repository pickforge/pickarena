import 'package:equatable/equatable.dart';

enum AgentRunStatus { success, failure, timeout, cancelled }

class AgentRunResult extends Equatable {
  const AgentRunResult({
    required this.status,
    required this.stdoutPreview,
    required this.stderrPreview,
    required this.exitCode,
    required this.latency,
    this.promptTokens,
    this.completionTokens,
    this.trajectoryLogPath,
    this.metadata = const {},
  });

  final AgentRunStatus status;
  final String stdoutPreview;
  final String stderrPreview;
  final int? exitCode;
  final Duration latency;
  final int? promptTokens;
  final int? completionTokens;
  final String? trajectoryLogPath;
  final Map<String, Object?> metadata;

  bool get succeeded => status == AgentRunStatus.success && exitCode == 0;

  @override
  List<Object?> get props => [
    status,
    stdoutPreview,
    stderrPreview,
    exitCode,
    latency,
    promptTokens,
    completionTokens,
    trajectoryLogPath,
    metadata,
  ];
}
