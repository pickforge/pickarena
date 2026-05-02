import 'dart:convert';

class TestReportSummary {
  TestReportSummary({
    required this.total,
    required this.passed,
    required this.failed,
    required this.errored,
    required this.failures,
  });

  final int total;
  final int passed;
  final int failed;
  final int errored;
  final List<Map<String, String>> failures;

  double get score => total == 0 ? 0.0 : passed / total;
  bool get allPassed => total > 0 && failed == 0 && errored == 0;
}

TestReportSummary parseTestReporterJson(String stdout) {
  final tests = <int, String>{};
  var passed = 0;
  var failed = 0;
  var errored = 0;
  final failures = <Map<String, String>>[];

  for (final line in const LineSplitter().convert(stdout)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('{')) continue;
    final Map<String, dynamic> evt;
    try {
      evt = jsonDecode(trimmed) as Map<String, dynamic>;
    } on FormatException {
      continue;
    }

    final type = evt['type'] as String?;
    if (type == 'testStart') {
      final test = evt['test'] as Map<String, dynamic>?;
      final id = test?['id'] as int?;
      final name = test?['name'] as String? ?? '';
      if (id != null) tests[id] = name;
    } else if (type == 'testDone') {
      final hidden = evt['hidden'] as bool? ?? false;
      if (hidden) continue;
      final result = evt['result'] as String?;
      final id = evt['testID'] as int?;
      final name = id != null ? (tests[id] ?? '') : '';
      switch (result) {
        case 'success':
          passed++;
        case 'failure':
          failed++;
          failures.add({'name': name, 'message': 'failure'});
        case 'error':
          errored++;
          failures.add({'name': name, 'message': 'error'});
      }
    } else if (type == 'error') {
      final id = evt['testID'] as int?;
      final name = id != null ? (tests[id] ?? '') : '';
      final msg = (evt['error'] as String?) ?? '';
      failures.add({
        'name': name,
        'message': msg.length > 200 ? msg.substring(0, 200) : msg,
      });
    }
  }

  final total = passed + failed + errored;
  return TestReportSummary(
    total: total,
    passed: passed,
    failed: failed,
    errored: errored,
    failures: failures,
  );
}
