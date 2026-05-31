import 'package:dart_arena/providers/model_provider.dart';

class EvaluatorConfig {
  const EvaluatorConfig({this.judgeProvider, this.judgeModel});

  final ModelProvider? judgeProvider;
  final String? judgeModel;

  bool get hasJudge => judgeProvider != null && judgeModel != null;
}
