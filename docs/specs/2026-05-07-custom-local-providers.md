# Spec: Custom Local OpenAI-compatible Providers

## Goal
Replace the single fixed `local_openai` provider with a user-managed list of
local OpenAI-compatible providers (Codex via cli-proxy-api, Qwen via
llama.cpp, etc.). Each entry has its own URL, API key, optional extra headers,
and optional reasoning efforts. Add / edit / delete via Settings.

The runtime side already supports this — `OpenAiCompatibleProvider` accepts
`id`, `displayName`, `baseUrl`, `apiKey`, `extraHeaders`, `defaultEfforts`.
We only need a list-based config layer + UI on top.

## Files touched

- `lib/storage/settings.dart` — add custom-providers index + helpers
- `lib/providers/provider_factory.dart` — replace fixed `local_openai` block
  with a loop
- `lib/ui/pages/settings_page.dart` — replace `_LocalOpenAiSection` with
  `_CustomLocalProvidersSection` (+ add/edit dialog), update `_JudgeSection`
  to merge dynamic IDs
- `lib/ui/pages/new_run_page.dart` — keep the existing null-safe judge fallback
  when a saved judge id no longer exists
- `test/storage/settings_test.dart` (extend existing) — round-trip +
  migration unit tests
- `test/providers/provider_factory_test.dart` (extend existing) — factory
  builds N providers from list and no longer assumes `local_openai` is always
  enabled
- `test/ui/pages/settings_page_custom_providers_test.dart` (new)
  — save/cancel and judge-dropdown wiring smoke tests

No DB schema changes. Everything stays in `flutter_secure_storage`.

## 1. Storage layer (`SettingsRepository`)

Decision A2: index list + reuse existing per-id keys (`api_key:<id>`,
`base_url:<id>`).

Add:

```dart
static const _customLocalProvidersKey = 'custom_local_providers';

class CustomLocalProviderEntry {
  const CustomLocalProviderEntry({
    required this.id,
    required this.name,
    this.extraHeaders = const {},
    this.defaultEfforts = const [],
  });
  final String id;
  final String name;
  final Map<String, String> extraHeaders;
  final List<String> defaultEfforts;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (extraHeaders.isNotEmpty) 'headers': extraHeaders,
        if (defaultEfforts.isNotEmpty) 'efforts': defaultEfforts,
      };

  factory CustomLocalProviderEntry.fromJson(Map<String, dynamic> j) {
    final headers = <String, String>{};
    final rawHeaders = j['headers'];
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        if (entry.key is String && entry.value is String) {
          headers[entry.key as String] = entry.value as String;
        }
      }
    }
    final efforts = <String>[
      for (final effort in (j['efforts'] as List? ?? const <dynamic>[]))
        if (effort is String) effort,
    ];
    return CustomLocalProviderEntry(
      id: j['id'] as String,
      name: j['name'] as String,
      extraHeaders: headers,
      defaultEfforts: efforts,
    );
  }
}

const customLocalProviderReservedIds = <String>{
  'ollama_local',
  'ollama_cloud',
  'opencode_go',
  'opencode_zen',
  'openai',
  'openrouter',
  'deepseek',
  'anthropic',
  'droid',
};
final customLocalProviderIdPattern = RegExp(r'^[a-z0-9_]{2,32}$');
String? validateCustomLocalProviderId(
  String id, {
  required Iterable<String> existingIds,
  String? currentId,
});
String? validateCustomLocalProviderEntry(
  CustomLocalProviderEntry entry, {
  required Iterable<String> existingIds,
});
Future<List<CustomLocalProviderEntry>> getCustomLocalProviders();
Future<void> setCustomLocalProviders(List<CustomLocalProviderEntry> entries);
Future<void> deleteCustomLocalProvider(String id);
// ^ also clears api_key:<id> and base_url:<id>
```

ID validation: `^[a-z0-9_]{2,32}$`. Reserved IDs that must be rejected for new
entries: `ollama_local`, `ollama_cloud`, `opencode_go`, `opencode_zen`,
`openai`, `openrouter`, `deepseek`, `anthropic`, `droid`. The legacy
`local_openai` ID is allowed (it is the migrated entry).

Add a pure validation helper used by storage and UI. It must trim UI input
before validation, reject duplicate IDs in the submitted list, reject empty
names after trim, and parse JSON defensively: ignore malformed header/effort
items instead of throwing from `fromJson`.

`setCustomLocalProviders` writes only the index JSON after validating the full
list. It must not delete credentials or base URLs for IDs omitted from the
submitted list; only `deleteCustomLocalProvider` performs secret cleanup. This
keeps edit/reorder saves from accidentally deleting secrets if a caller works
from stale state.

### Migration (run on first call to `getCustomLocalProviders`)

```dart
final raw = await _storage.read(key: _customLocalProvidersKey);
if (raw == null) {
  final legacyUrl = await getBaseUrlOverride('local_openai');
  final legacyKey = await getApiKey('local_openai');
  final trimmedUrl = legacyUrl?.trim() ?? '';
  final trimmedKey = legacyKey?.trim() ?? '';
  if (trimmedUrl.isNotEmpty || trimmedKey.isNotEmpty) {
    if (trimmedUrl.isEmpty) {
      await setBaseUrlOverride('local_openai', 'http://127.0.0.1:8080/v1');
    } else if (trimmedUrl != legacyUrl) {
      await setBaseUrlOverride('local_openai', trimmedUrl);
    }
    final seed = [
      const CustomLocalProviderEntry(id: 'local_openai', name: 'Local OpenAI'),
    ];
    await setCustomLocalProviders(seed);
    return seed;
  }
  return const [];
}
try {
  return (jsonDecode(raw) as List)
      .whereType<Map>()
      .map((e) => CustomLocalProviderEntry.fromJson(e.cast<String, dynamic>()))
      .toList();
} on Object {
  return const [];
}
```

Important migration edge cases:
- Do not seed an entry for a legacy URL that is present but only whitespace.
- If only a legacy API key exists, seed `local_openai` and write the previous
  default base URL so the migrated provider remains usable.
- If the index key exists but contains invalid JSON, do not run legacy
  migration; return an empty list and leave the raw value untouched.

## 2. Provider factory

Replace the fixed `local_openai` block in `buildEnabledProviders` with:

```dart
final customs = await repo.getCustomLocalProviders();
for (final c in customs) {
  final url = (await repo.getBaseUrlOverride(c.id))?.trim();
  if (url == null || url.isEmpty) continue; // skip unconfigured
  providers.add(OpenAiCompatibleProvider(
    null,
    id: c.id,
    displayName: c.name,
    baseUrl: url,
    apiKey: await repo.getApiKey(c.id) ?? '',
    extraHeaders: c.extraHeaders,
    defaultEfforts: c.defaultEfforts,
  ));
}
```

## 3. Settings UI

### `_CustomLocalProvidersSection`
- Header "Local OpenAI-compatible providers" + helper text.
- `FutureBuilder` wraps a list of `Card` widgets, one per entry, showing
  display name, base URL preview, key-set badge, and trailing Edit / Delete
  icons.
- "Add provider" `OutlinedButton.icon` at the bottom.
- Add and Edit both open `_LocalProviderDialog` via `showDialog`.
- Keep a `_load()` method in the section. After add/edit/delete returns
  `true`, reload from storage and notify the parent `SettingsPage` so
  `_JudgeSection` refreshes its dynamic provider list.

### `_LocalProviderDialog` form fields
- Display name (required)
- ID (required; disabled in edit mode; live-validate slug + uniqueness +
  reserved-id check)
- Base URL (required, default `http://127.0.0.1:8080/v1`)
- API key (optional, obscured, eye toggle)
- Extra headers — list of `key: value` rows with add/remove
- Default efforts — comma-separated text field (e.g. `low,medium,high`)
- "Test connection" button — constructs a temp `OpenAiCompatibleProvider` and
  calls `listModels()`, snackbars `OK (N models)` or the error message
- Save / Cancel

Dialog semantics:
- Cancel closes without writing anything.
- Test connection uses the unsaved, trimmed form values and writes nothing.
- Save reads the latest provider list from storage at submit time, then either
  appends the new ID or replaces the existing ID in place. This prevents a
  stale dialog from overwriting entries added elsewhere while it was open.
- Add mode must reject IDs already present in that latest list. Edit mode keeps
  the ID immutable.
- Base URL, display name, API key, header keys/values, and efforts are trimmed
  before persistence. A blank API key clears `api_key:<id>`.
- Extra header rows with both fields blank are ignored; rows with a blank key
  or blank value after trimming are validation errors. Persist headers in input
  order as a `Map<String, String>`, with duplicate keys rejected.
- Default efforts are parsed by comma, trimmed, empty entries removed, and
  duplicate efforts deduplicated while preserving first occurrence order.

### Delete flow
Confirm `AlertDialog` → `repo.deleteCustomLocalProvider(id)` → reload list.
`deleteCustomLocalProvider` should be idempotent: remove the ID from the latest
index if present, then clear `api_key:<id>` and `base_url:<id>` even if the
entry was already absent.

### `_JudgeSection`
After loading, merge the static `_knownProviders` with
`customs.map((c) => c.id)` (dedup, preserve order). Keep the existing UI; just
feed a longer list into the dropdown.
When the saved provider ID is not in that merged list, set the dropdown state
to `null` so pressing "Save judge" does not persist a stale deleted custom ID.
The settings page should refresh this section after custom-provider add/delete.

### Robustness
In `lib/ui/pages/new_run_page.dart`, preserve the current null-safe fallback:
if the saved `judgeProviderId` is not present in the loaded provider list,
treat judge as disabled rather than crashing.

## 4. Tests

`test/storage/settings_test.dart` (extend the existing file)
- round-trip: `setCustomLocalProviders` → `getCustomLocalProviders`
- migration: seed `local_openai` when only legacy keys exist, no-op when
  legacy keys absent
- migration: do not seed when legacy URL is an empty/whitespace string and no
  key exists
- migration: when only a legacy key exists, seed `local_openai` and write the
  default base URL
- malformed index JSON returns an empty list instead of throwing
- `deleteCustomLocalProvider` clears `api_key:<id>` + `base_url:<id>` + index
  entry
- `setCustomLocalProviders` removing an entry from the index does not clear
  that entry's api/base-url secrets
- ID validation rejects reserved/invalid slugs (this is a pure helper —
  test the helper directly), duplicate IDs, and blank display names

`test/providers/provider_factory_test.dart` (update existing assumptions)
- two entries with URLs set → factory yields two `OpenAiCompatibleProvider`s
  with matching ids/displayNames in order
- entries without URL, or with whitespace-only URL, are skipped
- `local_openai` is no longer always enabled when no custom-provider index or
  legacy settings exist; update existing tests that assert it is always present

`test/ui/pages/settings_page_custom_providers_test.dart`
- Add dialog Cancel writes nothing.
- Add dialog Save trims fields, persists headers/efforts, and refreshes the
  judge-provider dropdown with the new ID.
- Delete clears the entry and the judge dropdown no longer offers that ID.

Use the existing `FlutterSecureStorage.setMockInitialValues({})` pattern in
tests; do not introduce a new storage fake.

## 5. Verification (the coder must run all of these)

- `fvm flutter analyze`
- `fvm flutter test`
- Build the app once (`fvm flutter build linux --debug` is sufficient on this
  host) to confirm UI compiles.

Manual smoke (the coder describes this in the final report; no need to
actually launch unless trivial):
1. Settings shows migrated `Local OpenAI` entry.
2. Add a Codex entry (`http://127.0.0.1:<codex_port>/v1`, key, header).
3. Add a Qwen entry (`http://127.0.0.1:<qwen_port>/v1`, no key).
4. New-run page lists both with their models.
5. Delete one → disappears from new-run.
6. Saved judge pointing at deleted provider → app still loads.

## Out of scope
- Editing built-in providers (OpenAI / Anthropic / etc.) through the same UI.
- Per-entry model allow-lists or rate-limits.
- Cleaning up orphan `provider_id`s in `run_summaries`.
