import 'package:dart_arena/analytics/cost_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('estimates microdollar cost from token counts and exact pricing', () {
    const estimator = CostEstimator(
      pricingRegistry: {
        'p:m': ModelPricing(inputCostPerMToken: 2, outputCostPerMToken: 10),
      },
    );

    expect(
      estimator.estimateMicros(
        providerId: 'p',
        modelId: 'm',
        promptTokens: 100,
        completionTokens: 20,
      ),
      400,
    );
  });

  test('returns unknown when tokens or pricing are missing', () {
    const estimator = CostEstimator(pricingRegistry: {});

    expect(
      estimator.estimateMicros(
        providerId: 'p',
        modelId: 'm',
        promptTokens: 1,
        completionTokens: 1,
      ),
      isNull,
    );
    expect(
      const CostEstimator().estimateMicros(
        providerId: 'openai',
        modelId: 'gpt-5',
        promptTokens: null,
        completionTokens: 1,
      ),
      isNull,
    );
  });

  test('uses provider/model fallback only when unambiguous', () {
    const estimator = CostEstimator(
      pricingRegistry: {
        'p:m': ModelPricing(inputCostPerMToken: 1, outputCostPerMToken: 1),
        'q:m': ModelPricing(inputCostPerMToken: 2, outputCostPerMToken: 2),
        'p:other': ModelPricing(inputCostPerMToken: 3, outputCostPerMToken: 3),
      },
    );

    expect(
      estimator.pricingFor(providerId: 'p', modelId: 'm::high'),
      const ModelPricing(inputCostPerMToken: 1, outputCostPerMToken: 1),
    );
    expect(
      estimator
          .estimateDetailed(
            providerId: 'p',
            modelId: 'm::high',
            promptTokens: 1,
            completionTokens: 1,
          )
          .pricingStatus,
      'normalized_model_match',
    );
    expect(estimator.pricingFor(providerId: 'unknown', modelId: 'm'), isNull);
  });

  test('detailed estimates expose missing usage and pricing statuses', () {
    const estimator = CostEstimator(pricingRegistry: {});

    expect(
      estimator
          .estimateDetailed(
            providerId: 'p',
            modelId: 'm',
            promptTokens: null,
            completionTokens: 1,
          )
          .pricingStatus,
      'missing_usage',
    );
    final missingPricing = estimator.estimateDetailed(
      providerId: 'p',
      modelId: 'm',
      promptTokens: 1,
      completionTokens: 1,
    );
    expect(missingPricing.micros, isNull);
    expect(missingPricing.pricingStatus, 'missing_pricing');
  });

  test('emits deterministic pricing registry provenance', () {
    final provenance = pricingRegistryProvenance(
      pricingRegistry: const {
        'z:m': ModelPricing(
          inputCostPerMToken: 2,
          outputCostPerMToken: 4,
          source: 'manual',
          effectiveFrom: '2026-06-03',
        ),
        'a:m': ModelPricing(
          inputCostPerMToken: 1,
          outputCostPerMToken: 3,
          source: 'manual',
          effectiveFrom: '2026-06-01',
        ),
      },
      version: 'test-version',
    );

    expect(provenance['version'], 'test-version');
    expect(provenance['currency'], defaultPricingRegistryCurrency);
    expect(provenance['modelCount'], 2);
    expect((provenance['models']! as Map<String, Object?>).keys, [
      'a:m',
      'z:m',
    ]);
    expect(
      ((provenance['models']! as Map<String, Object?>)['a:m']!
          as Map<String, Object?>)['effectiveFrom'],
      '2026-06-01',
    );
  });
}
