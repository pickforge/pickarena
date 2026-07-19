import 'package:dart_arena/runner/resource_enforcement_policy.dart';
import 'package:test/test.dart';

void main() {
  test('reports kernel-enforced limits when systemd scope is available', () {
    expect(taskResourceEnforcementJson(kernelEnforcementAvailable: true), {
      'cpus': {
        'enforced': true,
        'mechanism': 'systemdCpuQuota',
        'kernelEnforced': true,
      },
      'memoryMb': {
        'enforced': true,
        'mechanism': 'systemdMemoryMax',
        'kernelEnforced': true,
      },
      'maxProcesses': {
        'enforced': true,
        'mechanism': 'systemdTasksMax',
        'kernelEnforced': true,
      },
      'maxOutputBytes': {
        'enforced': true,
        'mechanism': 'boundedByteOutputCapture',
        'kernelEnforced': false,
      },
    });
  });

  test('reports enforced: false when kernel enforcement is unavailable', () {
    final policy = taskResourceEnforcementJson(
      kernelEnforcementAvailable: false,
    );
    for (final key in const ['cpus', 'memoryMb', 'maxProcesses']) {
      final field = policy[key]! as Map<String, Object?>;
      expect(field['enforced'], isFalse, reason: key);
      expect(field['kernelEnforced'], isFalse, reason: key);
    }
    // Output capture is enforced in-process regardless of the kernel.
    final output = policy['maxOutputBytes']! as Map<String, Object?>;
    expect(output['enforced'], isTrue);
    expect(output['kernelEnforced'], isFalse);
  });
}
