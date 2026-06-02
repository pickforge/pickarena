import 'package:dart_arena/runner/subprocess_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scrubs common secret environment keys while preserving tool env', () {
    final env = benchmarkSubprocessEnvironment(
      baseEnvironment: const {
        'PATH': '/usr/bin',
        'HOME': '/home/dev',
        'TMPDIR': '/tmp/dart_arena',
        'PUB_CACHE': '/home/dev/.pub-cache',
        'OPENAI_API_KEY': 'secret',
        'GITHUB_TOKEN': 'secret',
        'AWS_SECRET_ACCESS_KEY': 'secret',
        'AUTHORIZATION': 'Bearer secret',
        'CLIENT_SECRET_VALUE': 'secret',
        'SECRET_KEY': 'secret',
        'SSH_AUTH_SOCK': '/tmp/ssh-agent.sock',
        'SSH_AGENT_PID': '123',
      },
    );

    expect(env, containsPair('PATH', '/usr/bin'));
    expect(env, containsPair('HOME', '/home/dev'));
    expect(env, containsPair('TMPDIR', '/tmp/dart_arena'));
    expect(env, containsPair('PUB_CACHE', '/home/dev/.pub-cache'));
    expect(env, isNot(contains('OPENAI_API_KEY')));
    expect(env, isNot(contains('GITHUB_TOKEN')));
    expect(env, isNot(contains('AWS_SECRET_ACCESS_KEY')));
    expect(env, isNot(contains('AUTHORIZATION')));
    expect(env, isNot(contains('CLIENT_SECRET_VALUE')));
    expect(env, isNot(contains('SECRET_KEY')));
    expect(env, isNot(contains('SSH_AUTH_SOCK')));
    expect(env, isNot(contains('SSH_AGENT_PID')));
  });

  test('supports explicit per-run denied keys case-insensitively', () {
    final env = benchmarkSubprocessEnvironment(
      baseEnvironment: const {
        'PATH': '/usr/bin',
        'CUSTOM_PROVIDER_KEY': 'secret',
      },
      additionalDeniedKeys: const ['custom_provider_key'],
    );

    expect(env, contains('PATH'));
    expect(env, isNot(contains('CUSTOM_PROVIDER_KEY')));
  });
}
