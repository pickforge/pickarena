# dart_arena — Plan 2: Cloud Providers

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 7 cloud providers so the app is usable without local models. End state: NewRunPage lets the user pick any subset of configured providers, each with a model dropdown (or free-text fallback). Settings page has one section per provider for API key entry.

**Why this comes before Plan 3 (more tasks/evaluators):** the user has no way to run the app today without a local Ollama install. Unblocks all subsequent benchmarking work.

**Providers added in this plan:**

| Provider           | Auth                     | Endpoint                                    | API shape          |
| ------------------ | ------------------------ | ------------------------------------------- | ------------------ |
| OpenCode Zen       | `Authorization: Bearer`  | `https://opencode.ai/zen/v1`                | OpenAI-compatible  |
| Ollama Cloud       | `Authorization: Bearer`  | `https://ollama.com`                        | Ollama (reuses class) |
| OpenAI             | `Authorization: Bearer`  | `https://api.openai.com/v1`                 | OpenAI-compatible  |
| OpenRouter         | `Authorization: Bearer`  | `https://openrouter.ai/api/v1`              | OpenAI-compatible  |
| DeepSeek           | `Authorization: Bearer`  | `https://api.deepseek.com/v1`               | OpenAI-compatible  |
| Anthropic          | `x-api-key`              | `https://api.anthropic.com/v1`              | Anthropic Messages |
| Factory Droid      | n/a (uses local CLI)     | `droid exec` subprocess                     | agent (CLI)        |

Five of these are OpenAI-compatible, so we factor a single `OpenAiCompatibleProvider` base class to avoid duplication.

**Out of scope for this plan:**
- Zen Claude (`/v1/messages`) and Zen GPT-5 (`/v1/responses`) routing. The user can hit Claude via Anthropic direct and OpenAI via OpenAI direct in v2; Zen routing for those families lands in a later plan if needed.
- Multi-task / multi-evaluator support (Plan 3).
- Run history list page (Plan 4).

---

## File map (this plan)

Created:

- `lib/providers/openai_compatible_provider.dart` — base class for OpenAI chat/completions
- `lib/providers/opencode_zen_provider.dart`
- `lib/providers/openai_provider.dart`
- `lib/providers/openrouter_provider.dart`
- `lib/providers/deepseek_provider.dart`
- `lib/providers/anthropic_provider.dart`
- `lib/providers/droid_exec_provider.dart`
- `lib/providers/provider_factory.dart` — builds enabled list from settings
- `test/providers/<each>_test.dart` — one mocked test file per provider

Modified:

- `lib/storage/settings.dart` — adds typed per-provider key/url accessors
- `lib/providers/ollama_provider.dart` — no code change; registered twice (local + cloud)
- `lib/ui/pages/settings_page.dart` — multi-section layout
- `lib/ui/pages/new_run_page.dart` — provider multi-select + per-provider model dropdown
- `test/storage/settings_test.dart` — extended

---

## Task 1: Generic OpenAI-compatible provider base class

**Files:**
- Create: `lib/providers/openai_compatible_provider.dart`
- Create: `test/providers/openai_compatible_provider_test.dart`

- [ ] **Step 1: Failing test using mocked Dio**

Create `test/providers/openai_compatible_provider_test.dart`:

```dart
import 'package:dart_arena/providers/openai_compatible_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

class _ConcreteProvider extends OpenAiCompatibleProvider {
  _ConcreteProvider(super.dio)
      : super(
          id: 'test',
          displayName: 'Test',
          baseUrl: 'https://test.example/v1',
          apiKey: 'sk-x',
        );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  test('generate posts to /chat/completions and parses content+usage',
      () async {
    final dio = _MockDio();
    when(() => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          data: <String, dynamic>{
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'hello'},
              },
            ],
            'usage': {'prompt_tokens': 10, 'completion_tokens': 3},
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

    final p = _ConcreteProvider(dio);
    final r = await p.generate(prompt: 'hi', model: 'm');

    expect(r.rawText, 'hello');
    expect(r.promptTokens, 10);
    expect(r.completionTokens, 3);
  });

  test('listModels parses /models response', () async {
    final dio = _MockDio();
    when(() => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          data: <String, dynamic>{
            'data': [
              {'id': 'model-a'},
              {'id': 'model-b'},
            ],
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

    final p = _ConcreteProvider(dio);
    expect(await p.listModels(), ['model-a', 'model-b']);
  });
}
```

- [ ] **Step 2: Run → FAIL**

```bash
cd /home/dev/Development/Personal/dart_arena && flutter test test/providers/openai_compatible_provider_test.dart
```

- [ ] **Step 3: Implement**

Create `lib/providers/openai_compatible_provider.dart`:

```dart
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dio/dio.dart';

class OpenAiCompatibleProvider implements ModelProvider {
  OpenAiCompatibleProvider(
    Dio? dio, {
    required this.id,
    required this.displayName,
    required this.baseUrl,
    required this.apiKey,
    this.extraHeaders = const <String, String>{},
  }) : _dio = dio ?? Dio();

  @override
  final String id;
  @override
  final String displayName;
  final String baseUrl;
  final String apiKey;
  final Map<String, String> extraHeaders;
  final Dio _dio;

  @override
  ProviderMode get mode => ProviderMode.rawApi;

  Map<String, String> _headers() => <String, String>{
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        ...extraHeaders,
      };

  @override
  Future<List<String>> listModels() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/models',
      options: Options(headers: _headers()),
    );
    final list = (res.data?['data'] as List<dynamic>? ?? <dynamic>[])
        .map((m) => (m as Map<String, dynamic>)['id'] as String)
        .toList();
    return list;
  }

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    final res = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/chat/completions',
      data: <String, dynamic>{
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'stream': false,
      },
      options: Options(
        headers: _headers(),
        sendTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );
    stopwatch.stop();

    final data = res.data ?? const <String, dynamic>{};
    final choices = data['choices'] as List<dynamic>? ?? const <dynamic>[];
    final message = choices.isEmpty
        ? const <String, dynamic>{}
        : (choices.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>? ?? const <String, dynamic>{};
    final content = message['content'] as String? ?? '';
    final usage = data['usage'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return ModelResponse(
      rawText: content,
      extractedCode: null,
      promptTokens: usage['prompt_tokens'] as int?,
      completionTokens: usage['completion_tokens'] as int?,
      latency: stopwatch.elapsed,
    );
  }
}
```

- [ ] **Step 4: PASS + analyze**

```bash
flutter test test/providers/openai_compatible_provider_test.dart && flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/providers/openai_compatible_provider.dart test/providers/openai_compatible_provider_test.dart
git commit -m "feat(providers): add OpenAI-compatible base provider"
```

---

## Task 2: OpenCodeZenProvider

**Files:**
- Create: `lib/providers/opencode_zen_provider.dart`
- Create: `test/providers/opencode_zen_provider_test.dart`

- [ ] **Step 1: Test**

```dart
// test/providers/opencode_zen_provider_test.dart
import 'package:dart_arena/providers/opencode_zen_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OpenCodeZenProvider has correct identity and base URL', () {
    final p = OpenCodeZenProvider(apiKey: 'k');
    expect(p.id, 'opencode_zen');
    expect(p.displayName, 'OpenCode Zen');
    expect(p.baseUrl, 'https://opencode.ai/zen/v1');
  });
}
```

- [ ] **Step 2: Implement**

```dart
// lib/providers/opencode_zen_provider.dart
import 'package:dart_arena/providers/openai_compatible_provider.dart';
import 'package:dio/dio.dart';

class OpenCodeZenProvider extends OpenAiCompatibleProvider {
  OpenCodeZenProvider({required String apiKey, Dio? dio})
      : super(
          dio,
          id: 'opencode_zen',
          displayName: 'OpenCode Zen',
          baseUrl: 'https://opencode.ai/zen/v1',
          apiKey: apiKey,
        );

  /// Return only models routed through /chat/completions.
  /// Zen also proxies Claude (via /v1/messages) and GPT-5 (via /v1/responses),
  /// which use incompatible API shapes.
  @override
  Future<List<String>> listModels() async {
    try {
      final all = await super.listModels();
      if (all.isEmpty) return _chatModels;
      // Filter to known chat-compatible models if the API doesn't provide
      // endpoint metadata per model.
      final chatCompatiblePrefixes = [
        'qwen', 'minimax', 'glm', 'kimi',
        'big-pickle', 'ling-', 'hy3', 'nemotron',
      ];
      final filtered = all.where((id) =>
          chatCompatiblePrefixes.any((p) => id.startsWith(p))).toList();
      return filtered.isNotEmpty ? filtered : _chatModels;
    } catch (_) {
      return _chatModels;
    }
  }

  static const _chatModels = <String>[
    'qwen3.6-plus',
    'qwen3.5-plus',
    'minimax-m2.7',
    'minimax-m2.5',
    'minimax-m2.5-free',
    'glm-5.1',
    'glm-5',
    'kimi-k2.6',
    'kimi-k2.5',
    'big-pickle',
    'ling-2.6-flash',
    'hy3-preview-free',
    'nemotron-3-super-free',
  ];
}
```

- [ ] **Step 3: PASS + analyze + commit**

```bash
git add lib/providers/opencode_zen_provider.dart test/providers/opencode_zen_provider_test.dart
git commit -m "feat(providers): add OpenCodeZenProvider"
```

---

## Task 3: OpenAIProvider

**Files:**
- Create: `lib/providers/openai_provider.dart`
- Create: `test/providers/openai_provider_test.dart`

- [ ] **Step 1: Test**

```dart
// test/providers/openai_provider_test.dart
import 'package:dart_arena/providers/openai_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OpenAIProvider has correct identity and base URL', () {
    final p = OpenAIProvider(apiKey: 'sk-test');
    expect(p.id, 'openai');
    expect(p.displayName, 'OpenAI');
    expect(p.baseUrl, 'https://api.openai.com/v1');
  });
}
```

- [ ] **Step 2: Implement**

```dart
// lib/providers/openai_provider.dart
import 'package:dart_arena/providers/openai_compatible_provider.dart';
import 'package:dio/dio.dart';

class OpenAIProvider extends OpenAiCompatibleProvider {
  OpenAIProvider({required String apiKey, Dio? dio})
      : super(
          dio,
          id: 'openai',
          displayName: 'OpenAI',
          baseUrl: 'https://api.openai.com/v1',
          apiKey: apiKey,
        );
}
```

- [ ] **Step 3: PASS + analyze + commit**

```bash
git add lib/providers/openai_provider.dart test/providers/openai_provider_test.dart
git commit -m "feat(providers): add OpenAIProvider"
```

---

## Task 4: OpenRouterProvider

**Files:**
- Create: `lib/providers/openrouter_provider.dart`
- Create: `test/providers/openrouter_provider_test.dart`

- [ ] **Step 1: Test (asserts X-Title header)**

```dart
// test/providers/openrouter_provider_test.dart
import 'package:dart_arena/providers/openrouter_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OpenRouterProvider has correct identity, base URL, and X-Title header', () {
    final p = OpenRouterProvider(apiKey: 'sk-test');
    expect(p.id, 'openrouter');
    expect(p.displayName, 'OpenRouter');
    expect(p.baseUrl, 'https://openrouter.ai/api/v1');
    // Verify X-Title is wired into extraHeaders
    final headers = p.extraHeaders;
    expect(headers['X-Title'], 'dart_arena');
  });
}
```

- [ ] **Step 2: Implement**

```dart
// lib/providers/openrouter_provider.dart
import 'package:dart_arena/providers/openai_compatible_provider.dart';
import 'package:dio/dio.dart';

class OpenRouterProvider extends OpenAiCompatibleProvider {
  OpenRouterProvider({required String apiKey, Dio? dio})
      : super(
          dio,
          id: 'openrouter',
          displayName: 'OpenRouter',
          baseUrl: 'https://openrouter.ai/api/v1',
          apiKey: apiKey,
          extraHeaders: const <String, String>{
            'X-Title': 'dart_arena',
          },
        );
}
```

- [ ] **Step 3: PASS + analyze + commit**

```bash
git add lib/providers/openrouter_provider.dart test/providers/openrouter_provider_test.dart
git commit -m "feat(providers): add OpenRouterProvider"
```

---

## Task 5: DeepSeekProvider

**Files:**
- Create: `lib/providers/deepseek_provider.dart`
- Create: `test/providers/deepseek_provider_test.dart`

- [ ] **Step 1: Test**

```dart
// test/providers/deepseek_provider_test.dart
import 'package:dart_arena/providers/deepseek_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DeepSeekProvider has correct identity and base URL', () {
    final p = DeepSeekProvider(apiKey: 'sk-test');
    expect(p.id, 'deepseek');
    expect(p.displayName, 'DeepSeek');
    expect(p.baseUrl, 'https://api.deepseek.com/v1');
  });
}
```

- [ ] **Step 2: Implement**

```dart
// lib/providers/deepseek_provider.dart
import 'package:dart_arena/providers/openai_compatible_provider.dart';
import 'package:dio/dio.dart';

class DeepSeekProvider extends OpenAiCompatibleProvider {
  DeepSeekProvider({required String apiKey, Dio? dio})
      : super(
          dio,
          id: 'deepseek',
          displayName: 'DeepSeek',
          baseUrl: 'https://api.deepseek.com/v1',
          apiKey: apiKey,
        );
}
```

- [ ] **Step 3: PASS + analyze + commit**

```bash
git add lib/providers/deepseek_provider.dart test/providers/deepseek_provider_test.dart
git commit -m "feat(providers): add DeepSeekProvider"
```

---

## Task 6: AnthropicProvider (separate API shape)

**Files:**
- Create: `lib/providers/anthropic_provider.dart`
- Create: `test/providers/anthropic_provider_test.dart`

Anthropic uses `/v1/messages` with different headers and body/response shapes.

- [ ] **Step 1: Test**

```dart
import 'package:dart_arena/providers/anthropic_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() => registerFallbackValue(Options()));

  test('generate parses Messages API response shape', () async {
    final dio = _MockDio();
    when(() => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          data: <String, dynamic>{
            'content': [
              {'type': 'text', 'text': 'world'},
            ],
            'usage': {'input_tokens': 5, 'output_tokens': 1},
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

    final p = AnthropicProvider(apiKey: 'sk', dio: dio);
    final r = await p.generate(prompt: 'hi', model: 'claude-sonnet-4-5');
    expect(r.rawText, 'world');
    expect(r.promptTokens, 5);
    expect(r.completionTokens, 1);
  });

  test('listModels returns the curated default list when /models 404s',
      () async {
    final dio = _MockDio();
    final p = AnthropicProvider(apiKey: 'sk', dio: dio);
    expect(await p.listModels(), contains('claude-sonnet-4-5'));
  });
}
```

- [ ] **Step 2: Implement**

```dart
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dio/dio.dart';

class AnthropicProvider implements ModelProvider {
  AnthropicProvider({required this.apiKey, Dio? dio})
      : _dio = dio ?? Dio();

  @override
  String get id => 'anthropic';
  @override
  String get displayName => 'Anthropic';
  @override
  ProviderMode get mode => ProviderMode.rawApi;

  static const String baseUrl = 'https://api.anthropic.com/v1';
  final String apiKey;
  final Dio _dio;

  Map<String, String> _headers() => <String, String>{
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      };

  @override
  Future<List<String>> listModels() async => const [
        'claude-opus-4-5',
        'claude-sonnet-4-5',
        'claude-haiku-4-5',
        'claude-3-5-haiku',
      ];

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    final res = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/messages',
      data: <String, dynamic>{
        'model': model,
        'max_tokens': 4096,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      },
      options: Options(
        headers: _headers(),
        sendTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );
    stopwatch.stop();

    final data = res.data ?? const <String, dynamic>{};
    final content = data['content'] as List<dynamic>? ?? const <dynamic>[];
    final text = content
        .whereType<Map<String, dynamic>>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String? ?? '')
        .join();
    final usage = data['usage'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return ModelResponse(
      rawText: text,
      extractedCode: null,
      promptTokens: usage['input_tokens'] as int?,
      completionTokens: usage['output_tokens'] as int?,
      latency: stopwatch.elapsed,
    );
  }
}
```

- [ ] **Step 3: PASS + analyze + commit**

```bash
git add lib/providers/anthropic_provider.dart test/providers/anthropic_provider_test.dart
git commit -m "feat(providers): add AnthropicProvider"
```

---

## Task 7: Ollama Cloud (no new class)

`OllamaProvider` already supports any baseUrl + bearer token, so this task is purely a registration question handled in Task 9 (provider factory). No new code.

Skip — covered by factory wiring.

---

## Task 8: DroidExecProvider (subprocess)

**Files:**
- Create: `lib/providers/droid_exec_provider.dart`
- Create: `test/providers/droid_exec_provider_test.dart`

Shells out to `droid exec --auto low --output-format text --model <model> "<prompt>"`. The user's `fk_` key isn't passed via the app — Droid is pre-authenticated locally.

- [ ] **Step 1: Test using injectable Process runner**

The provider takes a `ProcessRunner` typedef so we can stub it without spawning real subprocesses.

```dart
import 'package:dart_arena/providers/droid_exec_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses stdout into ModelResponse', () async {
    final p = DroidExecProvider(
      runner: (executable, args) async => DroidProcessResult(
        stdout: 'hello from droid',
        stderr: '',
        exitCode: 0,
      ),
    );
    final r = await p.generate(prompt: 'hi', model: 'gpt-5.5');
    expect(r.rawText, 'hello from droid');
  });

  test('listModels returns curated list', () async {
    final p = DroidExecProvider();
    final m = await p.listModels();
    expect(m, contains('gpt-5.5'));
  });
}
```

- [ ] **Step 2: Implement**

```dart
import 'dart:io';

import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/providers/model_provider.dart';

class DroidProcessResult {
  const DroidProcessResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });
  final String stdout;
  final String stderr;
  final int exitCode;
}

typedef DroidProcessRunner = Future<DroidProcessResult> Function(
  String executable,
  List<String> arguments,
);

class DroidExecProvider implements ModelProvider {
  DroidExecProvider({DroidProcessRunner? runner})
      : _runner = runner ?? _defaultRunner;

  static Future<DroidProcessResult> _defaultRunner(
    String exe,
    List<String> args,
  ) async {
    final res = await Process.run(exe, args);
    return DroidProcessResult(
      stdout: res.stdout.toString(),
      stderr: res.stderr.toString(),
      exitCode: res.exitCode,
    );
  }

  final DroidProcessRunner _runner;

  @override
  String get id => 'droid';
  @override
  String get displayName => 'Factory Droid';
  @override
  ProviderMode get mode => ProviderMode.agent;

  @override
  Future<List<String>> listModels() async => const [
        'gpt-5.5',
        'gpt-5.4',
        'gpt-5.3-codex',
        'claude-sonnet-4-6',
        'claude-opus-4-7',
        'gemini-3-flash',
      ];

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    final sw = Stopwatch()..start();
    final res = await _runner('droid', [
      'exec',
      '--auto',
      'low',
      '--output-format',
      'text',
      '--model',
      model,
      prompt,
    ]);
    sw.stop();
    if (res.exitCode != 0) {
      throw Exception('droid exec failed: ${res.stderr}');
    }
    return ModelResponse(
      rawText: res.stdout,
      extractedCode: null,
      promptTokens: null,
      completionTokens: null,
      latency: sw.elapsed,
    );
  }
}
```

- [ ] **Step 3: PASS + analyze + commit**

```bash
git add lib/providers/droid_exec_provider.dart test/providers/droid_exec_provider_test.dart
git commit -m "feat(providers): add DroidExecProvider"
```

---

## Task 9: Extend SettingsRepository for per-provider keys

**Files:**
- Modify: `lib/storage/settings.dart`
- Modify: `test/storage/settings_test.dart`

Add typed accessors for every provider's key + base URL override. Keep existing `getOllamaBaseUrl/setOllamaBaseUrl` for compat.

- [ ] **Step 1: Test**

Append to `test/storage/settings_test.dart`:

```dart
test('per-provider api keys roundtrip', () async {
  FlutterSecureStorage.setMockInitialValues({});
  final repo = SettingsRepository();
  expect(await repo.getApiKey('opencode_zen'), isNull);
  await repo.setApiKey('opencode_zen', 'sk-zen-1');
  expect(await repo.getApiKey('opencode_zen'), 'sk-zen-1');
  await repo.clearApiKey('opencode_zen');
  expect(await repo.getApiKey('opencode_zen'), isNull);
});

test('ollama cloud key has its own slot', () async {
  FlutterSecureStorage.setMockInitialValues({});
  final repo = SettingsRepository();
  await repo.setApiKey('ollama_cloud', 'cloud-token');
  expect(await repo.getApiKey('ollama_cloud'), 'cloud-token');
});
```

- [ ] **Step 2: Implement**

Replace `lib/storage/settings.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsRepository {
  SettingsRepository([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _ollamaBaseUrl = 'ollama_base_url';

  Future<String> getOllamaBaseUrl() async =>
      (await _storage.read(key: _ollamaBaseUrl)) ?? 'http://localhost:11434';

  Future<void> setOllamaBaseUrl(String value) =>
      _storage.write(key: _ollamaBaseUrl, value: value);

  String _apiKeyKey(String providerId) => 'api_key:$providerId';
  String _baseUrlKey(String providerId) => 'base_url:$providerId';

  Future<String?> getApiKey(String providerId) =>
      _storage.read(key: _apiKeyKey(providerId));

  Future<void> setApiKey(String providerId, String value) =>
      _storage.write(key: _apiKeyKey(providerId), value: value);

  Future<void> clearApiKey(String providerId) =>
      _storage.delete(key: _apiKeyKey(providerId));

  Future<String?> getBaseUrlOverride(String providerId) =>
      _storage.read(key: _baseUrlKey(providerId));

  Future<void> setBaseUrlOverride(String providerId, String value) =>
      _storage.write(key: _baseUrlKey(providerId), value: value);
}
```

- [ ] **Step 3: PASS + analyze + commit**

```bash
git add lib/storage/settings.dart test/storage/settings_test.dart
git commit -m "feat(storage): per-provider API key + base URL overrides"
```

---

## Task 10: ProviderFactory — build enabled list from settings

**Files:**
- Create: `lib/providers/provider_factory.dart`
- Create: `test/providers/provider_factory_test.dart`

The factory reads `SettingsRepository`, returns a `List<ModelProvider>` containing only providers that have an API key (or always-on ones: Ollama Local + Droid).

- [ ] **Step 1: Test**

```dart
import 'package:dart_arena/providers/provider_factory.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('Ollama Local + Droid are always enabled', () async {
    final providers = await buildEnabledProviders(SettingsRepository());
    final ids = providers.map((p) => p.id).toList();
    expect(ids, containsAll(['ollama_local', 'droid']));
  });

  test('cloud providers appear once their key is set', () async {
    final repo = SettingsRepository();
    expect(
      (await buildEnabledProviders(repo)).any((p) => p.id == 'opencode_zen'),
      isFalse,
    );
    await repo.setApiKey('opencode_zen', 'sk');
    expect(
      (await buildEnabledProviders(repo)).any((p) => p.id == 'opencode_zen'),
      isTrue,
    );
  });
}
```

- [ ] **Step 2: Implement**

```dart
import 'package:dart_arena/providers/anthropic_provider.dart';
import 'package:dart_arena/providers/deepseek_provider.dart';
import 'package:dart_arena/providers/droid_exec_provider.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/ollama_provider.dart';
import 'package:dart_arena/providers/openai_provider.dart';
import 'package:dart_arena/providers/opencode_zen_provider.dart';
import 'package:dart_arena/providers/openrouter_provider.dart';
import 'package:dart_arena/storage/settings.dart';

Future<List<ModelProvider>> buildEnabledProviders(
  SettingsRepository repo,
) async {
  final providers = <ModelProvider>[];

  providers.add(OllamaProvider(
    id: 'ollama_local',
    displayName: 'Ollama Local',
    baseUrl: await repo.getOllamaBaseUrl(),
    apiKey: null,
  ));

  final ollamaCloudKey = await repo.getApiKey('ollama_cloud');
  if (ollamaCloudKey != null && ollamaCloudKey.isNotEmpty) {
    providers.add(OllamaProvider(
      id: 'ollama_cloud',
      displayName: 'Ollama Cloud',
      baseUrl: await repo.getBaseUrlOverride('ollama_cloud') ??
          'https://ollama.com',
      apiKey: ollamaCloudKey,
    ));
  }

  Future<void> addOpenAiCompat(
    String providerId,
    ModelProvider Function(String key) build,
  ) async {
    final k = await repo.getApiKey(providerId);
    if (k != null && k.isNotEmpty) providers.add(build(k));
  }

  await addOpenAiCompat('opencode_zen', (k) => OpenCodeZenProvider(apiKey: k));
  await addOpenAiCompat('openai', (k) => OpenAIProvider(apiKey: k));
  await addOpenAiCompat('openrouter', (k) => OpenRouterProvider(apiKey: k));
  await addOpenAiCompat('deepseek', (k) => DeepSeekProvider(apiKey: k));
  await addOpenAiCompat('anthropic', (k) => AnthropicProvider(apiKey: k));

  providers.add(DroidExecProvider());

  return providers;
}
```

- [ ] **Step 3: PASS + analyze + commit**

```bash
git add lib/providers/provider_factory.dart test/providers/provider_factory_test.dart
git commit -m "feat(providers): add provider factory wired to settings"
```

---

## Task 11: Settings page expansion

**Files:**
- Modify: `lib/ui/pages/settings_page.dart`

Replace the single-field UI with a scrollable list of provider sections. Each section:
- Provider name as section header
- API key field (obscured, toggle visibility) — except Ollama Local which keeps the base URL field instead, and Droid which shows just an info note ("uses local CLI")
- Save button per section (writes to SettingsRepository)

Layout sketch:

```dart
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _repo = SettingsRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OllamaLocalSection(repo: _repo),
          const Divider(),
          _ApiKeySection(
            repo: _repo,
            providerId: 'ollama_cloud',
            label: 'Ollama Cloud',
          ),
          const Divider(),
          _ApiKeySection(repo: _repo, providerId: 'opencode_zen', label: 'OpenCode Zen'),
          const Divider(),
          _ApiKeySection(repo: _repo, providerId: 'openai', label: 'OpenAI'),
          const Divider(),
          _ApiKeySection(repo: _repo, providerId: 'openrouter', label: 'OpenRouter'),
          const Divider(),
          _ApiKeySection(repo: _repo, providerId: 'deepseek', label: 'DeepSeek'),
          const Divider(),
          _ApiKeySection(repo: _repo, providerId: 'anthropic', label: 'Anthropic'),
          const Divider(),
          const ListTile(
            title: Text('Factory Droid'),
            subtitle: Text('Uses local droid CLI; no key needed in app.'),
          ),
        ],
      ),
    );
  }
}
```

`_ApiKeySection` is a stateful widget with a TextField (obscured by default, with eye toggle), a status badge ("Set" / "Not configured"), and a Save button. `_OllamaLocalSection` is the existing Ollama URL widget extracted.

Manual smoke: open Settings, type a fake key, save, navigate away+back → key persists.

- [ ] Implement, no dedicated widget tests (covered by manual smoke + repo tests).
- [ ] `flutter analyze && flutter build linux --debug`
- [ ] Commit `feat(ui): multi-provider Settings page`.

---

## Task 12: NewRunPage — multi-provider selection + model dropdown with fallback

**Files:**
- Modify: `lib/ui/pages/new_run_page.dart`

Replace the single-Ollama UI:

1. On `initState`, call `buildEnabledProviders(SettingsRepository())` and store the list.
2. Render a checkbox list of providers with a per-row model picker.
3. Per-row picker logic:
   - On first expand of a row, call `provider.listModels()`.
   - Success → render `DropdownButton<String>` with the returned ids.
   - Error or empty → render a `TextField` with helper text "type model id".
4. "Run" button collects checked rows: builds `tasks: [OffByOnePaginationTask()]`, `providers: [...]`, `modelByProvider: {id: chosenModel}`. If `chosenModel` is empty for a checked provider, disable Run.
5. Pass the `RunBloc` via `context.push('/run', extra: bloc)` exactly like today.

Sketch:

```dart
class _ProviderRow extends StatefulWidget {
  const _ProviderRow({
    required this.provider,
    required this.checked,
    required this.onChecked,
    required this.onModelChanged,
  });
  final ModelProvider provider;
  final bool checked;
  final ValueChanged<bool> onChecked;
  final ValueChanged<String> onModelChanged;

  @override
  State<_ProviderRow> createState() => _ProviderRowState();
}

class _ProviderRowState extends State<_ProviderRow> {
  Future<List<String>>? _modelsFuture;
  String _typed = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CheckboxListTile(
          title: Text(widget.provider.displayName),
          value: widget.checked,
          onChanged: (v) {
            widget.onChecked(v ?? false);
            _modelsFuture ??= widget.provider.listModels();
          },
        ),
        if (widget.checked)
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
            child: FutureBuilder<List<String>>(
              future: _modelsFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snap.hasError ||
                    snap.data == null ||
                    snap.data!.isEmpty) {
                  return TextField(
                    decoration: const InputDecoration(
                      labelText: 'Model id',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      _typed = v;
                      widget.onModelChanged(v);
                    },
                  );
                }
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    border: OutlineInputBorder(),
                  ),
                  items: snap.data!
                      .map((m) =>
                          DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) widget.onModelChanged(v);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
```

Hold the selection state in `_NewRunPageState`:

```dart
final Map<String, bool> _checked = {};
final Map<String, String> _models = {};
```

When the user taps Run, build the `StartRun` event. **Reuse the existing `RunBloc` construction logic unchanged** from the current `_NewRunPageState.onPressed` — it creates the `AppDatabase`, `RunDao`, `WorkdirManager`, and `RunBloc` with proper directories and ID generation. Only replace the old single-provider `bloc.add(...)` call with the multi-provider version:

```dart
// --- existing bloc setup (unchanged from Plan 1) ---
final settings = SettingsRepository();
final docs = await getApplicationSupportDirectory();
final root = Directory(p.join(docs.path, 'workdirs'))
  ..createSync(recursive: true);
final db = AppDatabase();
final bloc = RunBloc(
  workdirManager: WorkdirManager(root: root),
  runDao: RunDao(db),
  now: () => DateTime.now(),
  idGenerator: () => 'run-${DateTime.now().millisecondsSinceEpoch}',
);

// --- new: multi-provider selection ---
final selected = _providers.where((p) => _checked[p.id] == true).toList();
final modelMap = {
  for (final p in selected) p.id: _models[p.id] ?? '',
};
if (selected.isEmpty || modelMap.values.any((m) => m.trim().isEmpty)) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pick at least one provider + model')),
    );
  }
  return;
}
bloc.add(StartRun(
  tasks: [OffByOnePaginationTask()],
  providers: selected,
  modelByProvider: modelMap,
));
if (mounted) context.push('/run', extra: bloc);
```

- [ ] Implement (no widget test; covered by Task 14 manual smoke).
- [ ] `flutter analyze && flutter build linux --debug`
- [ ] Commit `feat(ui): multi-provider new-run page with model dropdowns`.

---

## Task 13: Re-run all unit tests; ensure nothing regressed

```bash
cd /home/dev/Development/Personal/dart_arena && flutter analyze && flutter test
```

All previous tests + new provider tests must pass. Commit nothing (no code change).

---

## Task 14: Manual end-to-end smoke

**Done criteria — gate on user confirmation, not assistant claim.**

- [ ] **Step 1:** `flutter run -d linux`
- [ ] **Step 2:** Settings → enter OpenCode Zen API key → Save.
- [ ] **Step 3:** Settings → enter Anthropic API key → Save (optional, for cross-provider check).
- [ ] **Step 4:** Home → New Run.
- [ ] **Step 5:** Verify the provider list now shows: Ollama Local, OpenCode Zen, Anthropic, Factory Droid (and any other configured ones).
- [ ] **Step 6:** Check OpenCode Zen → wait for dropdown → pick `qwen3.5-plus` (or whichever model is available on your Go plan).
- [ ] **Step 7:** Click Run.
- [ ] **Step 8:** RunProgress shows 0/1 → 1/1, lands on results.
- [ ] **Step 9:** Score row reads `opencode_zen / qwen3.5-plus / bug.off_by_one_pagination — score: …`.

If anything fails, debug and either fix in this plan or open a follow-up task.

---

## Verification gate (before marking plan complete)

- [ ] `flutter analyze` clean.
- [ ] `flutter test` — every test passes (Plan 1 baseline + ~7 new provider tests).
- [ ] `flutter build linux --debug` succeeds.
- [ ] User has confirmed the manual smoke at Task 14 against a real cloud provider.

---

## Out of scope reminder

- Plan 3: more tasks (the other 9 of the 10), more evaluators (Analyze/Test/WidgetTree/LlmJudge/DiffSize), shared judge model setting.
- Plan 4: run history list, leaderboard view, CSV export.
