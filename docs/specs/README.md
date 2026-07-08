# PickArena specs

Start here when working on the active mobile benchmark plan. The full spec is longer by design; use this page to choose the next layer of detail.

## Read in this order

1. [PickArena Mobile Agent Benchmark](2026-06-15-pickarena-mobile-agent-benchmark.md) — active source of truth for MVP, V1, and V2.
2. [Task overview](../../tasks/README.md) — current official tasks and QA commands.
3. [Task authoring reference](../../tasks/AUTHORING.md) — bundle shape, prompt rules, admission gates, and verifier notes.
4. [Bubblewrap Public-Run Sandbox Contract](2026-06-05-bubblewrap-public-run-sandbox.md) — release sandbox and provenance constraints.
5. [Archived PickArena master spec](old/2026-05-31-pickarena-by-pickforge-studio-master.md) — historical context only.

## Working through the roadmap

- **MVP:** keep the official Flutter corpus reproducible. Use admitted `tasks/flutter` bundles, run task QA, preserve hidden verifier separation, and tie public claims to Bubblewrap-backed release evidence.
- **V1:** broaden Flutter coverage after MVP is stable: UI, navigation, state, platform, refactoring, accessibility, flake, f2p, and p2p evidence.
- **V2:** add DeepSWE-grade replay and cross-framework tracks: React Native Android, native Android, native iOS, security tasks, cost/token/error reporting, and clean verifier environments.

## Research anchors

- DeepSWE — benchmark rigor: clean grading, patch replay, hidden separation, f2p/p2p, flake, provenance, and public result evidence.
- BridgeBench — category breadth: UI, debugging, refactoring, reasoning, security, speed, and fake-fix resistance.
- [Flutter testing](https://docs.flutter.dev/testing/overview) / [accessibility](https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility) — Flutter verifier patterns.
- [React Native testing](https://reactnative.dev/docs/testing-overview) / [React Native DevTools](https://reactnative.dev/docs/react-native-devtools) / [Metro](https://metrobundler.dev/docs/configuration) — React Native Android verifier tooling.
- [Android UIAutomator](https://developer.android.com/training/testing/other-components/ui-automator), [ADB](https://developer.android.com/tools/adb), [logcat](https://developer.android.com/tools/logcat) — native Android verification.
- [iOS XCTest](https://developer.apple.com/documentation/xctest), `xcodebuild`, `simctl`, [accessibility](https://developer.apple.com/accessibility/) — native iOS verification.
- [OWASP MASVS](https://mas.owasp.org/MASVS/) — mobile security task taxonomy and checks.
