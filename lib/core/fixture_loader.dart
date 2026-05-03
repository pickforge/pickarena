import 'package:flutter/services.dart';

class FixtureLoader {
  FixtureLoader({required this.assetRoot, required this.files});

  final String assetRoot;
  final List<String> files;

  Future<Map<String, String>> load() async {
    final out = <String, String>{};
    for (final rel in files) {
      out[rel] = await rootBundle.loadString('$assetRoot/$rel');
    }
    return out;
  }
}
