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

  /// Decides which actions stay inline and which move behind the overflow menu.
  ///
  /// Actions are ordered by ascending [ResponsiveActionBarAction.priority]
  /// (lower stays inline longer), with ties preserving the original input
  /// order. The inline set is always a prefix of that order, so lower-priority
  /// actions are kept first and everything else remains reachable from overflow.
  _ActionSplit _splitActions(BuildContext context, double maxWidth) {
    final ordered = _orderedByPriority();
    if (ordered.isEmpty || !maxWidth.isFinite) {
      return _ActionSplit(ordered, const <ResponsiveActionBarAction>[]);
    }

    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final labelStyle =
        theme.textTheme.labelLarge ?? const TextStyle(fontSize: 14);

    double measureText(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
      )..layout();
      return painter.width;
    }

    // Chrome estimates (icon + internal padding) around the measured label.
    const double actionChrome = 54;
    const double primaryChrome = 48;
    const double overflowWidth = 48;
    const double gap = 8;

    final primaryWidth = measureText(primaryLabel) + primaryChrome;
    final actionWidths = <double>[
      for (final action in ordered) measureText(action.label) + actionChrome,
    ];

    // Budget left of the primary CTA (the Spacer can collapse to zero).
    final budget = maxWidth - primaryWidth - gap;

    // Everything fits inline with no overflow control.
    double allInline = 0;
    for (final width in actionWidths) {
      allInline += width + gap;
    }
    if (allInline <= budget) {
      return _ActionSplit(ordered, const <ResponsiveActionBarAction>[]);
    }

    // Otherwise reserve room for the overflow control and greedily keep the
    // longest prefix of ordered actions that still fits.
    final inlineBudget = budget - overflowWidth - gap;
    final inline = <ResponsiveActionBarAction>[];
    final overflow = <ResponsiveActionBarAction>[];
    double used = 0;
    var overflowing = false;
    for (var i = 0; i < ordered.length; i++) {
      final next = used + actionWidths[i] + gap;
      if (!overflowing && next <= inlineBudget) {
        used = next;
        inline.add(ordered[i]);
      } else {
        overflowing = true;
        overflow.add(ordered[i]);
      }
    }

    return _ActionSplit(inline, overflow);
  }

  List<ResponsiveActionBarAction> _orderedByPriority() {
    final indexed = <MapEntry<int, ResponsiveActionBarAction>>[
      for (var i = 0; i < actions.length; i++) MapEntry(i, actions[i]),
    ];
    indexed.sort((a, b) {
      final byPriority = a.value.priority.compareTo(b.value.priority);
      if (byPriority != 0) return byPriority;
      return a.key.compareTo(b.key);
    });
    return <ResponsiveActionBarAction>[for (final e in indexed) e.value];
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
