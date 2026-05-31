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
    expect(estimator.pricingFor(providerId: 'unknown', modelId: 'm'), isNull);
  });
}
