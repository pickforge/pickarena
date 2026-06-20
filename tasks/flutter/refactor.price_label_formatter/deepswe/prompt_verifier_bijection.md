# Prompt/verifier bijection

## Classification

Restricted evaluator-only artifact. This file names hidden verifier cases and must not be provided to solvers.

## Status

Bijection evidence is current for the refactor price-label DeepSWE slice. Three fresh solver families pass clean replay; one public-passing Kimi solver fails hidden replay and is retained as failed-solver evidence. Full DeepSWE completion remains pending on provider-internal stream chunks, clean committed provenance, authored-by provenance, and stronger workspace isolation proof.

## Sources

- `instruction.md`
- `baseline/test/price_labels_test.dart`
- source hidden verifier: `hidden_tests/test/_hidden/price_label_formatter_hidden_test.dart`
- grading injection path: `test/_hidden/price_label_formatter_hidden_test.dart`
- `qa/admission_report.json`
- `qa/v1plus_report.md`
- `replay_manifest.json`
- `flake_report.json`

## Requirement to verifier mapping

| Requirement | Public coverage | Hidden coverage | Evidence status |
| --- | --- | --- | --- |
| Preserve public APIs for formatter and three widgets. | Public widget tests compile and use constructors/keys. | Hidden routing tests instantiate all widgets with injected formatter. | API-breaking negative rejected; passing solvers preserve API. |
| Route every customer-facing price through injected `formatter`. | Public tests cover visible default labels. | Hidden routing/injected-formatter cases cover product, cart, and checkout. | Covered; Kimi failure shows public tests alone are insufficient. |
| Cart line total is `quantity * unitPriceCents`. | Public cart row test covers quantity/unit/line total. | Hidden cart routing case verifies line total routing through formatter. | Covered. |
| `formatCents` renders Free for zero. | Public product zero-price test. | Hidden zero case. | Covered. |
| Whole dollars omit `.00`; non-whole amounts keep two digits. | Public default labels exercise representative cases. | Hidden cent/sub-dollar/whole/non-whole cases. | Covered. |
| Thousands are grouped with commas. | Public labels include common small values. | Hidden large whole/non-whole cases. | Covered. |
| `formatSaleLabel` shows compare-at only when strictly greater. | Public sale test covers higher compare-at. | Hidden higher/equal/lower/null/free sale cases. | Covered. |
| Integer arithmetic only; no intl/locale/double. | Not directly public-covered. | Hidden behavior catches common rounding/formatting regressions; no static dependency gate here. | Partial; static dependency scan not yet formalized. |

## Hidden assertion back-mapping

- `single cent keeps two decimal digits`
- `sub-dollar amount keeps two decimal digits`
- `whole dollars omit the decimal part`
- `non-whole amount above ten keeps two decimal digits`
- `large non-whole amount groups thousands with commas`
- `large whole amount groups thousands and omits decimals`
- `zero renders as Free`
- `higher compare-at adds a was suffix`
- `equal compare-at returns the current price only`
- `lower compare-at returns the current price only`
- `null compare-at returns the current price only`
- `free price with higher compare-at adds a was suffix`
- `regular price routes through the formatter`
- `sale price routes through the formatter`
- `equal compare-at shows the current price only`
- `unit price and line total route through the formatter`
- `summary lines route through the formatter`
- `product tile uses the injected formatter`
- `cart line row uses the injected formatter`
- `checkout summary uses the injected formatter`


## Evidence pointers

- Clean replay: `replay_manifest.json`
- Three passing fresh solver reruns: `solver_runs/{gpt,minimax,glm}/rerun_2026_06_19/`
- Failed public-only solver: `solver_runs/kimi/rerun_2026_06_19/`
- 10-run hidden flake loop: `flake_runs_10/flake_loop_10_result.json`
- Solver-facing leakage scan: `leakage_scan_result.json`

## Known coverage nuances

- No formal static check currently rejects `double`/`intl` use; behavior and dependency constraints are validated through tests and patch review evidence.
- Original authored-by provenance is not durably known.
- Provider-internal stream chunks/session JSONL were not exposed for this run.
