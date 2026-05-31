import 'package:flutter/services.dart';

Future<String> loadPlanMarkdown({required String assetPath, String? repoRoot}) {
  return rootBundle.loadString(assetPath);
}
