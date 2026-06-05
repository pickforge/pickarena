import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/providers/model_stream_event.dart';
import 'package:equatable/equatable.dart';

enum ProviderMode { rawApi, agent }

class ModelInfo extends Equatable {
  final String id;
  final List<String> efforts;
  const ModelInfo({required this.id, this.efforts = const []});

  @override
  List<Object?> get props => [id, efforts];
}

abstract class ModelProvider implements Disposable {
  String get id;
  String get displayName;
  ProviderMode get mode;
  Future<List<ModelInfo>> listModels();
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  });
}

abstract class ModelRuntimeMetadataProvider {
  Map<String, Object?> providerRuntimeConfig();
  Map<String, Object?> modelRuntimeConfig(String modelId);
}

mixin Disposable {
  void dispose() {}
}

abstract class StreamingModelProvider implements ModelProvider {
  Stream<ModelStreamEvent> generateStream({
    required String prompt,
    required String model,
    Duration? timeout,
  });
}
