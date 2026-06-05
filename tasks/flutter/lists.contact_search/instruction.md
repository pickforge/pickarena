Fix `ContactSearchController` so contact search behaves predictably for a UI list.

Requirements:
- Preserve the public `Contact` and `ContactSearchController.filter` APIs.
- Blank or whitespace-only queries must return all contacts sorted by display name.
- Nonblank queries must be trimmed and matched case-insensitively.
- Search must match either contact names or email addresses.
- Returned contacts must be sorted by display name without mutating the input list.
