import 'dart:io';

import 'package:dart_arena/agent/agent_run_result.dart';

abstract class AgentHarness {
  String get id;

  Future<AgentRunResult> run({
    required Directory workspace,
    required String instruction,
    required String modelId,
    required Duration timeout,
    Iterable<String> deniedEnvironmentKeys = const [],
  });
}
