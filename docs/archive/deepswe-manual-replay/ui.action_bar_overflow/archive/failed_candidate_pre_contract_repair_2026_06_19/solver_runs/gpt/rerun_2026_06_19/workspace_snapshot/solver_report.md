Changed behavior:
- Secondary actions are now ordered by priority (stable for ties) and split between inline buttons and an overflow menu based on available width and text scale.
- The primary FilledButton remains directly visible, wide layouts keep all actions inline, and compact layouts expose secondary actions through the keyed More actions menu.

Commands run:
- `flutter pub get`
- `flutter test test/responsive_action_bar_test.dart`
