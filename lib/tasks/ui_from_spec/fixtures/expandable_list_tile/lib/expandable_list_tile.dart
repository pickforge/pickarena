import 'package:flutter/material.dart';

class ExpandableListTile extends StatefulWidget {
  const ExpandableListTile({
    super.key,
    required this.title,
    required this.details,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
  });

  final Widget title;
  final Widget details;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  @override
  State<ExpandableListTile> createState() => _ExpandableListTileState();
}

class _ExpandableListTileState extends State<ExpandableListTile> {
  @override
  Widget build(BuildContext context) {
    // TODO: build a tile that:
    // - Always shows `title` and a trailing chevron icon.
    // - Tapping the row toggles expansion.
    // - Rotates the chevron 180 degrees on expand using a RotationTransition (or similar).
    // - When expanded, shows `details` below the title row.
    // - Calls `onExpansionChanged` whenever the expanded state flips.
    return const SizedBox.shrink();
  }
}
