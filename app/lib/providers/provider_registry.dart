import 'package:dart_arena/providers/model_provider.dart';

class ProviderRegistry {
  final Map<String, ModelProvider> _byId = <String, ModelProvider>{};

  void register(ModelProvider provider) {
    _byId[provider.id] = provider;
  }

  ModelProvider? byId(String id) => _byId[id];

  Iterable<ModelProvider> all() => _byId.values;
}
