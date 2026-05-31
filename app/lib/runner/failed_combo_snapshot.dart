import 'package:equatable/equatable.dart';

class FailedComboSnapshot extends Equatable {
  const FailedComboSnapshot({
    required this.index,
    required this.label,
    required this.providerId,
    required this.modelId,
    required this.taskId,
    required this.errorMessage,
    required this.stackTrace,
    required this.failedAt,
  });

  final int index;
  final String label;
  final String providerId;
  final String modelId;
  final String taskId;
  final String errorMessage;
  final String? stackTrace;
  final DateTime failedAt;

  @override
  List<Object?> get props => [
    index,
    label,
    providerId,
    modelId,
    taskId,
    errorMessage,
    stackTrace,
    failedAt,
  ];
}
