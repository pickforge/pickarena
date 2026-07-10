Changed
- Updated `lib/feed_refresh_controller.dart` for deduped `refresh()`, forced latest-wins refreshes, stale result suppression, retry gating, and accurate multi-load `isLoading`.
- Wrote `solver_report.md`.

Validated
- `flutter test test/feed_refresh_controller_test.dart` passed.

Risks/uncertainties
- None known.

Next action
- None.