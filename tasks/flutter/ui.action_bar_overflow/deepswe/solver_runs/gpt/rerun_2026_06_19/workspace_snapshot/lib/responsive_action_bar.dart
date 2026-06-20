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

  _ActionSplit _splitActions(BuildContext context, double maxWidth) {
    if (actions.isEmpty) {
      return const _ActionSplit(
        <ResponsiveActionBarAction>[],
        <ResponsiveActionBarAction>[],
      );
    }

    final rankedActions = _rankedActions();
    final textScale = _textScaleFactor(context);
    final primaryWidth = _primaryWidth * textScale;
    final actionWidth = _actionWidth * textScale;
    final compactWidth = _compactWidth * textScale;

    if (!maxWidth.isFinite ||
        maxWidth >= primaryWidth + actionWidth * actions.length) {
      return _ActionSplit(actions, const <ResponsiveActionBarAction>[]);
    }

    if (maxWidth < compactWidth) {
      return _ActionSplit(const <ResponsiveActionBarAction>[], rankedActions);
    }

    final availableWidth = maxWidth - primaryWidth - _overflowWidth;
    var inlineCount = (availableWidth / actionWidth).floor();
    if (inlineCount < 0) {
      inlineCount = 0;
    }
    if (inlineCount >= rankedActions.length) {
      inlineCount = rankedActions.length - 1;
    }

    return _ActionSplit(
      rankedActions.take(inlineCount).toList(growable: false),
      rankedActions.skip(inlineCount).toList(growable: false),
    );
  }

  List<ResponsiveActionBarAction> _rankedActions() {
    final indexedActions = <_IndexedAction>[
      for (var index = 0; index < actions.length; index++)
        _IndexedAction(actions[index], index),
    ];
    indexedActions.sort((a, b) {
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

  double _textScaleFactor(BuildContext context) {
    const baseFontSize = 14.0;
    final scaledFontSize = MediaQuery.textScalerOf(context).scale(baseFontSize);
    if (!scaledFontSize.isFinite || scaledFontSize <= 0) {
      return 1;
    }
    return scaledFontSize / baseFontSize;
  }

  static const double _primaryWidth = 136;
  static const double _actionWidth = 96;
  static const double _overflowWidth = 48;
  static const double _compactWidth = 360;
}

class _IndexedAction {
  const _IndexedAction(this.action, this.index);

  final ResponsiveActionBarAction action;
  final int index;
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
