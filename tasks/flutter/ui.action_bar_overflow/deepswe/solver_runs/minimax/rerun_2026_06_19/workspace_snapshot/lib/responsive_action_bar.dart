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

  static const double _kButtonGap = 8.0;
  static const double _kIconLabelGap = 8.0;
  static const double _kIconSize = 24.0;
  static const double _kButtonHorizontalPadding = 12.0;
  static const double _kMaxActionLabelWidth = 120.0;
  static const double _kMaxPrimaryLabelWidth = 96.0;

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

  _ActionSplit _splitActions(BuildContext context, double maxWidth) {
    if (actions.isEmpty) {
      return const _ActionSplit([], []);
    }

    final order = List<int>.generate(actions.length, (i) => i);
    order.sort((a, b) {
      final c = actions[a].priority.compareTo(actions[b].priority);
      if (c != 0) return c;
      return a.compareTo(b);
    });
    final sorted = <ResponsiveActionBarAction>[
      for (final i in order) actions[i],
    ];

    if (maxWidth.isInfinite) {
      return _ActionSplit(sorted, const <ResponsiveActionBarAction>[]);
    }

    final primaryWidth = _measurePrimaryWidth(context, primaryLabel);
    var actionTotal = 0.0;
    for (final action in sorted) {
      actionTotal += _measureActionWidth(context, action);
    }
    final n = sorted.length;
    final total = primaryWidth + actionTotal + (n + 1) * _kButtonGap;

    if (total <= maxWidth) {
      return _ActionSplit(sorted, const <ResponsiveActionBarAction>[]);
    }
    return _ActionSplit(const <ResponsiveActionBarAction>[], sorted);
  }

  double _measurePrimaryWidth(BuildContext context, String label) {
    return _measureText(context, label, maxWidth: _kMaxPrimaryLabelWidth) +
        _kButtonHorizontalPadding * 2;
  }

  double _measureActionWidth(
      BuildContext context, ResponsiveActionBarAction action) {
    final measured = _measureText(context, action.label,
        maxWidth: _kMaxActionLabelWidth);
    return measured +
        _kButtonHorizontalPadding * 2 +
        _kIconSize +
        _kIconLabelGap;
  }

  double _measureText(BuildContext context, String text,
      {double? maxWidth}) {
    final scaler = MediaQuery.textScalerOf(context);
    final theme = Theme.of(context);
    final base = theme.textTheme.labelLarge;
    final style = base ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
      ellipsis: '…',
    );
    painter.layout(maxWidth: maxWidth ?? double.infinity);
    return painter.size.width;
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
          excludeSemantics: true,
          label: tooltip,
          button: true,
          onTap: toggleMenu,
          child: IconButton(
            key: ResponsiveActionBar.overflowButtonKey,
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
