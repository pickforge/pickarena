Fix `OfflineFeedPreferencesRepository` so a user's offline feed preferences actually survive an app restart.

Context: the offline feed screen lets users choose a sort order, a filter, and whether to show only
downloaded items. Those choices are stored through an injected `OfflineFeedPreferencesStore`, which
is a tiny async key/value abstraction over the device's persistent storage. On the next launch the
app builds a fresh `OfflineFeedPreferencesRepository` over the same store and calls `load()` to
restore the user's choices.

Right now the choices are lost: after restarting the app, the feed comes back with the default sort,
filter, and downloaded-only flag even though the user changed them. On top of that, some older beta
builds wrote preference values that this version no longer recognizes, and reading them must not
crash the screen.

Requirements:
- Preserve the public API exactly: `OfflineFeedSortOrder`, `OfflineFeedFilter`,
  `OfflineFeedPreferences` (with `sortOrder`, `filter`, `downloadedOnly`, `defaults`, `copyWith`,
  and value equality), `OfflineFeedPreferencesStore`, and `OfflineFeedPreferencesRepository`
  (including its `store` field and the `sortOrderKey`, `filterKey`, and `downloadedOnlyKey` static
  constants).
- `save(preferences)` must write every field through the injected store so the values persist.
- A brand-new repository constructed over the same store must `load()` back the values that were
  saved.
- Persist enum values using their `.name`, and persist booleans as the exact strings `"true"` and
  `"false"`.
- When a value is missing from the store, fall back to the matching default from
  `OfflineFeedPreferences.defaults`.
- When a stored value is unknown or malformed, `load()` must never throw. Default only the field that
  is bad and keep the valid sibling fields.

Keep the implementation deterministic and offline: do not add `shared_preferences`, file IO, platform
channels, timers, delays, network access, or any new dependency.
