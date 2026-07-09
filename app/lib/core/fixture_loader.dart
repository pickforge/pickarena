import 'fixture_loader_io.dart';

class FixtureLoader {
  FixtureLoader({required this.assetRoot, required this.files, this.repoRoot});

  final String assetRoot;
  final List<String> files;
  final String? repoRoot;

  Future<Map<String, String>> load() async {
    return loadFixtureFiles(
      assetRoot: assetRoot,
      files: files,
      repoRoot: repoRoot,
    );
  }
}
