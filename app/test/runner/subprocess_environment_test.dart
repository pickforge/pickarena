import 'dart:io';

import 'package:dart_arena/runner/subprocess_environment.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

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

  test('scrubs proxy environment keys case-insensitively', () {
    final env = benchmarkSubprocessEnvironment(
      baseEnvironment: const {
        'PATH': '/usr/bin',
        'http_proxy': 'http://user:pass@example.test:8080',
        'HTTPS_PROXY': 'https://user:pass@example.test:8443',
        'ALL_PROXY': 'socks5://user:pass@example.test:1080',
        'NO_PROXY': 'localhost,.internal.example',
      },
    );

    expect(env, containsPair('PATH', '/usr/bin'));
    expect(env, isNot(contains('http_proxy')));
    expect(env, isNot(contains('HTTPS_PROXY')));
    expect(env, isNot(contains('ALL_PROXY')));
    expect(env, isNot(contains('NO_PROXY')));
  });

  test('scrubs credential file and package registry environment keys', () {
    final env = benchmarkSubprocessEnvironment(
      baseEnvironment: const {
        'PATH': '/usr/bin',
        'netrc': '/home/dev/.netrc',
        'KUBECONFIG': '/home/dev/.kube/config',
        'DOCKER_CONFIG': '/home/dev/.docker',
        'NPM_CONFIG_USERCONFIG': '/home/dev/.npmrc',
        'PIP_CONFIG_FILE': '/home/dev/.pip/pip.conf',
        'PIP_INDEX_URL': 'https://user:pass@example.test/simple',
        'PIP_EXTRA_INDEX_URL': 'https://user:pass@example.test/extra',
        'UV_INDEX_URL': 'https://user:pass@example.test/simple',
        'UV_EXTRA_INDEX_URL': 'https://user:pass@example.test/extra',
        'GIT_ASKPASS': '/home/dev/bin/git-askpass',
        'GIT_SSH': '/home/dev/bin/git-ssh',
        'GIT_SSH_COMMAND': 'ssh -i /home/dev/.ssh/id_ed25519',
        'GIT_CONFIG_GLOBAL': '/home/dev/.gitconfig',
        'COMPOSER_AUTH': '{"github-oauth":{"github.com":"secret"}}',
      },
    );

    expect(env, containsPair('PATH', '/usr/bin'));
    expect(env, isNot(contains('netrc')));
    expect(env, isNot(contains('KUBECONFIG')));
    expect(env, isNot(contains('DOCKER_CONFIG')));
    expect(env, isNot(contains('NPM_CONFIG_USERCONFIG')));
    expect(env, isNot(contains('PIP_CONFIG_FILE')));
    expect(env, isNot(contains('PIP_INDEX_URL')));
    expect(env, isNot(contains('PIP_EXTRA_INDEX_URL')));
    expect(env, isNot(contains('UV_INDEX_URL')));
    expect(env, isNot(contains('UV_EXTRA_INDEX_URL')));
    expect(env, isNot(contains('GIT_ASKPASS')));
    expect(env, isNot(contains('GIT_SSH')));
    expect(env, isNot(contains('GIT_SSH_COMMAND')));
    expect(env, isNot(contains('GIT_CONFIG_GLOBAL')));
    expect(env, isNot(contains('COMPOSER_AUTH')));
  });

  test('can preserve explicitly allowed sensitive keys', () {
    final env = benchmarkSubprocessEnvironment(
      baseEnvironment: const {'PATH': '/usr/bin', 'CODEX_API_KEY': 'secret'},
      allowedSensitiveKeys: const ['codex_api_key'],
    );

    expect(env, containsPair('CODEX_API_KEY', 'secret'));
  });

  test('can mark explicit reentrant Flutter tool calls', () {
    final env = benchmarkSubprocessEnvironment(
      baseEnvironment: const {'PATH': '/usr/bin'},
      allowReentrantFlutterTool: true,
    );

    expect(env, containsPair('FLUTTER_ALREADY_LOCKED', 'true'));
  });

  test('pins Flutter subprocesses to the inherited SDK toolchain', () {
    const flutterRoot = '/opt/flutter-sdk';
    final flutterBin = p.join(flutterRoot, 'bin');
    final env = benchmarkSubprocessEnvironment(
      baseEnvironment: {
        'FLUTTER_ROOT': flutterRoot,
        'PATH': [
          '/usr/bin',
          flutterBin,
          '/opt/other-flutter/bin',
        ].join(Platform.pathSeparator),
      },
    );

    expect(env, containsPair('FLUTTER_ROOT', flutterRoot));
    expect(env['PATH']!.split(Platform.pathSeparator).first, flutterBin);
    expect(
      resolveFlutterExecutable('flutter', environment: env),
      p.join(
        flutterRoot,
        'bin',
        Platform.isWindows ? 'flutter.bat' : 'flutter',
      ),
    );
  });

  test('can isolate user home and config directories', () {
    final env = benchmarkSubprocessEnvironment(
      baseEnvironment: const {
        'PATH': '/usr/bin',
        'HOME': '/home/dev',
        'USERPROFILE': r'C:\Users\dev',
        'XDG_CONFIG_HOME': '/home/dev/.config',
        'XDG_CACHE_HOME': '/home/dev/.cache',
        'APPDATA': r'C:\Users\dev\AppData\Roaming',
        'LOCALAPPDATA': r'C:\Users\dev\AppData\Local',
        'PUB_CACHE': '/home/dev/.pub-cache',
      },
      homeDirectory: '/tmp/dart_arena_home',
    );

    expect(env, containsPair('PATH', '/usr/bin'));
    expect(env, containsPair('PUB_CACHE', '/home/dev/.pub-cache'));
    expect(env, containsPair('HOME', '/tmp/dart_arena_home'));
    expect(env, containsPair('USERPROFILE', '/tmp/dart_arena_home'));
    expect(env['XDG_CONFIG_HOME'], endsWith('/tmp/dart_arena_home/.config'));
    expect(env['XDG_CACHE_HOME'], endsWith('/tmp/dart_arena_home/.cache'));
    expect(
      env['ANALYZER_STATE_LOCATION_OVERRIDE'],
      endsWith('/tmp/dart_arena_home/.dartServer'),
    );
    expect(env['APPDATA'], endsWith('/tmp/dart_arena_home/AppData/Roaming'));
    expect(env['LOCALAPPDATA'], endsWith('/tmp/dart_arena_home/AppData/Local'));
  });

  test('preserves default pub cache when isolating home', () {
    final env = benchmarkSubprocessEnvironment(
      baseEnvironment: const {'PATH': '/usr/bin', 'HOME': '/home/dev'},
      homeDirectory: '/tmp/dart_arena_home',
    );

    expect(env, containsPair('HOME', '/tmp/dart_arena_home'));
    expect(env, containsPair('PUB_CACHE', '/home/dev/.pub-cache'));
  });

  test('explicit denied keys override allowed sensitive keys', () {
    final env = benchmarkSubprocessEnvironment(
      baseEnvironment: const {'PATH': '/usr/bin', 'CODEX_API_KEY': 'secret'},
      additionalDeniedKeys: const ['CODEX_API_KEY'],
      allowedSensitiveKeys: const ['CODEX_API_KEY'],
    );

    expect(env, contains('PATH'));
    expect(env, isNot(contains('CODEX_API_KEY')));
  });

  test('explicit denied keys override reentrant Flutter marker', () {
    final env = benchmarkSubprocessEnvironment(
      baseEnvironment: const {'PATH': '/usr/bin'},
      additionalDeniedKeys: const ['flutter_already_locked'],
      allowReentrantFlutterTool: true,
    );

    expect(env, contains('PATH'));
    expect(env, isNot(contains('FLUTTER_ALREADY_LOCKED')));
  });
}
