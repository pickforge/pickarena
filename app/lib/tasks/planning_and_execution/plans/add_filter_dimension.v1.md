# Plan — Add `category` Filter Dimension

## Files to create

1. `lib/category_filter.dart` — single output file.

## Implementation steps

1. Import `Filter` and `Item` from `lib/filter.dart`.
2. Define `class CategoryFilter implements Filter`.
3. Constructor: `CategoryFilter({required this.category})`. Field: `final String category`.
4. Implement `bool matches(Item item)`:
   - If `category` is empty (length 0), return `true` (acts as a pass-through).
   - Otherwise return `item.category == category`.

## Tests to satisfy

`test/category_filter_test.dart` (already provided) asserts:

- `CategoryFilter` is a `Filter`.
- `matches` returns `true` for matching categories, `false` for non-matching.
- Empty `category` filter matches every item.

## Output format

Return ONLY the contents of `lib/category_filter.dart` inside a single fenced Dart code block. Do not include any other files.
