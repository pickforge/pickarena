Fix `SelectionController` so it supports stable multi-selection state for a list UI.

Requirements:
- Preserve the public `SelectionController` API.
- `toggle(id)` must add an unselected id and remove an already selected id.
- Multiple ids may be selected at the same time.
- Blank or whitespace-only ids must be ignored.
- `selectedIds` must return a sorted snapshot so callers cannot mutate internal state.
- `clear()` must remove every selected id.
