import 'dart:math' as math;

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
        final hasSecondaryControls =
            split.inline.isNotEmpty || split.overflow.isNotEmpty;

        return Row(
          children: <Widget>[
            for (final action in split.inline)
              Flexible(child: _ActionButton(action: action)),
            if (split.overflow.isNotEmpty)
              _OverflowMenu(actions: split.overflow, tooltip: overflowTooltip),
            const Spacer(),
            if (hasSecondaryControls) const SizedBox(width: _groupSpacing),
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
    final orderedActions = _orderedActions();
    if (orderedActions.isEmpty || !maxWidth.isFinite) {
      return _ActionSplit(
        orderedActions,
        const <ResponsiveActionBarAction>[],
      );
    }

    final primaryWidth = _primaryButtonWidth(context, primaryLabel);
    final allInlineWidth = orderedActions.fold<double>(
          primaryWidth + _groupSpacing,
          (width, action) => width + _actionButtonWidth(context, action.label),
        );

    if (allInlineWidth <= maxWidth) {
      return _ActionSplit(
        orderedActions,
        const <ResponsiveActionBarAction>[],
      );
    }

    final primaryReserve = math.max(primaryWidth, maxWidth / 2);
    final availableForInline =
        maxWidth - primaryReserve - _overflowButtonWidth - _groupSpacing;
    final inline = <ResponsiveActionBarAction>[];
    var usedWidth = 0.0;

    for (final action in orderedActions) {
      final actionWidth = _actionButtonWidth(context, action.label);
      if (usedWidth + actionWidth > availableForInline) {
        break;
      }
      inline.add(action);
      usedWidth += actionWidth;
    }

    return _ActionSplit(
      inline,
      orderedActions.skip(inline.length).toList(growable: false),
    );
  }

  List<ResponsiveActionBarAction> _orderedActions() {
    final indexedActions = <_IndexedAction>[
      for (var index = 0; index < actions.length; index++)
        _IndexedAction(actions[index], index),
    ]..sort((a, b) {
        final priorityOrder = a.action.priority.compareTo(b.action.priority);
        if (priorityOrder != 0) {
          return priorityOrder;
        }
        return a.index.compareTo(b.index);
      });

    return <ResponsiveActionBarAction>[
      for (final indexedAction in indexedActions) indexedAction.action,
    ];
  }
}

const double _groupSpacing = 16;
const double _overflowButtonWidth = 48;
const double _buttonMinWidth = 64;
const double _primaryHorizontalPadding = 48;
const double _actionHorizontalPadding = 40;
const double _actionIconWidth = 24;
const double _actionIconGap = 8;

class _IndexedAction {
  const _IndexedAction(this.action, this.index);

  final ResponsiveActionBarAction action;
  final int index;
}

double _primaryButtonWidth(BuildContext context, String label) {
  return math.max(
    _buttonMinWidth,
    _textWidth(context, label) + _primaryHorizontalPadding,
  );
}

double _actionButtonWidth(BuildContext context, String label) {
  return math.max(
    _buttonMinWidth,
    _textWidth(context, label) +
        _actionIconWidth +
        _actionIconGap +
        _actionHorizontalPadding,
  );
}

double _textWidth(BuildContext context, String text) {
  final style = Theme.of(context).textTheme.labelLarge ??
      const TextStyle(fontSize: 14);
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();

  return painter.width;
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

        return IconButton(
          key: ResponsiveActionBar.overflowButtonKey,
          tooltip: tooltip,
          icon: const Icon(Icons.more_horiz),
          onPressed: toggleMenu,
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
