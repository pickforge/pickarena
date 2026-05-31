import 'package:equatable/equatable.dart';

class ModelResponse extends Equatable {
  const ModelResponse({
    required this.rawText,
    required this.extractedCode,
    required this.promptTokens,
    required this.completionTokens,
    required this.latency,
  });

  final String rawText;
  final String? extractedCode;
  final int? promptTokens;
  final int? completionTokens;
  final Duration latency;

  @override
  List<Object?> get props => [
    rawText,
    extractedCode,
    promptTokens,
    completionTokens,
    latency,
  ];
}
