class VerifierFixture {
  const VerifierFixture({
    required this.files,
    required this.testPath,
    this.id = 'hidden_test',
    this.authoredId,
  });

  final String id;
  final String? authoredId;
  final Map<String, String> files;
  final String testPath;
}
