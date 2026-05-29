class TaskWorkspace {
  const TaskWorkspace({
    this.files = const {},
    this.fixtureRootPath,
    this.instruction,
    this.setupCommands = const [],
  });

  factory TaskWorkspace.fromFixtures(
    Map<String, String> fixtures, {
    String? instruction,
  }) {
    return TaskWorkspace(files: fixtures, instruction: instruction);
  }

  final Map<String, String> files;
  final String? fixtureRootPath;
  final String? instruction;
  final List<List<String>> setupCommands;
}
