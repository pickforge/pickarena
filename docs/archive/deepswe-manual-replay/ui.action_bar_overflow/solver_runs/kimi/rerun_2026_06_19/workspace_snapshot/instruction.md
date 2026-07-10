Fix `ResponsiveActionBar` so it stays usable on narrow phones and with larger text.

The widget currently lays every secondary action in one horizontal row. That works on
wide screens, but compact layouts can overflow or make lower-priority actions hard to
reach. Keep the primary CTA directly visible, and move lower-priority secondary actions
behind a deterministic overflow menu when there is not enough room.

Requirements:
- Preserve the public `ResponsiveActionBarAction` and `ResponsiveActionBar` APIs,
  including the static keys.
- The primary button must remain a direct, tappable `FilledButton` keyed by
  `ResponsiveActionBar.primaryButtonKey`.
- Wide layouts should keep all secondary actions inline and should not show an overflow
  button. They must not move actions into overflow solely because unconstrained label
  text is wide; direct action buttons may ellipsize labels within their own bounds on
  wide bars.
- Compact layouts should show the primary CTA plus a real "More actions" overflow
  control keyed by `ResponsiveActionBar.overflowButtonKey`.
- When overflow is present, the widget found by
  `ResponsiveActionBar.overflowButtonKey` must expose `overflowTooltip` as its
  accessible label and have a tap action.
- Overflow menu entries must use `ResponsiveActionBar.overflowItemKey(id)`, show the
  original label and icon, and call the original action callback exactly once.
- Lower `priority` values stay inline longer; ties keep the original input order.
- Do not render the same secondary action both inline and in the overflow menu.
- Honor ambient text scaling and keep the controls accessible by label and tap action.
- Keep the solution deterministic and offline: no timers, sleeps, network, platform
  channels, golden files, horizontal scrolling, clipping, or hardcoded public examples.
- There is no required pixel breakpoint or exact inline count; for any partial
  inline/overflow split, the inline set must keep lower-priority actions first, with
  equal priorities preserving input order, and all remaining actions must be reachable
  from overflow.
