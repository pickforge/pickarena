import 'package:equatable/equatable.dart';

enum RunComboPhase {
  queued,
  requestingModel,
  streamingResponse,
  extractingCode,
  creatingWorkdir,
  preparing,
  evaluating,
  persisting,
}

class RunProgressSnapshot extends Equatable {
  const RunProgressSnapshot({
    required this.index,
    required this.label,
    required this.phase,
    required this.startedAt,
    this.reasoningPreview = '',
    this.answerPreview = '',
    this.promptTokens,
    this.completionTokens,
  });

  final int index;
  final String label;
  final RunComboPhase phase;
  final DateTime startedAt;
  final String reasoningPreview;
  final String answerPreview;
  final int? promptTokens;
  final int? completionTokens;

  RunProgressSnapshot copyWith({
    RunComboPhase? phase,
    String? reasoningPreview,
    String? answerPreview,
    int? promptTokens,
    int? completionTokens,
  }) {
    return RunProgressSnapshot(
      index: index,
      label: label,
      phase: phase ?? this.phase,
      startedAt: startedAt,
      reasoningPreview: reasoningPreview ?? this.reasoningPreview,
      answerPreview: answerPreview ?? this.answerPreview,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
    );
  }

  @override
  List<Object?> get props => [
    index,
    label,
    phase,
    startedAt,
    reasoningPreview,
    answerPreview,
    promptTokens,
    completionTokens,
  ];
}
