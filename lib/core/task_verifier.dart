class VerifierFixture {
  const VerifierFixture({
    required this.files,
    required this.testPath,
    this.id = 'hidden_test',
  });

  final String id;
  final Map<String, String> files;
  final String testPath;
}
