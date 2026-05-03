String buildPromptWithPlan({
  required String taskPrompt,
  required String? planMarkdown,
}) {
  if (planMarkdown == null) return taskPrompt;
  return '''$taskPrompt

REFERENCE PLAN:
The following plan was authored by a human and describes the intended implementation approach. You should follow it; deviations are penalized.

```plan
$planMarkdown
```''';
}
