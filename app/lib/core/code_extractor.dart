String? extractDartCode(String raw) {
  final dartFence = RegExp(r'```dart\s*\n([\s\S]*?)\n```');
  final dartMatch = dartFence.firstMatch(raw);
  if (dartMatch != null) return '${dartMatch.group(1)!}\n';

  final anyFence = RegExp(r'```\s*\n([\s\S]*?)\n```');
  final anyMatch = anyFence.firstMatch(raw);
  if (anyMatch != null) return '${anyMatch.group(1)!}\n';

  return null;
}

String? extractJsonBlock(String raw) {
  final jsonFence = RegExp(r'```json\s*\n([\s\S]*?)\n```');
  final jsonMatch = jsonFence.firstMatch(raw);
  if (jsonMatch != null) return '${jsonMatch.group(1)!}\n';

  final anyFence = RegExp(r'```\s*\n([\s\S]*?)\n```');
  final anyMatch = anyFence.firstMatch(raw);
  if (anyMatch != null) return '${anyMatch.group(1)!}\n';

  return null;
}
