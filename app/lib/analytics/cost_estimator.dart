import 'package:equatable/equatable.dart';

class ModelPricing extends Equatable {
  const ModelPricing({
    required this.inputCostPerMToken,
    required this.outputCostPerMToken,
    this.source,
    this.effectiveFrom,
  });

  final double inputCostPerMToken;
  final double outputCostPerMToken;
  final String? source;
  final String? effectiveFrom;

  Map<String, Object?> toJson() => {
    'inputCostPerMToken': inputCostPerMToken,
    'outputCostPerMToken': outputCostPerMToken,
    if (source != null) 'source': source,
    if (effectiveFrom != null) 'effectiveFrom': effectiveFrom,
  };

  @override
  List<Object?> get props => [
    inputCostPerMToken,
    outputCostPerMToken,
    source,
    effectiveFrom,
  ];
}

class PricingLookup extends Equatable {
  const PricingLookup({required this.pricing, required this.status});

  final ModelPricing pricing;
  final String status;

  @override
  List<Object?> get props => [pricing, status];
}

class CostEstimate extends Equatable {
  const CostEstimate({required this.micros, required this.pricingStatus});

  final int? micros;
  final String pricingStatus;

  @override
  List<Object?> get props => [micros, pricingStatus];
}

const defaultPricingRegistryVersion = '2026-05-31';
const defaultPricingRegistryCurrency = 'USD';
const _defaultPricingSource = 'manual';
const _defaultPricingEffectiveFrom = '2026-05-31';

const defaultModelPricingRegistry = <String, ModelPricing>{
  'openai:gpt-5': ModelPricing(
    inputCostPerMToken: 1.25,
    outputCostPerMToken: 10,
    source: _defaultPricingSource,
    effectiveFrom: _defaultPricingEffectiveFrom,
  ),
  'openai:gpt-5.3-codex': ModelPricing(
    inputCostPerMToken: 1.25,
    outputCostPerMToken: 10,
    source: _defaultPricingSource,
    effectiveFrom: _defaultPricingEffectiveFrom,
  ),
  'openai:gpt-5.5': ModelPricing(
    inputCostPerMToken: 1.25,
    outputCostPerMToken: 10,
    source: _defaultPricingSource,
    effectiveFrom: _defaultPricingEffectiveFrom,
  ),
  'anthropic:claude-opus-4.7': ModelPricing(
    inputCostPerMToken: 15,
    outputCostPerMToken: 75,
    source: _defaultPricingSource,
    effectiveFrom: _defaultPricingEffectiveFrom,
  ),
  'anthropic:claude-sonnet-4.5': ModelPricing(
    inputCostPerMToken: 3,
    outputCostPerMToken: 15,
    source: _defaultPricingSource,
    effectiveFrom: _defaultPricingEffectiveFrom,
  ),
  'deepseek:deepseek-v4-pro': ModelPricing(
    inputCostPerMToken: 1,
    outputCostPerMToken: 3,
    source: _defaultPricingSource,
    effectiveFrom: _defaultPricingEffectiveFrom,
  ),
  'deepseek:deepseek-v4-flash': ModelPricing(
    inputCostPerMToken: 0.14,
    outputCostPerMToken: 0.28,
    source: _defaultPricingSource,
    effectiveFrom: _defaultPricingEffectiveFrom,
  ),
};

Map<String, Object?> pricingRegistryProvenance({
  Map<String, ModelPricing> pricingRegistry = defaultModelPricingRegistry,
  String version = defaultPricingRegistryVersion,
  String currency = defaultPricingRegistryCurrency,
}) {
  final keys = pricingRegistry.keys.toList()..sort();
  return {
    'version': version,
    'currency': currency,
    'modelCount': keys.length,
    'models': {for (final key in keys) key: pricingRegistry[key]!.toJson()},
  };
}

class CostEstimator {
  const CostEstimator({this.pricingRegistry = defaultModelPricingRegistry});

  final Map<String, ModelPricing> pricingRegistry;

  PricingLookup? pricingLookup({
    required String providerId,
    required String modelId,
  }) {
    final exact = pricingRegistry['$providerId:$modelId'];
    if (exact != null) {
      return PricingLookup(pricing: exact, status: 'exact');
    }

    final providerMatches = pricingRegistry.entries.where((entry) {
      final (:provider, :model) = _splitPricingKey(entry.key);
      return provider == providerId &&
          _normalizeModelId(model) == _normalizeModelId(modelId);
    }).toList();
    if (providerMatches.length == 1) {
      return PricingLookup(
        pricing: providerMatches.single.value,
        status: 'normalized_model_match',
      );
    }

    final modelMatches = pricingRegistry.entries.where((entry) {
      final split = _splitPricingKey(entry.key);
      return _normalizeModelId(split.model) == _normalizeModelId(modelId);
    }).toList();
    if (modelMatches.length == 1) {
      return PricingLookup(
        pricing: modelMatches.single.value,
        status: 'model_only_match',
      );
    }

    return null;
  }

  ModelPricing? pricingFor({
    required String providerId,
    required String modelId,
  }) => pricingLookup(providerId: providerId, modelId: modelId)?.pricing;

  int? estimateMicros({
    required String providerId,
    required String modelId,
    required int? promptTokens,
    required int? completionTokens,
  }) => estimateDetailed(
    providerId: providerId,
    modelId: modelId,
    promptTokens: promptTokens,
    completionTokens: completionTokens,
  ).micros;

  CostEstimate estimateDetailed({
    required String providerId,
    required String modelId,
    required int? promptTokens,
    required int? completionTokens,
  }) {
    if (promptTokens == null || completionTokens == null) {
      return const CostEstimate(micros: null, pricingStatus: 'missing_usage');
    }
    final lookup = pricingLookup(providerId: providerId, modelId: modelId);
    if (lookup == null) {
      return const CostEstimate(micros: null, pricingStatus: 'missing_pricing');
    }
    final pricing = lookup.pricing;
    final costMicros =
        promptTokens * pricing.inputCostPerMToken +
        completionTokens * pricing.outputCostPerMToken;
    return CostEstimate(
      micros: costMicros.round(),
      pricingStatus: lookup.status,
    );
  }
}

({String provider, String model}) _splitPricingKey(String key) {
  final sep = key.indexOf(':');
  if (sep < 0) return (provider: '', model: key);
  return (provider: key.substring(0, sep), model: key.substring(sep + 1));
}

String _normalizeModelId(String modelId) => modelId.split('::').first;
