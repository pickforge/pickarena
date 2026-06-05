Map<String, Object?> taskResourceEnforcementJson() => const {
  'cpus': {
    'enforced': true,
    'mechanism': 'systemdCpuQuota',
    'kernelEnforced': true,
  },
  'memoryMb': {
    'enforced': true,
    'mechanism': 'rssPolling',
    'kernelEnforced': false,
  },
  'maxProcesses': {
    'enforced': true,
    'mechanism': 'processTreePolling',
    'kernelEnforced': false,
  },
  'maxOutputBytes': {
    'enforced': true,
    'mechanism': 'boundedOutputCapture',
    'kernelEnforced': false,
  },
};
