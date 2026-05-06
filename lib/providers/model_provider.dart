import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/providers/model_stream_event.dart';

enum ProviderMode { rawApi, agent }

abstract class ModelProvider {
  String get id;
  String get displayName;
  ProviderMode get mode;
  Future<List<String>> listModels();
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  });
}

abstract class StreamingModelProvider implements ModelProvider {
  Stream<ModelStreamEvent> generateStream({
    required String prompt,
    required String model,
    Duration? timeout,
  });
}
