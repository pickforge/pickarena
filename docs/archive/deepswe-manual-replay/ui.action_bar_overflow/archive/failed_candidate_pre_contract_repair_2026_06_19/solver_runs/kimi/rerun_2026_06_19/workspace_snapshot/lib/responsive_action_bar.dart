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
          spacing: _inlineSpacing,
          children: <Widget>[
            for (final action in split.inline) _ActionButton(action: action),
            if (split.overflow.isNotEmpty)
              _OverflowMenu(actions: split.overflow, tooltip: overflowTooltip),
            const Spacer(),
            FilledButton(
              key: primaryButtonKey,
              onPressed: onPrimaryPressed,
              child: Text(primaryLabel, overflow: TextOverflow.ellipsis),
            ),
          ],
        );
      },
    );
  }

  _ActionSplit _splitActions(BuildContext context, double maxWidth) {
    if (actions.isEmpty) {
      return _ActionSplit(const <ResponsiveActionBarAction>[], const <ResponsiveActionBarAction>[]);
    }

    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final labelStyle = theme.textTheme.labelLarge ?? theme.textTheme.bodyLarge;

    final primaryWidth = _measureText(
          text: primaryLabel,
          style: labelStyle,
          textScaler: textScaler,
          textDirection: textDirection,
        ) +
        _primaryHorizontalPadding;

    final actionWidths = <double>[];
    for (final action in actions) {
      actionWidths.add(
        _measureText(
              text: action.label,
              style: labelStyle,
              textScaler: textScaler,
              textDirection: textDirection,
            ) +
            _actionHorizontalOverhead,
      );
    }

    final sortedIndices = List<int>.generate(actions.length, (i) => i);
    sortedIndices.sort((a, b) {
      final priorityCompare = actions[a].priority.compareTo(actions[b].priority);
      if (priorityCompare != 0) return priorityCompare;
      return a.compareTo(b);
    });

    final totalInlineWidth = actionWidths.fold<double>(0, (sum, w) => sum + w);

    // Can every action stay inline without needing an overflow button?
    if (totalInlineWidth + primaryWidth + (actions.length + 1) * _inlineSpacing <=
        maxWidth) {
      return _ActionSplit(actions.toList(), const <ResponsiveActionBarAction>[]);
    }

    // Otherwise keep the lowest-priority actions inline that still leave room
    // for the overflow button.
    var inlineCount = 0;
    double usedWidth = 0;
    for (var i = 0; i < sortedIndices.length; i++) {
      final projectedWidth = usedWidth + actionWidths[sortedIndices[i]];
      final projectedTotal = projectedWidth +
          primaryWidth +
          _overflowButtonWidth +
          (i + 3) * _inlineSpacing;
      if (projectedTotal <= maxWidth) {
        inlineCount = i + 1;
        usedWidth = projectedWidth;
      } else {
        break;
      }
    }

    final inline = <ResponsiveActionBarAction>[];
    final overflow = <ResponsiveActionBarAction>[];
    for (var i = 0; i < sortedIndices.length; i++) {
      if (i < inlineCount) {
        inline.add(actions[sortedIndices[i]]);
      } else {
        overflow.add(actions[sortedIndices[i]]);
      }
    }

    return _ActionSplit(inline, overflow);
  }

  static double _measureText({
    required String text,
    required TextStyle? style,
    required TextScaler textScaler,
    required TextDirection textDirection,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
    );
    painter.layout();
    return painter.width;
  }

  static const double _primaryHorizontalPadding = 48;
  static const double _actionHorizontalOverhead = 56;
  static const double _overflowButtonWidth = 48;
  static const double _inlineSpacing = 8;
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
