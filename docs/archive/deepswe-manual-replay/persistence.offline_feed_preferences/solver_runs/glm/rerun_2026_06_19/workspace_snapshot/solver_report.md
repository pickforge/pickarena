# Solver Report — persistence.offline_feed_preferences

## Root cause
`OfflineFeedPreferencesRepository.save()` only stored preferences in an in-memory `_cached`
field and never wrote anything through the injected `OfflineFeedPreferencesStore`. As a result, a
brand-new repository constructed over the same store on the next app launch read an empty store and
fell back to the defaults, losing the user's choices.

## Fix (lib/offline_feed_preferences.dart)
`save()` now writes every field through the store before updating the cache:
- `sortOrderKey` ← `preferences.sortOrder.name`
- `filterKey` ← `preferences.filter.name`
- `downloadedOnlyKey` ← `"true"` / `"false"`

Enum values are persisted via `.name` and the boolean is persisted as the exact strings
`"true"` / `"false"`, matching the existing `load()` parsing (`_parseEnum` / `_parseBool`).

## Existing behavior preserved
- Public API unchanged (enums, `OfflineFeedPreferences` value object with `defaults`,
  `copyWith`, value equality, `store` field, `sortOrderKey`/`filterKey`/`downloadedOnlyKey`
  constants, `OfflineFeedPreferencesStore`).
- `load()` still never throws on unknown/malformed/missing values: it defaults only the bad field
  via the existing `_parseEnum`/`_parseBool` fallbacks and keeps valid siblings.
- Missing values still fall back to `OfflineFeedPreferences.defaults`.
- `_cached` keeps in-repository `load()` after `save()` returning the latest without re-reading.

## Commands run
- `flutter pub get`
- `flutter test test/offline_feed_preferences_test.dart` → 4/4 passed