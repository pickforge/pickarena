import 'package:flutter/material.dart';

class ResponsiveActionBarAction {
  const ResponsiveActionBarAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.priority = 0,
  });

  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  /// Lower numbers stay visible longer. Ties keep original input order.
  final int priority;
}

class ResponsiveActionBar extends StatelessWidget {
  const ResponsiveActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    required this.actions,
    this.overflowTooltip = 'More actions',
  });

  static const Key primaryButtonKey = Key('responsive_action_bar_primary');
  static const Key overflowButtonKey = Key('responsive_action_bar_overflow');
  static Key actionButtonKey(String id) =>
      Key('responsive_action_bar_action_$id');
  static Key overflowItemKey(String id) =>
      Key('responsive_action_bar_overflow_item_$id');

  final String primaryLabel;
  final VoidCallback onPrimaryPressed;
  final List<ResponsiveActionBarAction> actions;
  final String overflowTooltip;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = _splitActions(context, constraints.maxWidth);
        return Row(
          children: <Widget>[
            for (final action in split.inline)
              Flexible(child: _ActionButton(action: action)),
            if (split.overflow.isNotEmpty)
              _OverflowMenu(actions: split.overflow, tooltip: overflowTooltip),
            const Spacer(),
            Flexible(
              child: FilledButton(
                key: primaryButtonKey,
                onPressed: onPrimaryPressed,
                child: Text(primaryLabel, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        );
      },
    );
  }

  _ActionSplit _splitActions(BuildContext context, double max) {
    final scaler = MediaQuery.textScalerOf(context);
    num w(String text) =>
        24 +
        TextPainter.computeWidth(
          text: TextSpan(text: text),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        ).clamp(0, scaler.scale(96));
    int p((int, ResponsiveActionBarAction) e) => e.$2.priority;
    final ranked = actions.indexed.toList()
      ..sort((a, b) => p(a) == p(b) ? a.$1 - b.$1 : p(a) - p(b));
    var count = ranked.length;
    for (; count > 0; count--) {
      final width = (max - (count < ranked.length ? 48 : 0)) / (count + 2);
      final fits = ranked.take(count).every((e) => width >= w(e.$2.label));
      if (width >= w(primaryLabel) && fits) break;
    }
    final shown = ranked.take(count).map((e) => e.$2).toList();
    return _ActionSplit(shown, ranked.skip(count).map((e) => e.$2).toList());
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final ResponsiveActionBarAction action;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: ResponsiveActionBar.actionButtonKey(action.id),
      onPressed: action.onPressed,
      icon: Icon(action.icon),
      label: Text(action.label, overflow: TextOverflow.ellipsis),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.actions, required this.tooltip});

  final List<ResponsiveActionBarAction> actions;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: <Widget>[
        for (final action in actions)
          MenuItemButton(
            key: ResponsiveActionBar.overflowItemKey(action.id),
            leadingIcon: Icon(action.icon),
            onPressed: action.onPressed,
            child: Text(action.label),
          ),
      ],
      builder: (context, controller, child) {
        void toggleMenu() {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        }

        return Semantics(
          key: ResponsiveActionBar.overflowButtonKey,
          label: tooltip,
          button: true,
          onTap: toggleMenu,
          child: IconButton(
            tooltip: tooltip,
            icon: const Icon(Icons.more_horiz),
            onPressed: toggleMenu,
          ),
        );
      },
    );
  }
}

class _ActionSplit {
  const _ActionSplit(this.inline, this.overflow);

  final List<ResponsiveActionBarAction> inline;
  final List<ResponsiveActionBarAction> overflow;
}
