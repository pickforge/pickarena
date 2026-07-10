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

  /// Orders actions so that lower `priority` values come first, preserving the
  /// original input order for ties (a stable ordering by priority).
  List<ResponsiveActionBarAction> _stableByPriority(
    List<ResponsiveActionBarAction> source,
  ) {
    final indexed = <MapEntry<int, ResponsiveActionBarAction>>[];
    for (var i = 0; i < source.length; i++) {
      indexed.add(MapEntry(i, source[i]));
    }
    indexed.sort((a, b) {
      final byPriority = a.value.priority.compareTo(b.value.priority);
      if (byPriority != 0) return byPriority;
      return a.key.compareTo(b.key);
    });
    return [for (final entry in indexed) entry.value];
  }

  /// Measures the rendered width of `text` using the same text style as the
  /// bar's buttons, honoring the ambient text scaler.
  double _measureText(
    String text,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: scaler,
      textDirection: direction,
    )..layout();
    return painter.width;
  }

  _ActionSplit _splitActions(BuildContext context, double maxWidth) {
    final ordered = _stableByPriority(actions);

    // No width bound: treat as wide and keep everything inline.
    if (!maxWidth.isFinite) {
      return _ActionSplit(ordered, const <ResponsiveActionBarAction>[]);
    }

    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final labelStyle =
        theme.textTheme.labelLarge ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w500);

    // Horizontal padding (12 start + 16 end) + icon (24) + spacing (8) = 60,
    // with the Material minimum button width of 64 honored as a floor.
    double actionWidth(ResponsiveActionBarAction action) {
      return math.max(64.0, 60.0 + _measureText(action.label, labelStyle, scaler, direction));
    }

    // FilledButton horizontal padding (24 + 24) = 48, with a 64 minimum floor.
    final primaryWidth = math.max(
      64.0,
      48.0 + _measureText(primaryLabel, labelStyle, scaler, direction),
    );

    // Preferred layout: primary CTA plus every secondary action inline.
    final preferredWidth = primaryWidth +
        ordered.fold<double>(0.0, (sum, action) => sum + actionWidth(action));

    if (preferredWidth <= maxWidth) {
      // Everything fits comfortably: keep all secondary actions inline and do
      // not show an overflow control.
      return _ActionSplit(ordered, const <ResponsiveActionBarAction>[]);
    }

    // Not enough room: keep the primary CTA directly visible and move every
    // secondary action behind the overflow menu so nothing overflows and no
    // action is rendered twice.
    return _ActionSplit(
      const <ResponsiveActionBarAction>[],
      ordered,
    );
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