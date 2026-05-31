import 'package:flutter/services.dart';

Future<Map<String, String>> loadFixtureFiles({
  required String assetRoot,
  required List<String> files,
  String? repoRoot,
}) async {
  final out = <String, String>{};
  for (final rel in files) {
    out[rel] = await rootBundle.loadString('$assetRoot/$rel');
  }
  return out;
}
