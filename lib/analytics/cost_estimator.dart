import 'package:equatable/equatable.dart';

class ModelPricing extends Equatable {
  const ModelPricing({
    required this.inputCostPerMToken,
    required this.outputCostPerMToken,
  });

  final double inputCostPerMToken;
  final double outputCostPerMToken;

  @override
  List<Object?> get props => [inputCostPerMToken, outputCostPerMToken];
}

const defaultModelPricingRegistry = <String, ModelPricing>{
  'openai:gpt-5': ModelPricing(
    inputCostPerMToken: 1.25,
    outputCostPerMToken: 10,
  ),
  'openai:gpt-5.3-codex': ModelPricing(
    inputCostPerMToken: 1.25,
    outputCostPerMToken: 10,
  ),
  'openai:gpt-5.5': ModelPricing(
    inputCostPerMToken: 1.25,
    outputCostPerMToken: 10,
  ),
  'anthropic:claude-opus-4.7': ModelPricing(
    inputCostPerMToken: 15,
    outputCostPerMToken: 75,
  ),
  'anthropic:claude-sonnet-4.5': ModelPricing(
    inputCostPerMToken: 3,
    outputCostPerMToken: 15,
  ),
  'deepseek:deepseek-v4-pro': ModelPricing(
    inputCostPerMToken: 1,
    outputCostPerMToken: 3,
  ),
  'deepseek:deepseek-v4-flash': ModelPricing(
    inputCostPerMToken: 0.14,
    outputCostPerMToken: 0.28,
  ),
};

class CostEstimator {
  const CostEstimator({this.pricingRegistry = defaultModelPricingRegistry});

  final Map<String, ModelPricing> pricingRegistry;

  ModelPricing? pricingFor({
    required String providerId,
    required String modelId,
  }) {
    final exact = pricingRegistry['$providerId:$modelId'];
    if (exact != null) return exact;

    final providerMatches = pricingRegistry.entries.where((entry) {
      final (:provider, :model) = _splitPricingKey(entry.key);
      return provider == providerId &&
          _normalizeModelId(model) == _normalizeModelId(modelId);
    }).toList();
    if (providerMatches.length == 1) return providerMatches.single.value;

    final modelMatches = pricingRegistry.entries.where((entry) {
      final split = _splitPricingKey(entry.key);
      return _normalizeModelId(split.model) == _normalizeModelId(modelId);
    }).toList();
    if (modelMatches.length == 1) return modelMatches.single.value;

    return null;
  }

  int? estimateMicros({
    required String providerId,
    required String modelId,
    required int? promptTokens,
    required int? completionTokens,
  }) {
    if (promptTokens == null || completionTokens == null) return null;
    final pricing = pricingFor(providerId: providerId, modelId: modelId);
    if (pricing == null) return null;
    final costMicros =
        promptTokens * pricing.inputCostPerMToken +
        completionTokens * pricing.outputCostPerMToken;
    return costMicros.round();
  }
}

({String provider, String model}) _splitPricingKey(String key) {
  final sep = key.indexOf(':');
  if (sep < 0) return (provider: '', model: key);
  return (provider: key.substring(0, sep), model: key.substring(sep + 1));
}

String _normalizeModelId(String modelId) => modelId.split('::').first;
