/// Provenance describing how task resource limits are actually enforced.
///
/// [kernelEnforcementAvailable] must reflect reality: it is true only when
/// evaluator processes run inside the systemd user scope (Bubblewrap +
/// systemd-run) that applies CPUQuota/MemoryMax/TasksMax cgroup limits.
/// Without kernel enforcement, memory/process limits are best-effort polling
/// and are recorded as `enforced: false` so release readiness can block.
Map<String, Object?> taskResourceEnforcementJson({
  required bool kernelEnforcementAvailable,
}) => {
  'cpus': {
    'enforced': kernelEnforcementAvailable,
    'mechanism': kernelEnforcementAvailable ? 'systemdCpuQuota' : 'none',
    'kernelEnforced': kernelEnforcementAvailable,
  },
  'memoryMb': {
    'enforced': kernelEnforcementAvailable,
    'mechanism': kernelEnforcementAvailable ? 'systemdMemoryMax' : 'rssPolling',
    'kernelEnforced': kernelEnforcementAvailable,
  },
  'maxProcesses': {
    'enforced': kernelEnforcementAvailable,
    'mechanism': kernelEnforcementAvailable
        ? 'systemdTasksMax'
        : 'processTreePolling',
    'kernelEnforced': kernelEnforcementAvailable,
  },
  'maxOutputBytes': {
    'enforced': true,
    'mechanism': 'boundedByteOutputCapture',
    'kernelEnforced': false,
  },
};
