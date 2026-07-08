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

  /// Nominal per-control widths (in dp at text scale 1.0). These are layout
  /// budgets only; they intentionally do not depend on measuring label text, so
  /// a wide bar never moves an action to overflow merely because its label is
  /// long. Inline action labels may ellipsize within their allotted slot.
  static const double _actionSlotWidth = 150.0;
  static const double _primaryWidth = 130.0;
  static const double _overflowWidth = 56.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = _textScaleOf(context);
        final split = _splitActions(constraints.maxWidth, textScale);

        final children = <Widget>[];
        for (final action in split.inline) {
          children.add(
            SizedBox(
              width: _actionSlotWidth * textScale,
              child: _ActionButton(action: action),
            ),
          );
        }
        if (split.overflow.isNotEmpty) {
          children.add(
            _OverflowMenu(actions: split.overflow, tooltip: overflowTooltip),
          );
        }
        children.add(const Spacer());
        children.add(
          SizedBox(
            width: _primaryWidth * textScale,
            child: FilledButton(
              key: primaryButtonKey,
              onPressed: onPrimaryPressed,
              child: Text(
                primaryLabel,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        );

        return Row(children: children);
      },
    );
  }

  /// Splits the actions into inline + overflow sets.
  ///
  /// Actions are first stably ordered by ascending [ResponsiveActionBarAction
  /// .priority] (ties preserve original input order). Then the largest prefix
  /// that fits within [maxWidth] alongside the primary CTA (and the overflow
  /// control, when any actions remain) is kept inline; the rest go to overflow.
  _ActionSplit _splitActions(double maxWidth, double textScale) {
    if (actions.isEmpty) {
      return const _ActionSplit(<ResponsiveActionBarAction>[], []);
    }

    final ordered = _stableByPriority(actions);
    final slot = _actionSlotWidth * textScale;
    final primary = _primaryWidth * textScale;
    final overflow = _overflowWidth * textScale;
    final n = ordered.length;

    // Pick the largest inline count that fits. When all actions fit, no
    // overflow control is needed. This naturally handles infinite widths
    // (everything stays inline) and yields progressive partial splits.
    var inlineCount = 0;
    for (var candidate = n; candidate >= 1; candidate--) {
      final needed =
          candidate * slot + primary + (candidate < n ? overflow : 0.0);
      if (needed <= maxWidth) {
        inlineCount = candidate;
        break;
      }
    }

    return _ActionSplit(
      ordered.sublist(0, inlineCount),
      ordered.sublist(inlineCount),
    );
  }

  /// Stable ordering by ascending priority, preserving input order on ties.
  static List<ResponsiveActionBarAction> _stableByPriority(
    List<ResponsiveActionBarAction> source,
  ) {
    final indexed = <_IndexedAction>[];
    for (var i = 0; i < source.length; i++) {
      indexed.add(_IndexedAction(i, source[i]));
    }
    indexed.sort((a, b) {
      final byPriority = a.action.priority.compareTo(b.action.priority);
      if (byPriority != 0) return byPriority;
      return a.index.compareTo(b.index);
    });
    return [for (final entry in indexed) entry.action];
  }

  static double _textScaleOf(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // Approximate the linear factor; for the default scaler this is 1.0.
    return scaler.scale(100.0) / 100.0;
  }
}

class _IndexedAction {
  const _IndexedAction(this.index, this.action);

  final int index;
  final ResponsiveActionBarAction action;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final ResponsiveActionBarAction action;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: ResponsiveActionBar.actionButtonKey(action.id),
      onPressed: action.onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(action.icon),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              action.label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
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