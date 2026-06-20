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

  // Layout constants tuned to Material 3 default button metrics. They are used
  // only to decide which actions fit inline; actual rendering uses the real
  // Material widgets, so the visible result may differ slightly.
  static const double _iconGap = 8;
  static const double _iconSize = 24;
  static const double _actionButtonHorizontalPadding = 22;
  static const double _actionGap = 8;
  static const double _primaryButtonHorizontalPadding = 24;
  static const double _overflowButtonWidth = 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final textStyle = theme.textTheme.labelLarge ?? const TextStyle();

    final ordered = _sortByPriority(actions);
    final actionWidths = <ResponsiveActionBarAction, double>{
      for (final action in ordered) action: _measureActionWidth(action.label, textStyle, textScaler),
    };
    final primaryWidth = _measurePrimaryWidth(primaryLabel, textStyle, textScaler);

    return LayoutBuilder(
      builder: (context, constraints) {
        final split = _splitActions(
          maxWidth: constraints.maxWidth,
          orderedActions: ordered,
          actionWidths: actionWidths,
          primaryWidth: primaryWidth,
        );
        return Row(
          children: <Widget>[
            for (final action in split.inline)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: _actionGap),
                child: _ActionButton(action: action),
              ),
            if (split.overflow.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: _actionGap),
                child: _OverflowMenu(
                  actions: split.overflow,
                  tooltip: overflowTooltip,
                ),
              ),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  key: primaryButtonKey,
                  onPressed: onPrimaryPressed,
                  child: Text(primaryLabel, overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<ResponsiveActionBarAction> _sortByPriority(
    List<ResponsiveActionBarAction> input,
  ) {
    final indexed = <_IndexedAction>[
      for (var i = 0; i < input.length; i++) _IndexedAction(input[i], i),
    ];
    indexed.sort((a, b) {
      final byPriority = a.action.priority.compareTo(b.action.priority);
      if (byPriority != 0) return byPriority;
      return a.index.compareTo(b.index);
    });
    return [for (final item in indexed) item.action];
  }

  double _measureActionWidth(
    String label,
    TextStyle textStyle,
    TextScaler textScaler,
  ) {
    final labelWidth = _measureLabelWidth(label, textStyle, textScaler);
    return _actionButtonHorizontalPadding +
        _iconSize +
        _iconGap +
        labelWidth +
        _actionButtonHorizontalPadding;
  }

  double _measurePrimaryWidth(
    String label,
    TextStyle textStyle,
    TextScaler textScaler,
  ) {
    final labelWidth = _measureLabelWidth(label, textStyle, textScaler);
    return _primaryButtonHorizontalPadding +
        labelWidth +
        _primaryButtonHorizontalPadding;
  }

  double _measureLabelWidth(
    String label,
    TextStyle textStyle,
    TextScaler textScaler,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  _ActionSplit _splitActions({
    required double maxWidth,
    required List<ResponsiveActionBarAction> orderedActions,
    required Map<ResponsiveActionBarAction, double> actionWidths,
    required double primaryWidth,
  }) {
    if (orderedActions.isEmpty) {
      return const _ActionSplit(
        <ResponsiveActionBarAction>[],
        <ResponsiveActionBarAction>[],
      );
    }
    if (!maxWidth.isFinite) {
      return _ActionSplit(
        orderedActions,
        const <ResponsiveActionBarAction>[],
      );
    }

    // First try: assume no overflow button, place every action inline.
    final noOverflow = _greedyFit(
      orderedActions: orderedActions,
      actionWidths: actionWidths,
      maxActionBudget: maxWidth - primaryWidth,
    );
    if (noOverflow.overflow.isEmpty) {
      return noOverflow;
    }

    // Some actions do not fit inline. Reserve space for the overflow button
    // and re-partition so lower-priority actions go to overflow.
    final overflowReserved = _overflowButtonWidth + _actionGap;
    return _greedyFit(
      orderedActions: orderedActions,
      actionWidths: actionWidths,
      maxActionBudget: maxWidth - primaryWidth - overflowReserved,
    );
  }

  _ActionSplit _greedyFit({
    required List<ResponsiveActionBarAction> orderedActions,
    required Map<ResponsiveActionBarAction, double> actionWidths,
    required double maxActionBudget,
  }) {
    final inline = <ResponsiveActionBarAction>[];
    final overflow = <ResponsiveActionBarAction>[];
    var used = 0.0;
    for (final action in orderedActions) {
      final width = actionWidths[action]!;
      final candidate = used + width + _actionGap;
      if (candidate <= maxActionBudget) {
        inline.add(action);
        used = candidate;
      } else {
        overflow.add(action);
      }
    }
    return _ActionSplit(inline, overflow);
  }
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
