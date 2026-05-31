sealed class ModelStreamEvent {
  const ModelStreamEvent();
}

class ModelStreamStarted extends ModelStreamEvent {
  const ModelStreamStarted();
}

class ModelStreamReasoningDelta extends ModelStreamEvent {
  const ModelStreamReasoningDelta(this.text);
  final String text;
}

class ModelStreamContentDelta extends ModelStreamEvent {
  const ModelStreamContentDelta(this.text);
  final String text;
}

class ModelStreamUsage extends ModelStreamEvent {
  const ModelStreamUsage({this.promptTokens, this.completionTokens});
  final int? promptTokens;
  final int? completionTokens;
}

class ModelStreamCompleted extends ModelStreamEvent {
  const ModelStreamCompleted();
}
